-- MATCHING.md #8 flagged this exact batch and proposed exactly this fix:
-- 37 ncwaterfalls claim groups (54 as of 2026-09-14; some already resolved
-- since, including two split off into their own features this session)
-- are marked identity_certain = false only because the *name* comparison
-- failed -- Kevin Adams titles his pages for search engines ("Hidden
-- Falls", "Pulpit Falls-Hiking, Photos"), and the position was never in
-- question. Verified fresh here, not just trusted from the doc: distance
-- from our coordinate to the one Kevin Adams publishes on each page runs
-- 0 to 245 m, comfortably inside the <2 km accept band (MATCHING.md #3)
-- and inside the 250 m corroboration bound.
--
-- The genuinely bad ncwaterfalls matches (7 groups, "far from ours",
-- 21.5 km to 396 km out) are a different note and untouched by this --
-- name-only matching correctly refused those.

BEGIN;

UPDATE claim_groups
SET identity_certain = true,
    note = coalesce(note || ' ', '') ||
           'Re-arbitrated 2026-09-17: position confirmed within 250 m; the only failure was the ' ||
           'name comparison against Kevin Adams'' SEO-tailed page titles.'
WHERE source = 'ncwaterfalls'
  AND NOT identity_certain
  AND note LIKE '%Matched on position%with no name agreement%';

INSERT INTO schema_migrations (filename) VALUES ('080_ncwaterfalls_position_only_matches.sql');

COMMIT;
