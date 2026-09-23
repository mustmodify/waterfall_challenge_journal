-- Backfill the height_ft key into facts, using 104's two functions.
--
-- Agreement means within 15% of the larger value. Where sources agree, the
-- exact reading beats the rounded one -- 146 over 125 -- because a number
-- nobody rounded is a number somebody measured.
--
-- Where they disagree by more than 15%, no reading wins and pretending
-- otherwise would be the dishonest option. Those store a range instead,
-- rounded at the granularity people use for numbers that size, so the value
-- reads "approx 125 - 150" rather than asserting a false precision.
--
-- Rerunnable.

BEGIN;

DELETE FROM facts WHERE key = 'height_ft';

WITH pts AS (
    SELECT DISTINCT ON (c.feature_id, s.src)
           c.id AS claim_id, c.feature_id, c.accepted, s.src,
           (c.value #>> '{}')::numeric AS feet
    FROM claims c
    JOIN claim_groups cg ON cg.id = c.group_id
    CROSS JOIN LATERAL (SELECT CASE WHEN cg.source LIKE 'hikingwnc%'
                                    THEN 'hikingwnc' ELSE cg.source END) AS s(src)
    WHERE c.field = 'height_ft' AND cg.identity_certain
      AND jsonb_typeof(c.value) = 'number' AND (c.value #>> '{}')::numeric > 0
    ORDER BY c.feature_id, s.src, c.accepted DESC, c.id
),
agreement AS (
    SELECT a.claim_id, a.feature_id, a.accepted, a.feet, count(*) AS agreeing
    FROM pts a
    JOIN pts b ON b.feature_id = a.feature_id AND height_gap(a.feet, b.feet) <= 0.15
    GROUP BY a.claim_id, a.feature_id, a.accepted, a.feet
),
totals AS (
    SELECT feature_id, count(*) AS n, min(feet) AS lo, max(feet) AS hi
    FROM pts GROUP BY feature_id
),
winner AS (
    SELECT DISTINCT ON (a.feature_id)
           a.feature_id, a.feet, a.agreeing, t.n, t.lo, t.hi
    FROM agreement a JOIN totals t ON t.feature_id = a.feature_id
    -- Most agreement first, then the exact reading over the rounded one.
    ORDER BY a.feature_id, a.agreeing DESC,
             height_is_approximate(a.feet), a.accepted DESC, a.claim_id
),
staged AS (
    SELECT feature_id, feet, n, agreeing, lo, hi,
           round(lo / CASE WHEN lo < 50 THEN 5 WHEN lo <= 100 THEN 10 ELSE 25 END)
             * CASE WHEN lo < 50 THEN 5 WHEN lo <= 100 THEN 10 ELSE 25 END AS lo_r,
           round(hi / CASE WHEN hi < 50 THEN 5 WHEN hi <= 100 THEN 10 ELSE 25 END)
             * CASE WHEN hi < 50 THEN 5 WHEN hi <= 100 THEN 10 ELSE 25 END AS hi_r,
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
SELECT s.feature_id, 'height_ft',
       CASE WHEN s.stage = 'disputed'
            -- Rounded to the granularity for each bound's own magnitude. Two
            -- readings can be more than 15% apart and still round into the
            -- same bucket (12 and 16 both round to 15), and "approx 15 - 15"
            -- reads like a bug, so collapse that to one number.
            THEN 'approx ' || CASE WHEN s.lo_r = s.hi_r THEN s.lo_r::text
                                   ELSE s.lo_r::text || ' - ' || s.hi_r::text END
            ELSE trim(trailing '.' from trim(trailing '0' from s.feet::text))
       END,
       CASE WHEN s.stage = 'disputed' THEN 'string' ELSE 'integer' END,
       'feet', s.stage,
       CASE s.stage
         WHEN 'disputed'      THEN 1.0
         WHEN 'single_source' THEN 1.7
         WHEN 'disambiguated' THEN 2.3
         WHEN 'corroborated'  THEN 3.0
       END,
       CASE WHEN s.stage = 'disputed'
            THEN s.n || ' sources spread from ' || s.lo || ' to ' || s.hi ||
                 ' ft, more than 15% apart, so no single reading is claimed'
            ELSE s.agreeing || ' of ' || s.n || ' sources agree within 15%'
       END
FROM staged s;

INSERT INTO schema_migrations (filename) VALUES ('105_backfill_height_facts.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
