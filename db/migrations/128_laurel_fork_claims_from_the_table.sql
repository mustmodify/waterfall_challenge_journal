-- Turn the Laurel Fork reading into claims.
--
-- 124 wrote what the two hikingwnc pages proved into a confusion-set journal
-- entry and stopped there, which was half the job. A journal entry is prose:
-- nothing arbitrates it, nothing grades it, and rebuilding facts from claims
-- would lose every word of it. The rule we settled on is that review work
-- enters as a claim, so that facts stays derivable from claims alone. jw
-- caught the omission: "did you create AI claims for the falls near laurel
-- fork based on what you read?"
--
-- The 942-945 page carries a table with a row per waterfall, and two of those
-- rows describe features we already have:
--
--   Big Cliff Falls  30 ft  2231 ft  35.05459, -82.84494   feature 1206
--   Chute Falls      16 ft  2100 ft  35.05368, -82.84584   feature 1073
--
-- Both are hikingwnc's own assertions, so they are hikingwnc claims, not
-- ours. What is ours is the identification -- that Chute Falls is the
-- waterfall we hold as Christopher Falls -- and that judgement lives in the
-- group note where it can be argued with, exactly like every other match
-- decision.
--
-- The table is a separate group from the page's header block, because it is
-- a separate assertion: the header describes the trip as a whole and names
-- one waterfall for the page, the table describes four waterfalls
-- individually. Same source, same url, different claim.
--
-- Nothing is accepted. These are readings, and arbitration decides what wins
-- once they are in. For 1073 that means a height of 16 ft arriving beside the
-- existing 25 ft from the Christopher page -- one author measuring the same
-- drop three years apart, which is a genuine disagreement and should be
-- graded as one rather than quietly reconciled here.

BEGIN;

-- ------------------------------------------------- 1073, as Chute Falls --
INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('hikingwnc|1073|942-945-table', 1073, 'hikingwnc',
 'https://hikingwnc.com/942-945-big-cliff-falls-etc-sc/', true,
 'The Chute Falls row of this page''s table is the waterfall we hold as Christopher Falls. His own two pages settle it: this page puts Bella Falls and Evil Ducky Falls on the unnamed trib, and the Christopher Falls page says two of Bella, Christopher and Evil Ducky are on the trib and the third on Laurel Fork -- leaving Christopher on Laurel Fork, where Chute Falls is the bottom-most of the four. The coordinates agree to 4 m. So he has catalogued one waterfall twice, as #793 in 2021 and #945 in 2024. See the Falls On Or Near Laurel Fork confusion set.')
ON CONFLICT (ref) DO NOTHING;

INSERT INTO claims (group_id, feature_id, field, value, normalized_value, accepted)
SELECT g.id, 1073, 'alias', '"Chute Falls"'::jsonb, NULL, false
FROM claim_groups g WHERE g.ref = 'hikingwnc|1073|942-945-table'
ON CONFLICT DO NOTHING;

INSERT INTO claims (group_id, feature_id, field, value, normalized_value, accepted, note)
SELECT g.id, 1073, 'height', to_jsonb('16′'::text), to_jsonb(height_feet('16′')), false,
       'Measured in 2024. The Christopher Falls page gives 25 ft from a 2021 visit; same drop, three years apart.'
FROM claim_groups g WHERE g.ref = 'hikingwnc|1073|942-945-table'
ON CONFLICT DO NOTHING;

INSERT INTO claims (group_id, feature_id, field, value, normalized_value, accepted)
SELECT g.id, 1073, 'elevation_ft', '2100'::jsonb, NULL, false
FROM claim_groups g WHERE g.ref = 'hikingwnc|1073|942-945-table'
ON CONFLICT DO NOTHING;

-- -------------------------------------------- 1206, as Big Cliff Falls --
INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('hikingwnc|1206|942-945-table', 1206, 'hikingwnc',
 'https://hikingwnc.com/942-945-big-cliff-falls-etc-sc/', true,
 'The Big Cliff Falls row of this page''s table. This feature carries the page''s coordinate, which is Big Cliff Falls'' own, so it is that waterfall -- its stored name, "945 Big Cliff Falls etc. (SC)", is hikingwnc''s counter for the last of four falls plus his shorthand for "and the others", not a name anyone uses.')
ON CONFLICT (ref) DO NOTHING;

INSERT INTO claims (group_id, feature_id, field, value, normalized_value, accepted)
SELECT g.id, 1206, 'name', '"Big Cliff Falls"'::jsonb, NULL, false
FROM claim_groups g WHERE g.ref = 'hikingwnc|1206|942-945-table'
ON CONFLICT DO NOTHING;

INSERT INTO claims (group_id, feature_id, field, value, normalized_value, accepted)
SELECT g.id, 1206, 'height', to_jsonb('30′'::text), to_jsonb(height_feet('30′')), false
FROM claim_groups g WHERE g.ref = 'hikingwnc|1206|942-945-table'
ON CONFLICT DO NOTHING;

INSERT INTO claims (group_id, feature_id, field, value, normalized_value, accepted)
SELECT g.id, 1206, 'elevation_ft', '2231'::jsonb, NULL, false
FROM claim_groups g WHERE g.ref = 'hikingwnc|1206|942-945-table'
ON CONFLICT DO NOTHING;

INSERT INTO schema_migrations (filename) VALUES ('128_laurel_fork_claims_from_the_table.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
