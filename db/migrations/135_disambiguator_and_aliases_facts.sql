-- Compute a disambiguator fact and an aliases fact, so a name can be short
-- and still be unique.
--
-- Publishing the name fact as-is would rename 138 features, lose 35 distinct
-- names and leave 33 names shared -- five High Falls, four Twin Falls, three
-- Boomer Inn Falls that used to say which floor. The sources agree on the
-- short name precisely because they do not carry our disambiguators, so
-- confidence is no help: "Little Creek Falls (Highlands)" is corroborated and
-- still wrong to rename.
--
-- jw's answer: keep both. "we should compute a 'disambiguator' fact if we
-- aren't already, and that should be appended to the place name in the UI.
-- Also an aliases fact which is an array."
--
-- So `name` holds what the waterfall is called, `disambiguator` holds what
-- tells it from the others, and the UI puts them back together. High Falls +
-- South Fork Mills River is then both correct and unique, which neither the
-- name alone nor the old combined string manages.
--
-- WHERE A DISAMBIGUATOR COMES FROM. Our own feature names, which are the
-- curated ones, in four shapes:
--
--   Twin Falls (Toxaway River)        a parenthetical that is not an alias
--   High Falls- South Fork Mills...   after a dash
--   Upper Falls @ Graveyard Fields    after an @
--   Pinnacle Falls SC (Beech Bot...)  a bare state code
--
-- TWO FIXES THE READING TURNED UP:
--
-- (TH) is a typo for (TN). Big Laurel Falls (TH) sits 1-2 km from four falls
-- marked (TN) in the Virgin Falls area of Tennessee, and there is a second
-- Big Laurel Falls in North Carolina 250 km away. It was being classified as
-- a remark because "th" was in the note vocabulary; it comes out.
--
-- Seven hikingwnc name claims carry a trailing asterisk -- "Uwharrie Falls*",
-- "Moravian Falls*", "Shacktown Falls*" -- which is a footnote marker on
-- their page, not part of any name. Our feature names are already clean, so
-- publishing the fact would have ADDED junk. name_display() strips it.
--
-- Also settles feature 1206. jw: "945 Big Cliff Falls etc. is actually Big
-- Cliff Falls as we discussed." 128 filed that name from the page's own
-- table; the older claim was still the accepted one and still winning.

BEGIN;

-- 'th' out of the note vocabulary: it is a mistyped state, not a remark.
CREATE OR REPLACE FUNCTION parenthetical_kind(inside text, field text) RETURNS text
    LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN field NOT IN ('name', 'alias') THEN NULL
    WHEN inside IS NULL OR btrim(inside) = '' THEN NULL
    WHEN inside ~* '(falls|waterfall|cascade|shoals|cataract)' THEN 'alias'
    WHEN inside ~* '^(my name|name|unofficial name|private|access restricted|gone|closed)\M'
      OR inside ~ '^[0-9]{2}-[0-9]{2}-[0-9]{4}$' THEN 'note'
    ELSE 'disambiguator'
  END;
$$;

-- A trailing asterisk is hikingwnc's footnote marker, never part of a name.
CREATE OR REPLACE FUNCTION name_display(raw text) RETURNS text
    LANGUAGE sql IMMUTABLE AS $$
  SELECT nullif(btrim(regexp_replace(
    regexp_replace(
      regexp_replace(
        regexp_replace(
          regexp_replace(coalesce(raw, ''), '\s+via\s+.*$', '', 'i'),
          '\([^)]*\)', ' ', 'g'),
        '\s*[-—–]\s*(a\.k\.a\.|hiking|photos?|maps?|guides?|directions?|history|visit(ing)?|info)\M.*$',
        '', 'i'),
      '\*+\s*$', '', 'g'),
    '\s+', ' ', 'g'), ' ,;-*'), '');
$$;

-- What tells this waterfall from the others that share its name.
CREATE OR REPLACE FUNCTION name_disambiguator(nm text) RETURNS text
    LANGUAGE sql IMMUTABLE AS $$
  SELECT nullif(btrim(coalesce(
    CASE WHEN parenthetical_kind(name_parenthetical(nm), 'name') = 'disambiguator'
         THEN name_parenthetical(nm) END,
    substring(nm from '(?:[-—–]|@)\s*([A-Z][^()]*)$'),
    -- A bare state code, whether it ends the name or precedes a parenthesis.
    substring(nm from '\s(SC|TN|GA|VA|NC)\s*(?:\(|$)')
  ), ''), '');
