#!/usr/bin/env python3
"""Ask Overpass whether each of our waterfalls has any water near it.

A waterfall standing nowhere near a mapped stream is usually a bad
coordinate, so this is a cheap way to find the ones worth looking at.
script/check/water_check.py answers the same question for one point; this answers
it for hundreds without needing to be watched.

Two things make that practical. Overpass will take many `around` filters in
one query and answer `out count` for each in turn, so a few hundred points
become a couple of dozen round trips rather than a few hundred. And the
batches run three at a time, each opening on a different mirror.

Every answer is appended to the results file as it lands, and a rerun skips
whatever is already there -- so this can be interrupted, and a sweep that
died at 42 of 396 picks up at 43.

    python3 script/check/water_sweep.py --single-source
    python3 script/check/water_sweep.py --all
    python3 script/check/water_sweep.py --dry          # just list what's been found

Add --radius to widen the search; the results file records the radius each
answer was found at, so widening it re-asks rather than trusting the old no.
"""
import concurrent.futures
import hashlib
import os
import subprocess
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'import', 'spider'))
import overpass

RESULTS = 'data/water-sweep.tsv'
DEFAULT_RADIUS_M = 75
BATCH = 25
WORKERS = 3

# Looking Glass Falls, which is on Looking Glass Creek and always will be.
# It rides along in every batch: a mirror that answers "no water" for it has
# answered wrong for the whole batch, and one of them did. Without this the
# wrong answer is indistinguishable from a real result, and gets cached.
CONTROL = (35.2962, -82.7687)


def features(which):
    where = {
        'single-source': """
            JOIN coordinate_confidence cc ON cc.feature_id = f.id
            WHERE cc.tier = 'single source' AND f.deprecated_reason IS NULL""",
        'all': "WHERE f.deprecated_reason IS NULL",
    }[which]
    sql = """
        SELECT f.id, f.name, l.latitude, l.longitude
        FROM features f
        JOIN locations l ON l.id = f.feature_location_id
        %s
        ORDER BY f.id
    """ % where
    db = os.environ.get('DATABASE_URL', 'wc_journey_db')
    out = subprocess.run(['psql', db, '-t', '-A', '-F', '\t', '-c', sql],
                         capture_output=True, text=True, check=True).stdout
    rows = []
    for line in out.strip().splitlines():
        if line.strip():
            fid, name, lat, lon = line.split('\t')
            rows.append((int(fid), name, float(lat), float(lon)))
    return rows


def done(radius):
    """Feature ids already answered at this radius."""
    if not os.path.exists(RESULTS):
        return set()
    seen = set()
    for line in open(RESULTS, encoding='utf-8'):
        parts = line.rstrip('\n').split('\t')
        if len(parts) >= 4 and parts[3] == str(radius):
            seen.add(int(parts[0]))
    return seen


def ask(batch, radius, worker):
    """One query covering a batch of points, returning a count per point.

    Overpass emits `out count` results in the order the statements appear,
    so position in the answer is what ties a count back to a waterfall.
    """
    points = [(lat, lon) for _, _, lat, lon in batch] + [CONTROL]
    parts = ['[out:json][timeout:300];']
    for i, (lat, lon) in enumerate(points):
        parts.append(
            '(way["waterway"](around:{r},{a},{o});'
            'way["natural"="water"](around:{r},{a},{o});'
            'relation["natural"="water"](around:{r},{a},{o});)->.s{i};'
            .format(r=radius, a=lat, o=lon, i=i))
        parts.append('.s%d out count;' % i)
    q = '\n'.join(parts)
    name = 'water-%dm-%s' % (radius, hashlib.sha1(q.encode()).hexdigest()[:12])
    data = overpass.query(q, name, start=worker)

    counts = [int(el.get('tags', {}).get('total', 0))
              for el in data.get('elements', []) if el.get('type') == 'count']
    if len(counts) != len(points):
        raise RuntimeError('asked about %d points, got %d counts back'
                           % (len(points), len(counts)))
    if counts[-1] == 0:
        # Don't keep an answer the control says is wrong, or the next run
        # reads it straight back out of the cache.
        os.remove(os.path.join(overpass.CACHE_DIR, name + '.json'))
        raise RuntimeError('control point came back dry; answer discarded')
    return counts[:-1]


def main(argv):
    if '--dry' in argv:
        if not os.path.exists(RESULTS):
            print('Nothing swept yet.')
            return 0
        for line in open(RESULTS, encoding='utf-8'):
            fid, name, near, _ = line.rstrip('\n').split('\t')
            if near == '0':
                print('%6s  %s' % (fid, name))
        return 0

    which = 'all' if '--all' in argv else 'single-source'
    radius = DEFAULT_RADIUS_M
    if '--radius' in argv:
        radius = int(argv[argv.index('--radius') + 1])

    rows = features(which)
    skip = done(radius)
    todo = [r for r in rows if r[0] not in skip]
    print('%d %s waterfalls, %d already answered at %dm, %d to ask about'
          % (len(rows), which, len(rows) - len(todo), radius, len(todo)))
    if not todo:
        return 0

    batches = [todo[i:i + BATCH] for i in range(0, len(todo), BATCH)]
    out = open(RESULTS, 'a', encoding='utf-8')
    answered = dry = 0

    with concurrent.futures.ThreadPoolExecutor(WORKERS) as pool:
        futures = {pool.submit(ask, b, radius, i): b
                   for i, b in enumerate(batches)}
        for fut in concurrent.futures.as_completed(futures):
            batch = futures[fut]
            try:
                counts = fut.result()
            except Exception as e:
                # One batch failing shouldn't cost the other twenty-odd.
                # Its points simply stay unanswered, and the next run asks.
                print('  batch of %d failed: %s' % (len(batch), e),
                      file=sys.stderr)
                continue
            for (fid, name, _, _), n in zip(batch, counts):
                out.write('%d\t%s\t%d\t%d\n' % (fid, name, n, radius))
                answered += 1
                dry += n == 0
            out.flush()
            print('  %d/%d answered, %d with no water nearby'
                  % (answered, len(todo), dry))

    out.close()
    print('Done. %s holds the answers; --dry lists the ones to look at.'
          % RESULTS)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
