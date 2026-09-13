-- Petzoldt energy units: a difficulty rating that survives comparison.
--
-- Paul Petzoldt, who founded NOLS, counted one energy unit per mile travelled
-- and one per 500 feet of elevation gain. A one mile walk with 1,000 feet of
-- gain and a two mile walk with 500 feet both come to d=3.00, which is the
-- point -- it puts a short brutal climb and a long flat slog on one scale.
--
-- It says nothing about weather, terrain, trail condition or how fit you are.
-- It is a baseline under ideal conditions, and dwhike says so plainly.
--
-- The rating is derived rather than stored, so it cannot drift from the
-- distance and gain it is computed from. Gain is the piece we mostly lack:
-- hikingwnc publishes neither it nor a rating, so this fills in only where a
-- source gives us the climb.
--
-- dwhike's six bands:
--   0.00-2.49 easy, 2.50-4.99 moderate, 5.00-7.49 challenging,
--   7.50-9.99 hard, 10.00-12.49 very hard, 12.50 and up extreme.

BEGIN;

ALTER TABLE features ADD COLUMN elevation_gain_ft integer;

-- rt_hike_distance is text and holds things like 'Roadside' alongside numbers.
ALTER TABLE features ADD COLUMN petzoldt numeric(5,2)
GENERATED ALWAYS AS (
    CASE WHEN rt_hike_distance ~ '^[0-9]+(\.[0-9]+)?$' AND elevation_gain_ft IS NOT NULL
         THEN round(rt_hike_distance::numeric + elevation_gain_ft / 500.0, 2)
    END) STORED;

CREATE FUNCTION petzoldt_band(d numeric) RETURNS text AS $$
    SELECT CASE
        WHEN d IS NULL     THEN NULL
        WHEN d < 2.5       THEN 'easy'
        WHEN d < 5         THEN 'moderate'
        WHEN d < 7.5       THEN 'challenging'
        WHEN d < 10        THEN 'hard'
        WHEN d < 12.5      THEN 'very hard'
        ELSE                    'extreme'
    END;
$$ LANGUAGE sql IMMUTABLE;

ALTER TABLE claims DROP CONSTRAINT claims_field_known;
ALTER TABLE claims ADD CONSTRAINT claims_field_known CHECK (field IN (
    'coordinate', 'parking_coordinate', 'view_coordinate', 'height_ft',
    'elevation_ft', 'elevation_gain_ft', 'petzoldt', 'beauty_rating',
    'photo_rating', 'solitude_rating', 'hike_distance', 'accessibility',
    'owner', 'name', 'alias', 'coordinate_raw'));

ALTER TABLE claims DROP CONSTRAINT claims_value_shape;
ALTER TABLE claims ADD CONSTRAINT claims_value_shape CHECK (
    CASE
    WHEN field IN ('coordinate', 'parking_coordinate', 'view_coordinate') THEN
        jsonb_typeof(value->'lat') = 'number' AND
        jsonb_typeof(value->'lon') = 'number' AND
        (value->>'lat')::numeric BETWEEN -90 AND 90 AND
        (value->>'lon')::numeric BETWEEN -180 AND 180
    WHEN field = 'height_ft' THEN
        jsonb_typeof(value) = 'number' AND (value#>>'{}')::numeric > 0
    WHEN field IN ('elevation_ft', 'elevation_gain_ft') THEN
        jsonb_typeof(value) = 'number'
    WHEN field = 'petzoldt' THEN
        jsonb_typeof(value) = 'number' AND (value#>>'{}')::numeric >= 0
    WHEN field IN ('beauty_rating', 'photo_rating', 'solitude_rating') THEN
        jsonb_typeof(value) = 'number' AND (value#>>'{}')::numeric BETWEEN 1 AND 10
    ELSE jsonb_typeof(value) = 'string' AND value#>>'{}' <> ''
    END);

ALTER FUNCTION petzoldt_band(numeric) OWNER TO johnathonwright;

COMMIT;
