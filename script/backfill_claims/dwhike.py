"""Generate db/migrations/044_dwhike_hike_claims.sql from the archived galleries.

Each gallery description is a fixed block: Trailhead GPS, Route Type,
Difficulty, Hike Length, Duration, Min and Max Elevation, Total Vertical Gain.
The gain is the piece no other source publishes, and it is what makes a
Petzoldt rating computable.

A gallery is a hike, not a waterfall, and a hike can pass several falls. It is
attached to a feature only when the gallery names that fall, and the trailhead
has to be within 8 km of it -- there are two Rainbow Falls and two Twin Falls in
this region alone.
"""
import html, json, math, os, re, sys
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'spider'))
import cache

CACHE = 'data/spider-cache/dwhike-wayback.jsonl.gz'
GENERIC = {'falls', 'fall', 'waterfall', 'waterfalls', 'hike', 'nc', 'sc', 'ga',
           'trail', 'loop', 'the', 'and', 'upper', 'lower', 'middle', 'big', 'little'}

def flat(page):
    body = re.sub(r'(?is)<(script|style).*?</\1>', ' ', page)
    return re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ', body)))

def field(text, label, stop):
    m = re.search(re.escape(label) + r':\s*(.{0,80}?)\s*(?=' + stop + ')', text)
    return m.group(1).strip() if m else None

def number(v):
    m = re.search(r'-?[\d,]+(?:\.\d+)?', v or '')
    return float(m.group().replace(',', '')) if m else None

def norm(s):
    return ' '.join(re.sub(r'[^a-z0-9 ]', ' ', (s or '').lower().replace('&', 'and')).split())

def km(a, b, c, d):
    return 111.32 * math.hypot(a - c, (b - d) * math.cos(math.radians(a)))

def lit(s):
    return "'" + s.replace("'", "''") + "'"

feats = []
for line in open(sys.argv[1], encoding='utf-8'):
    fid, name, kind, lat, lon, ours = line.rstrip('\n').split('|')
    if lat:
        miles = re.match(r'^([0-9]+(?:\.[0-9]+)?)', ours)
        feats.append((int(fid), name, kind, float(lat), float(lon),
                      set(norm(name).split()) - GENERIC,
                      float(miles.group(1)) if miles else None))

# "Cedar Rock Falls" and dwhike's "Cedar Rock" share every word that matters
# once Falls is set aside as generic, and they are a mountain and a waterfall.
# So the gallery has to say which kind of thing it visited.
WATER = ('falls', 'waterfall', 'cascade', 'shoals')
SUMMIT = ('lookout', 'tower', 'mountain', 'knob', 'bald', 'dome', 'top')

STOP = (r'Route Type|Difficulty|Hike Length|Hike Duration|Trailhead Temp|Trail Traffic|'
        r'Min\. Elevation|Max\. Elevation|Total Vertical Gain|Avg\. Elevation|Trails Used|$')

groups, rows = [], []
parsed = matched = loose = 0
for rec in cache.latest(CACHE):
    text = flat(rec.get('html', ''))
    if 'Total Vertical Gain' not in text and 'Trailhead GPS' not in text:
        continue
    parsed += 1
    title = re.search(r'<title[^>]*>(.*?)</title>', rec.get('html', ''), re.S)
    title = html.unescape(title.group(1)).split(' - dwhike')[0].strip() if title else rec['path']
    slug = rec['path'].rsplit('/', 1)[-1].replace('-', ' ')

    gps = re.search(r'Trailhead GPS[^:]*:\s*(-?\d+\.\d+)\s*,\s*(-?\d+\.\d+)', text)
    trailhead = (float(gps.group(1)), float(gps.group(2))) if gps else None
    length = number(field(text, 'Hike Length', STOP))
    gain = number(field(text, 'Total Vertical Gain', STOP))
    difficulty = field(text, 'Difficulty', STOP)

    words = set(norm(title + ' ' + slug).split()) - GENERIC
    said = norm(title + ' ' + slug)
    hits = []
    for fid, fname, kind, flat_, flon, fwords, ourmiles in feats:
        if not fwords or not fwords <= words:
            continue
        wanted = WATER if kind == 'waterfall' else SUMMIT
        if not any(w in said for w in wanted):
            continue
        d = km(trailhead[0], trailhead[1], flat_, flon) if trailhead else None
        if d is None or d < 8:
            hits.append((d if d is not None else 99, fid, fname, ourmiles))
    if len(hits) != 1:
        continue
    d, fid, fname, ourmiles = hits[0]
    matched += 1

    # Naming the fall is not the same as walking to it. When his route is far
    # longer than the walk our other sources describe, he passed the waterfall
    # on the way to somewhere else, and his climb is not the climb to it.
    certain, scale = 'true', ''
    if length and ourmiles and length > ourmiles * 1.5:
        certain = 'false'
        scale = (' His route is %.1f miles against the %.1f miles our other sources '
                 'give for this fall, so it passes it rather than going to it.'
                 % (length, ourmiles))
        loose += 1
    # the same gallery slug appears under more than one area
    ref = 'dwhike|%d|%s' % (fid, rec['path'].split('Hikes-in-the-South/')[-1])
    groups.append("(%s, %d, 'dwhike', %s, %s, %s)"
                  % (lit(ref), fid, lit(rec['url']), certain,
                     lit('Gallery "%s", walked %s. Trailhead %s km from the fall.%s'
                         % (title[:80], rec['timestamp'][:8],
                            round(d, 1) if d < 99 else '?', scale))))

    def add(f, v, note='NULL'):
        rows.append("(%s, '%s', %s, %s)" % (lit(ref), f, lit(v), note))

    if trailhead:
        add('parking_coordinate', '{"lat": %s, "lon": %s}' % trailhead)
    if gain is not None:
        add('elevation_gain_ft', str(int(gain)),
            lit('Total Vertical Gain over the whole route.'))
    if length:
        add('hike_distance', json.dumps('%g miles' % length),
            lit('Total mileage for the route, which is round trip.'))
    if difficulty:
        add('accessibility', json.dumps(difficulty.title()),
            lit('His own band, from the Petzoldt rating.'))

out = open('db/migrations/044_dwhike_hike_claims.sql', 'w', encoding='utf-8')
out.write("""-- Hike distance, vertical gain and trailheads, from dwhike's galleries.
--
-- Generated by script/backfill_claims/dwhike.py from the Wayback copies in
-- data/spider-cache. dwhike.com is a SmugMug site and SmugMug refuses all
-- crawlers because the servers cannot take it; SmugMug does allowlist
-- archive.org_bot, so these copies were made with permission and reading them
-- costs his servers nothing.
--
-- Vertical gain is the point. No other source we have publishes it, and
-- without it features.petzoldt stays null for every fall.
--
-- Nothing is accepted here: a gallery is a hike and a hike passes several
-- waterfalls, so the distance and gain belong to the route rather than to any
-- one fall on it.

BEGIN;

-- Regenerated in place: dropping this source's groups takes its claims with it.
DELETE FROM claim_groups WHERE source = 'dwhike' AND ref LIKE 'dwhike|%|%/%';

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
print('galleries with a data block %d | attached to one fall %d, of which %d only pass it'
      ' | groups %d, claims %d' % (parsed, matched, loose, len(groups), len(rows)))
