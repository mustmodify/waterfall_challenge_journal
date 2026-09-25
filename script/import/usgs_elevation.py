#!/usr/bin/env python3
"""Pull ground elevation for every feature we have a coordinate for, from the
USGS Elevation Point Query Service.

Why: elevation_ft is only populated for 116 of 989 features, all from
ncwaterfalls, which makes the map's elevation filter a proxy for "which
records happen to carry this field" rather than a filter on elevation. USGS
covers anything with a coordinate, is free and keyless, and is already a
named source for this project.

What the number means: the ground elevation at the coordinate we hold. For a
waterfall that is usually the base or the brink, so the reading inherits
whatever error is in our coordinate. It is a reading about our point, not an
independent survey of the waterfall.

Spot-checked against the six waterfalls where ncwaterfalls already gave us an
elevation: all agreed within 2%. Ours are round (2740, 3180, 3360), USGS's are
precise, so under the rounding heuristic in ARCHITECTURE.md USGS reads as
exact and wins a close comparison.

Cache first, parse second -- nothing here re-fetches what it already has, so
it is safe to stop and restart, which matters because this makes ~900 calls.

    python3 script/import/usgs_elevation.py fetch      # populate the cache
    python3 script/import/usgs_elevation.py extract    # cache -> migration SQL
"""
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

EPQS = 'https://epqs.nationalmap.gov/v1/json'
CACHE = 'data/spider-cache/usgs-epqs'
DB = os.environ.get('DATABASE_URL', 'wc_journey_db')
PAUSE = 0.4
OUT = 'db/migrations/097_usgs_elevations.sql'


def targets():
    """Every non-deprecated feature with a coordinate."""
    sql = """
        SELECT f.id, l.latitude, l.longitude
        FROM features f JOIN locations l ON l.id = f.feature_location_id
        WHERE f.deprecated_reason IS NULL
        ORDER BY f.id
    """
    out = subprocess.run(['psql', DB, '-t', '-A', '-F', '\t', '-c', sql],
                         capture_output=True, text=True, check=True).stdout
    rows = []
    for line in out.strip().splitlines():
        if not line.strip():
            continue
        fid, lat, lon = line.split('\t')
        rows.append((int(fid), lat, lon))
    return rows


def fetch():
    os.makedirs(CACHE, exist_ok=True)
    rows = targets()
    done = hit = miss = 0
    for fid, lat, lon in rows:
        path = os.path.join(CACHE, f'{fid}.json')
        if os.path.exists(path):
            hit += 1
            continue
        url = f'{EPQS}?x={lon}&y={lat}&units=Feet&wkid=4326&includeDate=false'
        req = urllib.request.Request(url, headers={
            'User-Agent': 'wanderfall-elevation/1.0 (jw@mustmodify.com)'})
        delay = 3
        for attempt in range(4):
            try:
                with urllib.request.urlopen(req, timeout=30) as resp:
                    body = json.load(resp)
                break
            except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as e:
                if attempt == 3:
                    print(f'  {fid}: giving up ({e})', file=sys.stderr)
                    body = None
                    break
                time.sleep(delay)
                delay *= 2
        if body is None:
            miss += 1
            continue
        # Record what we asked alongside what came back, so the cache alone is
        # enough to audit a reading later.
        body['_query'] = {'feature_id': fid, 'lat': lat, 'lon': lon}
        with open(path, 'w') as fh:
            json.dump(body, fh)
        done += 1
        time.sleep(PAUSE)
    print(f'fetched {done}, already cached {hit}, failed {miss}, total {len(rows)}')


def lit(s):
    return "'" + str(s).replace("'", "''") + "'"


def extract():
    files = sorted(f for f in os.listdir(CACHE) if f.endswith('.json'))
    rows = []
    for name in files:
        # A response can land empty if the connection dropped mid-write. Skip
        # it and say so rather than failing the whole extract -- deleting the
        # file lets a later fetch retry just that one.
        try:
            body = json.load(open(os.path.join(CACHE, name)))
        except (ValueError, OSError) as e:
            print(f'  unreadable cache file {name}: {e}', file=sys.stderr)
            continue
        q = body.get('_query') or {}
        val = body.get('value')
        if val is None:
            continue
        try:
            feet = round(float(val))
        except (TypeError, ValueError):
            continue
        # The service answers -1000000 for a point outside its coverage.
        if feet < -100 or feet > 7000:
            print(f'  skipping {name}: implausible {feet} ft', file=sys.stderr)
            continue
        rows.append((int(q['feature_id']), feet, q.get('lat'), q.get('lon')))

    with open(OUT, 'w') as fh:
        fh.write(f"""-- Ground elevation from the USGS Elevation Point Query Service for every
-- feature we hold a coordinate for. Raw responses are cached under
-- {CACHE}/, one file per feature, each carrying the
-- coordinate it was asked about so a reading can be audited later.
--
-- Before this, elevation_ft existed for 116 of 989 features, all from
-- ncwaterfalls -- so the map's elevation filter was really a filter on
-- "which records carry this field". This covers everything with a
-- coordinate.
--
-- The reading is the ground elevation at OUR coordinate, so it inherits any
-- error in that coordinate. It is a statement about the point we hold, not an
-- independent survey of the waterfall. Spot-checked against the six
-- waterfalls where ncwaterfalls already gave an elevation: agreement within
-- 2% on all six.
--
-- Claims are recorded unaccepted. Arbitration is a separate decision, and
-- ncwaterfalls already holds accepted values for 116 of these.

BEGIN;

INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
""")
        vals = []
        for fid, feet, lat, lon in rows:
            note = (f'Ground elevation at {lat}, {lon}, the coordinate we hold for this '
                    f'feature. Queried once and cached; see {CACHE}/{fid}.json.')
            vals.append(f"({lit(f'usgs|{fid}|epqs')}, {fid}, 'usgs', "
                        f"'https://epqs.nationalmap.gov/v1/json', true, {lit(note)})")
        fh.write(',\n'.join(vals))
        fh.write("\nON CONFLICT (ref) DO NOTHING;\n\n")

        fh.write("INSERT INTO claims (group_id, feature_id, field, value, accepted)\n"
                 "SELECT g.id, g.feature_id, 'elevation_ft', v.feet::jsonb, false\n"
                 "FROM (VALUES\n")
        fh.write(',\n'.join(f"  ({lit(f'usgs|{fid}|epqs')}, '{feet}')" for fid, feet, _, _ in rows))
        fh.write("\n) AS v(ref, feet)\nJOIN claim_groups g ON g.ref = v.ref;\n\n")

        fh.write("INSERT INTO schema_migrations (filename) VALUES "
                 f"('{os.path.basename(OUT)}') ON CONFLICT (filename) DO NOTHING;\n\nCOMMIT;\n")
    print(f'wrote {OUT}: {len(rows)} elevations from {len(files)} cached responses')


if __name__ == '__main__':
    cmd = sys.argv[1] if len(sys.argv) > 1 else ''
    if cmd == 'fetch':
        fetch()
    elif cmd == 'extract':
        extract()
    else:
        print(__doc__)
        sys.exit(1)
