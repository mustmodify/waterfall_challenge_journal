-- Two of the six towers with no hike data have had one all along.
--
-- Migration 028 filled 16 of 22 towers from hikingwnc, which has no page for
-- the other six. dwhike walked two of them and published the numbers, and the
-- claims layer has been holding those since the spider ran -- they were never
-- promoted because the promotion in 045 covered waterfalls.
--
-- His Hike Length is the whole route, which is what this column means. Only
-- groups whose identity is certain are taken: those are the galleries that name
-- the tower and start within a few hundred metres of it, rather than passing
-- it on the way somewhere else.
--
-- Clingmans Dome is the one to watch and is deliberately left alone. His
-- gallery there is an MST section, "Clingmans Dome to Fork Ridge", which starts
-- at the same car park and walks away from the tower: gain 700 feet, rating
-- 5.40, so four miles of hiking that is not the paved climb to the lookout. It
-- carries no Hike Length claim, so nothing was promoted -- but the usual guard
-- would not have caught it either, because that guard compares his distance
-- against ours and ours is the thing that is missing.

BEGIN;

UPDATE features f
SET rt_hike_distance = regexp_replace(d.value#>>'{}', ' miles?$', ''),
    elevation_gain_ft = (g.value#>>'{}')::int
FROM claims d
JOIN claim_groups cg ON cg.id = d.group_id
LEFT JOIN claims g ON g.group_id = cg.id AND g.field = 'elevation_gain_ft'
WHERE d.feature_id = f.id
  AND cg.source = 'dwhike'
  AND cg.identity_certain
  AND d.field = 'hike_distance'
  AND (f.rt_hike_distance IS NULL OR f.rt_hike_distance !~ '[0-9]');

-- One answer per field. A feature with two galleries would otherwise have both
-- marked accepted in the same statement, which the index refuses outright.
WITH promoted AS (
    SELECT DISTINCT ON (c.feature_id, c.field) c.id
    FROM claims c
    JOIN claim_groups cg ON cg.id = c.group_id
    JOIN features f ON f.id = c.feature_id
    WHERE cg.source = 'dwhike' AND cg.identity_certain
      AND c.field IN ('hike_distance', 'elevation_gain_ft')
      AND f.kind = 'tower' AND f.rt_hike_distance IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM claims a
                      WHERE a.feature_id = c.feature_id AND a.field = c.field AND a.accepted)
    ORDER BY c.feature_id, c.field, c.id)
UPDATE claims SET accepted = true WHERE id IN (SELECT id FROM promoted);

COMMIT;
