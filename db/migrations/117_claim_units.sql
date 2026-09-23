-- Say what unit a claim is actually in, one claim at a time.
--
-- The feature page had a Units column filled in per field, which works for
-- height ("feet") and coordinates ("degrees") and falls apart for distance,
-- where it could only say "as written". That is true and useless. Courthouse
-- Falls shows why:
--
--   alltrails     3.8 mi
--   hikingwnc     0.7
--   ncwaterfalls  0.9 miles
--
-- Two of those carry their unit inline and one does not, so the unit belongs
-- to the claim rather than to the field. All three are miles, which is worth
-- saying out loud: it means the three readings really are comparable and the
-- disagreement between them is about distance, not about units.
--
-- hikingwnc's bare 0.7 is reported as miles without qualification. Nobody
-- wrote the word, but every source here that does spell it out means miles,
-- and a column that hedges on 733 of 1,222 rows is noise rather than
-- caution.
--
-- The vocabulary is hike_distance_feet()'s, deliberately: two places deciding
-- what "m" means would be one place too many.

BEGIN;

CREATE OR REPLACE FUNCTION claim_units(raw text, field text) RETURNS text
    LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    -- Converted on the way in, so the claim is already in feet whatever the
    -- source wrote. 117 does not fix that; it only reports it.
    WHEN field IN ('height_ft', 'elevation_ft', 'elevation_gain_ft') THEN 'feet'
    WHEN field IN ('coordinate', 'parking_coordinate', 'view_coordinate',
                   'coordinate_raw') THEN 'degrees'
    WHEN field IN ('beauty_rating', 'photo_rating', 'solitude_rating') THEN 'of 10'
    WHEN field = 'hike_distance' THEN
      CASE
        WHEN lower(coalesce(raw, '')) ~ 'roadside' THEN 'no walk'
        WHEN raw ~* 'yard'                         THEN 'yards'
        WHEN raw ~* 'kilometre|kilometer|\ykm\y'   THEN 'kilometres'
        WHEN raw ~* 'metre|meter'                  THEN 'metres'
        WHEN raw ~* '\yft\y|foot|feet'             THEN 'feet'
        WHEN raw ~* '\ym\y'
         AND coalesce(nullif(substring(raw from '([0-9]+(?:\.[0-9]+)?)'), '')::numeric, 0) >= 20
                                                   THEN 'metres'
        WHEN raw ~* 'mi\y|mile'                    THEN 'miles'
        -- A bare number is miles; the sources that spell it out all mean
        -- miles, and jw's call is to say so plainly rather than hedge.
        WHEN raw ~ '[0-9]'                         THEN 'miles'
        ELSE NULL
      END
    ELSE NULL
  END;
$$;

COMMENT ON FUNCTION claim_units(text, text) IS
    'The unit one claim is expressed in. Per claim rather than per field, '
    'because distances arrive as "3.8 mi", "0.9 miles" and a bare "0.7". '
    'Shares hike_distance_feet()''s vocabulary on purpose.';

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'johnathonwright') THEN
    ALTER FUNCTION claim_units(text, text) OWNER TO johnathonwright;
  END IF;
END $$;

INSERT INTO schema_migrations (filename) VALUES ('117_claim_units.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
