-- hike_distance is the worst-behaved field we compare. Only 2 of 210
-- multi-source features agree on it character for character, because the
-- sources are writing prose rather than filling in a number: "1.0 (out and
-- back)", "0.8 mi", "Approx 1.4 mile each way", "About 100 yards", "215
-- yards", "0.2 - Scramble", "Roadside", "0.25 to overlook (out and back) or
-- 0.40 to base (out and back)".
--
-- So it has to be parsed before it can be compared, and jw's call is to store
-- a canonical number in one small unit rather than trying to compare the
-- prose. Feet, matching height_ft / elevation_ft / elevation_gain_ft. The raw
-- claim is never touched; conversion happens on the way into facts.
--
-- Round trip is the unit of the field's own name, so anything the source
-- marks "each way" or "one way" is doubled -- the same rule walkMiles()
-- already applies in the browser.
--
-- The ambiguous-unit case jw raised: a bare "m" could be miles or metres, and
-- magnitude settles it, because no hike here is under 20 metres or over about
-- 36 miles. In practice the sources write "mi" or "miles" and the bare
-- numbers are miles, so this mostly guards against a future import.

BEGIN;

CREATE FUNCTION hike_distance_feet(raw text) RETURNS numeric
    LANGUAGE plpgsql IMMUTABLE AS $$
DECLARE
    t   text;
    num numeric;
    ft  numeric;
BEGIN
    t := lower(coalesce(raw, ''));

    -- An em dash is ncwaterfalls writing "we do not know", not a distance.
    IF t = '' OR t ~ '^\s*[—–-]\s*$' THEN
        RETURN NULL;
    END IF;

    -- No walk at all.
    IF t ~ 'roadside' THEN
        RETURN 0;
    END IF;

    -- First number in the string. "163 steps plus 123 yards" takes the 163,
    -- which is wrong, but it is one row and guessing which number a sentence
    -- means is worse than being predictable.
    num := nullif(substring(t from '([0-9]+(?:\.[0-9]+)?)'), '')::numeric;
    IF num IS NULL THEN
        RETURN NULL;
    END IF;

    IF t ~ 'yard' THEN
        ft := num * 3;
    ELSIF t ~ 'kilometre|kilometer|\ykm\y' THEN
        ft := num * 3280.84;
    ELSIF t ~ 'metre|meter' THEN
        ft := num * 3.28084;
    ELSIF t ~ '\yft\y|foot|feet' THEN
        ft := num;
    ELSIF t ~ '\ym\y' AND num >= 20 THEN
        -- Bare "m" with a big number is metres; a small one is miles.
        ft := num * 3.28084;
    ELSE
        ft := num * 5280;
    END IF;

    -- The column means round trip, so halve-distance phrasing doubles.
    IF t ~ 'each way|one way' THEN
        ft := ft * 2;
    END IF;

    RETURN round(ft);
END;
$$;

COMMENT ON FUNCTION hike_distance_feet(text) IS
    'Round-trip walking distance in feet, parsed out of the free text the '
    'sources write. Doubles anything marked each way or one way, since the '
    'field means round trip. Null where the value is not a distance at all.';

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'johnathonwright') THEN
    ALTER FUNCTION hike_distance_feet(text) OWNER TO johnathonwright;
  END IF;
END $$;

INSERT INTO schema_migrations (filename) VALUES ('107_hike_distance_feet.sql');

COMMIT;
