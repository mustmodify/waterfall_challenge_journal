-- The eight waterfalls that were hiding inside three hikingwnc pages.
--
-- jw asked for the range pages to be split into separate features.
--
-- Three of hikingwnc's pages cover a run of falls rather than one, and give
-- each of them its own name, height and coordinate. We held one feature per
-- page, wearing the coordinate of whichever row we happened to match:
--
--   436-439 Fall Creek      Upper, Main, Third, Last          757 is Last
--   942-945 Big Cliff (SC)  Upper Big Cliff, Big Cliff,      1206 is Big Cliff
--                           Split, Chute                     1073 is Chute
--   947-950 Red Eft         Red Eft, Black Eft, D Eft,       1208 is Red Eft
--                           Hidden Cl Eft
--
-- Twelve waterfalls, four of which we already had -- 128 and 129 filed those
-- readings. The other eight were simply absent, and this creates them.
--
-- Every one is single-source: hikingwnc says where they are and nobody else
-- does, so none of them will publish to the map until a second source agrees.
-- That is the threshold doing its job, not a shortfall here.
--
-- The names are hikingwnc's own, from his table or his GPS lines. Three of
-- them -- Upper Falls, Main Falls, Third Falls -- mean nothing away from the
-- page they came from, so the stored name carries the creek the way "Upper
-- Falls (Snowbird Creek)" already does. The name claim holds the bare name
-- and the disambiguator is read off the stored name, so the map composes the
-- two rather than either being copied into the other.
--
-- What this does not settle: feature 757 is still called "Fall Creek Falls"
-- while sitting on the drop the same page calls Last Falls, and the 40-foot
-- Main Falls the page is named for now exists separately. 129 filed the
-- unaccepted "Last Falls" name claim for 757 and left the arbitration open.
-- It is still open.
--
-- Rerunnable: the slug decides what is missing, so a second run creates
-- nothing and rebuilds the same facts.

BEGIN;

CREATE TEMP TABLE range_falls (
    feature_id  integer,
    full_name   text,
    bare        text,
    lat         numeric(10,8),
    lon         numeric(11,8),
    height_raw  text,
    height_ft   integer,
    elev        integer,
    url         text,
    page        text,
    note        text
) ON COMMIT DROP;

INSERT INTO range_falls
  (full_name, bare, lat, lon, height_raw, height_ft, elev, url, page, note)
VALUES
  ('Upper Falls (Fall Creek)', 'Upper Falls', 34.82280, -83.25157, '50′ (2 drop)', 50, NULL,
   'https://hikingwnc.com/436-439-fall-creek-falls/', '436-439-prose',
   'The topmost of the four falls this page walks past. Its height comes from the page''s single Height line, which names each fall in turn; its coordinate from the page''s own "GPS Info: LAT ... (Upper Falls)" line.'),
  ('Main Falls (Fall Creek)', 'Main Falls', 34.81889, -83.26679, '40′', 40, NULL,
   'https://hikingwnc.com/436-439-fall-creek-falls/', '436-439-prose',
   'The 40-foot fall this page is named for, and the one we did not have: feature 757 sits 237 m away on the last of the four. Height and coordinate both from the page.'),
  ('Third Falls (Fall Creek)', 'Third Falls', 34.81947, -83.26818, '15′', 15, NULL,
   'https://hikingwnc.com/436-439-fall-creek-falls/', '436-439-prose',
   'The third of the four, 106 m from feature 757. Height and coordinate both from the page.'),
  ('Upper Big Cliff Falls (SC)', 'Upper Big Cliff Falls', 35.05473, -82.84459, '16 ft', 16, 2297,
   'https://hikingwnc.com/942-945-big-cliff-falls-etc-sc/', '942-945-table',
   'The first row of this page''s four-row table. Feature 1206 carries the second row (Big Cliff Falls) and feature 1073 the fourth (Chute Falls, which 128 identified as our Christopher Falls); this row and the third had no feature at all.'),
  ('Split Falls (Laurel Fork SC)', 'Split Falls', 35.05418, -82.84523, '12 ft', 12, 2198,
   'https://hikingwnc.com/942-945-big-cliff-falls-etc-sc/', '942-945-table',
   'The third row of this page''s table, between Big Cliff Falls and Chute Falls on Laurel Fork. The stored name carries the creek because we already hold a Split Falls on Wildcat Trail, a hundred kilometres away.'),
  ('Black Eft Falls', 'Black Eft Falls', 35.19629, -82.95697, '12 ft', 12, 3215,
   'https://hikingwnc.com/947-950-red-eft-falls-etc/', '947-950-table',
   'The second row of this page''s four-row table. Feature 1208 carries the first row (Red Eft Falls); the other three had no feature.'),
  ('D Eft Falls', 'D Eft Falls', 35.19718, -82.95831, '14 ft', 14, 3347,
   'https://hikingwnc.com/947-950-red-eft-falls-etc/', '947-950-table',
   'The third row of this page''s table, recorded as written. The name reads like something lost a word, but that is what the table says, and guessing at the missing one would be inventing a name.'),
  ('Hidden Cl Eft Falls', 'Hidden Cl Eft Falls', 35.19748, -82.95943, '20 ft', 20, 3445,
   'https://hikingwnc.com/947-950-red-eft-falls-etc/', '947-950-table',
   'The fourth and highest row of this page''s table, recorded as written, with the same reservation about the name as D Eft Falls.');

