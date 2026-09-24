"""One Overpass query at a time, patiently, with the answer kept on disk.

The public Overpass instances are shared and free, so a 504 or a 429 usually
means somebody else is mid-query, not that there is anything wrong with ours.
jw: "you need to try a couple of times before it works sometimes. Just add a
few second delay."

So: back off, try again, and try a different mirror before giving up. The
mirrors run the same software over the same planet file, so rotating is
politeness rather than shopping for an answer -- it spreads the load instead
of hammering one host until it relents.

Every raw response is written to disk before anything reads it, which is the
rule for every source here: cache first, parse afterwards. A query that took
four minutes and two mirrors to answer should never have to be asked twice,
and an extractor should be rerunnable against a file rather than against the
internet.

    from overpass import query
    data = query(text, name='escarpment-waterfalls')

Or from the shell, which is the useful form when checking something once:

    python3 script/spider/overpass.py my.overpass name-for-the-cache
"""
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# Same software, same data. Listed slowest-to-refuse first.
#
# overpass.osm.ch is deliberately not here. On 2026-09-24 it answered valid
# JSON with zero results for questions the others answered normally --
# including "does node 309814375 exist", which is Looking Glass Falls and has
# since 2008. Its osm3s timestamp_osm_base came back as "117253" where the
# others give a date, so it is serving from a database that never finished
# loading. A refusal costs one retry; an empty answer that looks like a real
# one gets cached and believed. Worth trying again another day.
MIRRORS = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
]

CACHE_DIR = 'data/spider-cache/overpass'
UA = {'User-Agent': 'wanderfall-research/0.1 (+https://wanderfall.app)'}

# A busy mirror answers 504 or 429; both mean "later", not "no".
RETRY_CODES = (429, 502, 503, 504)


def _post(url, q, timeout):
    req = urllib.request.Request(
        url, data=urllib.parse.urlencode({'data': q}).encode(),
        method='POST', headers=UA)
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read()


def query(q, name, tries=4, pause=6, timeout=180, refresh=False, start=0):
    """Run an Overpass query, returning parsed JSON and caching the raw body.

    `name` is the cache filename, so it should describe the question rather
    than the moment -- the point of the cache is that the same question is
    only ever asked once.

    `start` picks which mirror to try first. Callers running more than one
    query at a time should give each a different one; otherwise every worker
    opens on the same host, which is the opposite of spreading the load.
    """
    os.makedirs(CACHE_DIR, exist_ok=True)
    path = os.path.join(CACHE_DIR, name + '.json')
    if os.path.exists(path) and not refresh:
        return json.load(open(path))

    order = MIRRORS[start % len(MIRRORS):] + MIRRORS[:start % len(MIRRORS)]
    delay = pause
    last = None
    for attempt in range(tries):
        for url in order:
            host = urllib.parse.urlparse(url).hostname
            try:
                body = _post(url, q, timeout)
            except urllib.error.HTTPError as e:
                last = '%s %s' % (host, e.code)
                if e.code not in RETRY_CODES:
                    raise
            except (urllib.error.URLError, OSError) as e:
                last = '%s %s' % (host, e)
            else:
                # A mirror under load sometimes answers 200 with an HTML
                # error page, so the shape of the body is the real test.
                try:
                    data = json.loads(body)
                except ValueError:
                    last = '%s: not JSON' % host
                    print('  %s answered with something that is not JSON'
                          % host, file=sys.stderr)
                    continue
                with open(path, 'wb') as f:
                    f.write(body)
                return data
            print('  %s, trying the next mirror' % last, file=sys.stderr)
        if attempt < tries - 1:
            print('  all mirrors busy; waiting %gs' % delay, file=sys.stderr)
            time.sleep(delay)
            delay *= 2

    raise RuntimeError('Overpass would not answer after %d rounds (%s)'
                       % (tries, last))


def main(argv):
    if len(argv) < 3:
        print(__doc__.strip().split('\n\n')[-1], file=sys.stderr)
        return 2
    q = open(argv[1], encoding='utf-8').read()
    data = query(q, argv[2])
    els = data.get('elements', [])
    print('%d elements -> %s/%s.json' % (len(els), CACHE_DIR, argv[2]))
    # A count query returns its numbers in the one element's tags.
    if len(els) == 1 and els[0].get('type') == 'count':
        for k, v in sorted(els[0].get('tags', {}).items()):
            print('  %-10s %s' % (k, v))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
