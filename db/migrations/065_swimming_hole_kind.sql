-- swimming_hole joins waterfall/tower/vista/other as a feature kind.
--
-- Not every swimming hole is a waterfall: a lake beach, a river pool, or a
-- quarry belongs here just as much as a plunge pool at the base of a fall.
-- Where a swimming hole and a waterfall are the same physical place (Silver
-- Run Falls, Schoolhouse Falls), it stays a single 'waterfall' feature --
-- swimming is a detail of that fall, not a separate place. This kind is for
-- swimming spots that either aren't waterfalls at all, or aren't in the
-- waterfall dataset yet.

BEGIN;

ALTER TABLE features DROP CONSTRAINT features_kind_check;
ALTER TABLE features ADD CONSTRAINT features_kind_check
    CHECK (kind IN ('waterfall', 'tower', 'vista', 'swimming_hole', 'other'));

INSERT INTO schema_migrations (filename) VALUES ('065_swimming_hole_kind.sql');

COMMIT;
