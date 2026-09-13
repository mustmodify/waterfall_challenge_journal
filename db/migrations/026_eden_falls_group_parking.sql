-- Parking for the Eden Falls group, from hikingwnc's own hike description.
--
-- Palmetto Trail Falls, Eden Falls, Mountain Cat Falls and Vespa Falls are one
-- 6.8-8.0 mile hike, described on the Eden Falls page, which states plainly:
-- "The GPS on the parking area is 35.02937, -82.79939."
--
-- Their recorded coordinates are the falls, not the parking, so nothing moves
-- here -- this only fills in where you leave the car.
--
-- Note what the same description settles about the duplicates:
--   Eden and Vespa share almost the same point and should: "The two waterfalls
--   are very close together", Vespa sitting just below Eden.
--   Mountain Cat does not. It is passed at 1.9 miles from the gate while Eden
--   is at the 8.0 mile turnaround, yet hikingwnc gives both 35.02984,
--   -82.77171. That is an upstream error and is not corrected here, because no
--   source gives Mountain Cat's own position.

BEGIN;

INSERT INTO locations (latitude, longitude) VALUES (35.02937, -82.79939);

UPDATE features
SET parking_location_id = (SELECT id FROM locations
                           WHERE latitude = 35.02937 AND longitude = -82.79939)
WHERE id IN (1028, 1029, 1030, 1031);

COMMIT;
