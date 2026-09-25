-- Consensus means nobody disagrees, which 125 stopped checking.
--
-- jw's rubric is worded "consensus from three sites is a B", and consensus
-- was already defined in ARCHITECTURE.md before any of this:
--
--   disambiguated  two or more sources, a minority still disagrees
--   corroborated   two or more sources, none disagree
--
-- 125 graded on the count of agreeing sources alone and retired
-- disambiguated, so a fact where three sources agree and a fourth objects
-- scored the same B as three out of three. Three agreeing is not a consensus
-- of four. jw caught it: "the grades I gave were specifically called out as a
-- consensus."
--
-- So dissent is disqualifying again. A fact with any dissenting source is
-- disambiguated at 2.3, however many agree, and the count-based rungs apply
-- only when the sources are unanimous.
--
-- It is a small correction by volume and a real one by kind. 66 facts carry
-- dissent: 12 at three-of-four, which were scoring B and now score C+, and
-- 54 at two-of-three or two-of-four, which keep 2.3 but stop being labelled
-- "two sources" as though the third had not spoken.
--
-- Why dissent costs the same as having only two sources, rather than a rung
-- off the top: a source that disagrees is evidence something is wrong, and
-- the rung should say "a person should look", which is what 2.3 already
-- means everywhere else. Scaling the penalty by how many dissent would be a
-- finer instrument than the evidence supports at 66 rows.

BEGIN;

CREATE OR REPLACE FUNCTION agreement_stage(agreeing int, n int) RETURNS text
    LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN n <= 1         THEN 'single_source'
    WHEN agreeing <= 1  THEN 'disputed'
    -- Anyone still disagreeing means this is not a consensus, whatever the
    -- majority looks like.
    WHEN agreeing < n   THEN 'disambiguated'
    WHEN agreeing = 2   THEN 'two_sources'
    WHEN agreeing = 3   THEN 'corroborated'
    WHEN agreeing = 4   THEN 'four_sources'
    ELSE 'five_sources'
  END;
$$;

COMMENT ON FUNCTION agreement_stage(int, int) IS
    'The rung a fact earns from its sources. Unanimity is required for the '
    'count-based rungs -- a single dissenting source drops it to '
    'disambiguated, because consensus means nobody disagrees. Three is the '
    'first unanimous rung that counts as consensus, per jw.';

UPDATE facts f
SET confidence_stage = g.stage,
    confidence_score = stage_score(g.stage)
FROM (
  SELECT id,
         CASE
           WHEN notes LIKE 'Only one source%' THEN 'single_source'
           WHEN notes LIKE 'No two of%'       THEN 'disputed'
           WHEN notes ~ '^[0-9]+ of [0-9]+ sources agree'
             THEN agreement_stage(
                    (regexp_match(notes, '^([0-9]+) of ([0-9]+)'))[1]::int,
                    (regexp_match(notes, '^([0-9]+) of ([0-9]+)'))[2]::int)
           WHEN notes ~ 'sources spread from' THEN 'disputed'
         END AS stage
  FROM facts
) g
WHERE g.id = f.id AND g.stage IS NOT NULL;

INSERT INTO schema_migrations (filename) VALUES ('126_consensus_means_nobody_disagrees.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
