-- claims is supposed to hold raw data, so give it somewhere to put the
-- tidied-up version instead of tidying in place.
--
-- CLAUDE.md is explicit that what arrives from a source is raw and untrusted,
-- and the pipeline runs claims -> arbitration -> the surface. Two fields
-- already work that way: accessibility keeps "Moderate Class I bushwhack" and
-- hike_distance keeps "About 100 yards", with accessibility_rank() and
-- hike_distance_feet() interpreting further down. The cost is that every
-- reader has to cope with the prose. normalized_value is that cost paid once:
-- the source's own words stay in value, the tidied version sits beside it.
--
--   Approx 60'                                  ->  60'
--   Approx 30' (sliding distance is about 60')  ->  30'
--   ~250 ft                                     ->  250 ft
--   About 2.4 miles                             ->  2.4 miles
--
-- "Approximately" is dropped rather than recorded. 104 built
-- height_is_approximate() on the theory that "approx 15" tells you something
-- a bare 15 does not; jw's call is that it is noise, because every one of
-- these numbers is approximate and the ones that stay quiet about it are not
-- more exact for it.
--
-- TWO THINGS A BLANKET STRIP WOULD RUIN, both found by running it:
--
-- Names. "Rainbow Falls (Gorges)", "High Falls (West Fork Tuskasegee River)",
-- "Glen Falls (Upper)" -- the parenthesis is the entire disambiguator, and
-- for exactly the generic names that collide across the region. Stripping it
-- turns three different waterfalls into one. So names and aliases are left
-- alone completely; there is no hedging in a name to remove anyway.
--
-- Direction. 285 distances say "(out and back)" and 3 say "(each way)", and
-- hike_distance_feet() doubles the latter. Dropping that parenthesis halves
-- a hike. So a parenthetical is removed only when it does not carry a
-- direction word.
--
-- Null means there was nothing to tidy, so read it as
-- coalesce(normalized_value, value). That keeps thousands of identical copies
-- out of the table.
--
-- What this does NOT fix: height_ft, elevation_ft and elevation_gain_ft still
-- hold a number the importer converted rather than what the source wrote, so
-- there is no raw text here to normalize. Recovering those means re-importing
-- from data/, which still holds every original -- a separate migration.

BEGIN;

ALTER TABLE claims ADD COLUMN IF NOT EXISTS normalized_value jsonb;

COMMENT ON COLUMN claims.normalized_value IS
    'value with hedges ("approx", "about", "~") and parenthetical asides '
    'removed. Null when value needed no tidying, so read it as '
    'coalesce(normalized_value, value).';

CREATE OR REPLACE FUNCTION normalize_claim_value(raw text, field text)
    RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    -- A name's parenthesis is its disambiguator, not an aside.
    WHEN field IN ('name', 'alias') THEN NULL
    ELSE nullif(btrim(regexp_replace(
      regexp_replace(
        regexp_replace(
          -- Asides first, or "(sliding distance is about 60')" leaves its own
          -- "about" behind. Kept when the parenthesis says which direction,
          -- since hike_distance_feet() doubles "each way".
          regexp_replace(coalesce(raw, ''),
            '\((?![^)]*(each way|one way|out and back|round trip))[^)]*\)',
            ' ', 'gi'),
          '\m(approx\.?|approximately|about|around|roughly|est\.?|estimated|circa|ca\.?)\M',
          ' ', 'gi'),
        '~', ' ', 'g'),
      '\s+', ' ', 'g'), ' .,;'), '')
  END;
$$;

COMMENT ON FUNCTION normalize_claim_value(text, text) IS
    'Strips hedging words, tildes and parenthetical asides, then collapses '
    'whitespace. Case is preserved: this tidies a value, it does not fold it. '
    'Names and aliases are returned null -- their parentheses disambiguate '
    'colliding waterfalls and must survive. Parentheses naming a direction '
    'survive too, because the distance parser reads them.';

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'johnathonwright') THEN
    ALTER FUNCTION normalize_claim_value(text, text) OWNER TO johnathonwright;
  END IF;
END $$;

DROP FUNCTION IF EXISTS normalize_claim_value(text);

-- Rerunnable: recompute every row, so a change to the rules above takes
-- effect on a re-run rather than only applying to rows that had nothing.
UPDATE claims c
SET normalized_value = CASE
      WHEN jsonb_typeof(c.value) <> 'string' THEN NULL
      WHEN normalize_claim_value(c.value #>> '{}', c.field)
           IS DISTINCT FROM (c.value #>> '{}')
       AND normalize_claim_value(c.value #>> '{}', c.field) IS NOT NULL
        THEN to_jsonb(normalize_claim_value(c.value #>> '{}', c.field))
      ELSE NULL
    END
WHERE c.normalized_value IS NOT NULL
   OR jsonb_typeof(c.value) = 'string';

INSERT INTO schema_migrations (filename) VALUES ('115_claims_normalized_value.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
