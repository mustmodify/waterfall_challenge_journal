"""Pull ncwaterfalls.com waterfall pages into a local cache.

robots.txt there is "User-agent: * / Allow: /", and the site publishes a
sitemap, so the page list comes from the sitemap rather than from crawling
links. Still one request at a time, 250 ms apart, with a user agent that says
who we are.

Every page lands in a gzipped JSONL cache and is never fetched twice.
"""
import os, re, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cache
from fetcher import Fetcher

CACHE = 'data/spider-cache/ncwaterfalls.jsonl.gz'
http = Fetcher(pause=0.25)

def fetch(url):
    return http.get(url).decode('utf-8', 'replace')

def main():
    sitemap = fetch('https://ncwaterfalls.com/sitemap.xml')
    locs = re.findall(r'<loc>([^<]+)</loc>', sitemap)
    pages = [u for u in locs if '/waterfalls/' in u and u.rstrip('/').count('/') == 4]
    # the learning pages carry the rating scales the numbers are on
    pages += [u for u in locs if '/learning' in u or '/about' in u]

    done = cache.urls(CACHE)
    todo = [u for u in pages if u not in done]
    print('%d pages, %d cached, %d to fetch' % (len(pages), len(done), len(todo)))

    written = failed = 0
    out = cache.Writer(CACHE)
    for url in todo:
        try:
            body = fetch(url)
        except Exception as e:
            failed += 1
            print('  failed %s: %s' % (url, e))
            continue
        out.add({'url': url, 'html': body,
                 'fetched_at': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())})
        written += 1
        if written % 50 == 0:
            print('  %d/%d' % (written, len(todo)))
    out.close()
    print('wrote %d, failed %d, cache %s' % (written, failed, CACHE))

main()
