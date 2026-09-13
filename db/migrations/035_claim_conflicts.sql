-- Where the sources disagree, and where nothing has been decided.
--
-- A field is in conflict when two sources assert different values for it. It is
-- unresolved when claims exist and none is accepted -- which is also what a
-- field looks like when we overrode every source without saying so.

CREATE VIEW claim_conflicts AS
SELECT c.feature_id,
       f.name,
       c.field,
       count(DISTINCT c.value) AS distinct_values,
       count(*) FILTER (WHERE c.accepted) AS accepted,
       string_agg(DISTINCT cg.source, ', ' ORDER BY cg.source) AS sources
FROM claims c
JOIN claim_groups cg ON cg.id = c.group_id
JOIN features f ON f.id = c.feature_id
WHERE c.field <> 'alias'
GROUP BY c.feature_id, f.name, c.field
HAVING count(DISTINCT c.value) > 1 OR count(*) FILTER (WHERE c.accepted) = 0;

-- Two readings of the same fall differing in the fifth decimal is not a
-- disagreement; 3 km is. This reports how far apart the sources actually put
-- each feature, in metres, so the noise can be filtered rather than counted.
CREATE VIEW claim_coordinate_spread AS
WITH pts AS (
    SELECT c.feature_id, cg.source, c.accepted,
           (c.value->>'lat')::numeric AS lat,
           (c.value->>'lon')::numeric AS lon
    FROM claims c JOIN claim_groups cg ON cg.id = c.group_id
    WHERE c.field = 'coordinate')
SELECT s.feature_id,
       f.name,
       round(max(111320 * sqrt(power(a.lat - b.lat, 2) +
             power((a.lon - b.lon) * cos(radians(a.lat)), 2)))) AS metres_apart,
       max(s.sources) AS sources,
       bool_or(s.decided) AS decided
FROM (SELECT feature_id, count(DISTINCT source) AS sources, bool_or(accepted) AS decided
      FROM pts GROUP BY feature_id) s
JOIN pts a ON a.feature_id = s.feature_id
JOIN pts b ON b.feature_id = s.feature_id AND b.source > a.source
JOIN features f ON f.id = s.feature_id
GROUP BY s.feature_id, f.name;
