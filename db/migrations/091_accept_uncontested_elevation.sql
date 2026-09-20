-- elevation_ft has been a features column since early on, but its own
-- comment says "currently towers only" -- true until now: only 3 waterfalls
-- ever had an accepted elevation_ft, while 131 identity_certain claims for
-- the field sat unaccepted (almost all from ncwaterfalls, which is the only
-- source that publishes it per MATCHING.md). Needed now because the map is
-- getting an elevation filter, which is useless without the data.
--
-- 13 features have more than one distinct elevation_ft value among their
-- identity_certain claims -- real disagreements between sources (or between
-- a fall and its "upper"/"lower" sibling sharing a claim group by mistake).
-- Left alone for manual review rather than guessed at. Everywhere else --
-- 98 features -- there is exactly one candidate value, so accepting it is
-- not arbitration, just recording the only answer anyone has given.
--
-- A few of those 98 (feature 586 among them) hold the same value twice, in
-- two separate ncwaterfalls claim groups -- an import-time duplicate, not a
-- second opinion. Accept only one row per feature (the lowest claim id) so
-- the one-accepted-claim-per-field index doesn't see two winners.

BEGIN;

UPDATE claims c
SET accepted = true
FROM claim_groups cg
WHERE c.group_id = cg.id
  AND c.field = 'elevation_ft'
  AND cg.identity_certain
  AND c.id = (
    SELECT min(c4.id) FROM claims c4
    WHERE c4.feature_id = c.feature_id AND c4.field = 'elevation_ft'
  )
  AND c.feature_id NOT IN (
    SELECT c2.feature_id
    FROM claims c2 JOIN claim_groups cg2 ON cg2.id = c2.group_id
    WHERE c2.field = 'elevation_ft' AND cg2.identity_certain
    GROUP BY c2.feature_id
    HAVING count(DISTINCT (c2.value)::text) > 1
  )
  -- A handful (feature 909 among them) already have an accepted reading from
  -- earlier, hand-done work -- don't fight the unique-accepted-claim index
  -- over those, just fill in the ones nobody has decided on yet.
  AND NOT EXISTS (
    SELECT 1 FROM claims c3
    WHERE c3.feature_id = c.feature_id AND c3.field = 'elevation_ft' AND c3.accepted
  );

UPDATE features f
SET elevation_ft = (c.value)::text::integer
FROM claims c
WHERE c.feature_id = f.id AND c.field = 'elevation_ft' AND c.accepted;

INSERT INTO schema_migrations (filename) VALUES ('091_accept_uncontested_elevation.sql');

COMMIT;
