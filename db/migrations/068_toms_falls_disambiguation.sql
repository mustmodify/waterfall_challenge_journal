-- Three waterfalls were tangled together under confusingly similar names:
-- Tom's Spring Falls (feature 366, CMC hike 174, southwest of Asheville),
-- Toms Creek Falls (new, near Marion NC, northeast of Asheville), and Toms
-- Falls (new, near Hendersonville, CMC hike 115 -- jw's spreadsheet had this
-- one mislabeled as "Toms Creek Falls", which is a different, real place).
--
-- AllTrails' own curated description for the Daniel Ridge trailhead trail
-- claims the waterfall there is "also called Toms Creek Falls and Jackson's
-- Falls" -- checked and false. AllTrails' own record for "Toms Creek Falls
-- Trail" (id 10233744) puts that waterfall near Marion, NC, an 80-foot
-- cascade with an old waterwheel foundation, ~88 km from feature 366's
-- coordinate. Their prose made the identical name-collision mistake this
-- migration is untangling; recorded here so nobody re-imports it as fact.
--
-- jw confirmed all three by hand: Daniel Ridge Falls' coordinate
-- (35.28879430838692, -82.82666219343832, from Google Maps) landed within
-- 20 m of what we already stored and of OpenStreetMap's claim -- three
-- independent readings agreeing is exactly what "identity_certain" was
-- withheld pending. The OSM group was uncertain only because the name
-- comparison never accounted for our "(Daniel Ridge)" qualifier being a
-- disambiguator, not a disagreement -- the same asymmetric-qualifier case
-- MATCHING.md already documents for the five High Falls.

BEGIN;

-- Feature 366: rename, and accept the OpenStreetMap claims now confirmed by
-- a third independent reading (Google Maps, via jw).
UPDATE features SET name = 'Tom''s Spring Falls' WHERE id = 366;

UPDATE claim_groups
SET identity_certain = true,
    note = coalesce(note || ' ', '') ||
           'Re-arbitrated 2026-09-17: the name disagreement was our own ' ||
           '"(Daniel Ridge)" qualifier, which OSM omits -- a disambiguator ' ||
           'asymmetry, not a disagreement. Position confirmed a third way ' ||
           'by jw reading Google Maps: 35.28879430838692, -82.82666219343832.'
WHERE feature_id = 366 AND source = 'openstreetmap' AND NOT identity_certain;

UPDATE claims SET accepted = true
WHERE group_id = (SELECT id FROM claim_groups WHERE feature_id = 366 AND source = 'openstreetmap')
  AND field IN ('coordinate', 'name');

-- The correct AllTrails page for feature 366, and a note debunking the
-- "aka" in its own curated description.
INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('alltrails|366|toms-spring-falls-daniel-ridge', 366, 'alltrails',
 'https://www.alltrails.com/trail/us/north-carolina/tom-s-spring-falls-via-daniel-ridge-trailhead',
 true,
 'Trailhead 489 m out; name matches exactly, and this is the only falls the ' ||
 'short (1 mi) route reaches, so distance bounds the search and the name ' ||
 'decides, per MATCHING.md #4. Their curated_description calls this fall ' ||
 '"also called Toms Creek Falls and Jackson''s Falls" -- false. Toms Creek ' ||
 'Falls is AllTrails'' own trail 10233744, near Marion NC, ~88 km away.');

INSERT INTO claims (group_id, feature_id, field, value, accepted, note)
SELECT g.id, g.feature_id, v.field, v.value::jsonb, v.accepted, v.note
FROM (VALUES
  ('name', '"Tom''s Spring Falls"', false, 'Agrees with the accepted OSM spelling; not accepted twice over, one claim per field.'),
  ('hike_distance', '"1 mile"', true, 'Out and back, so already round trip.')
) AS v(field, value, accepted, note)
JOIN claim_groups g ON g.ref = 'alltrails|366|toms-spring-falls-daniel-ridge';

INSERT INTO links (feature_id, url, rel)
VALUES (366, 'https://www.alltrails.com/trail/us/north-carolina/tom-s-spring-falls-via-daniel-ridge-trailhead', 'alltrails')
ON CONFLICT (feature_id, url) DO NOTHING;

