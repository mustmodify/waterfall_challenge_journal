-- Accept the USGS elevation wherever nothing competes, and publish it to
-- features.elevation_ft so the map's elevation filter has something to filter
-- on. Before this the filter covered 116 of 989 features, which made it a
-- filter on "which records carry this field" rather than on elevation.
--
-- Not arbitration, mostly: for the features with no accepted elevation this
-- is the only reading anyone has given. Where ncwaterfalls already holds an
-- accepted value it is left alone -- 091 decided those, and the unique index
-- on one accepted claim per field would refuse a second anyway.
--
-- Worth trusting because the two sources agree closely where they overlap.
-- Across all 116 features holding both readings the mean difference is 83 ft,
-- 2.6% relative, and only two are more than 15% apart.
--
-- Those two are a finding rather than noise. USGS reports the ground
-- elevation at OUR coordinate, so a large disagreement with a source's stated
-- elevation is evidence about the coordinate, not just the height above sea
-- level:
--
--   Big Bearwallow Falls -- usgs 3681 against ncwaterfalls 2420
--   Cutler Falls         -- usgs 2492 against ncwaterfalls 3819
--
-- Both sit at single_source tier, so nothing corroborates where they are, and
-- Cutler Falls already appears in MATCHING.md as an ncwaterfalls match
-- refused at 118 km. Their coordinates are left untouched here -- this
-- migration is not the place to move a pin -- but both belong in the review
-- queue.

BEGIN;

UPDATE claims c
SET accepted = true
FROM claim_groups cg
WHERE c.group_id = cg.id
  AND cg.source = 'usgs'
  AND c.field = 'elevation_ft'
  AND NOT EXISTS (
    SELECT 1 FROM claims other
    WHERE other.feature_id = c.feature_id
      AND other.field = 'elevation_ft'
      AND other.accepted
  );

UPDATE features f
SET elevation_ft = (c.value #>> '{}')::integer
FROM claims c
WHERE c.feature_id = f.id
  AND c.field = 'elevation_ft'
  AND c.accepted
  AND f.elevation_ft IS DISTINCT FROM (c.value #>> '{}')::integer;

INSERT INTO schema_migrations (filename) VALUES ('106_accept_usgs_elevations.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
