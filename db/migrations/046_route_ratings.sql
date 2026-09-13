-- A Petzoldt rating belongs to a route, not to a waterfall.
--
-- 045 promoted dwhike's vertical gain onto features, where the generated column
-- combined it with a distance from hikingwnc. The two describe different walks.
-- dwhike reaches Cedar Rock Falls on a 13.8 mile loop with 2,800 feet of climb;
-- hikingwnc walks 1.6 miles straight to it. Pairing one source's gain with the
-- other's mileage produced d=7.20, a number describing no hike anyone has taken.
--
-- So the rating is computed inside a claim group, where both numbers come from
-- the same person walking the same day. features.petzoldt stays, and stays null
-- until some source gives us gain and distance for the same route.

BEGIN;

UPDATE features SET elevation_gain_ft = NULL WHERE elevation_gain_ft IS NOT NULL;

UPDATE claims SET accepted = false WHERE field = 'elevation_gain_ft' AND accepted;

CREATE VIEW route_ratings AS
SELECT cg.id AS group_id,
       cg.feature_id,
       f.name,
       cg.source,
       cg.url,
       (regexp_replace(d.value#>>'{}', '[^0-9.].*$', ''))::numeric AS miles,
       (g.value#>>'{}')::int AS gain_ft,
       round((regexp_replace(d.value#>>'{}', '[^0-9.].*$', ''))::numeric
             + (g.value#>>'{}')::int / 500.0, 2) AS petzoldt,
       petzoldt_band(round((regexp_replace(d.value#>>'{}', '[^0-9.].*$', ''))::numeric
             + (g.value#>>'{}')::int / 500.0, 2)) AS band
FROM claim_groups cg
JOIN features f ON f.id = cg.feature_id
JOIN claims d ON d.group_id = cg.id AND d.field = 'hike_distance'
JOIN claims g ON g.group_id = cg.id AND g.field = 'elevation_gain_ft'
WHERE d.value#>>'{}' ~ '^[0-9]';

ALTER VIEW route_ratings OWNER TO johnathonwright;

COMMIT;
