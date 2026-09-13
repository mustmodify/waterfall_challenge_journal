-- Where you stand to see it, which is not always where it is.
--
-- A big fall cannot be taken in from its own plunge pool. Whitewater drops 411
-- feet past an overlook a quarter mile away; standing at the base of something
-- that size gets you spray and a wall of rock. The point you walk to and the
-- point you look from are different facts about the same waterfall.
--
-- One viewpoint per feature for now. Several is the honest shape -- an upper
-- overlook, a lower one, a spot across the gorge -- and the claims layer
-- already holds as many as sources offer, so widening this later is a matter
-- of promoting more than one of them.

BEGIN;

ALTER TABLE features ADD COLUMN IF NOT EXISTS view_location_id integer REFERENCES locations(id);

ALTER TABLE claims DROP CONSTRAINT claims_field_known;
ALTER TABLE claims ADD CONSTRAINT claims_field_known CHECK (field IN (
    'coordinate', 'parking_coordinate', 'view_coordinate', 'height_ft',
    'elevation_ft', 'beauty_rating', 'photo_rating', 'solitude_rating',
    'hike_distance', 'accessibility', 'owner', 'name', 'alias',
    'coordinate_raw'));

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
    WHEN field = 'elevation_ft' THEN
        jsonb_typeof(value) = 'number'
    WHEN field IN ('beauty_rating', 'photo_rating', 'solitude_rating') THEN
        jsonb_typeof(value) = 'number' AND (value#>>'{}')::numeric BETWEEN 1 AND 10
    ELSE jsonb_typeof(value) = 'string' AND value#>>'{}' <> ''
    END);

COMMIT;
