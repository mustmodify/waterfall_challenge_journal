-- Backfill the accessibility key into facts, using accessibility_rank(102).
--
-- Agreement means within half a step of each other, so Moderate and Moderate+
-- agree and Moderate and Hard do not. See 102 for why that tolerance is the
-- right one rather than a loose one.
--
-- The value stored is the rank, not the source's prose, because the rank is
-- the comparable thing and the prose is already in claims. units says what
-- the number means so a reader is not left guessing whether 2 is good.
--
-- Rows where every source's value is about permission or transport rather
-- than difficulty get no fact: a null rank is not a confidence problem, it is
-- a different kind of statement.
--
-- Rerunnable.

BEGIN;

DELETE FROM facts WHERE key = 'accessibility';

WITH pts AS (
    SELECT DISTINCT ON (c.feature_id, s.src)
           c.id AS claim_id, c.feature_id, c.accepted, s.src,
           accessibility_rank(c.value #>> '{}') AS rank
    FROM claims c
    JOIN claim_groups cg ON cg.id = c.group_id
    CROSS JOIN LATERAL (SELECT CASE WHEN cg.source LIKE 'hikingwnc%'
                                    THEN 'hikingwnc' ELSE cg.source END) AS s(src)
    WHERE c.field = 'accessibility' AND cg.identity_certain
      AND accessibility_rank(c.value #>> '{}') IS NOT NULL
    ORDER BY c.feature_id, s.src, c.accepted DESC, c.id
),
agreement AS (
    SELECT a.claim_id, a.feature_id, a.accepted, a.rank, count(*) AS agreeing
    FROM pts a
    JOIN pts b ON b.feature_id = a.feature_id AND abs(b.rank - a.rank) <= 0.5
    GROUP BY a.claim_id, a.feature_id, a.accepted, a.rank
),
totals AS (
    SELECT feature_id, count(*) AS n FROM pts GROUP BY feature_id
),
winner AS (
    SELECT DISTINCT ON (a.feature_id)
           a.feature_id, a.rank, a.agreeing, t.n
    FROM agreement a JOIN totals t ON t.feature_id = a.feature_id
    -- Ties break toward the harder reading: if two ranks are equally
    -- supported, telling someone a walk is harder than it is costs them a
    -- wasted drive, and the other way round costs them a bad afternoon.
    ORDER BY a.feature_id, a.agreeing DESC, a.rank DESC, a.accepted DESC, a.claim_id
),
staged AS (
    SELECT feature_id, rank, n, agreeing,
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
SELECT s.feature_id, 'accessibility',
       trim(trailing '.' from trim(trailing '0' from s.rank::text)),
       'decimal', 'rank 0 roadside to 4 very hard, + is half a step', s.stage,
       CASE s.stage
         WHEN 'disputed'      THEN 1.0
         WHEN 'single_source' THEN 1.7
         WHEN 'disambiguated' THEN 2.3
         WHEN 'corroborated'  THEN 3.0
       END,
       s.agreeing || ' of ' || s.n || ' sources agree within half a step'
FROM staged s;

INSERT INTO schema_migrations (filename) VALUES ('103_backfill_accessibility_facts.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
