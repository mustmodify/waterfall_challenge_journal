-- Marks a waterfall (or other feature) as having a usable swimming hole,
-- without giving it a second 'swimming_hole'-kind feature at the same spot.
--
-- Not a settled design -- see ARCHITECTURE.md, "Swimming holes: a
-- `swimmable` flag, not a settled design." Most swimming holes turn out to
-- be an existing waterfall's own plunge pool, and a separate feature at the
-- same coordinate would read as two places on the map where there is one.
-- 'swimming_hole' remains a real kind (065) for spots that are not
-- waterfalls at all: lakes, coves, quarries, park beaches.

BEGIN;

ALTER TABLE features ADD COLUMN swimmable boolean DEFAULT false NOT NULL;

INSERT INTO schema_migrations (filename) VALUES ('067_swimmable_flag.sql');

COMMIT;
