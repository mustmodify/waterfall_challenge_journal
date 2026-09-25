-- Keep what normalizing takes out of a name, without deciding what it is.
--
-- 115 left names alone because stripping their parentheses turned "Rainbow
-- Falls (Gorges)", "High Falls (West Fork Tuskasegee River)" and "Glen Falls
-- (Upper)" into three names that collide. That was right with nowhere to put
-- the parenthesis. This gives it somewhere.
--
-- jw's observation is what settles the shape: the raw value for anything
-- lifted out of a name is still the name claim. Nobody published "Gorges" as
-- a fact about this waterfall, so it is a derived column beside
-- normalized_value, not a claim row of its own with invented provenance.
--
-- The column is called parenthetical rather than disambiguator because
-- READING ALL 178 OF THEM says only some of them are one:
--
--   18  alias          Bubbling Springs Cascades (Guardrail Falls)
--                      Wildcat Wayside (Wildcat Branch Falls)
--  138  disambiguator  Rainbow Falls (Gorges), Glen Falls (Upper)
--                      High Falls (West Fork Tuskasegee River)
--   22  note           Amos Creek Falls (My name)
--                      Waterfall #9 (04-14-2022), Crabtree Falls (access restricted)
--
-- Guardrail Falls is the case that makes a single "disambiguator" column
-- wrong: it is another name for the same water, not a way of telling two
-- waters apart. So this stores the text and says nothing about its meaning.
-- parenthetical_kind() offers a reading, and a later migration can promote
-- the ones that survive review into a disambiguator column of their own --
-- by which time a person will have looked at 178 rows rather than a regex
-- having guessed at them.
--
-- Deliberately not called note: claims.note already exists and holds importer
-- provenance ("OpenStreetMap tag height=60."). Two notes columns side by side
-- would be worse than a plain description of what this actually contains.
--
-- Dashes are NOT a split point, though they look like one. ncwaterfalls
-- appends "-Hiking Guide, Photos, Map & Directions" to its page titles and
-- that is noise, but "Bust-Your-Butt Falls" is a real waterfall,
-- "Mountains-to-Sea Trail" is a real trail and "Foothills Trail - A4 to A8"
-- is a real route. So the tail is cut only where the dash is followed by the
-- vocabulary name_core() already recognises as marketing -- and it is
-- dropped, not kept, because no one needs "Photos, Map & Directions" back.
--
-- name_display() is name_core()'s sibling: the same cuts, but it keeps case
-- and punctuation, because this one is read by people where name_core() is a
-- match key that gets lowercased and stripped anyway.

BEGIN;

ALTER TABLE claims ADD COLUMN IF NOT EXISTS parenthetical text;

COMMENT ON COLUMN claims.parenthetical IS
    'What normalizing lifted out of value, verbatim and unclassified -- '
    '"Gorges", "Upper", "Guardrail Falls", "My name". Derived, not claimed: '
    'the raw value is still the claim. For a name, parenthetical_kind() reads '
    'it as an alias, a disambiguator or a note, but that reading is not '
    'stored yet. On other fields it is plain description.';

CREATE OR REPLACE FUNCTION name_display(raw text) RETURNS text
    LANGUAGE sql IMMUTABLE AS $$
  SELECT nullif(btrim(regexp_replace(
    regexp_replace(
      regexp_replace(coalesce(raw, ''), '\([^)]*\)', ' ', 'g'),
      '\s*[-—–]\s*(a\.k\.a\.|hiking|photos?|maps?|guides?|directions?|history|visit(ing)?|info)\M.*$',
      '', 'i'),
    '\s+', ' ', 'g'), ' ,;-'), '');
$$;

COMMENT ON FUNCTION name_display(text) IS
    'name_core() for people rather than for matching: drops the parenthetical '
    'and the SEO tail, but keeps case and punctuation.';

CREATE OR REPLACE FUNCTION name_parenthetical(raw text) RETURNS text
    LANGUAGE sql IMMUTABLE AS $$
  SELECT nullif(btrim(substring(coalesce(raw, '') from '\(([^)]*)\)')), '');
$$;

-- A reading of the parenthesis, offered rather than stored.
--
-- Takes the field because the reading only makes sense for a name. The other
-- fields carry parentheses too -- "(usually dry)" on a distance, "(bushwhack)"
-- on an accessibility -- and those are plain description, not a name's alias
-- or qualifier. Asking this of them returns null rather than a guess.
DROP FUNCTION IF EXISTS parenthetical_kind(text);
CREATE OR REPLACE FUNCTION parenthetical_kind(inside text, field text) RETURNS text
    LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN field NOT IN ('name', 'alias') THEN NULL
    WHEN inside IS NULL OR btrim(inside) = '' THEN NULL
    -- An alias is another name for the same water, so it names water.
    WHEN inside ~* '(falls|waterfall|cascade|shoals|cataract)' THEN 'alias'
    -- Provenance and status, not part of anybody's name.
    WHEN inside ~* '^(my name|name|unofficial name|private|access restricted|th|gone|closed)\M'
      OR inside ~ '^[0-9]{2}-[0-9]{2}-[0-9]{4}$' THEN 'note'
    ELSE 'disambiguator'
  END;
$$;

COMMENT ON FUNCTION parenthetical_kind(text, text) IS
    'Which of the three things a name''s parenthesis is holding: alias, '
    'disambiguator or note. Null for every other field, whose parentheses are '
    'description rather than naming. A reading, not a verdict -- see 116 for '
    'the counts it was derived from.';

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'johnathonwright') THEN
    ALTER FUNCTION name_display(text) OWNER TO johnathonwright;
    ALTER FUNCTION name_parenthetical(text) OWNER TO johnathonwright;
    ALTER FUNCTION parenthetical_kind(text, text) OWNER TO johnathonwright;
  END IF;
END $$;

-- Names now normalize, where 115 returned null for them.
CREATE OR REPLACE FUNCTION normalize_claim_value(raw text, field text)
    RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN field IN ('name', 'alias') THEN name_display(raw)
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

-- Rerunnable: recompute both derived columns for every claim. The
-- parenthetical is kept wherever one was removed, on any field -- a height of
-- "Approx 30' (sliding distance is about 60')" loses that aside too, and it
-- is worth as much as a name's.
UPDATE claims c
SET normalized_value = CASE
      WHEN jsonb_typeof(c.value) <> 'string' THEN NULL
      WHEN normalize_claim_value(c.value #>> '{}', c.field)
           IS DISTINCT FROM (c.value #>> '{}')
       AND normalize_claim_value(c.value #>> '{}', c.field) IS NOT NULL
        THEN to_jsonb(normalize_claim_value(c.value #>> '{}', c.field))
      ELSE NULL
    END,
    parenthetical = CASE
      WHEN jsonb_typeof(c.value) <> 'string' THEN NULL
      -- Only where normalizing actually dropped it: a distance keeping
      -- "(out and back)" has not lost anything to record.
      WHEN name_parenthetical(c.value #>> '{}') IS NOT NULL
       AND coalesce(normalize_claim_value(c.value #>> '{}', c.field), '')
           NOT LIKE '%(' || name_parenthetical(c.value #>> '{}') || ')%'
        THEN name_parenthetical(c.value #>> '{}')
      ELSE NULL
    END
WHERE jsonb_typeof(c.value) = 'string'
   OR c.normalized_value IS NOT NULL
   OR c.parenthetical IS NOT NULL;

INSERT INTO schema_migrations (filename) VALUES ('116_name_disambiguator.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
