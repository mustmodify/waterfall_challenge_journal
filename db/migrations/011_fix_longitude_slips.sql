-- Six waterfalls sit exactly one degree of longitude too far east.
--
-- The error is upstream in hikingwnc.com's own data, not in our import: the
-- source JSON carries the same values. The signature is unambiguous -- each
-- has a name-sibling whose latitude agrees to four decimals while the
-- longitude differs by exactly 1.00000:
--
--   Silver Run Falls          35.06620, -83.06540
--   Upper Silver Run Falls    35.06720, -82.06420   <- 91 km east, into SC
--
-- Confirmed by isolation: as recorded, each is 4-18 km from its nearest
-- neighbour; moved one degree west, each lands 0.2-0.6 km from the fall it is
-- named after. Rainbow Falls (Camp Greenville) trips the same name test and is
-- NOT corrected -- it is genuinely 1.1 km from Jones Gap Falls where it stands,
-- and is simply a different Rainbow Falls from the one on US64.

BEGIN;

UPDATE locations SET longitude = longitude - 1
WHERE id IN (
    SELECT feature_location_id FROM features
    WHERE id IN (
        471,   -- Upper Silver Run Falls      -> beside Silver Run Falls
        856,   -- Waddle Branch Falls         -> beside Lower Waddle Branch Falls
        1112,  -- Upper Shoal Creek Falls     -> beside Shoal Creek Falls
        508,   -- Stone Mountain Falls        -> Stone Mountain State Park
        509,   -- Middle Falls at Stone Mtn   -> beside Lower Falls at Stone Mtn
        1199   -- Joe Pack Falls              -> beside Twin Falls (Thompson River)
    )
);

COMMIT;
