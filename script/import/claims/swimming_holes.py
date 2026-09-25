"""Generate db/migrations/084_swimming_holes.sql from data/swimming_holes_working.csv.

Every match below was verified against the live database this session --
either by coordinate (within 115m) or, where the CSV had no coordinate, by
exact name against a feature whose own location independently confirms the
same place (e.g. "High Falls- Little River" sitting in DuPont State Forest).
Not a repeat of the earlier over-eager fuzzy matching from the Toms/Mooney
investigation -- every one of these was checked by hand.
"""
import csv, json

IN = 'data/swimming_holes_working.csv'
OUT = 'db/migrations/084_swimming_holes.sql'

# CSV Name -> existing feature id. These become `UPDATE features SET swimmable = true`.
MATCHES = {
    'Courthouse Falls': 407,
    'Granny Burrell Falls': 1266,
    'High Falls (Lake Glenville)': 431,
    'Hooker Plunge': 417,
    'Jawbone Falls': 369,
    'Schoolhouse Plunge': 391,
    'Silver Run Plunge': 323,
    'Big Laurel Falls': 326,
    'Duggers Creek Falls': 569,
    'Elk River Falls': 314,
    'Huntfish Falls': 387,
    'Little Bradley Falls': 410,
    'Turtleback Falls': 334,
    'Bust Your Butt Falls': 359,
    'Midnight Hole': 839,
    'Mouse Creek Plunge': 397,
    'Sunburst Swimming Hole': 504,
    'Sliding Rock (Brevard)': 463,
    'Sliding Rock (Cashiers)': 591,
    'High Falls (DuPont)': 384,
    'High Falls (Thompson River)': 362,
    'Flat Laurel Creek': 490,
    'Upper Creek Falls': 386,
    'Secret Falls (Highlands)': 332,
    'Big Creek': 888,
    'Graveyard Fields Plunge': 350,
    'Skinny Dip Falls': 339,
}

# "The Bullhole" and "Bullhole" are the same place from two sources; merge.
SKIP = {'The Bullhole'}
RENAME = {'Bullhole': 'The Bullhole'}

OWNER_MAP = [
    ('national forest', 'Federal'),
    ('state park|state forest|state recreation area', 'State'),
    ('great smoky mountains national park', 'GSMNP'),
]

def owner_category(raw):
    if not raw:
        return None
    low = raw.lower()
    import re
    for pattern, category in OWNER_MAP:
        if re.search(pattern, low):
            return category
    return None

def lit(s):
    if s is None:
        return 'NULL'
    return "'" + str(s).replace("'", "''") + "'"

rows = list(csv.DictReader(open(IN, encoding='utf-8')))
by_name = {r['Name']: r for r in rows}

out = open(OUT, 'w', encoding='utf-8')
out.write("""-- Turns data/swimming_holes_working.csv into real data: 27 rows are
-- swimming holes at waterfalls we already carry (swimmable = true), the
-- rest are genuinely separate places (new swimming_hole features).
--
-- Every match was checked against this database directly this session --
-- by coordinate where the CSV had one, by cross-referencing an unambiguous
-- independent detail (landowner, region, a name-source's own description)
-- where it didn't. Not a repeat of the over-eager fuzzy matching that
-- caused the Toms Creek/Mooney Falls mess earlier -- see that thread for
-- why this pass was done by hand instead.

BEGIN;

""")

n_swimmable = n_new = n_skip_nolatlon = 0

for csv_name, feature_id in MATCHES.items():
    out.write("UPDATE features SET swimmable = true WHERE id = %d; -- %s\n" % (feature_id, csv_name))
    n_swimmable += 1

out.write("\n")

for row in rows:
    name = row['Name'].strip()
    if name in SKIP or name in MATCHES:
        continue
    display_name = RENAME.get(name, name)
    kind_type = row['Type'].strip()
    owner_raw = row['Owner'].strip()
    latlong = row['Lat/Long'].strip()
    url = row['Link'].strip()

    owner = owner_category(owner_raw)
    comment_parts = []
    if kind_type:
        comment_parts.append('type: %s' % kind_type)
    if owner_raw:
        comment_parts.append('source owner text: %s' % owner_raw)
    comment = '; '.join(comment_parts) or None

    out.write("-- %s\n" % display_name)
    out.write("WITH\n")
    feat_loc = 'NULL'
    if latlong:
        lat, lon = [p.strip() for p in latlong.split(',')]
        out.write("loc AS (\n    INSERT INTO locations (latitude, longitude) VALUES (%s, %s) RETURNING id\n),\n" % (lat, lon))
        feat_loc = '(SELECT id FROM loc)'
    else:
        n_skip_nolatlon += 1
    out.write("feat AS (\n")
    out.write("    INSERT INTO features (name, kind, feature_location_id, owner, slug)\n")
    out.write("    VALUES (%s, 'swimming_hole', %s, %s, slugify(%s))\n" % (lit(display_name), feat_loc, lit(owner), lit(display_name)))
    out.write("    RETURNING id\n)\n")
    if url:
        out.write("INSERT INTO links (feature_id, url, rel, comments)\n")
        out.write("SELECT id, %s, %s, %s FROM feat;\n\n" % (lit(url), lit('swimming-hole-research'), lit(comment)))
    else:
        out.write("SELECT id FROM feat;\n\n")
    n_new += 1

out.write("INSERT INTO schema_migrations (filename) VALUES ('084_swimming_holes.sql');\n\n")
out.write("COMMIT;\n")
out.close()
print('swimmable: %d, new features: %d (of which %d have no coordinate and will not show as a map pin)' % (n_swimmable, n_new, n_skip_nolatlon))
