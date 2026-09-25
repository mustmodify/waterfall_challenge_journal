-- Grade a fact by how many sources agree, on jw's rubric.
--
--   no two agree            D   1.0
--   one source              C-  1.7
--   two agree               C+  2.3
--   three agree             B   3.0
--   four agree              B+  3.3
--   five or more agree      A-  3.7
--   confirmed in person     A   4.0
--   three-plus and in person A+ 4.3
--
-- This finally enforces the three-source rule. Until now any number of
-- agreeing sources with no dissent scored 'corroborated' at 3.0, so two
-- sources got a B -- 594 facts, and jw has said twice that there is no
-- consensus without three. Two sources now get a C+.
--
-- WHY FIVE IS AN A- AND NOT AN A. Five sources agreeing is five parties who
-- might have copied each other, and in this data they demonstrably do:
-- ncwaterfalls and hikingwnc share numbers, and AllTrails routes echo both.
-- Standing at the waterfall is the one thing that cannot be a copy, so it
-- keeps 4.0 on its own. A+ is then exactly what jw first described it as --
-- every piece of data agrees AND the signs agree -- rather than a grade
-- five websites can hand each other.
--
-- Nothing scores above B+ today. Four agreeing sources is the ceiling the
-- data reaches, on 20 features, and only for coordinates and names; no
-- feature anywhere has five sources on any field. So A- and above are
-- aspirational, which is the right shape for the top of a scale.
--
-- DISSENT IS NOT PENALISED HERE, which is a decision worth flagging rather
-- than burying. Three agreeing out of four scores the same B as three out of
-- three; the dissenting source shows up in the note but not in the grade.
-- That follows jw's rubric literally -- "consensus from three sites is a B"
-- -- and the old 'disambiguated' rung that used to mean "a majority agree,
-- someone does not" is no longer produced. If dissent should cost a rung,
-- that is a small change to agreement_stage() and a rerun.

BEGIN;

ALTER TABLE facts DROP CONSTRAINT IF EXISTS facts_stage_known;
ALTER TABLE facts ADD CONSTRAINT facts_stage_known CHECK (
  confidence_stage = ANY (ARRAY[
    'disputed', 'single_source', 'two_sources', 'corroborated',
    'four_sources', 'five_sources',
    'ai_reviewed', 'human_reviewed', 'confirmed_irl', 'confirmed_and_agreed',
    -- Kept legal so an older migration can be rerun without failing, though
    -- nothing produces it any more.
    'disambiguated']::text[]));

-- How many distinct sources agreed, as a rung. n is the total that had an
-- opinion, so one source is single_source however loudly it agrees with
-- itself.
CREATE OR REPLACE FUNCTION agreement_stage(agreeing int, n int) RETURNS text
    LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN n <= 1        THEN 'single_source'
    WHEN agreeing <= 1 THEN 'disputed'
    WHEN agreeing = 2  THEN 'two_sources'
    WHEN agreeing = 3  THEN 'corroborated'
    WHEN agreeing = 4  THEN 'four_sources'
    ELSE 'five_sources'
  END;
$$;

CREATE OR REPLACE FUNCTION stage_score(stage text) RETURNS numeric
    LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE stage
    WHEN 'disputed'             THEN 1.0
    WHEN 'single_source'        THEN 1.7
    WHEN 'two_sources'          THEN 2.3
    WHEN 'disambiguated'        THEN 2.3
    WHEN 'corroborated'         THEN 3.0
    WHEN 'four_sources'         THEN 3.3
    WHEN 'ai_reviewed'          THEN 3.3
    WHEN 'five_sources'         THEN 3.7
    WHEN 'human_reviewed'       THEN 3.7
    WHEN 'confirmed_irl'        THEN 4.0
    WHEN 'confirmed_and_agreed' THEN 4.3
  END;
$$;

COMMENT ON FUNCTION agreement_stage(int, int) IS
    'The rung a fact earns from how many distinct sources agree. Three is '
    'the first rung that counts as consensus, per jw.';
COMMENT ON FUNCTION stage_score(text) IS
    'The 0-4.3 score for a rung. Review rungs share scores with agreement '
    'rungs deliberately: four agreeing sources is worth about what an AI '
    'review is worth, and five about what a human review is worth.';

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'johnathonwright') THEN
    ALTER FUNCTION agreement_stage(int, int) OWNER TO johnathonwright;
    ALTER FUNCTION stage_score(text) OWNER TO johnathonwright;
  END IF;
END $$;

-- Re-grade every fact in place. The winning values and the agreement counts
-- were already decided by 096, 103 and 123; only the rung and the score
-- change, so the counts are read back out of the note each fact carries.
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
           -- 105's disputed heights describe a spread instead of a count.
           WHEN notes ~ 'sources spread from' THEN 'disputed'
         END AS stage
  FROM facts
) g
WHERE g.id = f.id AND g.stage IS NOT NULL;

INSERT INTO schema_migrations (filename) VALUES ('125_grade_by_how_many_sources_agree.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
