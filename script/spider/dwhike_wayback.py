"""Pull dwhike's hike galleries from the Wayback Machine into a local cache.

dwhike.com is a SmugMug site, and SmugMug refuses all crawlers -- its robots.txt
ends with "user-agent: * / disallow: /" -- because the servers cannot take the
traffic. It does allowlist archive.org_bot and ia_archiver, so the Internet
Archive's copies were made with permission, and reading them costs dwhike's
servers nothing.

Every page lands in a gzipped JSONL cache and is never fetched twice. Re-running
after an interruption resumes; parsing reads the cache, not the network.

Politeness: one request at a time, 250 ms apart, with a user agent that says who
we are.
"""
import json, os, sys, time, urllib.error
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cache
from fetcher import Fetcher

CACHE = 'data/spider-cache/dwhike-wayback.jsonl.gz'
REGIONS = ('North-Carolina-Hikes', 'South-Carolina-Hikes', 'Georgia-Hikes')

# Replaying an archived page is far more work for the Archive than answering a
# CDX query, and it starts refusing connections well before 250 ms.
index = Fetcher(pause=0.25, timeout=180)
pages = Fetcher(pause=1.5, timeout=120)

def fetch(url, timeout=90):
    return index.get(url)

def newest_snapshots():
    """Gallery pages only: .../Hikes-in-the-South/<state>/<area>/<gallery>."""
    best = {}
    for region in REGIONS:
        url = ('https://web.archive.org/cdx/search/cdx?url=dwhike.com/Hikes-in-the-South/'
               '%s*&output=json&fl=original,timestamp,statuscode'
               '&filter=statuscode:200&collapse=urlkey' % region)
        try:
            rows = json.loads(index.get(url).decode())[1:]
        except urllib.error.HTTPError as e:
            print('cdx %s: %s' % (region, e), file=sys.stderr)
            continue
        for original, timestamp, _ in rows:
            path = original.split('dwhike.com')[-1].split('?')[0].rstrip('/')
            if '/i-' in path or '!' in path or path.endswith(('.jpg', '.json', '.xml')):
                continue
            if path.strip('/').count('/') != 3:
                continue
            if path not in best or timestamp > best[path][0]:
                best[path] = (timestamp, original)
        print('%s: %d galleries so far' % (region, len(best)))
    return best

def main():
    done = cache.urls(CACHE)
    targets = newest_snapshots()
    todo = [(p, ts, orig) for p, (ts, orig) in sorted(targets.items()) if orig not in done]
    print('%d galleries, %d already cached, %d to fetch' % (len(targets), len(done), len(todo)))

    written = failed = 0
    out = cache.Writer(CACHE)
    for path, timestamp, original in todo:
        snap = 'https://web.archive.org/web/%sid_/%s' % (timestamp, original)
        try:
            body = pages.get(snap).decode('utf-8', 'replace')
        except Exception as e:
            failed += 1
            print('  failed %s: %s' % (path, e), file=sys.stderr)
            continue
        out.add({'url': original, 'path': path, 'timestamp': timestamp,
                 'fetched_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()),
                 'html': body})
        written += 1
        if written % 25 == 0:
            print('  %d/%d' % (written, len(todo)))
    out.close()
    print('wrote %d, failed %d, cache %s' % (written, failed, CACHE))

main()