-- New feature: Toms Creek Falls, Marion NC. Distinct from feature 366 -- see
-- above. Coordinate is jw's own reading, originally logged against the
-- wrong hike number (174) in his spreadsheet before this migration untangled
-- the two.
WITH loc AS (
    INSERT INTO locations (latitude, longitude) VALUES (35.7776747249305, -82.06198593646882) RETURNING id
), feat AS (
    INSERT INTO features (name, kind, feature_location_id, rt_hike_distance, owner, slug)
    VALUES ('Toms Creek Falls', 'waterfall', (SELECT id FROM loc), '0.8', 'Federal', slugify('Toms Creek Falls'))
    RETURNING id
), grp AS (
    INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note)
    SELECT 'jw|' || id || '|toms-creek-falls', id, 'jw', NULL, true,
        'Distinct from Tom''s Spring Falls (feature 366) and Toms Falls (Hendersonville) -- ' ||
        'confirmed by jw, who has visited. Northeast of Asheville, near Marion NC.'
    FROM feat
    RETURNING id, feature_id
)
INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT grp.id, grp.feature_id, 'coordinate', '{"lat": 35.7776747249305, "lon": -82.06198593646882}'::jsonb, true FROM grp
UNION ALL
SELECT grp.id, grp.feature_id, 'name', '"Toms Creek Falls"'::jsonb, true FROM grp;

INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note)
SELECT 'alltrails|' || f.id || '|toms-creek-falls-trail', f.id, 'alltrails',
    'https://www.alltrails.com/trail/us/north-carolina/toms-creek-falls-trail', true,
    'Name matches exactly; Marion, NC location agrees with jw''s coordinate.'
FROM features f WHERE f.name = 'Toms Creek Falls';

INSERT INTO links (feature_id, url, rel)
SELECT f.id, 'https://www.alltrails.com/trail/us/north-carolina/toms-creek-falls-trail', 'alltrails'
FROM features f WHERE f.name = 'Toms Creek Falls'
ON CONFLICT (feature_id, url) DO NOTHING;

-- New feature: Toms Falls, Hendersonville area. CMC hike 115 -- jw's
-- spreadsheet had this one mislabeled with the wrong name and the wrong
-- (174's) coordinate; the actual name and coordinate are below. AllTrails
-- lists it as an explore/poi page rather than a trail, which the MCP tools
-- here don't fetch, so it is cited but not independently corroborated by us
-- yet. Google Maps lists it as a separate place per jw, without a specific
-- coordinate to record as its own claim.
WITH loc AS (
    INSERT INTO locations (latitude, longitude) VALUES (35.48496459208312, -82.3058583767334) RETURNING id
), feat AS (
    INSERT INTO features (name, kind, feature_location_id, cmc_hike_no, slug)
    VALUES ('Toms Falls', 'waterfall', (SELECT id FROM loc), 115, slugify('Toms Falls'))
    RETURNING id
), grp AS (
    INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note)
    SELECT 'jw|' || id || '|toms-falls', id, 'jw',
        'https://www.alltrails.com/explore/poi/us/north-carolina/hendersonville/tom-s-falls',
        true,
        'CMC hike 115; jw''s spreadsheet had this mislabeled "Toms Creek Falls" and carried ' ||
        '174''s coordinate by mistake. Actual name is Toms Falls. AllTrails carries it only as ' ||
        'an explore/poi page, not a trail, so it is not independently corroborated here yet. ' ||
        'Google Maps lists it as a separate place per jw.'
    FROM feat
    RETURNING id, feature_id
)
INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT grp.id, grp.feature_id, 'coordinate', '{"lat": 35.48496459208312, "lon": -82.3058583767334}'::jsonb, true FROM grp
UNION ALL
SELECT grp.id, grp.feature_id, 'name', '"Toms Falls"'::jsonb, true FROM grp;

INSERT INTO schema_migrations (filename) VALUES ('068_toms_falls_disambiguation.sql');

COMMIT;
