#!/usr/bin/env python3
"""Check whether a point sits near an OSM-mapped waterway or water body.

Uses Overpass's own `around` filter to do the distance search server-side --
no local point-in-polygon math needed, since most mountain streams are mapped
as lines (waterway=stream/river), not polygons, and `around` handles both.

Usage:
    python3 script/check/water_check.py LAT LON [RADIUS_METERS]
    python3 script/check/water_check.py --feature-id 398
    python3 script/check/water_check.py --single-source     # every single-source waterfall

Uses DATABASE_URL for the --feature-id / --single-source modes, same
default as script/migrate (falls back to the local wc_journey_db).
"""
import json
import os
import subprocess
import sys
import time
import urllib.request

OVERPASS_URL = 'https://overpass-api.de/api/interpreter'
DEFAULT_RADIUS_M = 75
CACHE_DIR = 'data/spider-cache/overpass-water'


def query_overpass(lat, lon, radius_m):
    q = f"""
    [out:json][timeout:25];
    (
      way["waterway"](around:{radius_m},{lat},{lon});
      way["natural"="water"](around:{radius_m},{lat},{lon});
      relation["natural"="water"](around:{radius_m},{lat},{lon});
    );
    out tags;
    """
    os.makedirs(CACHE_DIR, exist_ok=True)
    cache_path = os.path.join(CACHE_DIR, f'{lat}_{lon}_{radius_m}.json')
    if os.path.exists(cache_path):
        return json.load(open(cache_path))
    req = urllib.request.Request(
        OVERPASS_URL, data=('data=' + q).encode(), method='POST',
        headers={'User-Agent': 'wanderfall-water-check/1.0 (jw@mustmodify.com)'})
    # The public instance is shared and occasionally 504s under load --
    # nothing wrong with the query. Back off and retry rather than treating
    # that as a real "no water here" result.
    delay = 5
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                data = json.load(resp)
            break
        except urllib.error.HTTPError as e:
            if e.code not in (429, 504) or attempt == 4:
                raise
            print(f'  ({e.code}, retrying in {delay}s...)', file=sys.stderr)
            time.sleep(delay)
            delay *= 2
        except urllib.error.URLError as e:
            # A dropped connection or DNS blip, not the server saying
            # anything about the query -- worth a retry same as a 504.
            if attempt == 4:
                raise
            print(f'  (network error {e.reason}, retrying in {delay}s...)', file=sys.stderr)
            time.sleep(delay)
            delay *= 2
    json.dump(data, open(cache_path, 'w'))
    time.sleep(2)  # be polite: one call at a time, cached after that
    return data


def near_water(lat, lon, radius_m=DEFAULT_RADIUS_M):
    data = query_overpass(lat, lon, radius_m)
    elements = data.get('elements', [])
    names = []
    for el in elements:
        tags = el.get('tags', {})
        label = tags.get('name') or tags.get('waterway') or tags.get('natural') or el.get('type')
        names.append(label)
    return len(elements) > 0, names


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        sys.exit(1)

    if args[0] in ('--feature-id', '--single-source'):
        # Shells out to psql rather than adding a psycopg2 dependency --
        # every other one-off script here does the same.
        db = os.environ.get('DATABASE_URL', 'wc_journey_db')
        if args[0] == '--feature-id':
            sql = f"""
                SELECT f.id, f.name, l.latitude, l.longitude
                FROM features f JOIN locations l ON l.id = f.feature_location_id
                WHERE f.id = {int(args[1])}
            """
        else:
            sql = """
                SELECT f.id, f.name, l.latitude, l.longitude
                FROM features f
                JOIN locations l ON l.id = f.feature_location_id
                JOIN coordinate_confidence cc ON cc.feature_id = f.id
                WHERE cc.tier = 'single source' AND f.deprecated_reason IS NULL
                ORDER BY f.name
            """
        out = subprocess.run(
            ['psql', db, '-t', '-A', '-F', '\t', '-c', sql],
            capture_output=True, text=True, check=True).stdout
        rows = []
        for line in out.strip().splitlines():
            if not line.strip():
                continue
            fid, name, lat, lon = line.split('\t')
            rows.append((int(fid), name, lat, lon))
        for fid, name, lat, lon in rows:
            ok, names = near_water(float(lat), float(lon))
            flag = 'OK  ' if ok else 'DRY '
            print(f'{flag} {fid:>5}  {name:<45} {lat},{lon}  {"; ".join(n for n in names if n) or "-"}')
        return

    lat, lon = float(args[0]), float(args[1])
    radius = float(args[2]) if len(args) > 2 else DEFAULT_RADIUS_M
    ok, names = near_water(lat, lon, radius)
    print('near water:' if ok else 'NOT near water:', ok)
    if names:
        print('  ' + '; '.join(n for n in names if n))


if __name__ == '__main__':
    main()
