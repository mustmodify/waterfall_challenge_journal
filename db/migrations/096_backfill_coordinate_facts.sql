-- Backfill the coordinate key into facts. Coordinate first because it is the
-- one key with an existing implementation to check against: whatever this
-- produces can be diffed against coordinate_confidence, and a disagreement
-- is a bug in the new logic rather than a discovery.
--
-- Agreement between two coordinate claims means within 250 m of each other,
-- the same threshold coordinate_confidence already calls corroborated.
-- Finding the largest set of mutually agreeing claims is a clique problem, so
-- this approximates it the cheap way: for each claim, count how many claims
-- sit within 250 m of it, and take the best. Dissent is everything left over.
--
-- Rerunnable: it clears the coordinate rows it owns before rebuilding them.

BEGIN;

DELETE FROM facts WHERE key = 'coordinate';

-- One point per SOURCE, not per claim. Two readings from hikingwnc and
-- hikingwnc-supplement are one site twice, not corroboration -- MATCHING.md:
-- "corroboration only counts when the two readings can fail differently."
-- Counting claims instead let that pass as agreement, which the diff against
-- coordinate_confidence caught.
WITH pts AS (
    SELECT DISTINCT ON (c.feature_id, s.src)
           c.id AS claim_id, c.feature_id, c.accepted, s.src,
           (c.value->>'lat')::numeric AS lat,
           (c.value->>'lon')::numeric AS lon
    FROM claims c
    JOIN claim_groups cg ON cg.id = c.group_id
    CROSS JOIN LATERAL (SELECT CASE WHEN cg.source LIKE 'hikingwnc%'
                                    THEN 'hikingwnc' ELSE cg.source END) AS s(src)
    WHERE c.field = 'coordinate' AND cg.identity_certain
      AND c.value ? 'lat' AND c.value ? 'lon'
    ORDER BY c.feature_id, s.src, c.accepted DESC, c.id
),
agreement AS (
    SELECT a.claim_id, a.feature_id, a.accepted, a.lat, a.lon,
           count(*) AS agreeing
    FROM pts a
    JOIN pts b ON b.feature_id = a.feature_id
      AND 111320 * sqrt(
            power(a.lat - b.lat, 2)
          + power((a.lon - b.lon) * cos(radians(a.lat)), 2)) <= 250
    GROUP BY a.claim_id, a.feature_id, a.accepted, a.lat, a.lon
),
totals AS (
    SELECT feature_id, count(*) AS n FROM pts GROUP BY feature_id
),
winner AS (
    SELECT DISTINCT ON (a.feature_id)
           a.feature_id, a.lat, a.lon, a.agreeing, t.n
    FROM agreement a JOIN totals t ON t.feature_id = a.feature_id
    ORDER BY a.feature_id, a.agreeing DESC, a.accepted DESC, a.claim_id
),
staged AS (
    SELECT feature_id, lat, lon, n, agreeing,
           -- Disambiguated means consensus: a majority agreed and a minority
           -- did not. You cannot have a consensus with fewer than three
           -- sources, so n >= 3 is required outright rather than left to
           -- fall out of the arithmetic. Two sources that contradict each
           -- other are a dispute, not a consensus -- without this, one
           -- dissenter is always within floor(2/2) and a flat contradiction
           -- reads as agreement, which is how the first run produced zero
           -- disputed rows while coordinate_confidence found five.
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
SELECT s.feature_id, 'coordinate',
       trim(trailing '.' from trim(trailing '0' from s.lat::text)) || ', ' ||
       trim(trailing '.' from trim(trailing '0' from s.lon::text)),
       'coordinate', 'degrees', s.stage,
       CASE s.stage
         WHEN 'disputed'      THEN 1.0
         WHEN 'single_source' THEN 1.7
         WHEN 'disambiguated' THEN 2.3
         WHEN 'corroborated'  THEN 3.0
       END,
       s.agreeing || ' of ' || s.n || ' sources agree within 250 m'
FROM staged s;

INSERT INTO schema_migrations (filename) VALUES ('096_backfill_coordinate_facts.sql') ON CONFLICT (filename) DO NOTHING;

COMMIT;
