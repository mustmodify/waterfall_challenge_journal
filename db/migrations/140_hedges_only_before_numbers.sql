-- "about" is a hedge in front of a number and a preposition everywhere else.
--
-- The watercourse claims made this visible. ncwaterfalls writes, for one
-- waterfall, 'Moore Creek? See "Naming" for a discussion about the creek
-- name' -- and normalizing turned that into "for a discussion the creek
-- name", because the hedge list has stripped "about" wherever it appeared
-- since 115.
--
-- It went unnoticed while the rule only ran on measurements, where "about"
-- really is always a hedge: "About 100 yards", "about 2.4 miles". A hedge
-- word earns that name by sitting in front of a quantity, so that is now the
-- test. "Approx 60'" still normalizes; a sentence keeps its prepositions.
--
-- Rerunnable: recomputes every text claim.

BEGIN;

CREATE OR REPLACE FUNCTION normalize_claim_value(raw text, field text, source text)
    RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN field IN ('name', 'alias') THEN name_display(raw)
    WHEN field = 'access_status' THEN access_verdict(raw)
    WHEN field IN ('hike_distance', 'detour_hike_distance') THEN
      (hike_distance_feet(
         coalesce(
           nullif(btrim(regexp_replace(
             regexp_replace(
               regexp_replace(
                 regexp_replace(coalesce(raw, ''),
                   '\((?![^)]*(each way|one way|out and back|round trip))[^)]*\)',
                   ' ', 'gi'),
                 '\m(approx\.?|approximately|about|around|roughly|est\.?|estimated|circa|ca\.?)\M(?=\s*[~.]?\s*[0-9])',
                 ' ', 'gi'),
               '~', ' ', 'g'),
             '\s+', ' ', 'g'), ' .,;'), ''),
           coalesce(raw, '')))
       * CASE WHEN source = 'ncwaterfalls'
                AND coalesce(raw, '') !~* 'each way|one way|out and back|round trip'
              THEN 2 ELSE 1 END)::text
    ELSE nullif(btrim(regexp_replace(
      regexp_replace(
        regexp_replace(
          regexp_replace(coalesce(raw, ''),
            '\((?![^)]*(each way|one way|out and back|round trip))[^)]*\)',
            ' ', 'gi'),
          -- Only in front of a quantity. That is what makes it a hedge.
          '\m(approx\.?|approximately|about|around|roughly|est\.?|estimated|circa|ca\.?)\M(?=\s*[~.]?\s*[0-9])',
          ' ', 'gi'),
        '~', ' ', 'g'),
      '\s+', ' ', 'g'), ' .,;'), '')
  END;
$$;

UPDATE claims c
SET normalized_value = CASE
      WHEN jsonb_typeof(c.value) <> 'string' THEN NULL
      WHEN c.field IN ('hike_distance', 'detour_hike_distance') THEN
        to_jsonb(normalize_claim_value(c.value #>> '{}', c.field, cg.source))
      WHEN normalize_claim_value(c.value #>> '{}', c.field, cg.source)
           IS DISTINCT FROM (c.value #>> '{}')
       AND normalize_claim_value(c.value #>> '{}', c.field, cg.source) IS NOT NULL
        THEN to_jsonb(normalize_claim_value(c.value #>> '{}', c.field, cg.source))
      ELSE NULL
    END
FROM claim_groups cg
WHERE cg.id = c.group_id
  AND (jsonb_typeof(c.value) = 'string' OR c.normalized_value IS NOT NULL);

INSERT INTO schema_migrations (filename) VALUES ('140_hedges_only_before_numbers.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
