"""Fetch hikingwnc pages that cover more than one waterfall.

Most of hikingwnc is one page per waterfall, and data/hiking_wnc_falls.json
carries those already. A handful of pages cover a run of falls instead, and
the url says so: it starts with two numbers, the first and last of the run,
as in 942-945-big-cliff-falls-etc-sc. Those pages hold a table with a row per
waterfall -- name, height, elevation, GPS -- and none of it reached us,
because whatever produced the JSON copied the page-level row once per
waterfall instead of reading the table. Four features stand in for about
fourteen waterfalls as a result.

Three numbers in a url are not always a range: 691-22-foot-falls is the 691st
fall and it is called 22 Foot Falls. A range has its second number larger
than its first, which separates the four real ones cleanly.

This only fetches and writes the page as it arrived. Nothing is parsed here
-- an extractor can be rerun against a file on disk, while a parser wired
into the fetch has to re-ask the site every time it changes its mind.

    python3 script/spider/hikingwnc.py            # the ranges we know of
    python3 script/spider/hikingwnc.py <url> ...  # or whichever you name
"""
import os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fetcher import Fetcher

OUT = 'data/hikingwnc'

# The four pages whose urls name a range. Listed rather than discovered so a
# run is reproducible without a database to hand.
RANGES = [
    'https://hikingwnc.com/436-439-fall-creek-falls/',
    'https://hikingwnc.com/942-945-big-cliff-falls-etc-sc/',
    'https://hikingwnc.com/947-950-red-eft-falls-etc/',
    'https://hikingwnc.com/996-997-lower-lynn-camp-falls/',
]


def slug(url):
    return re.sub(r'[^a-z0-9-]', '', url.rstrip('/').rsplit('/', 1)[-1].lower())


def main(urls):
    os.makedirs(OUT, exist_ok=True)
    f = Fetcher(pause=1.0)
    for url in urls:
        path = os.path.join(OUT, slug(url) + '.html')
        if os.path.exists(path):
            print('have  %s' % path)
            continue
        try:
            body = f.get(url)
        except Exception as e:
            print('FAIL  %s: %s' % (url, e), file=sys.stderr)
            continue
        with open(path, 'wb') as out:
            out.write(body)
        print('saved %s  (%d bytes)' % (path, len(body)))


if __name__ == '__main__':
    main(sys.argv[1:] or RANGES)
