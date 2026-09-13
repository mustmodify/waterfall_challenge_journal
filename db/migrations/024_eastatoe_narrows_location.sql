-- Eastatoe Narrows was recorded at its access point, not at the water.
--
-- Five features sit within 400 m of each other in three exact-duplicate pairs,
-- and hikingwnc lists the walk to each as 5.4 to 8.0 miles:
--
--   35.03063, -82.77601  Eastatoe Narrows      5.4 mi
--   35.03063, -82.77601  Palmetto Trail Falls  6.8 mi
--   35.02984, -82.77171  Mountain Cat Falls    8.0 mi
--   35.02984, -82.77171  Eden Falls            8.0 mi
--   35.02977, -82.77195  Vespa Falls           8.0 mi
--
-- Five waterfalls each an eight mile walk cannot be 400 m apart. Those are
-- where you park, recorded once per fall.
--
-- The new coordinate is on Eastatoe Creek near a confluence and away from any
-- road, which is what a waterfall looks like and what a trailhead does not.
--
-- Only this one is corrected, because it is the only one we have a reading for.
-- The other four keep their access coordinates and are wrong in the same way.

BEGIN;

INSERT INTO locations (latitude, longitude)
VALUES (35.03200855, -82.81900106);

UPDATE features
SET parking_location_id = feature_location_id,
    feature_location_id = (SELECT id FROM locations
                           WHERE latitude = 35.03200855 AND longitude = -82.81900106)
WHERE id = 1006;

COMMIT;
