-- Who may go there, read partly off the names.
--
-- jw: "we should create a normalizer that creates that kind of access fact
-- based in part on the name claims."
--
-- Three of our names carry a permission note in their parenthetical --
-- "English Falls (access restricted)", "Cover Falls (Private)", "Rainbow
-- Falls (Private along US64)" -- and OpenStreetMap tags two more access=
-- private outright. Until now that only ever showed up as text inside a
-- name, which means nothing could filter on it or answer a question with it.
--
-- This is a normalizer rather than three hand-written claims so the next
-- import gets the same reading for free. Nothing is copied out of the names
-- into a column: the raw names are untouched, and the fact is rebuilt from
-- them the way every other fact is rebuilt from its claims.
--
-- access is not access_status. access_status is whether you can get there
-- today -- a washed-out trail, a storm closure, something that will change.
-- access is whether you are allowed to, which mostly does not.
--
-- No fact is written where nothing has been said. Most of these waterfalls
-- are on national forest and nobody has bothered to state it, and writing
-- "public" for 900 features on that reasoning would be inventing data rather
-- than recording it. access_status has an 'unverified' value because you
-- asked for one there; whether access wants the same is your call.

BEGIN;

-- The permission note some names carry, or nothing.
--
-- Deliberately narrow. "(Private along US64)" says two things -- who owns it
-- and where it is -- and this reads only the first; the second is a
-- disambiguator question, not an access one.
CREATE OR REPLACE FUNCTION access_from_name(raw text) RETURNS text AS $$
  SELECT CASE
    WHEN p.inside IS NULL THEN NULL
    WHEN p.inside ~* '\mprivate\M' THEN 'private'
    WHEN p.inside ~* '(access restricted|no public access|permission required|by permission|permission only)'
      THEN 'restricted'
  END
  FROM (SELECT name_parenthetical(raw) AS inside) p;
$$ LANGUAGE sql IMMUTABLE;

-- Normalize what the sources already said, so a claimed 'private' and a
-- name-read 'private' are the same string.
UPDATE claims SET normalized_value = to_jsonb(lower(btrim(value #>> '{}')))
WHERE field = 'access'
  AND lower(btrim(value #>> '{}')) IN ('private', 'restricted', 'permissive',
                                       'yes', 'no', 'customers', 'destination');

DELETE FROM facts WHERE key = 'access';

WITH claimed AS (
    SELECT DISTINCT ON (c.feature_id)
           c.feature_id,
           btrim(coalesce(c.normalized_value, c.value) #>> '{}') AS value,
           cg.source
    FROM claims c JOIN claim_groups cg ON cg.id = c.group_id
    WHERE c.field = 'access' AND cg.identity_certain
      AND btrim(coalesce(c.normalized_value, c.value) #>> '{}') <> ''
    ORDER BY c.feature_id, c.accepted DESC, c.id DESC
),
read_off AS (
    SELECT f.id AS feature_id, access_from_name(f.name) AS value
    FROM features f
    WHERE f.kind = 'waterfall' AND access_from_name(f.name) IS NOT NULL
)
INSERT INTO facts (feature_id, key, value, value_type, units,
                   confidence_stage, confidence_score, notes)
SELECT f.id, 'access',
       coalesce(cl.value, ro.value), 'string', NULL,
       'single_source', 1.7,
       CASE WHEN cl.feature_id IS NOT NULL
            THEN 'Stated by ' || cl.source || '.'
            ELSE 'Read off the parenthetical in the name, which is where this '
              || 'was recorded before there was a field for it. One source, and '
              || 'a terse one -- worth confirming before anyone relies on it.'
       END
FROM features f
LEFT JOIN claimed cl ON cl.feature_id = f.id
LEFT JOIN read_off ro ON ro.feature_id = f.id
WHERE f.kind = 'waterfall'
  AND coalesce(cl.value, ro.value) IS NOT NULL;

-- Rainbow Falls lost its qualifier when the parenthetical was classified as a
-- remark rather than a disambiguator, which is true of "Private" and false of
-- "along US64" -- and there are four Rainbow Falls, so without one the map
-- shows two places by the same name and no way to tell them apart. The other
-- three are (Camp Greenville), (Horsepasture River) and (GSMNP); this one
-- gets the road it sits on, which is the same kind of answer.
INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, observed_on, note) VALUES
('wanderfall|1069|disambiguator-us64', 1069, 'wanderfall', NULL, true, '2026-09-24',
 'Our reading of our own name, not something a source published.')
ON CONFLICT (ref) DO NOTHING;

INSERT INTO claims (group_id, feature_id, field, value, normalized_value, accepted, note)
SELECT g.id, 1069, 'disambiguator',
       to_jsonb('Private along US64'::text), to_jsonb('US 64'::text), true,
       'The parenthetical carries both an owner and a location. The owner half '
    || 'is now the access fact; this is the other half, which is what actually '
    || 'tells this Rainbow Falls from the three others.'
FROM claim_groups g WHERE g.ref = 'wanderfall|1069|disambiguator-us64'
ON CONFLICT DO NOTHING;

DELETE FROM facts WHERE feature_id = 1069 AND key = 'disambiguator';
INSERT INTO facts (feature_id, key, value, value_type, units,
                   confidence_stage, confidence_score, notes)
VALUES (1069, 'disambiguator', 'US 64', 'string', NULL, 'single_source', 1.7,
        'Claimed by wanderfall, which reads the raw name rather than repeating it.');

INSERT INTO schema_migrations (filename) VALUES ('142_access_reads_the_name.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
