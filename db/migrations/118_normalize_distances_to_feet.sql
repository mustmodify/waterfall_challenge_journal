-- Normalize distances all the way to one number in one unit.
--
-- jw: "The whole point of normalization is to come to a uniform set of
-- values. We'd rather have a uniform set and figure out it was wrong than go
-- disparate."
--
-- 115 and 116 only went half way. A distance's normalized_value had the
-- hedging taken out and was still whatever shape the source wrote it in:
--
--   alltrails     3.8 mi
--   hikingwnc     0.7
--   ncwaterfalls  0.9 miles
--
-- Three strings that cannot be compared without parsing them again, which is
-- what facts was doing on the way past. So the parse moves up: the raw text
-- stays in value, and normalized_value holds feet, the same unit height_ft
-- and elevation_ft already use.
--
-- The trade jw is naming is worth being explicit about. Parsing here commits
-- to a reading, and a wrong reading becomes a wrong number rather than
-- staying ambiguous prose -- "163 steps plus 123 yards" normalizes to 163
-- yards, which is wrong. That is the point: a wrong number is visible on the
-- page beside the raw text it came from, whereas prose nobody can compare
-- stays wrong quietly and forever. Nothing is lost either way, because value
-- keeps the original.
--
-- claim_units now reports the unit of the normalized value rather than of the
-- raw one, so it reads "feet" for every distance. The source's own unit has
-- not gone anywhere: it is sitting in the Value column, in "3.8 mi".

BEGIN;

CREATE OR REPLACE FUNCTION claim_units(raw text, field text) RETURNS text
    LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN field IN ('height_ft', 'elevation_ft', 'elevation_gain_ft') THEN 'feet'
    -- Uniform by construction now, rather than by luck of what was written.
    WHEN field = 'hike_distance' THEN 'feet'
    WHEN field IN ('coordinate', 'parking_coordinate', 'view_coordinate',
                   'coordinate_raw') THEN 'degrees'
    WHEN field IN ('beauty_rating', 'photo_rating', 'solitude_rating') THEN 'of 10'
    ELSE NULL
  END;
$$;

COMMENT ON FUNCTION claim_units(text, text) IS
    'The unit a claim''s normalized_value is in. Uniform per field, because '
    'normalizing converts to it -- the source''s own unit stays visible in '
    'the raw value.';

CREATE OR REPLACE FUNCTION normalize_claim_value(raw text, field text)
    RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN field IN ('name', 'alias') THEN name_display(raw)
    -- All the way to feet, not just tidied. hike_distance_feet() already
    -- knows the vocabulary and already doubles "each way", so the hedges and
    -- asides are stripped first and handed to it.
    WHEN field = 'hike_distance' THEN
      hike_distance_feet(
        coalesce(
          nullif(btrim(regexp_replace(
            regexp_replace(
              regexp_replace(
                regexp_replace(coalesce(raw, ''),
                  '\((?![^)]*(each way|one way|out and back|round trip))[^)]*\)',
                  ' ', 'gi'),
                '\m(approx\.?|approximately|about|around|roughly|est\.?|estimated|circa|ca\.?)\M',
                ' ', 'gi'),
              '~', ' ', 'g'),
            '\s+', ' ', 'g'), ' .,;'), ''),
          coalesce(raw, '')))::text
    ELSE nullif(btrim(regexp_replace(
      regexp_replace(
        regexp_replace(
          regexp_replace(coalesce(raw, ''),
            '\((?![^)]*(each way|one way|out and back|round trip))[^)]*\)',
            ' ', 'gi'),
          '\m(approx\.?|approximately|about|around|roughly|est\.?|estimated|circa|ca\.?)\M',
          ' ', 'gi'),
        '~', ' ', 'g'),
      '\s+', ' ', 'g'), ' .,;'), '')
  END;
$$;

-- Rerunnable. Distances become numbers; everything else keeps 116's rules.
UPDATE claims c
SET normalized_value = CASE
      WHEN jsonb_typeof(c.value) <> 'string' THEN NULL
      WHEN c.field = 'hike_distance' THEN
        to_jsonb(normalize_claim_value(c.value #>> '{}', c.field))
      WHEN normalize_claim_value(c.value #>> '{}', c.field)
           IS DISTINCT FROM (c.value #>> '{}')
       AND normalize_claim_value(c.value #>> '{}', c.field) IS NOT NULL
        THEN to_jsonb(normalize_claim_value(c.value #>> '{}', c.field))
      ELSE NULL
    END
WHERE jsonb_typeof(c.value) = 'string'
   OR c.normalized_value IS NOT NULL;

INSERT INTO schema_migrations (filename) VALUES ('118_normalize_distances_to_feet.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