-- Adopt any that a previous run already created, and drop them from the work.
UPDATE range_falls r SET feature_id = f.id
FROM features f WHERE f.slug = slugify(r.full_name);

WITH loc AS (
    INSERT INTO locations (latitude, longitude)
    SELECT lat, lon FROM range_falls WHERE feature_id IS NULL
    RETURNING id, latitude, longitude
), feat AS (
    INSERT INTO features (name, kind, feature_location_id, height_ft, elevation_ft, slug)
    SELECT r.full_name, 'waterfall', l.id, r.height_ft, r.elev, slugify(r.full_name)
    FROM range_falls r
    JOIN loc l ON l.latitude = r.lat AND l.longitude = r.lon
    RETURNING id, name
)
UPDATE range_falls r SET feature_id = feat.id
FROM feat WHERE feat.name = r.full_name;

INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, observed_on, note)
SELECT 'hikingwnc|' || r.feature_id || '|' || r.page, r.feature_id, 'hikingwnc',
       r.url, true, '2026-09-24', r.note
FROM range_falls r
ON CONFLICT (ref) DO NOTHING;

INSERT INTO claims (group_id, feature_id, field, value, normalized_value, accepted, note)
SELECT g.id, r.feature_id, v.field, v.value, v.normalized_value, true, v.note
FROM range_falls r
JOIN claim_groups g ON g.ref = 'hikingwnc|' || r.feature_id || '|' || r.page
CROSS JOIN LATERAL (VALUES
    ('coordinate', jsonb_build_object('lat', r.lat, 'lon', r.lon), NULL::jsonb,
     'The only coordinate anyone has published for this waterfall.'),
    ('name', to_jsonb(r.bare), NULL, NULL),
    ('height', to_jsonb(r.height_raw), to_jsonb(height_feet(r.height_raw)), NULL),
    ('elevation_ft', to_jsonb(r.elev), NULL, NULL)
  ) AS v(field, value, normalized_value, note)
WHERE v.value IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM claims c
                  WHERE c.group_id = g.id AND c.field = v.field);

INSERT INTO links (feature_id, url, rel)
SELECT r.feature_id, r.url, 'hikingwnc' FROM range_falls r
ON CONFLICT (feature_id, url) DO NOTHING;

-- Facts are a cache, so eight new features leave eight gaps in it. Only the
-- four keys these claims can answer, and only for these features.
DELETE FROM facts
WHERE feature_id IN (SELECT feature_id FROM range_falls)
  AND key IN ('name', 'disambiguator', 'height', 'coordinate');

INSERT INTO facts (feature_id, key, value, value_type, units,
                   confidence_stage, confidence_score, notes)
SELECT r.feature_id, 'name', r.bare, 'string', NULL, 'single_source', 1.7,
       'Only one source has a value, so there is nothing to compare it with.'
FROM range_falls r
UNION ALL
SELECT r.feature_id, 'disambiguator', name_disambiguator(r.full_name), 'string', NULL,
       'single_source', 1.7,
       'Read off our own feature name, which is the curated one. Not something a source published, so it carries no corroboration.'
FROM range_falls r WHERE name_disambiguator(r.full_name) IS NOT NULL
UNION ALL
SELECT r.feature_id, 'height', r.height_ft::text, 'integer', 'feet',
       'single_source', 1.7,
       'Only one source has a value, so there is nothing to compare it with.'
FROM range_falls r
UNION ALL
SELECT r.feature_id, 'coordinate',
       trim_scale(r.lat)::text || ', ' || trim_scale(r.lon)::text, 'coordinate', 'degrees',
       'single_source', 1.7,
       'Only one source has a value, so there is nothing to compare it with.'
FROM range_falls r;

INSERT INTO schema_migrations (filename) VALUES ('143_range_pages_become_features.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
