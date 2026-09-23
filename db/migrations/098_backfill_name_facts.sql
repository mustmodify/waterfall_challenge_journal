-- Backfill the name key into facts, mirroring 096's shape.
--
-- Agreement between two names means equal after normalising, and the right
-- normalisation is name_core() with the spaces taken out. name_core already
-- exists for exactly this job -- it drops parentheticals and the SEO tail
-- ncwaterfalls appends -- but it turns punctuation into spaces, so
-- "Pearson's" and "Pearsons" still differ until the spaces go too. Removing
-- them is migration 088's rule, which recovered 13 real matches ("4 X 4
-- Falls" against "4x4 Falls") with nothing false inside 3.8 km.
--
-- Both halves are load-bearing. Pearson's Falls is claimed by three sources
-- as "Pearson's Falls", "Pearsons Falls-Visiting Guide, Photos, Map" and
-- "Pearson's Falls and Glen". Raw equality sees three different names;
-- name_core alone still sees three; together they correctly see two agreeing
-- and AllTrails describing a trail rather than the fall.
--
-- One reading per SOURCE, not per claim, for the same reason as 096:
-- hikingwnc and hikingwnc-supplement are one site twice.
--
-- The value stored is the winning claim's name as that source wrote it, not
-- features.name. Where those differ, the difference is the point -- it means
-- the name we display is not the one any source claims, which is the gap
-- docs/unattributed-values.md exists to track.
--
-- Rerunnable: clears the name rows it owns before rebuilding them.

BEGIN;

DELETE FROM facts WHERE key = 'name';

WITH pts AS (
    SELECT DISTINCT ON (c.feature_id, s.src)
           c.id AS claim_id, c.feature_id, c.accepted, s.src,
           c.value #>> '{}' AS raw,
           replace(name_core(c.value #>> '{}'), ' ', '') AS norm
    FROM claims c
    JOIN claim_groups cg ON cg.id = c.group_id
    CROSS JOIN LATERAL (SELECT CASE WHEN cg.source LIKE 'hikingwnc%'
                                    THEN 'hikingwnc' ELSE cg.source END) AS s(src)
    WHERE c.field = 'name' AND cg.identity_certain
      AND coalesce(c.value #>> '{}', '') <> ''
    ORDER BY c.feature_id, s.src, c.accepted DESC, c.id
),
agreement AS (
    SELECT a.claim_id, a.feature_id, a.accepted, a.raw, count(*) AS agreeing
    FROM pts a
    JOIN pts b ON b.feature_id = a.feature_id AND b.norm = a.norm
    GROUP BY a.claim_id, a.feature_id, a.accepted, a.raw
),
totals AS (
    SELECT feature_id, count(*) AS n FROM pts GROUP BY feature_id
),
winner AS (
    SELECT DISTINCT ON (a.feature_id)
           a.feature_id, a.raw, a.agreeing, t.n
    FROM agreement a JOIN totals t ON t.feature_id = a.feature_id
    ORDER BY a.feature_id, a.agreeing DESC, a.accepted DESC, a.claim_id
),
staged AS (
    SELECT feature_id, raw, n, agreeing,
           -- Same ladder as 096. Consensus needs three sources: two that
           -- contradict each other are a dispute, not a majority.
           CASE
             WHEN n = 1 THEN 'single_source'
             WHEN n - agreeing = 0 THEN 'corroborated'
             WHEN n >= 3 AND agreeing >= 2 AND n - agreeing <= floor(n / 2.0)
               THEN 'disambiguated'
             ELSE 'disputed'
           END AS stage
    FROM winner
)
INSERT INTO facts (feature_id, key, value, value_type, confidence_stage,
                   confidence_score, notes)
SELECT s.feature_id, 'name', s.raw, 'string', s.stage,
       CASE s.stage
         WHEN 'disputed'      THEN 1.0
         WHEN 'single_source' THEN 1.7
         WHEN 'disambiguated' THEN 2.3
         WHEN 'corroborated'  THEN 3.0
       END,
       s.agreeing || ' of ' || s.n || ' sources agree once punctuation and case are ignored'
FROM staged s;

INSERT INTO schema_migrations (filename) VALUES ('098_backfill_name_facts.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
