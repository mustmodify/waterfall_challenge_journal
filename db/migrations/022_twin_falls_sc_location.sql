-- Twin Falls (SC): our coordinate was the trailhead, not the waterfall.
--
-- Measured against readings taken from Google Maps:
--
--   stored point -> trailhead          69 m
--   stored point -> Reedy Cove Falls  431 m
--   trailhead    -> Reedy Cove Falls  495 m
--
-- 69 m from the trailhead is the trailhead. The falls are the point Google
-- labels Reedy Cove Falls, which is the same waterfall -- Twin Falls sits on
-- Reedy Cove Creek in Pickens County and carries both names. HikingWNC lists
-- the walk as 1.0 mile, consistent with roughly 500 m each way.
--
-- The identification by name is the one inference here; the distances are not.
--
-- features.parking_location_id has existed all along and no row used it. The
-- importers put whatever coordinate they had into feature_location_id, so an
-- unknown number of other places are also pinned at their parking. The 32
-- remaining groups of features sharing an exact coordinate are the likely
-- candidates -- several falls up one creek all recorded from one trailhead.

BEGIN;

INSERT INTO locations (latitude, longitude)
VALUES (35.01371329, -82.81874907);

UPDATE features
SET parking_location_id = feature_location_id,
    feature_location_id = (SELECT id FROM locations
                           WHERE latitude = 35.01371329 AND longitude = -82.81874907)
WHERE id = 406;

UPDATE locations SET latitude = 35.00979902, longitude = -82.82135347
WHERE id = (SELECT parking_location_id FROM features WHERE id = 406);

COMMIT;
