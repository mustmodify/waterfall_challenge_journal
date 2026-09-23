-- Follow-up to 092. Migration 003 (2026-08-04, reconciling WC100 with the
-- official CMC list) added a WC100 goal for a list entry literally named
-- "Upper & Lower Bubbling Springs" -- and matched it to feature 427, which
-- at the time carried that exact same name by coincidence. 092 renamed 427
-- to what it actually is (Bubbling Springs Cascades / Guardrail Falls,
-- confirmed against three independent sources), which exposed the
-- mismatch: the WC100 goal was never about 427 at all. It belongs to the
-- real Upper and Lower Bubbling Springs Branch falls -- features 488 and
-- 487 -- which the CMC list counts as one combined stop.
--
-- jw's call: don't try to model "one goal, two features" -- nothing else
-- here does, and it's not worth a schema change for one entry. Put both
-- falls on WC100 individually instead, same as they already are on
-- ADAMS100/ADAMS500.

BEGIN;

DELETE FROM goals WHERE feature_id = 427
  AND challenge_id = (SELECT id FROM challenges WHERE name = 'WC100');

INSERT INTO goals (challenge_id, feature_id)
SELECT (SELECT id FROM challenges WHERE name = 'WC100'), feature_id
FROM (VALUES (487), (488)) AS v(feature_id)
ON CONFLICT (challenge_id, feature_id) DO NOTHING;

INSERT INTO schema_migrations (filename) VALUES ('093_bubbling_springs_wc100_goal_fix.sql');

COMMIT;
