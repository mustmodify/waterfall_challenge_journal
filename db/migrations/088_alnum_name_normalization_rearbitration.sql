-- The matcher compares names as literal strings, so "4 X 4 Falls" (hikingwnc)
-- and "4x4 Falls" (OpenStreetMap) came out as "no agreeing name" even though
-- they are obviously the same name -- OSM just drops the spaces and the
-- capitalization. jw noticed this on the admin claims page for 4 X 4 Falls
-- and asked what stripping everything but letters and digits before
-- comparing (s/[^A-Za-z0-9]//gi) would turn up.
--
-- Run against every claim group currently marked identity_certain = false:
-- comparing normalized names surfaces exactly 13 openstreetmap groups whose
-- name matches ours this way, and every one of them sits within 68 m of our
-- coordinate. Nothing past that is close: the next nearest false-negative
-- match jumps straight to 3.8 km, then up to 395 km -- Silver Run Falls and
-- Jones Falls among them, the same over-eager name-only collisions
-- MATCHING.md already documents. So this normalization recovers real
-- corroboration without the false positives a looser rule would risk;
-- position was checked, not assumed, for every one of the 13 below.
--
-- Ten of these thirteen are currently "single source" tier, which means they
-- do not appear on the map at all -- coordinate_confidence only counts a
-- corroborating source when its group is identity_certain. This migration
-- promotes all ten to "corroborated" and they will show up for the first
-- time. The other three (Catheys Creek, Hunt Fish, Rain Forest) were already
-- corroborated by a different source; this just adds OpenStreetMap as a
-- third one.

BEGIN;

UPDATE claim_groups
SET identity_certain = true,
    note = note || ' Re-arbitrated 2026-09-17: the name comparison failed on ' ||
           'spacing/capitalization only ("4 X 4 Falls" vs "4x4 Falls" and ' ||
           'similar) -- stripping everything but letters and digits before ' ||
           'comparing shows the same name, and the coordinate is within 68 m.'
WHERE id IN (1101, 1108, 1126, 1145, 1176, 1363, 1388, 1397, 1457, 1525, 1547, 1639, 1650);

INSERT INTO schema_migrations (filename) VALUES ('088_alnum_name_normalization_rearbitration.sql');

COMMIT;
