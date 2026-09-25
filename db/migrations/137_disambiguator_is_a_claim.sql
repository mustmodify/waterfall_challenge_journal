-- The TH fix belongs in a claim, not in an edit to the name.
--
-- 135 renamed feature 1216 from "Big Laurel Falls (TH)" to "(TN)", which is
-- the one thing this project does not do: it overwrote what was there instead
-- of recording what we think about it. jw: "keep that in the 'raw' value. I
-- assume it would be removed from the name during normalization. But then you
-- would create an AI claim in 'disambiguators' for that. Raw value is the raw
-- name, fixed value is 'TN'."
--
-- So the name goes back to (TH), normalizing strips the parenthesis as it does
-- for every name, and the correction lives where every other correction lives:
-- a claim, with the raw text in value, the verdict in normalized_value, the
-- reasoning in the note, and a source anyone can disagree with.
--
-- disambiguator therefore becomes a claimable field rather than only a
-- computed one. Where a claim exists it wins; where none does, the fact still
-- falls back to reading our own curated name, which covers the other 96.
--
-- The reading itself: TH and TN are one key apart, TN is a state and TH is
-- not, and the coordinate settles it -- 35.844, -85.309 is White County,
-- Tennessee, well west of the North Carolina line and 1-2 km from Virgin
-- Falls, Big Branch Falls and both Sheep Cave Falls, every one of them marked
-- (TN). There is also a second Big Laurel Falls in North Carolina, 250 km
-- away, so the qualifier is doing real work.

BEGIN;

-- Put the raw name back.
UPDATE features SET name = 'Big Laurel Falls (TH)'
WHERE id = 1216 AND name = 'Big Laurel Falls (TN)';

ALTER TABLE claims DROP CONSTRAINT claims_field_known;
ALTER TABLE claims ADD CONSTRAINT claims_field_known CHECK (
  field = ANY (ARRAY[
    'coordinate','parking_coordinate','view_coordinate','coordinate_raw',
    'trailhead_coordinate',
    'detour_parking_coordinate','detour_trailhead_coordinate','detour_hike_distance',
    'access_status','disambiguator',
    'height','elevation_ft','elevation_gain_ft','petzoldt',
    'beauty_rating','photo_rating','solitude_rating',
    'hike_distance','accessibility','owner','name','alias',
    'photos_count','completed_hikes_count','reviews_count']::text[]));

INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, observed_on, note) VALUES
('wanderfall|1216|disambiguator-th', 1216, 'wanderfall',
 'https://hikingwnc.com/958-big-laurel-falls-th/', true, '2026-09-24',
 'Our reading, not something hikingwnc published. Its page and url both say TH.')
ON CONFLICT (ref) DO NOTHING;

INSERT INTO claims (group_id, feature_id, field, value, normalized_value, accepted, note)
SELECT g.id, 1216, 'disambiguator', to_jsonb('TH'::text), to_jsonb('TN'::text), false,
       'TH is a typo for TN: one key apart, TN is a state and TH is not, and the '
    || 'coordinate settles it. 35.844, -85.309 is White County, Tennessee, well west '
    || 'of the North Carolina line and 1-2 km from Virgin Falls, Big Branch Falls and '
    || 'both Sheep Cave Falls, all of which we hold as (TN). A second Big Laurel Falls '
    || 'sits in North Carolina 250 km away, so the qualifier is load-bearing.'
FROM claim_groups g WHERE g.ref = 'wanderfall|1216|disambiguator-th'
ON CONFLICT DO NOTHING;

-- A claimed disambiguator beats one read off our own name.
DELETE FROM facts WHERE key = 'disambiguator';

WITH claimed AS (
    SELECT DISTINCT ON (c.feature_id)
           c.feature_id,
           btrim(coalesce(c.normalized_value, c.value) #>> '{}') AS value,
           cg.source
    FROM claims c JOIN claim_groups cg ON cg.id = c.group_id
    WHERE c.field = 'disambiguator' AND cg.identity_certain
      AND btrim(coalesce(c.normalized_value, c.value) #>> '{}') <> ''
    ORDER BY c.feature_id, c.accepted DESC, c.id DESC
)
INSERT INTO facts (feature_id, key, value, value_type, units,
                   confidence_stage, confidence_score, notes)
SELECT f.id, 'disambiguator',
       coalesce(cl.value, name_disambiguator(f.name)), 'string', NULL,
       'single_source', 1.7,
       CASE WHEN cl.feature_id IS NOT NULL
            THEN 'Claimed by ' || cl.source || ', which reads the raw name rather than '
              || 'repeating it.'
            ELSE 'Read off our own feature name, which is the curated one. Not '
              || 'something a source published, so it carries no corroboration.'
       END
FROM features f
LEFT JOIN claimed cl ON cl.feature_id = f.id
WHERE f.kind = 'waterfall'
  AND coalesce(cl.value, name_disambiguator(f.name)) IS NOT NULL;

INSERT INTO schema_migrations (filename) VALUES ('137_disambiguator_is_a_claim.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
