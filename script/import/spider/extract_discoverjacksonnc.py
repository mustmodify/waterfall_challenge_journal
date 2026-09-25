"""Extract the embedded trail/waterfall JSON record from cached
discoverjacksonnc.com pages.

Each /trail/<slug>/<id>/ page embeds (unescaped, inline in the HTML) a JSON
object describing that trail/waterfall: title, description, category,
features (tags like "Swimming"), difficulty/distance, trailhead geolocation,
and a separate waterfall_geolocation when the trail leads to one. This script
finds that object by locating its "_id" key and brace-matching outward, then
writes the parsed records as a JSON array to data/discoverjacksonnc_trails.json.

Blog/listing pages don't carry this structured record -- their content is
read manually, not parsed here.
"""
import json, os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cache

CACHE = 'data/spider-cache/discoverjacksonnc.jsonl.gz'
OUT = 'data/discoverjacksonnc_trails.json'
LISTINGS_OUT = 'data/discoverjacksonnc_listings.json'

def extract_record(html, marker):
    idx = html.find(marker)
    if idx == -1:
        return None
    start = html.rfind('{"_id"', 0, idx)
    if start == -1:
        return None
    depth = 0
    in_str = False
    esc = False
    i = start
    while i < len(html):
        c = html[i]
        if in_str:
            if esc:
                esc = False
            elif c == '\\':
                esc = True
            elif c == '"':
                in_str = False
        else:
            if c == '"':
                in_str = True
            elif c == '{':
                depth += 1
            elif c == '}':
                depth -= 1
                if depth == 0:
                    break
        i += 1
    try:
        return json.loads(html[start:i + 1])
    except ValueError:
        return None

def extract_listing(html, url):
    """Listing pages (/listing/<slug>/<id>/) don't carry the rich trail JSON --
    just a schema.org LocalBusiness/Place block with title, description, and a
    street address (no coordinates)."""
    title = re.search(r'<title>([^<]*)</title>', html)
    desc = re.search(r'<meta name="description" content="([^"]*)"', html)
    addr = re.search(r'"address":(\{"@type":"PostalAddress"[^}]*\})', html)
    return {
        'title': (title.group(1) if title else '').split('|')[0].strip(),
        'description': desc.group(1) if desc else None,
        'address': json.loads(addr.group(1)) if addr else None,
        '_source_url': url,
    }

def main():
    records = []
    listings = []
    for rec in cache.latest(CACHE):
        if '/trail/' in rec['url']:
            obj = extract_record(rec['html'], '"geolocation":{"type":"Point"')
            if obj is None:
                print('  no record found in %s' % rec['url'])
                continue
            obj['_source_url'] = rec['url']
            records.append(obj)
        elif '/listing/' in rec['url']:
            listings.append(extract_listing(rec['html'], rec['url']))

    records.sort(key=lambda r: r.get('title', ''))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w') as f:
        json.dump(records, f, indent=2)
    print('wrote %d records to %s' % (len(records), OUT))

    listings.sort(key=lambda r: r.get('title', ''))
    with open(LISTINGS_OUT, 'w') as f:
        json.dump(listings, f, indent=2)
    print('wrote %d records to %s' % (len(listings), LISTINGS_OUT))

main()
