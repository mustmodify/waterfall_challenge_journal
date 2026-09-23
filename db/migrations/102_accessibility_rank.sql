-- accessibility is free text and has drifted to 71 distinct values over 934
-- waterfalls, because it is doing two jobs in one column: a difficulty rank
-- and a caveat. "Moderate+ (steep scramble)", "Roadside (don't get run
-- over)", "Moderate (with a 4x4 and open gates)". Comparing two sources means
-- getting the rank out of the prose first.
--
-- The ladder: Roadside 0, Easy 1, Moderate 2, Hard 3, Very Hard 4, with
-- Medium and Average folding into Moderate and Difficult into Hard. A
-- trailing + is half a step, ++ a whole one, and * is a footnote marker that
-- says nothing about difficulty.
--
-- Two sources agree if they land within half a step, which makes Moderate and
-- Moderate+ agreement. That tolerance is the point rather than sloppiness:
-- the + is essentially a hikingwnc habit, on 37% of its 885 ratings against
-- 8% of ncwaterfalls' 147 and none of dwhike's 39, so the usual cross-source
-- comparison is hikingwnc saying Moderate+ while another site says Moderate.
-- Demanding an exact match would manufacture a disagreement out of one site's
-- finer gradation.
--
-- Some values are not difficulty at all -- Kayak, Boat, Private, No access,
-- Not accessible for the public. Those get a null rank: whether you are
-- allowed to go is features.owner's job, and how you get there is not a
-- measure of how hard it is.

BEGIN;

CREATE FUNCTION accessibility_rank(raw text) RETURNS numeric
    LANGUAGE sql IMMUTABLE AS $$
    WITH base AS (
        -- Drop the parenthetical caveat; it is commentary, not difficulty.
        SELECT trim(regexp_replace(lower(coalesce(raw, '')), '\([^)]*\)', '', 'g')) AS b
    )
    SELECT CASE
        -- Access mode or permission, not difficulty.
        WHEN b ~ '(kayak|boat|private|no access|not accessible)' THEN NULL
        ELSE (
            CASE
                -- Highest first: "very hard" must not be read as "hard", and
                -- a range like "Easy/Moderate" resolves to its harder end,
                -- which is the safer way to be wrong when someone is deciding
                -- whether to take it on.
                WHEN b ~ 'very\s+hard'              THEN 4
                WHEN b ~ '(hard|difficult)'         THEN 3
                WHEN b ~ '(moderate|medium|average)' THEN 2
                WHEN b ~ 'easy'                     THEN 1
                WHEN b ~ 'roadside'                 THEN 0
                ELSE NULL
            END
            + CASE WHEN b ~ '\+\+' THEN 1.0 WHEN b ~ '\+' THEN 0.5 ELSE 0 END
        )
    END FROM base
$$;

COMMENT ON FUNCTION accessibility_rank(text) IS
    'Difficulty as a number so two sources can be compared: Roadside 0 to Very '
    'Hard 4, a trailing + worth half a step. Null where the value is about '
    'permission or transport rather than difficulty. Agreement is within half a '
    'step, because the + is a hikingwnc habit other sources do not share.';

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'johnathonwright') THEN
    ALTER FUNCTION accessibility_rank(text) OWNER TO johnathonwright;
  END IF;
END $$;

INSERT INTO schema_migrations (filename) VALUES ('102_accessibility_rank.sql');

COMMIT;
