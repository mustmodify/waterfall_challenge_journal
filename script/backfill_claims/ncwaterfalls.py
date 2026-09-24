"""Generate db/migrations/043_ncwaterfalls_claims.sql from the cached pages.

ncwaterfalls.com is Kevin Adams, whose book and lists are where the Adams 500
and Adams 250 challenges come from. Every waterfall page carries the same
labelled block: coordinates for the fall and its trailhead, beauty, elevation,
height, difficulty and distance.

His beauty ratings run 1 to 10 -- stated on /learning/classifying -- which is
the scale hikingwnc uses, so the two are comparable.
"""
import html, json, math, os, re, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'spider'))
import cache

CACHE = 'data/spider-cache/ncwaterfalls.jsonl.gz'

def text_of(page):
    body = re.sub(r'(?is)<(script|style).*?</\1>', ' ', page)
    return re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ', body)))

FIELDS = ('Accessibility', 'County', 'River Basin', 'Watercourse', 'Watershed',
          'Type and Height', 'Landowner', 'Beauty Rating', 'Elevation', 'USGS Map',
          'Hike Difficulty', 'Hike Distance', 'Waterfall GPS', 'Trailhead GPS')

def parse(text):
    out = {}
    for i, field in enumerate(FIELDS):
        m = re.search(re.escape(field) + r':\s*(.*?)(?=' +
                      '|'.join(re.escape(f) + ':' for f in FIELDS) + r'|Loving all the free|$)', text)
        if m:
            out[field] = m.group(1).strip(' .')
    return out

def coord(v):
    m = re.search(r'(-?\d+\.\d+)\s*,\s*(-?\d+\.\d+)', v or '')
    return (float(m.group(1)), float(m.group(2))) if m else None

def number(v):
    m = re.search(r'-?\d+(?:\.\d+)?', (v or '').replace(',', ''))
    return float(m.group()) if m else None

def norm(s):
    s = (s or '').lower().replace('&', 'and')
    return ' '.join(re.sub(r'[^a-z0-9 ]', ' ', s).split())

def km(a, b, c, d):
    return 111.32 * math.hypot(a - c, (b - d) * math.cos(math.radians(a)))

def lit(s):
    return "'" + s.replace("'", "''") + "'"

feats = []
for line in open(sys.argv[1], encoding='utf-8'):
    fid, name, lat, lon = line.rstrip('\n').split('|')
    feats.append((int(fid), name, float(lat) if lat else None, float(lon) if lon else None))

groups, rows = [], []
pages = named = placed = 0
for rec in cache.latest(CACHE):
    if '/waterfalls/' not in rec['url']:
        continue
    text = text_of(rec['html'])
    got = parse(text)
    if 'Waterfall GPS' not in got and 'Beauty Rating' not in got:
        continue
    pages += 1
    title = re.search(r'<title[^>]*>(.*?)</title>', rec['html'], re.S)
    title = html.unescape(title.group(1)).split('|')[0].strip() if title else ''
    wf = coord(got.get('Waterfall GPS'))
    th = coord(got.get('Trailhead GPS'))

    match, why = None, ''
    t = norm(title)
    by_name = [f for f in feats if norm(f[1]) == t]
    if not by_name and t:
        # ours often carry a river after the name: "Turtleback Falls- Horsepasture River"
        by_name = [f for f in feats if norm(f[1]).startswith(t + ' ')]
    # He covers the whole state and we carry the western end, so the names
    # collide: his Silver Run Falls is 396 km from ours, in Cumberland County.
    # The coordinate on his own page settles it.
    if len(by_name) == 1 and wf and by_name[0][2]:
        if km(wf[0], wf[1], by_name[0][2], by_name[0][3]) > 20:
            by_name = []
    if len(by_name) == 1:
        match, why = by_name[0], ''
        named += 1
    elif wf:
        near = sorted(((km(wf[0], wf[1], f[2], f[3]), f) for f in feats if f[2]), key=lambda x: x[0])
        if near and near[0][0] < 0.25:
            match = near[0][1]
            why = ('Matched on position, %d m, with no name agreement. Kevin Adams '
                   'calls it %s.' % (round(near[0][0] * 1000), title))
            placed += 1
    if not match:
        continue
    fid = match[0]
    ref = 'ncwaterfalls|%d|%s' % (fid, rec['url'].rsplit('/', 1)[-1])
    groups.append("(%s, %d, 'ncwaterfalls', %s, %s, %s)"
                  % (lit(ref), fid, lit(rec['url']), 'false' if why else 'true',
                     lit(why) if why else 'NULL'))

    def add(field, value, note='NULL'):
        rows.append("(%s, '%s', %s, %s)" % (lit(ref), field, lit(value), note))

    if title:
        add('name', json.dumps(title))
    if wf:
        add('coordinate', '{"lat": %s, "lon": %s}' % wf)
    if th:
        add('trailhead_coordinate', '{"lat": %s, "lon": %s}' % th,
            lit('Given as Trailhead GPS.'))
    b = number(got.get('Beauty Rating'))
    if b and 1 <= b <= 10:
        add('beauty_rating', str(int(b)))
    e = number(got.get('Elevation'))
    if e is not None:
        add('elevation_ft', str(int(e)))
    # The page's own sentence, not a number pulled out of it -- it often says
    # how the height was arrived at ("Height estimated", "measured with
    # rangefinder"), and the parsing belongs in normalize_claim_value.
    if got.get('Type and Height'):
        add('height', json.dumps(got['Type and Height']))
    if got.get('Hike Difficulty'):
        add('accessibility', json.dumps(got['Hike Difficulty']))
    if got.get('Hike Distance'):
        add('hike_distance', json.dumps(got['Hike Distance']),
            lit('One way unless it says otherwise; features.rt_hike_distance is round trip.'))
    if got.get('Landowner'):
        add('owner', json.dumps(got['Landowner']),
            lit('The owner by name. features.owner holds a category.'))

out = open('db/migrations/043_ncwaterfalls_claims.sql', 'w', encoding='utf-8')
out.write("""-- What Kevin Adams publishes about the falls we carry.
--
-- Generated by script/backfill_claims/ncwaterfalls.py from the cached pages in
-- data/spider-cache. ncwaterfalls.com allows crawling and publishes a sitemap;
-- the pages were fetched one at a time, a quarter second apart.
--
-- This is the source behind the Adams 500 and Adams 250 challenges, so it is
-- the closest thing we have to an authority on those lists. His beauty ratings
-- run 1 to 10, stated outright on /learning/classifying, which settles the
-- assumption migration 034 had to make.
--
-- Nothing is accepted here. Every one of these is a second opinion on a fall we
-- already place from hikingwnc, and the two deserve comparing before either is
-- promoted.

BEGIN;

INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
""")
out.write(',\n'.join(groups) + ';\n\n')
out.write("""INSERT INTO claims (group_id, feature_id, field, value, note)
SELECT g.id, g.feature_id, v.field, v.value::jsonb, v.note::text
FROM (VALUES
""")
out.write(',\n'.join(rows) + """
) AS v(ref, field, value, note)
JOIN claim_groups g ON g.ref = v.ref;

COMMIT;
""")
out.close()
print('pages parsed %d | matched by name %d, by position %d | groups %d, claims %d'
      % (pages, named, placed, len(groups), len(rows)))
