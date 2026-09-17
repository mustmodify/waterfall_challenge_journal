-- A ChatGPT/Gemini-style AI overview (fed to us by jw, who was checking its
-- work) claimed feature 431's coordinate was "displaced" by about 1800 feet
-- and should be corrected to 35.198262, -83.159715, citing
-- romanticasheville.com. Checked directly rather than trusted: that page
-- gives that exact number labeled explicitly as the *parking area* for the
-- trail down to the falls ("the signed 'Pines Recreation Area' parking
-- area... a 3/4-mile trail descends 650 ft" to the base) -- not the
-- waterfall. This is precisely the trailhead-vs-water mistake MATCHING.md #4
-- already documents. Feature 431's coordinate is fine: hikingwnc and
-- OpenStreetMap agree on it within 40 m, which is stronger corroboration
-- than the single reading the AI proposed replacing it with.
--
-- What IS useful here: 431 already held an unaccepted dwhike parking
-- coordinate (35.198521, -83.159605) that nobody had corroborated. It sits
-- 30 m from romanticasheville's independently-read number for the same
-- parking area -- accept it, and record the second reading beside it.
--
-- That parking area is also literally "Pines Recreation Area" (1966 Pine
-- Creek Road, Cullowhee, per romanticasheville -- matches the 1965 Pine
-- Creek Rd address discoverjacksonnc gave for our swimming_hole feature of
-- that same name, which has carried no coordinate since the swimming-hole
-- import). Placed here too.

BEGIN;

UPDATE claims SET accepted = true
WHERE group_id = (SELECT id FROM claim_groups WHERE feature_id = 431 AND source = 'dwhike')
  AND field = 'parking_coordinate';

INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('jw|431|romanticasheville-parking', 431, 'jw',
 'https://www.romanticasheville.com/high_falls_glenville.htm',
 true,
 'An AI overview cited this page''s coordinate as the waterfall itself and claimed 431 was ' ||
 'displaced. Read directly: the page labels this number the Pines Recreation Area parking lot ' ||
 'for the trail down to the falls, 3/4 mile and 650 ft above it -- not the waterfall. Recorded ' ||
 'as parking, which is 30 m from the existing (now accepted) dwhike parking reading.');

INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, g.feature_id, 'parking_coordinate', '{"lat": 35.198262, "lon": -83.159715}'::jsonb, false
FROM claim_groups g WHERE g.ref = 'jw|431|romanticasheville-parking';

WITH loc AS (
    INSERT INTO locations (latitude, longitude) VALUES (35.198262, -83.159715) RETURNING id
)
UPDATE features SET feature_location_id = (SELECT id FROM loc) WHERE id = 1296;

INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('jw|1296|romanticasheville', 1296, 'jw', 'https://www.romanticasheville.com/high_falls_glenville.htm', true,
 'Same parking area as feature 431''s High Falls (Cullowhee Falls) trailhead -- this is that lot.');

INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, g.feature_id, 'coordinate', '{"lat": 35.198262, "lon": -83.159715}'::jsonb, true
FROM claim_groups g WHERE g.ref = 'jw|1296|romanticasheville';

INSERT INTO schema_migrations (filename) VALUES ('085_high_falls_cullowhee_parking.sql');

COMMIT;
