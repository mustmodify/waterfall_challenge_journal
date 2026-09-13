-- Hike distances and heights for the lookout towers.
--
-- All 22 towers had no distance, no height and no accessibility: they came in
-- through migration 003 as a hand-entered challenge list, and the HikingWNC
-- waterfall import never touched them.
--
-- HikingWNC does have a page per tower, on a different schema from the
-- waterfalls -- "Hike Distance: 1.4 miles round trip", "Tower Height: 70 Feet",
-- "Tower Elevation: 5340 Feet" rather than the Beauty/Photo/Solitude block.
--
-- 16 of 22 matched. The six without a page are Barnett Knob, Clingmans Dome,
-- Moores Knob, Mt. Cammerer, Shuckstack and Yellow Mountain; five further pages
-- describe South Carolina towers that are not on the CMC list.
--
-- height_ft here is the structure, not a waterfall drop -- the same column, the
-- nearest honest meaning for a tower.

BEGIN;

ALTER TABLE features ADD COLUMN IF NOT EXISTS elevation_ft integer;

COMMENT ON COLUMN features.elevation_ft IS
    'Elevation of the feature itself, where a source gives one. Currently towers only.';

UPDATE features SET
    rt_hike_distance = v.dist,
    height_ft        = COALESCE(v.height, features.height_ft),
    elevation_ft     = COALESCE(v.elev, features.elevation_ft)
FROM (VALUES
    (437, '1.8', 14, 5342),
    (438, '1.9', 30, 2293),
    (439, '1.2', 31, 4716),
    (440, '6.5', 43, 5220),
    (441, '1.9', 30, 4626),
    (442, '1.2', 30, 4944),
    (447, '5.7', 60, 5842),
    (449, '5.1', 30, 3670),
    (450, '10.7', 21, 4843),
    (451, '1.4', 70, 5340),
    (452, '2.4', 47, 4230),
    (453, '7.6', 21, 4740),
    (454, '2.7', 12, 6684),
    (455, '1.1', 21, 5060),
    (456, '4.95', 40, 4558),
    (457, '4.1', 59, 2500)
) AS v(fid, dist, height, elev)
WHERE features.id = v.fid;

COMMIT;
