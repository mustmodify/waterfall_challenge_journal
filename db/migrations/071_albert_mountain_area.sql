-- Three readings from jw around Albert Mountain (Nantahala NF, near
-- Standing Indian), while investigating the unsourced-tier towers.
--
-- Albert Mountain (feature 440, tower): jw's Google Maps reading agrees
-- with what we already stored to within about 870 m -- consistent for a
-- tower's stored point being a rough original reading. Recorded as a
-- corroborating claim; towers publish regardless of coordinate_confidence
-- tier (see ARCHITECTURE.md), so this doesn't change what's visible, only
-- what's known.
--
-- Mooney Falls: jw's reading (35.0298, -83.4973) is a genuinely different
-- place from feature 668's "Mooney Falls" near Boone -- 101 km apart, and
-- feature 668 has its own real source (hikingwnc.com/334-mooney-falls/,
-- identity_certain, with its own height and ratings). Confirmed as a real,
-- separate waterfall by AllTrails' own "Mooney Falls" trail (id 10287629,
-- Nantahala National Forest), 106 m from jw's coordinate. New feature,
-- qualified to avoid colliding with 668.
--
-- Big Laurel Falls (feature 326, already 'confirmed'): jw's falls reading
-- (35.01854101439391, -83.50450973793822) agrees with what's stored to
-- within ~170 m, well inside the confirmed tier already -- no change
-- needed there. His educated-guess parking coordinate (35.0217935500392,
-- -83.50305388879569) checks out independently: AllTrails' own trailhead
-- distance from the falls coordinate is 388 m, and the guessed parking
-- point is 385 m from the falls -- effectively the same number, arrived at
-- two different ways. Recorded as a parking_coordinate claim.

BEGIN;

-- Albert Mountain: corroborating reading.
INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('jw|440|google-maps-check', 440, 'google-maps', NULL, true,
 'Read off Google Maps by jw while investigating the area around Albert Mountain. ' ||
 'Agrees with our stored point within about 870 m.');

INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, g.feature_id, 'coordinate', '{"lat": 35.05522389466838, "lon": -83.48630902952183}'::jsonb, false
FROM claim_groups g WHERE g.ref = 'jw|440|google-maps-check';

INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, g.feature_id, 'parking_coordinate', '{"lat": 35.046230004291594, "lon": -83.50725171582894}'::jsonb, true
FROM claim_groups g WHERE g.ref = 'jw|440|google-maps-check';

-- Big Laurel Falls: parking coordinate, corroborated by AllTrails' own
-- trailhead distance.
INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('jw|326|parking-check', 326, 'jw', NULL, true,
 'Educated-guess parking coordinate, checked against AllTrails'' own trailhead ' ||
 'distance for the falls (388 m) -- the guess sits 385 m from the falls, ' ||
 'essentially the same figure arrived at independently.');

INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, g.feature_id, 'parking_coordinate', '{"lat": 35.0217935500392, "lon": -83.50305388879569}'::jsonb, true
FROM claim_groups g WHERE g.ref = 'jw|326|parking-check';

-- New feature: Mooney Falls (Nantahala), distinct from feature 668.
WITH loc AS (
    INSERT INTO locations (latitude, longitude) VALUES (35.0297854883662, -83.49729535676491) RETURNING id
), feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Mooney Falls (Nantahala)', 'waterfall', (SELECT id FROM loc), 'Federal', slugify('Mooney Falls (Nantahala)'))
    RETURNING id
), grp AS (
    INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note)
    SELECT 'jw|' || id || '|mooney-falls-nantahala', id, 'jw', NULL, true,
        'On the road, so parking and the falls share one coordinate. Distinct from feature 668''s ' ||
        'Mooney Falls near Boone, 101 km away -- both real, per hikingwnc (668) and AllTrails (this one).'
    FROM feat
    RETURNING id, feature_id
)
INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT grp.id, grp.feature_id, 'coordinate', '{"lat": 35.0297854883662, "lon": -83.49729535676491}'::jsonb, true FROM grp
UNION ALL
SELECT grp.id, grp.feature_id, 'name', '"Mooney Falls (Nantahala)"'::jsonb, true FROM grp
UNION ALL
SELECT grp.id, grp.feature_id, 'parking_coordinate', '{"lat": 35.0297854883662, "lon": -83.49729535676491}'::jsonb, true FROM grp;

INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note)
SELECT 'alltrails|' || f.id || '|mooney-falls', f.id, 'alltrails',
    'https://www.alltrails.com/trail/us/north-carolina/mooney-falls', true,
    'Trailhead 106 m from jw''s coordinate; name matches exactly.'
FROM features f WHERE f.name = 'Mooney Falls (Nantahala)';

INSERT INTO links (feature_id, url, rel)
SELECT f.id, 'https://www.alltrails.com/trail/us/north-carolina/mooney-falls', 'alltrails'
FROM features f WHERE f.name = 'Mooney Falls (Nantahala)'
ON CONFLICT (feature_id, url) DO NOTHING;

INSERT INTO schema_migrations (filename) VALUES ('071_albert_mountain_area.sql');

COMMIT;
