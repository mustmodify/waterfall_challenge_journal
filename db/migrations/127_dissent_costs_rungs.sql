-- Price disagreement in rungs instead of flattening it.
--
-- jw: "if there is not a consensus it's a third step PLUS a third step per
-- disagreement. So three agree two disagree would be a 3.0 less 3
-- third-steps so a 2.0 = C."
--
-- So the penalty is 1 + (however many disagree), counted in rungs of the
-- grade ladder. A third of a step is what a rung IS here: the GPA scale runs
-- 3.0, 2.7, 2.3, 2.0 and so on, alternating 0.3 and 0.4, so subtracting 0.33
-- arithmetically lands between grades and then floors to the next one down,
-- which costs more than intended and produces scores like 2.67 that are not
-- grades at all. Stepping down the ladder gives jw's numbers exactly and
-- always lands on a real grade.
--
-- Checked against his own example: three agree, two disagree. Base for three
-- agreeing is 3.0, down 1 + 2 = 3 rungs, so 2.7 -> 2.3 -> 2.0, a C. Which is
-- what he said it should be.
--
-- Against the six shapes this data actually contains:
--
--   2 of 2   627 facts   C+     unanimous, no penalty
--   3 of 3   140         B      unanimous
--   4 of 4    25         B+     unanimous
--   3 of 4    12         C+     one holdout, down 2 rungs from B
--   2 of 3    51         C-     one holdout, down 2 rungs from C+
--   2 of 4     3         D+     two holdouts, down 3 rungs from C+
--
-- 126 put all 66 of those at a flat 2.3, which said a lone holdout among four
-- sources was worth exactly as much as two sources agreeing with nothing else
-- to go on. Now three-of-four keeps a C+ while two-of-four falls to D+, just
-- above the D that means no two sources agree at all -- which is about right,
-- since active contradiction is worse evidence than silence.
--
-- The floor is D. Nothing that has any agreement at all can score below the
-- rung reserved for nothing agreeing.
--
-- THE STAGE NO LONGER DETERMINES THE SCORE. disambiguated now carries 2.3,
-- 1.7 or 1.3 depending on how loud the dissent was. That is not a problem
-- to work around: ARCHITECTURE.md says the two columns exist "on purpose,
-- because they answer different questions and can disagree" -- stage is the
-- method that got us here, score is how much the result is worth.

BEGIN;

-- The ladder, once, so nothing else has to know the spacing.
CREATE OR REPLACE FUNCTION grade_rung(rung int) RETURNS numeric
    LANGUAGE sql IMMUTABLE AS $$
  SELECT (ARRAY[1.0, 1.3, 1.7, 2.0, 2.3, 2.7, 3.0, 3.3, 3.7, 4.0]::numeric[])
         [greatest(least(rung, 10), 1)];
$$;

CREATE OR REPLACE FUNCTION agreement_score(agreeing int, n int) RETURNS numeric
    LANGUAGE plpgsql IMMUTABLE AS $fn$
DECLARE
    base int;
BEGIN
    IF n IS NULL OR n <= 1 THEN
        RETURN 1.7;          -- one source: C-, nothing to compare
    END IF;
    IF agreeing IS NULL OR agreeing <= 1 THEN
        RETURN 1.0;          -- no two agree: D
    END IF;

    base := CASE
              WHEN agreeing = 2 THEN 5   -- C+
              WHEN agreeing = 3 THEN 7   -- B
              WHEN agreeing = 4 THEN 8   -- B+
              ELSE 9                     -- A-, five or more
            END;

    IF agreeing = n THEN
        RETURN grade_rung(base);
    END IF;

    -- Not a consensus: one rung for that, and one more per dissenting source.
    RETURN grade_rung(base - (1 + (n - agreeing)));
END;
$fn$;

COMMENT ON FUNCTION agreement_score(int, int) IS
    'The 0-4.3 score a fact earns from its sources. Unanimity scores by count '
    '-- two C+, three B, four B+, five A-. Anything short of unanimity costs '
    'a rung for not being a consensus plus a rung for each source that '
    'disagrees, floored at D.';

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'johnathonwright') THEN
    ALTER FUNCTION grade_rung(int) OWNER TO johnathonwright;
    ALTER FUNCTION agreement_score(int, int) OWNER TO johnathonwright;
  END IF;
END $$;

UPDATE facts f
SET confidence_stage = g.stage,
    confidence_score = g.score
FROM (
  SELECT id,
         CASE
           WHEN notes LIKE 'Only one source%' THEN 'single_source'
           WHEN notes LIKE 'No two of%'       THEN 'disputed'
           WHEN notes ~ 'sources spread from' THEN 'disputed'
           WHEN notes ~ '^[0-9]+ of [0-9]+ sources agree'
             THEN agreement_stage(
                    (regexp_match(notes, '^([0-9]+) of ([0-9]+)'))[1]::int,
                    (regexp_match(notes, '^([0-9]+) of ([0-9]+)'))[2]::int)
         END AS stage,
         CASE
           WHEN notes LIKE 'Only one source%' THEN 1.7
           WHEN notes LIKE 'No two of%'       THEN 1.0
           WHEN notes ~ 'sources spread from' THEN 1.0
           WHEN notes ~ '^[0-9]+ of [0-9]+ sources agree'
             THEN agreement_score(
                    (regexp_match(notes, '^([0-9]+) of ([0-9]+)'))[1]::int,
                    (regexp_match(notes, '^([0-9]+) of ([0-9]+)'))[2]::int)
         END AS score
  FROM facts
) g
WHERE g.id = f.id AND g.stage IS NOT NULL;

INSERT INTO schema_migrations (filename) VALUES ('127_dissent_costs_rungs.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
