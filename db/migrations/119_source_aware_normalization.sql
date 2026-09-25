-- Normalizing has to know which source it is reading.
--
-- Two things that cannot be decided from the text alone:
--
-- 1. AllTrails names a route, not a waterfall. "Courthouse Falls via Summey
--    Cove Trail" is how you get there, and 285 of its names carry a "via"
--    tail. Dropping it makes all four sources agree that the place is called
--    Courthouse Falls, which is what they all actually say.
--
-- 2. ncwaterfalls measures one way. The note has said so on 146 claims since
--    043, and nothing ever acted on it, because hike_distance_feet() only
--    doubles when the text says "each way" -- and Kevin's bare "0.9 miles"
--    says nothing. So the normalized column has been holding one-way feet for
--    him and round-trip feet for everyone else while the units column claimed
--    both were "feet". Uniform to look at, not uniform in fact, which is the
--    exact failure 118 was meant to prevent.
--
-- The one-way reading is measured, not assumed. Across the 80 features where
-- ncwaterfalls and hikingwnc both give a distance, and where hikingwnc marks
-- round trip explicitly, his figures run at 0.57 of theirs on average, with
-- 41 of 80 falling between 0.4 and 0.6 and only 5 within 20% of equal:
--
--   Bradley Cooper Falls   2.5 miles  against  4.5                0.56
--   Bridalveil (DuPont)    2.4 miles  against  4.2                0.57
--   Bennett Cove Falls     0.8 miles  against  2.1 (out and back) 0.38
--
-- He does not state the convention anywhere on his site, so this is inference
-- from his numbers rather than a rule he published. All 147 of his distance
-- claims are unmarked, so there is no risk of doubling something already
-- doubled.
--
-- Worth being clear what this does not fix: doubling removes a systematic
-- bias, it does not make the sources agree. Bubbling Springs sits at 0.11 and
-- Balsam Falls at 0.25 even afterwards, because those two describe different
-- approaches from different trailheads. That is a real disagreement and
-- should stay visible as one.
--
-- The two-argument normalize_claim_value() stays as a wrapper so 115, 116 and
-- 118 remain runnable.

BEGIN;

CREATE OR REPLACE FUNCTION name_display(raw text) RETURNS text
    LANGUAGE sql IMMUTABLE AS $$
  SELECT nullif(btrim(regexp_replace(
    regexp_replace(
      regexp_replace(
        -- "... via Summey Cove Trail" is the route, not the waterfall.
        regexp_replace(coalesce(raw, ''), '\s+via\s+.*$', '', 'i'),
        '\([^)]*\)', ' ', 'g'),
      '\s*[-—–]\s*(a\.k\.a\.|hiking|photos?|maps?|guides?|directions?|history|visit(ing)?|info)\M.*$',
      '', 'i'),
    '\s+', ' ', 'g'), ' ,;-'), '');
$$;

CREATE OR REPLACE FUNCTION normalize_claim_value(raw text, field text, source text)
    RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN field IN ('name', 'alias') THEN name_display(raw)
    WHEN field = 'hike_distance' THEN
      (hike_distance_feet(
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
           coalesce(raw, '')))
       -- One way, so a round trip is twice. Only where the text has not
       -- already said so and had it doubled for us.
       * CASE WHEN source = 'ncwaterfalls'
                AND coalesce(raw, '') !~* 'each way|one way|out and back|round trip'
              THEN 2 ELSE 1 END)::text
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

COMMENT ON FUNCTION normalize_claim_value(text, text, text) IS
    'The uniform form of a claim: a display name for names, round-trip feet '
    'for distances, tidied text otherwise. Takes the source because two '
    'conventions cannot be read off the text -- AllTrails names routes, and '
    'ncwaterfalls measures one way.';

-- Kept so the earlier migrations still run.
CREATE OR REPLACE FUNCTION normalize_claim_value(raw text, field text)
    RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT normalize_claim_value(raw, field, NULL);
$$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'johnathonwright') THEN
    ALTER FUNCTION normalize_claim_value(text, text, text) OWNER TO johnathonwright;
  END IF;
END $$;

-- Rerunnable, and now reading the group's source.
UPDATE claims c
SET normalized_value = CASE
      WHEN jsonb_typeof(c.value) <> 'string' THEN NULL
      WHEN c.field = 'hike_distance' THEN
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

INSERT INTO schema_migrations (filename) VALUES ('119_source_aware_normalization.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
