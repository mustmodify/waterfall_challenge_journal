-- Recompute the name facts so 135's normalizer changes actually land, and
-- split the one alias claim that holds two names.
--
-- 135 taught name_display() to strip a trailing asterisk and stopped reading
-- "(TH)" as a remark, but facts are a cache: changing the function does not
-- change what was already computed. So the name fact for Uwharrie Falls still
-- read "Uwharrie Falls*", and feature 1206 still read "945 Big Cliff Falls
-- etc." even though 135 had made the table's "Big Cliff Falls" the accepted
-- claim. jw: "Yeah we should remove asterisks when normalizing names."
--
-- The alias list turned up its own bug. One claim holds two names in a single
-- string -- "Bust-Yer-Butt Falls;Driftwood Falls" -- so Drift Falls was
-- listed as answering to a name nobody uses, punctuation and all. Only one
-- claim of 50 does this, which is why it survived: a separator inside a value
-- is invisible until something tries to treat the value as a list.
--
-- Rerunnable.

BEGIN;

-- One name per claim.
UPDATE claims SET value = to_jsonb('Bust-Yer-Butt Falls'::text)
WHERE field = 'alias' AND value #>> '{}' = 'Bust-Yer-Butt Falls;Driftwood Falls';

INSERT INTO claims (group_id, feature_id, field, value, accepted, note)
SELECT c.group_id, c.feature_id, 'alias', to_jsonb('Driftwood Falls'::text), false,
       'Split from a claim that held two names in one string.'
FROM claims c
WHERE c.field = 'alias' AND c.value #>> '{}' = 'Bust-Yer-Butt Falls'
  AND NOT EXISTS (SELECT 1 FROM claims d WHERE d.feature_id = c.feature_id
                    AND d.field = 'alias' AND d.value #>> '{}' = 'Driftwood Falls')
ON CONFLICT DO NOTHING;

DELETE FROM facts WHERE key IN ('name', 'aliases');

-- ---------------------------------------------------------------- name --
WITH pts AS (
    SELECT DISTINCT ON (c.feature_id, s.src)
           c.id AS claim_id, c.feature_id, c.accepted, s.src,
           coalesce(c.normalized_value, c.value) #>> '{}' AS nm
    FROM claims c
    JOIN claim_groups cg ON cg.id = c.group_id
    CROSS JOIN LATERAL (SELECT CASE WHEN cg.source LIKE 'hikingwnc%'
                                    THEN 'hikingwnc' ELSE cg.source END) AS s(src)
    WHERE c.field = 'name' AND cg.identity_certain
      AND coalesce(c.normalized_value, c.value) #>> '{}' <> ''
    ORDER BY c.feature_id, s.src, c.accepted DESC, c.id
),
agreement AS (
    SELECT a.claim_id, a.feature_id, a.accepted, a.nm, count(*) AS agreeing
    FROM pts a
    JOIN pts b ON b.feature_id = a.feature_id
      AND replace(name_core(b.nm), ' ', '') = replace(name_core(a.nm), ' ', '')
    GROUP BY a.claim_id, a.feature_id, a.accepted, a.nm
),
totals AS (SELECT feature_id, count(*) AS n FROM pts GROUP BY feature_id),
winner AS (
    SELECT DISTINCT ON (a.feature_id) a.feature_id, a.nm, a.agreeing, t.n
    FROM agreement a JOIN totals t ON t.feature_id = a.feature_id
    ORDER BY a.feature_id, a.agreeing DESC, a.accepted DESC, length(a.nm), a.claim_id
)
INSERT INTO facts (feature_id, key, value, value_type, units,
                   confidence_stage, confidence_score, notes)
SELECT s.feature_id, 'name', s.nm, 'string', NULL,
       agreement_stage(s.agreeing::int, s.n::int),
       agreement_score(s.agreeing::int, s.n::int),
       agreement_note(s.agreeing::int, s.n::int,
                      'once punctuation, case and spacing are ignored')
FROM winner s;

-- ------------------------------------------------------------- aliases --
WITH a AS (
    SELECT c.feature_id,
           btrim(coalesce(c.normalized_value, c.value) #>> '{}') AS alias
    FROM claims c JOIN claim_groups cg ON cg.id = c.group_id
    WHERE c.field = 'alias' AND cg.identity_certain
      AND btrim(coalesce(c.normalized_value, c.value) #>> '{}') <> ''
  UNION
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
    SELECT a.feature_id, a.alias
    FROM a JOIN features f ON f.id = a.feature_id
    LEFT JOIN facts nf ON nf.feature_id = a.feature_id AND nf.key = 'name'
    -- Not an alias if it is the name, under either spelling of the name.
    WHERE replace(name_core(a.alias), ' ', '')
          IS DISTINCT FROM replace(name_core(f.name), ' ', '')
      AND replace(name_core(a.alias), ' ', '')
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

INSERT INTO schema_migrations (filename) VALUES ('136_recompute_names_and_split_aliases.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
