-- The rest of what today's reading proved, as claims rather than prose.
--
-- 128 did the two Laurel Fork rows. This does the other two multi-waterfall
-- pages, where a table row lands exactly on a feature we already hold.
--
-- Each is hikingwnc's own assertion, so the source is hikingwnc. What is ours
-- is the identification -- which row of a four-row table describes the
-- feature we have -- and that lives in the group note, where it can be
-- argued with.
--
-- Feature 757, "Fall Creek Falls". The 436-439 page describes four falls
-- along a two-mile walk and gives each its own coordinate. Ours sits on the
-- last of them, to the metre:
--
--   Upper Falls  50'       34.82280, -83.25157
--   Main Falls   40'       34.81889, -83.26679
--   Third Falls  15'       34.81947, -83.26818
--   Last Falls   15-20'    34.82031, -83.26872   <- feature 757
--
-- So the waterfall we carry is the bottom one, and the 40-foot Main Falls the
-- page is named for is 236 m away and absent from our data entirely. The name
-- claim is filed unaccepted: "Fall Creek Falls" may well remain the right
-- name for what a visitor is looking for, and that is an arbitration
-- decision, not something to settle by import.
--
-- Feature 1208, "950 Red Eft Falls etc.". Same shape. Its coordinate is the
-- Red Eft Falls row exactly, and its stored name is hikingwnc's counter for
-- the last of four falls plus his shorthand for the others. The table's
-- elevation of 3117 ft arrives beside USGS's 3122 ft, five feet apart, which
-- is corroboration rather than conflict.
--
-- Nothing here is accepted. These are readings.

BEGIN;

-- ------------------------------------------------- 757, as Last Falls --
INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('hikingwnc|757|436-439-table', 757, 'hikingwnc',
 'https://hikingwnc.com/436-439-fall-creek-falls/', true,
 'This page covers four waterfalls along Fall Creek and gives a coordinate for each. Feature 757 sits on the last of them to the metre, so of the four it is the one hikingwnc calls Last Falls -- the Height line calls the same drop Final Falls. The 40-foot Main Falls the page is named for is 236 m upstream and is not in our data at all.')
ON CONFLICT (ref) DO NOTHING;

INSERT INTO claims (group_id, feature_id, field, value, normalized_value, accepted, note)
SELECT g.id, 757, 'name', '"Last Falls"'::jsonb, NULL, false,
       'What this page calls the individual drop. "Fall Creek Falls" is the page''s name for the whole run of four.'
FROM claim_groups g WHERE g.ref = 'hikingwnc|757|436-439-table'
ON CONFLICT DO NOTHING;

INSERT INTO claims (group_id, feature_id, field, value, normalized_value, accepted)
SELECT g.id, 757, 'height', to_jsonb('15-20′'::text), to_jsonb(height_feet('15-20′')), false
FROM claim_groups g WHERE g.ref = 'hikingwnc|757|436-439-table'
ON CONFLICT DO NOTHING;

-- ---------------------------------------------- 1208, as Red Eft Falls --
INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('hikingwnc|1208|947-950-table', 1208, 'hikingwnc',
 'https://hikingwnc.com/947-950-red-eft-falls-etc/', true,
 'The Red Eft Falls row of this page''s table. Feature 1208 carries that row''s coordinate exactly; its stored name, "950 Red Eft Falls etc.", is hikingwnc''s counter for the last of the four falls on this page plus his shorthand for the rest, not a name anyone uses. The other three -- Black Eft, D Eft and Hidden Cl Eft -- are not in our data.')
ON CONFLICT (ref) DO NOTHING;

INSERT INTO claims (group_id, feature_id, field, value, normalized_value, accepted)
SELECT g.id, 1208, 'name', '"Red Eft Falls"'::jsonb, NULL, false
FROM claim_groups g WHERE g.ref = 'hikingwnc|1208|947-950-table'
ON CONFLICT DO NOTHING;

INSERT INTO claims (group_id, feature_id, field, value, normalized_value, accepted)
SELECT g.id, 1208, 'height', to_jsonb('35 ft'::text), to_jsonb(height_feet('35 ft')), false
FROM claim_groups g WHERE g.ref = 'hikingwnc|1208|947-950-table'
ON CONFLICT DO NOTHING;

INSERT INTO claims (group_id, feature_id, field, value, normalized_value, accepted, note)
SELECT g.id, 1208, 'elevation_ft', '3117'::jsonb, NULL, false,
       'USGS reads 3122 ft at our coordinate, five feet away.'
FROM claim_groups g WHERE g.ref = 'hikingwnc|1208|947-950-table'
ON CONFLICT DO NOTHING;

INSERT INTO schema_migrations (filename) VALUES ('129_more_claims_from_todays_reading.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