$$;

COMMENT ON FUNCTION name_disambiguator(text) IS
    'The qualifier that separates this waterfall from others of the same '
    'name, read off our own curated feature name: a non-alias parenthetical, '
    'text after a dash or an @, or a bare state code.';

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'johnathonwright') THEN
    ALTER FUNCTION name_disambiguator(text) OWNER TO johnathonwright;
  END IF;
END $$;

-- (TH) -> (TN). Keyboard-adjacent letters, a state that makes sense, and the
-- coordinate settles it: 35.844, -85.309 is White County, Tennessee, well
-- west of the North Carolina line and 1-2 km from Virgin Falls, Big Branch
-- Falls and both Sheep Cave Falls, every one of them marked (TN).
UPDATE features SET name = 'Big Laurel Falls (TN)'
WHERE id = 1216 AND name = 'Big Laurel Falls (TH)';

-- The table's reading of the name wins over the page title's counter.
UPDATE claims SET accepted = false
WHERE feature_id = 1206 AND field = 'name' AND accepted;
UPDATE claims c SET accepted = true
FROM claim_groups g
WHERE c.group_id = g.id AND g.ref = 'hikingwnc|1206|942-945-table' AND c.field = 'name';

-- Recompute the derived claim columns, so the asterisk and (TH) changes land.
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
WHERE cg.id = c.group_id AND c.field IN ('name', 'alias');

-- value_type gains 'array' for the aliases list.
ALTER TABLE facts DROP CONSTRAINT facts_value_type_known;
ALTER TABLE facts ADD CONSTRAINT facts_value_type_known CHECK (
  value_type = ANY (ARRAY['string','integer','decimal','coordinate','array']::text[]));

DELETE FROM facts WHERE key IN ('disambiguator', 'aliases');

-- ------------------------------------------------------- disambiguator --
INSERT INTO facts (feature_id, key, value, value_type, units,
                   confidence_stage, confidence_score, notes)
SELECT f.id, 'disambiguator', name_disambiguator(f.name), 'string', NULL,
       'single_source', 1.7,
       'Read off our own feature name, which is the curated one. Not something '
    || 'a source published, so it carries no corroboration of its own.'
FROM features f
WHERE f.kind = 'waterfall' AND name_disambiguator(f.name) IS NOT NULL;

-- ------------------------------------------------------------ aliases --
WITH a AS (
    SELECT c.feature_id,
           btrim(coalesce(c.normalized_value, c.value) #>> '{}') AS alias
    FROM claims c JOIN claim_groups cg ON cg.id = c.group_id
    WHERE c.field = 'alias' AND cg.identity_certain
      AND btrim(coalesce(c.normalized_value, c.value) #>> '{}') <> ''
  UNION
    -- A name's parenthesis that names water is another name for it.
    SELECT c.feature_id, btrim(c.parenthetical)
    FROM claims c JOIN claim_groups cg ON cg.id = c.group_id
    WHERE c.field = 'name' AND cg.identity_certain
      AND parenthetical_kind(c.parenthetical, 'name') = 'alias'
  UNION
    SELECT f.id, btrim(name_parenthetical(f.name))
    FROM features f
    WHERE parenthetical_kind(name_parenthetical(f.name), 'name') = 'alias'
),
kept AS (
    -- An "alias" identical to the name it belongs to is not an alias.
    SELECT a.feature_id, a.alias
    FROM a JOIN features f ON f.id = a.feature_id
    WHERE replace(name_core(a.alias), ' ', '')
          IS DISTINCT FROM replace(name_core(f.name), ' ', '')
)
INSERT INTO facts (feature_id, key, value, value_type, units,
                   confidence_stage, confidence_score, notes)
SELECT feature_id, 'aliases',
       json_agg(DISTINCT alias ORDER BY alias)::text, 'array', NULL,
       'single_source', 1.7,
       count(DISTINCT alias) || ' other name' ||
       CASE WHEN count(DISTINCT alias) = 1 THEN '' ELSE 's' END ||
       ' this waterfall answers to'
FROM kept GROUP BY feature_id;

INSERT INTO schema_migrations (filename) VALUES ('135_disambiguator_and_aliases_facts.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
