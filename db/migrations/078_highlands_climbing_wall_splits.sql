-- Two more real waterfalls hiding behind name collisions, found by reading
-- the actual source text behind 'disputed' pairs rather than trusting that
-- identity_certain = true on both sides meant anything.
--
-- HIGHLANDS FALLS (feature 729): ncwaterfalls describes a ~100 ft falls on
-- the Cullasaja River, entirely inside Highlands Falls Country Club --
-- private, no public access, viewable only from Bearpen Mountain over a
-- mile away, blasted for the golf course's 15th green. hikingwnc's entry
-- (currently accepted, and our published coordinate) says Accessibility
-- "Roadside", Distance 0.0 -- a small falls right in town, nothing like
-- the golf-course one. OpenStreetMap's node 13 m from hikingwnc's point
-- calls it "Satulah Falls", not Highlands Falls. Two different real
-- places, 4.9 km apart, sharing a name a country club and a mountain
-- overlooking town could each independently earn.
--
-- CLIMBING WALL FALLS (feature 997): ncwaterfalls describes a Class III
-- bushwhack on Pisgah NF land off Looking Glass Creek -- cross the creek,
-- climb a branch, rangefinder-measured height. hikingwnc's entry
-- (currently accepted) says Accessibility "Easy+", Distance "Roadside".
-- A difficult bushwhack and an easy roadside stop are not the same place,
-- 3.8 km apart.

BEGIN;

-- Highlands Falls / Satulah Falls
INSERT INTO claims (group_id, feature_id, field, value, accepted, note)
SELECT cg.id, 729, 'alias', '"Satulah Falls"', true,
    'OpenStreetMap''s name for this node, 13 m from the accepted (hikingwnc) coordinate.'
FROM claim_groups cg WHERE cg.feature_id = 729 AND cg.source = 'openstreetmap';

UPDATE claim_groups
SET identity_certain = false,
    note = coalesce(note || ' ', '') ||
           'Re-arbitrated 2026-09-17: this describes a different, private waterfall inside ' ||
           'Highlands Falls Country Club (no public access, on the Cullasaja River, viewable only ' ||
           'from Bearpen Mountain) -- not the roadside falls hikingwnc/OSM ("Satulah Falls") ' ||
           'describe here. Moved to its own feature.'
WHERE feature_id = 729 AND source = 'ncwaterfalls';

WITH loc AS (
    INSERT INTO locations (latitude, longitude) VALUES (35.07007, -83.17435) RETURNING id
), feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, accessibility, rt_hike_distance, height_ft, beauty_rating, elevation_ft, slug)
    VALUES ('Highlands Falls (Highlands Falls Country Club)', 'waterfall', (SELECT id FROM loc),
            'Private', 'Not accessible for the public', 'View roadside from a distance', 100, NULL, 3839,
            slugify('Highlands Falls (Highlands Falls Country Club)'))
    RETURNING id
), grp AS (
    INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note)
    SELECT 'ncwaterfalls|729|highlands-falls-relocated', id, 'ncwaterfalls',
        'https://ncwaterfalls.com/waterfalls/highlands-falls', true,
        'Split from feature 729 (which is really Satulah Falls) 2026-09-17: private, on the ' ||
        'Cullasaja River inside Highlands Falls Country Club, viewable only from Bearpen Mountain.'
    FROM feat RETURNING id, feature_id
)
INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT grp.id, grp.feature_id, 'coordinate', '{"lat": 35.07007, "lon": -83.17435}'::jsonb, true FROM grp
UNION ALL
SELECT grp.id, grp.feature_id, 'parking_coordinate', '{"lat": 35.062095, "lon": -83.182922}'::jsonb, true FROM grp
UNION ALL
SELECT grp.id, grp.feature_id, 'name', '"Highlands Falls"'::jsonb, false FROM grp;

INSERT INTO links (feature_id, url, rel)
SELECT f.id, 'https://ncwaterfalls.com/waterfalls/highlands-falls', 'ncwaterfalls'
FROM features f WHERE f.name = 'Highlands Falls (Highlands Falls Country Club)'
ON CONFLICT (feature_id, url) DO NOTHING;

-- Climbing Wall Falls
UPDATE claim_groups
SET identity_certain = false,
    note = coalesce(note || ' ', '') ||
           'Re-arbitrated 2026-09-17: this describes a Class III bushwhack off Looking Glass Creek ' ||
           'in Pisgah NF -- not the "Roadside, Easy+" falls hikingwnc describes here. Moved to its ' ||
           'own feature.'
WHERE feature_id = 997 AND source = 'ncwaterfalls';

WITH loc AS (
    INSERT INTO locations (latitude, longitude) VALUES (35.305619, -82.783375) RETURNING id
), feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, accessibility, rt_hike_distance, height_ft, beauty_rating, elevation_ft, slug)
    VALUES ('Climbing Wall Falls (Looking Glass Creek)', 'waterfall', (SELECT id FROM loc),
            'Federal', 'Class III Bushwhack', '0.2', 100, 3, 2840,
            slugify('Climbing Wall Falls (Looking Glass Creek)'))
    RETURNING id
), grp AS (
    INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note)
    SELECT 'ncwaterfalls|997|climbing-wall-falls-relocated', id, 'ncwaterfalls',
        'https://ncwaterfalls.com/waterfalls/climbing-wall-falls', true,
        'Split from feature 997 (a different, easy roadside falls) 2026-09-17: Class III bushwhack, ' ||
        'Pisgah NF, off Looking Glass Creek.'
    FROM feat RETURNING id, feature_id
)
INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT grp.id, grp.feature_id, 'coordinate', '{"lat": 35.305619, "lon": -82.783375}'::jsonb, true FROM grp
UNION ALL
SELECT grp.id, grp.feature_id, 'parking_coordinate', '{"lat": 35.306375, "lon": -82.782696}'::jsonb, true FROM grp
UNION ALL
SELECT grp.id, grp.feature_id, 'name', '"Climbing Wall Falls"'::jsonb, false FROM grp;

INSERT INTO links (feature_id, url, rel)
SELECT f.id, 'https://ncwaterfalls.com/waterfalls/climbing-wall-falls', 'ncwaterfalls'
FROM features f WHERE f.name = 'Climbing Wall Falls (Looking Glass Creek)'
ON CONFLICT (feature_id, url) DO NOTHING;

INSERT INTO schema_migrations (filename) VALUES ('078_highlands_climbing_wall_splits.sql');

COMMIT;
