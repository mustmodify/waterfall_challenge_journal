-- Three counts AllTrails publishes for every trail, and a view over the ratio
-- of two of them.
--
-- `total_user_content_stats` carries photos_count, completed_hikes_count and
-- reviews_count. Photos over hikes is meant as a proxy for how photogenic a
-- place is: divide by hikes and you have controlled for how many people went,
-- so what is left is how many of them thought it was worth photographing.
--
-- THE UNIT IS THE ROUTE, NOT THE WATERFALL. This is the same problem
-- route_ratings solved for Petzoldt, and for the same reason: a count belongs
-- to the walk somebody took, and the walk is not the waterfall. Three ways
-- that bites:
--
--   * One fall, several routes. Dry Falls has both "Dry Falls Trail" and "Dry
--     Falls Viewing Platform". Adding their photos would double-count the
--     people who logged both.
--   * One route, several falls. "Cove Creek Falls and Toms Spring Falls"
--     names ours and visits another. Its photos are not all about ours.
--   * One route that merely starts here. "Jones Falls and Splash Dam Falls
--     From Elk River Falls" shares Elk River Falls' trailhead to the metre and
--     is a 5.3 mile walk to somewhere else.
--
-- So the counts are stored per claim group -- one group per (feature, trail)
-- attachment -- and never summed onto the feature. Which group speaks for a
-- waterfall is a judgement, and `accepted` is where that judgement is
-- recorded, exactly as for every other field.

ALTER TABLE claims DROP CONSTRAINT claims_field_known;
ALTER TABLE claims ADD CONSTRAINT claims_field_known CHECK (
    field::text = ANY (ARRAY[
        'coordinate', 'parking_coordinate', 'view_coordinate',
        'height_ft', 'elevation_ft', 'elevation_gain_ft', 'petzoldt',
        'beauty_rating', 'photo_rating', 'solitude_rating',
        'hike_distance', 'accessibility', 'owner', 'name', 'alias',
        'coordinate_raw',
        'photos_count', 'completed_hikes_count', 'reviews_count'
    ]::text[]));

-- The counts are numbers, and the default branch of claims_value_shape wants a
-- string. Zero is a real answer -- a trail nobody has photographed -- so the
-- bound is >= 0 rather than > 0.
ALTER TABLE claims DROP CONSTRAINT claims_value_shape;
ALTER TABLE claims ADD CONSTRAINT claims_value_shape CHECK (
    CASE
        WHEN field::text = ANY (ARRAY['coordinate', 'parking_coordinate', 'view_coordinate']::text[])
            THEN jsonb_typeof(value -> 'lat') = 'number'
             AND jsonb_typeof(value -> 'lon') = 'number'
             AND ((value ->> 'lat')::numeric) >= -90 AND ((value ->> 'lat')::numeric) <= 90
             AND ((value ->> 'lon')::numeric) >= -180 AND ((value ->> 'lon')::numeric) <= 180
        WHEN field::text = 'height_ft'
            THEN jsonb_typeof(value) = 'number' AND ((value #>> '{}')::numeric) > 0
        WHEN field::text = ANY (ARRAY['elevation_ft', 'elevation_gain_ft']::text[])
            THEN jsonb_typeof(value) = 'number'
        WHEN field::text = 'petzoldt'
            THEN jsonb_typeof(value) = 'number' AND ((value #>> '{}')::numeric) >= 0
        WHEN field::text = ANY (ARRAY['beauty_rating', 'photo_rating', 'solitude_rating']::text[])
            THEN jsonb_typeof(value) = 'number'
             AND ((value #>> '{}')::numeric) >= 1 AND ((value #>> '{}')::numeric) <= 10
        WHEN field::text = ANY (ARRAY['photos_count', 'completed_hikes_count', 'reviews_count']::text[])
            THEN jsonb_typeof(value) = 'number' AND ((value #>> '{}')::numeric) >= 0
        ELSE jsonb_typeof(value) = 'string' AND (value #>> '{}') <> ''
    END);

-- One row per route that carries both counts. Deliberately not aggregated to
-- the feature: see the note above. `hikes` of zero would be a new trail nobody
-- has logged, and is excluded rather than divided by.
CREATE VIEW trail_engagement AS
SELECT cg.id AS group_id,
       cg.feature_id,
       f.name AS feature_name,
       cg.source,
       cg.url,
       cg.identity_certain,
       ((p.value #>> '{}')::integer) AS photos,
       ((h.value #>> '{}')::integer) AS hikes,
       ((r.value #>> '{}')::integer) AS reviews,
       round(((p.value #>> '{}')::numeric) / ((h.value #>> '{}')::numeric), 4) AS photos_per_hike
FROM claim_groups cg
JOIN features f ON f.id = cg.feature_id
JOIN claims p ON p.group_id = cg.id AND p.field = 'photos_count'
JOIN claims h ON h.group_id = cg.id AND h.field = 'completed_hikes_count'
LEFT JOIN claims r ON r.group_id = cg.id AND r.field = 'reviews_count'
WHERE ((h.value #>> '{}')::numeric) > 0;

COMMENT ON VIEW trail_engagement IS
    'Photos and completed hikes per route, with their ratio. One row per claim '
    'group, never summed onto a feature: the counts describe a walk, and the '
    'walk is not the waterfall.';
