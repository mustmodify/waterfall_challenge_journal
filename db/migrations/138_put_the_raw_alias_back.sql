-- Put back a raw value I edited, and split it where splitting belongs.
--
-- 136 did this:
--
--   UPDATE claims SET value = 'Bust-Yer-Butt Falls'
--   WHERE value = 'Bust-Yer-Butt Falls;Driftwood Falls'
--
-- and then invented a second claim to hold the other half. That is the rule
-- this project runs on, broken twice in three lines: OpenStreetMap published
-- one alt_name containing both names, and we overwrote what it said and
-- fabricated a claim it never made. Re-importing the Overpass extract would
-- restore the semicolon string and leave the invented claim beside it.
--
-- jw, on the same mistake in 135: "raw values SHOULD NEVER be changed ... we
-- use superuser (ai or human) claims to override in those cases, which leaves
-- an audit trail. We should in principle have a pipeline set up so that we
-- could remove all the data other than override claims, re-generate claims
-- from what's in /data, regenerate facts, and everything would be the same."
--
-- The semicolon is not even a mistake. It is OpenStreetMap's documented
-- separator for a multi-valued tag, so "Bust-Yer-Butt Falls;Driftwood Falls"
-- is the source correctly saying two things in one field. Reading it is
-- normalizing's job, which is exactly where it goes.
--
-- 130 is a milder version of the same thing and is left alone deliberately:
-- it re-filed 116 claims from parking_coordinate to trailhead_coordinate,
-- changing our categorisation rather than the source's words. Defensible, but
-- it does not replay -- re-running the importer files them as parking again,
-- because the importer is where that bug actually lives. Noted here so the
-- next person fixing script/import/claims/ncwaterfalls.py knows why.

BEGIN;

-- Undo the fabricated claim.
DELETE FROM claims
WHERE field = 'alias'
  AND note = 'Split from a claim that held two names in one string.';

-- Restore what OpenStreetMap actually published.
UPDATE claims SET value = to_jsonb('Bust-Yer-Butt Falls;Driftwood Falls'::text)
WHERE field = 'alias' AND value #>> '{}' = 'Bust-Yer-Butt Falls'
  AND group_id IN (SELECT id FROM claim_groups WHERE source = 'openstreetmap');

-- Splitting is normalizing's job. A semicolon is OSM's multi-value separator,
-- so an alias claim can legitimately hold several names.
DELETE FROM facts WHERE key = 'aliases';

WITH raw AS (
    SELECT c.feature_id, coalesce(c.normalized_value, c.value) #>> '{}' AS txt
    FROM claims c JOIN claim_groups cg ON cg.id = c.group_id
    WHERE c.field = 'alias' AND cg.identity_certain
  UNION ALL
    SELECT c.feature_id, c.parenthetical
    FROM claims c JOIN claim_groups cg ON cg.id = c.group_id
    WHERE c.field = 'name' AND cg.identity_certain
      AND parenthetical_kind(c.parenthetical, 'name') = 'alias'
  UNION ALL
    SELECT f.id, name_parenthetical(f.name)
    FROM features f
    WHERE parenthetical_kind(name_parenthetical(f.name), 'name') = 'alias'
),
split AS (
    SELECT feature_id, btrim(part) AS alias
    FROM raw, LATERAL regexp_split_to_table(coalesce(txt, ''), '\s*;\s*') AS part
    WHERE btrim(part) <> ''
),
kept AS (
    SELECT s.feature_id, s.alias
    FROM split s JOIN features f ON f.id = s.feature_id
    LEFT JOIN facts nf ON nf.feature_id = s.feature_id AND nf.key = 'name'
    WHERE replace(name_core(s.alias), ' ', '')
          IS DISTINCT FROM replace(name_core(f.name), ' ', '')
      AND replace(name_core(s.alias), ' ', '')
          IS DISTINCT FROM replace(name_core(coalesce(nf.value, f.name)), ' ', '')
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

INSERT INTO schema_migrations (filename) VALUES ('138_put_the_raw_alias_back.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
