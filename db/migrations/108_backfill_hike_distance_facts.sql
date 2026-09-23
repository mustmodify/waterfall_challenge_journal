-- Backfill the hike_distance key into facts, in canonical feet via 107.
--
-- Agreement tolerance: 15% of the larger value, borrowed from the height rule
-- rather than chosen for distances specifically -- jw settled the unit and the
-- parsing but not this number, so it is a placeholder with a precedent rather
-- than a decision. It is a plausible one: sources legitimately differ about
-- where a hike ends, one measuring to an overlook and another to the base,
-- and 15% of a two-mile walk is about 500 m of slack.
--
-- Rerunnable.

BEGIN;

DELETE FROM facts WHERE key = 'hike_distance';

WITH pts AS (
    SELECT DISTINCT ON (c.feature_id, s.src)
           c.id AS claim_id, c.feature_id, c.accepted, s.src,
           hike_distance_feet(c.value #>> '{}') AS feet
    FROM claims c
    JOIN claim_groups cg ON cg.id = c.group_id
    CROSS JOIN LATERAL (SELECT CASE WHEN cg.source LIKE 'hikingwnc%'
                                    THEN 'hikingwnc' ELSE cg.source END) AS s(src)
    WHERE c.field = 'hike_distance' AND cg.identity_certain
      AND hike_distance_feet(c.value #>> '{}') IS NOT NULL
    ORDER BY c.feature_id, s.src, c.accepted DESC, c.id
),
agreement AS (
    SELECT a.claim_id, a.feature_id, a.accepted, a.feet, count(*) AS agreeing
    FROM pts a
    JOIN pts b ON b.feature_id = a.feature_id
      -- Roadside agrees only with roadside; a percentage of zero is not a
      -- useful tolerance.
      AND (
        (a.feet = 0 AND b.feet = 0)
        OR (greatest(a.feet, b.feet) > 0
            AND (greatest(a.feet, b.feet) - least(a.feet, b.feet))
                / greatest(a.feet, b.feet) <= 0.15)
      )
    GROUP BY a.claim_id, a.feature_id, a.accepted, a.feet
),
totals AS (
    SELECT feature_id, count(*) AS n FROM pts GROUP BY feature_id
),
winner AS (
    SELECT DISTINCT ON (a.feature_id)
           a.feature_id, a.feet, a.agreeing, t.n
    FROM agreement a JOIN totals t ON t.feature_id = a.feature_id
    -- Ties go to the longer walk, for the same reason accessibility ties go
    -- to the harder reading: the costly surprise is the one you did not pack
    -- for.
    ORDER BY a.feature_id, a.agreeing DESC, a.feet DESC, a.accepted DESC, a.claim_id
),
staged AS (
    SELECT feature_id, feet, n, agreeing,
           CASE
             WHEN n = 1 THEN 'single_source'
             WHEN n - agreeing = 0 THEN 'corroborated'
             WHEN n >= 3 AND agreeing >= 2 AND n - agreeing <= floor(n / 2.0)
               THEN 'disambiguated'
             ELSE 'disputed'
           END AS stage
    FROM winner
)
INSERT INTO facts (feature_id, key, value, value_type, units,
                   confidence_stage, confidence_score, notes)
SELECT s.feature_id, 'hike_distance', s.feet::text, 'integer',
       'feet, round trip', s.stage,
       CASE s.stage
         WHEN 'disputed'      THEN 1.0
         WHEN 'single_source' THEN 1.7
         WHEN 'disambiguated' THEN 2.3
         WHEN 'corroborated'  THEN 3.0
       END,
       s.agreeing || ' of ' || s.n || ' sources agree within 15% once parsed to feet'
FROM staged s;

INSERT INTO schema_migrations (filename) VALUES ('108_backfill_hike_distance_facts.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
