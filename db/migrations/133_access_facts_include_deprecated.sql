-- A deprecated waterfall still has an answer to "can I get there?"
--
-- 131 backfilled access_status for every waterfall except the deprecated
-- ones, which dropped exactly one feature: Skinny Dip Falls, marked
-- deprecated_reason 'damaged' after Tropical Storm Fred in 2021. So the one
-- waterfall on the site whose record explicitly mentions storm damage was the
-- one with no access fact, which is precisely backwards.
--
-- It is also the case that makes the distinction worth drawing. Reading
-- AllTrails on 2026-09-23 shows Skinny Dip as an easy 0.9-mile out-and-back
-- with 2,079 reviews and 6,340 recorded hikes and no closure marker anywhere.
-- The damage was to the waterfall -- Kevin Adams dropped its beauty rating
-- from 7 to 4 and says so on the page -- not to the path. "This is less
-- impressive than it was" and "you cannot get there" are different
-- statements, and only one of them is about access.
--
-- Rerunnable, and identical to 131 apart from dropping that one filter.

BEGIN;

DELETE FROM facts WHERE key = 'access_status';

WITH pts AS (
    SELECT DISTINCT ON (c.feature_id, s.src)
           c.feature_id, s.src,
           coalesce(c.normalized_value #>> '{}',
                    access_verdict(c.value #>> '{}')) AS verdict
    FROM claims c
    JOIN claim_groups cg ON cg.id = c.group_id
    CROSS JOIN LATERAL (SELECT CASE WHEN cg.source LIKE 'hikingwnc%'
                                    THEN 'hikingwnc' ELSE cg.source END) AS s(src)
    WHERE c.field = 'access_status' AND cg.identity_certain
    ORDER BY c.feature_id, s.src, c.accepted DESC, c.id
),
agreement AS (
    SELECT a.feature_id, a.verdict, count(*) AS agreeing
    FROM pts a JOIN pts b ON b.feature_id = a.feature_id AND b.verdict = a.verdict
    GROUP BY a.feature_id, a.verdict
),
totals AS (SELECT feature_id, count(*) AS n FROM pts GROUP BY feature_id),
winner AS (
    SELECT DISTINCT ON (a.feature_id) a.feature_id, a.verdict, a.agreeing, t.n
    FROM agreement a JOIN totals t ON t.feature_id = a.feature_id
    ORDER BY a.feature_id, a.agreeing DESC,
             array_position(ARRAY['inaccessible','detour','ok','unverified'], a.verdict)
)
INSERT INTO facts (feature_id, key, value, value_type, units,
                   confidence_stage, confidence_score, notes)
SELECT f.id, 'access_status',
       coalesce(w.verdict, 'unverified'), 'string', NULL,
       CASE WHEN w.feature_id IS NULL THEN 'unverified'
            ELSE agreement_stage(w.agreeing::int, w.n::int) END,
       CASE WHEN w.feature_id IS NULL THEN NULL
            ELSE agreement_score(w.agreeing::int, w.n::int) END,
       CASE WHEN w.feature_id IS NULL
            THEN 'No source has said anything about getting here, which after a storm is the '
              || 'commonest state and the least safe assumption.'
            ELSE agreement_note(w.agreeing::int, w.n::int, 'on how accessible this is')
       END
FROM features f
LEFT JOIN winner w ON w.feature_id = f.id
WHERE f.kind = 'waterfall';

INSERT INTO schema_migrations (filename) VALUES ('133_access_facts_include_deprecated.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
