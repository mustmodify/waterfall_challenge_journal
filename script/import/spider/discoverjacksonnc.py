"""Pull discoverjacksonnc.com trail/listing/blog pages into a local cache.

robots.txt there is "User-agent: * / Allow: /" with "Crawl-delay: 2", and the
site publishes a sitemap, so the page list comes from the sitemap rather than
from crawling links. One request at a time, 2s apart (per the crawl-delay),
with a user agent that says who we are.

We only pull pages relevant to falls, swimming holes, trails, and
rivers/lakes -- not the whole site (restaurants, lodging, etc.).

Every page lands in a gzipped JSONL cache and is never fetched twice.
"""
import os, re, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cache
from fetcher import Fetcher

CACHE = 'data/spider-cache/discoverjacksonnc.jsonl.gz'
http = Fetcher(pause=2.0)

RELEVANT_LISTING_SLUGS = (
    'balsam-lake', 'bear-lake', 'cedar-cliff-lake', 'lake-glenville',
    'tanasee-creek-lake', 'wolf-lake', 'tuckasegee-river',
    'tuckasegee-river-greenway', 'sliding-rock', 'lake-glenville-scenic-waterfall-cruises',
    'pines-recreation-area', 'pinnacle-park', 'mingus-mill',
)

RELEVANT_BLOG_SLUGS = (
    'swimming_holes', 'splash-right-in-visit-these-top-swimming-holes-in-jackson-county',
    'splash-swim-stay-cool-in-the-nc-mountains',
    'chasing-waterfalls-where-to-find-jackson-countys-most-scenic-spots',
    'discover-natural-beauty-jackson-countys-waterfalls',
    'best_nc_waterfalls', 'frozen_waterfalls',
    '10-must-visit-waterfalls-in-western-carolina',
    'five-waterfalls-to-explore-this-fall-in-the-nc-mountains',
    'top-four-waterfall-hikes-in-n-c-mountains',
    'waterfall-road-trips-how-to-explore-cascades-across-jackson-county',
    'a-guide-to-kid-friendly-hikes-and-waterfalls-in-jackson-county-nc',
)

def fetch(url):
    return http.get(url).decode('utf-8', 'replace')

def relevant(url):
    if '/trail/' in url and url.rstrip('/').count('/') == 5:
        return True
    if url.rstrip('/').endswith(('/outdoors/waterfalls', '/outdoors/rivers-lakes', '/outdoors/trails')):
        return True
    if '/listing/' in url and any('/listing/%s/' % s in url for s in RELEVANT_LISTING_SLUGS):
        return True
    if '/blog/post/' in url and any('/blog/post/%s/' % s in url for s in RELEVANT_BLOG_SLUGS):
        return True
    return False

def main():
    sitemap = fetch('https://www.discoverjacksonnc.com/sitemap.xml')
    locs = re.findall(r'<loc>([^<]+)</loc>', sitemap)
    pages = [u for u in locs if relevant(u)]

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
        if written % 10 == 0:
            print('  %d/%d' % (written, len(todo)))
    out.close()
    print('wrote %d, failed %d, cache %s' % (written, failed, CACHE))

main()
