-- How much agreement stands behind each coordinate we draw.
--
-- Three numbers decide a tier: how many independent sources place the fall at
-- all, how far apart those sources put it, and how far our own point sits from
-- the nearest of them. A fall three sources agree on to within a hundred
-- metres is a different thing from one that rests on a single guidebook line.

CREATE VIEW coordinate_confidence AS
WITH pts AS (
    SELECT c.feature_id,
           CASE WHEN cg.source LIKE 'hikingwnc%' THEN 'hikingwnc' ELSE cg.source END AS source,
           (c.value->>'lat')::numeric AS lat,
           (c.value->>'lon')::numeric AS lon
    FROM claims c
    JOIN claim_groups cg ON cg.id = c.group_id
    WHERE c.field = 'coordinate' AND cg.identity_certain),
stored AS (
    SELECT f.id AS feature_id, f.name, l.latitude AS lat, l.longitude AS lon
    FROM features f
    LEFT JOIN locations l ON l.id = f.feature_location_id
    WHERE f.deprecated_reason IS NULL),
spread AS (
    SELECT a.feature_id,
           max(111320 * sqrt(power(a.lat - b.lat, 2) +
               power((a.lon - b.lon) * cos(radians(a.lat)), 2))) AS metres
    FROM pts a JOIN pts b ON b.feature_id = a.feature_id AND b.source > a.source
    GROUP BY a.feature_id),
nearest AS (
    SELECT p.feature_id,
           min(111320 * sqrt(power(s.lat - p.lat, 2) +
               power((s.lon - p.lon) * cos(radians(s.lat)), 2))) AS metres
    FROM pts p JOIN stored s ON s.feature_id = p.feature_id AND s.lat IS NOT NULL
    GROUP BY p.feature_id)
SELECT s.feature_id,
       s.name,
       count(DISTINCT p.source) AS sources,
       round(coalesce(spread.metres, 0)) AS sources_apart_m,
       round(nearest.metres) AS ours_off_by_m,
       CASE
         WHEN s.lat IS NULL THEN 'no coordinate'
         WHEN count(p.source) = 0 THEN 'unsourced'
         WHEN coalesce(spread.metres, 0) > 500 THEN 'disputed'
         WHEN count(DISTINCT p.source) >= 3 AND coalesce(spread.metres, 0) <= 100
              AND nearest.metres <= 100 THEN 'confirmed'
         WHEN count(DISTINCT p.source) >= 2 AND coalesce(spread.metres, 0) <= 250
              AND nearest.metres <= 250 THEN 'corroborated'
         WHEN count(DISTINCT p.source) = 1 AND nearest.metres <= 100 THEN 'single source'
         ELSE 'unverified'
       END AS tier
FROM stored s
LEFT JOIN pts p ON p.feature_id = s.feature_id
LEFT JOIN spread ON spread.feature_id = s.feature_id
LEFT JOIN nearest ON nearest.feature_id = s.feature_id
GROUP BY s.feature_id, s.name, s.lat, spread.metres, nearest.metres;
