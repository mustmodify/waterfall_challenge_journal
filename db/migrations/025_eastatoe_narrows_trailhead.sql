-- The access point recorded in 024 was not the trailhead either.
--
-- 024 moved Eastatoe Narrows to the water and kept its old coordinate as
-- parking, on the assumption that a point shared by five long hikes was where
-- you park. It is not:
--
--   Eastatoe Gorge Spur Trailhead -> the falls    2.06 km
--   Eastatoe Gorge Spur Trailhead -> old point    4.28 km
--   old point                     -> the falls    3.91 km
--
-- 2.06 km straight-line against hikingwnc's 5.4 mile listing is what a
-- switchbacked descent into a gorge looks like. The old point is 4 km from
-- both and belongs to something else -- the Palmetto Trail cluster it was
-- copied around, most likely.
--
-- Palmetto Trail Falls, Mountain Cat Falls, Eden Falls and Vespa Falls are
-- still sitting on it, and are still wrong.

BEGIN;

UPDATE locations SET latitude = 35.05045930, longitude = -82.81643513
WHERE id = (SELECT parking_location_id FROM features WHERE id = 1006);

COMMIT;
