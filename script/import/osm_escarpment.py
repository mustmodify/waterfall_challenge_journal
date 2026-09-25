#!/usr/bin/env python3
"""Every OpenStreetMap waterfall in the escarpment, and the creek it sits on.

The extract we have been working from is three Overpass Turbo exports whose
box stops at -84.234 and -81.515, so 181 waterfall nodes sit outside it while
our own features run from -85.600 to -78.910. It also asked only for nodes,
which is why we have no watercourse from OpenStreetMap at all -- a waterfall
node's creek is the name on the way it belongs to, and the query never asked
for parents.

This asks for both, over the whole escarpment, in tiles. One query for the
region times out on a busy mirror and has to be thrown away whole; fourteen
smaller ones cache as they land, so an interrupted run resumes.

A parent way is a segment, not a creek -- Alarka Creek is sixty ways and Big
Creek is ninety-six (see MATCHING.md 9.7). That does not matter here, because
every segment of a creek carries the creek's name, and the name is what we
want. It does mean a node can sit on two ways, and where those disagree both
names are kept rather than one being picked.

    python3 script/import/osm_escarpment.py

Writes data/osm-escarpment.tsv and says which of the nodes we already hold.
Every tile is cached, so running it again is a re-read rather than a refetch.
"""
import json
import math
import os
import subprocess
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'spider'))
import overpass

SOUTH, WEST, NORTH, EAST = 34.50, -85.80, 36.70, -78.80
LAT_STEP, LON_STEP = 1.1, 1.0
RESULTS = 'data/osm-escarpment.tsv'

# Far enough to survive the difference between two people's GPS readings of
# the same drop, close enough that the next waterfall upstream is a different
# node. The same figure MATCHING.md uses for a node-to-feature match.
MATCH_M = 100


def tiles():
    lat = SOUTH
    while lat < NORTH:
        lon = WEST
        while lon < EAST:
            yield (round(lat, 2), round(lon, 2),
                   round(min(lat + LAT_STEP, NORTH), 2),
                   round(min(lon + LON_STEP, EAST), 2))
            lon += LON_STEP
        lat += LAT_STEP


# Looking Glass Falls, which has been a node since 2008. Every tile asks for
# it by id as well as for its own box, because a mirror under load can answer
# 200 with an empty element list -- a wrong answer shaped exactly like a tile
# with no waterfalls in it. Six tiles came back that way on the first run,
# Transylvania County among them, and the emptiness cached.
CONTROL_NODE = 309814375


def fetch(tile, worker):
    s, w, n, e = tile
    box = '%s,%s,%s,%s' % (s, w, n, e)
    q = ('[out:json][timeout:600];\n'
         '(node["waterway"="waterfall"](%s);\n'
         ' node["natural"="waterfall"](%s);)->.falls;\n'
         '.falls out body;\n'
         'way(bn.falls)["waterway"];\n'
         'out body;\n'
         'node(%d)->.control;\n'
         '.control out count;\n' % (box, box, CONTROL_NODE))
    name = 'escarpment-%s' % box.replace(',', '_').replace('-', 'm')
    data = overpass.query(q, name, timeout=600, start=worker)

    seen = [el for el in data.get('elements', []) if el['type'] == 'count']
    if len(seen) != 1 or int(seen[0].get('tags', {}).get('nodes', 0)) != 1:
        os.remove(os.path.join(overpass.CACHE_DIR, name + '.json'))
        raise RuntimeError('control node missing; answer discarded')
    return data


def collect(rounds=3):
    """Every waterfall node in the region, with the names of its parent ways.

    Tiles share their edges, so a node can arrive twice; the node id decides
    identity and the second copy is dropped.

    A tile the mirrors refuse is retried on a later round rather than
    abandoning the run, since an answered tile is cached and costs nothing to
    pass over again.
    """
    nodes, parents = {}, {}
    left = list(enumerate(tiles()))
    for attempt in range(rounds):
        failed = []
        for i, tile in left:
            try:
                data = fetch(tile, i + attempt)
            except Exception as e:
                print('  %s: %s' % (tile, e), file=sys.stderr)
                failed.append((i, tile))
                continue
            ways = []
            for el in data.get('elements', []):
                if el['type'] == 'node':
                    nodes.setdefault(el['id'], el)
                elif el['type'] == 'way':
                    ways.append(el)
            for w in ways:
                nm = (w.get('tags') or {}).get('name')
                if not nm:
                    continue
                for nid in w.get('nodes', []):
                    parents.setdefault(nid, set()).add(nm)
            print('  %s: %d nodes so far' % (tile, len(nodes)), file=sys.stderr)
        left = failed
        if not left:
            break
    if left:
        raise RuntimeError('%d tiles never answered: %s'
                           % (len(left), [t for _, t in left]))
    return nodes, parents


def ours():
    sql = """
        SELECT f.id, f.name, l.latitude, l.longitude
        FROM features f
        JOIN locations l ON l.id = f.feature_location_id
        WHERE f.deprecated_reason IS NULL
    """
    db = os.environ.get('DATABASE_URL', 'wc_journey_db')
    out = subprocess.run(['psql', db, '-t', '-A', '-F', '\t', '-c', sql],
                         capture_output=True, text=True, check=True).stdout
    rows = []
    for line in out.strip().splitlines():
        fid, name, lat, lon = line.split('\t')
        rows.append((int(fid), name, float(lat), float(lon)))
    return rows


def metres(a_lat, a_lon, b_lat, b_lon):
    dlat = (b_lat - a_lat) * 111320.0
    dlon = (b_lon - a_lon) * 111320.0 * math.cos(math.radians(a_lat))
    return math.hypot(dlat, dlon)


def nearest(lat, lon, rows):
    """Our closest feature, searched only within a degree of latitude."""
    best, best_m = None, None
    for fid, name, flat, flon in rows:
        if abs(flat - lat) > 0.01 or abs(flon - lon) > 0.012:
            continue
        m = metres(lat, lon, flat, flon)
        if best_m is None or m < best_m:
            best, best_m = (fid, name), m
    return best, best_m


def main(argv):
    nodes, parents = collect()
    rows = ours()
    out = open(RESULTS, 'w', encoding='utf-8')
    out.write('node_id\tosm_name\tlat\tlon\twatercourse\tfeature_id\tfeature_name\tmetres\n')

    matched = unmatched = with_creek = 0
    for nid, el in sorted(nodes.items()):
        lat, lon = el['lat'], el['lon']
        osm_name = (el.get('tags') or {}).get('name', '')
        creek = ' | '.join(sorted(parents.get(nid, ())))
        hit, m = nearest(lat, lon, rows)
        if hit and m <= MATCH_M:
            matched += 1
            fid, fname, dist = hit[0], hit[1], '%.0f' % m
        else:
            unmatched += 1
            fid, fname, dist = '', '', ''
        with_creek += bool(creek)
        out.write('%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n'
                  % (nid, osm_name, lat, lon, creek, fid, fname, dist))
    out.close()

    print('%d waterfall nodes in the escarpment' % len(nodes))
    print('%d sit on a named way, so OpenStreetMap knows their creek' % with_creek)
    print('%d match a feature of ours within %dm' % (matched, MATCH_M))
    print('%d do not, and are candidates for new features' % unmatched)
    print('Written to %s' % RESULTS)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
