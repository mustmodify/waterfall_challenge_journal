-- Jumping Fish Falls, on Avents Creek in Raven Rock State Park, from
-- ncwaterfalls.com. It had no coordinate and no detail of any kind.
--
-- ncwaterfalls gives hike distance one way; this column is round trip, so 0.6
-- becomes 1.2. The two coordinates are 0.39 miles apart in a straight line,
-- which is the right shape for a 0.6 mile walk and the wrong shape for a 0.3.
--
-- Beauty 4 is recorded on the assumption that ncwaterfalls scores out of ten
-- like hikingwnc, the source of every other rating here.

BEGIN;

INSERT INTO locations (latitude, longitude) VALUES
  (35.48122000, -78.91025000),
  (35.48344000, -78.90395000);

UPDATE features
SET feature_location_id = (SELECT id FROM locations
                           WHERE latitude = 35.48122000 AND longitude = -78.91025000),
    parking_location_id = (SELECT id FROM locations
                           WHERE latitude = 35.48344000 AND longitude = -78.90395000),
    height_ft = 5,
    elevation_ft = 135,
    beauty_rating = 4,
    rt_hike_distance = '1.2',
    accessibility = 'Moderate',
    owner = 'State'
WHERE id = 909;

INSERT INTO notes (feature_id, text, source)
VALUES (909, 'Cascading falls about 5 feet high on Avents Creek, Harnett County, '
             'Cape Fear basin. Reached by hiking trail; landowner is Raven Rock '
             'State Park. USGS quad Mamers. Watershed is very small. '
             'Beauty 4 and a 0.6 mile one-way hike per ncwaterfalls.com.', 'ncwaterfalls');

INSERT INTO links (feature_id, url, rel, comments)
VALUES (909, 'https://ncwaterfalls.com/waterfalls/jumping-fish-falls/', 'ncwaterfalls',
        'Coordinates, height, elevation and hike detail.')
ON CONFLICT (feature_id, url) DO NOTHING;

COMMIT;
