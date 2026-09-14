-- Clingmans Dome, which is now Kuwohi, gains its hike from AllTrails.
--
-- One of four towers with no hike data. hikingwnc has no page for it and
-- dwhike's only gallery there walks the MST away from the summit, so nothing
-- we held described the climb to the tower itself.
--
--   1.3 miles out and back, 337 feet of gain, which computes to Petzoldt 1.97.
--
-- The name matters as much as the numbers. The Cherokee name Kuwohi was
-- restored in 2024, and this is the same tower OpenStreetMap records as
-- "Kuwohi Tower" 26 m from our coordinate -- a match the importer flagged as
-- uncertain because the names shared nothing. Recording the alias settles that
-- and makes the tower findable by the name on the signs.
--
-- The feature keeps the name our challenge lists use. The Lookout Tower
-- Challenge says Clingmans Dome, and renaming it here would quietly break the
-- list somebody is working through.

BEGIN;

INSERT INTO claim_groups (ref, feature_id, source, url, note) VALUES
('alltrails|445|kuwohi-observation-tower', 445, 'alltrails',
 'https://www.alltrails.com/trail/us/north-carolina/clingmans-dome-observation-tower-trail',
 'The paved climb to the tower itself, out and back. Read 2026-09-14.');

INSERT INTO claims (group_id, feature_id, field, value, accepted, note)
SELECT g.id, g.feature_id, v.field, v.value::jsonb, v.accepted, v.note::text
FROM (VALUES
  ('hike_distance',     '"1.3 miles"', true,  'Out and back, so already round trip.'),
  ('elevation_gain_ft', '337',         true,  NULL),
  ('alias',             '"Kuwohi"',    true,  'The Cherokee name, restored in 2024 and on the signs.'),
  ('alias',             '"Kuwohi Observation Tower Trail"', true, 'What AllTrails calls the route.')
) AS v(field, value, accepted, note)
JOIN claim_groups g ON g.ref = 'alltrails|445|kuwohi-observation-tower';

UPDATE features
SET rt_hike_distance = '1.3',
    elevation_gain_ft = 337
WHERE id = 445;

-- The OpenStreetMap viewpoint 26 m away was left uncertain because "Kuwohi
-- Tower" and "Clingmans Dome" share no words. They are the same place.
UPDATE claim_groups
SET identity_certain = true,
    note = coalesce(note || ' ', '') ||
           'Confirmed: Kuwohi is the restored Cherokee name for Clingmans Dome.'
WHERE feature_id = 445 AND source = 'openstreetmap' AND NOT identity_certain;

COMMIT;
