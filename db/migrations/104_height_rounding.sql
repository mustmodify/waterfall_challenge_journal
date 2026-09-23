-- Comparing two heights needs to know which one is a measurement and which
-- is a shrug. jw's rule: a rounded number reads as approximate and an
-- unrounded one reads as exact, and what counts as rounded depends on
-- magnitude -- under 50 ft people round to 5, from 50 to 100 to 10 or 25,
-- above that to 25.
--
-- So 125 is approximate and 146 is exact, and when the two are within 15% the
-- exact one wins. Feature 393 is the case: hikingwnc says 125 and
-- ncwaterfalls says 146, which is (146-125)/146 = 14.4% apart, inside the
-- band, so 146 is the better answer. The percentage is always measured
-- against the larger value, which keeps it independent of argument order --
-- measuring against 125 instead gives 16.8% and flips the outcome, so this
-- is deliberate rather than incidental.
--
-- Only 5 of 71 multi-source heights agree exactly, so exact equality is not a
-- usable comparison here.

BEGIN;

-- Is this number rounded at the granularity people use for its size?
CREATE FUNCTION height_is_approximate(feet numeric) RETURNS boolean
    LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE
        WHEN feet IS NULL THEN NULL
        WHEN feet < 50  THEN feet::numeric % 5 = 0
        WHEN feet <= 100 THEN feet::numeric % 10 = 0 OR feet::numeric % 25 = 0
        ELSE feet::numeric % 25 = 0
    END
$$;

COMMENT ON FUNCTION height_is_approximate(numeric) IS
    'True when a height is rounded at the granularity people use for numbers '
    'that size -- under 50 to the nearest 5, 50-100 to 10 or 25, above that to '
    '25 -- which is the signal that it is an estimate rather than a measurement.';

-- How far apart two heights are, as a fraction of the larger. Against the
-- larger rather than either one, so the answer does not depend on which is
-- passed first.
CREATE FUNCTION height_gap(a numeric, b numeric) RETURNS numeric
    LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE
        WHEN a IS NULL OR b IS NULL OR greatest(a, b) = 0 THEN NULL
        ELSE (greatest(a, b) - least(a, b)) / greatest(a, b)
    END
$$;

COMMENT ON FUNCTION height_gap(numeric, numeric) IS
    'Difference between two heights as a fraction of the larger. Within 0.15, '
    'an exact reading beats an approximate one; beyond it, neither wins and the '
    'honest answer is a range.';

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'johnathonwright') THEN
    ALTER FUNCTION height_is_approximate(numeric) OWNER TO johnathonwright;
    ALTER FUNCTION height_gap(numeric, numeric) OWNER TO johnathonwright;
  END IF;
END $$;

INSERT INTO schema_migrations (filename) VALUES ('104_height_rounding.sql');

COMMIT;
