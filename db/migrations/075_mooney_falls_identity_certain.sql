-- 074 unaccepted hikingwnc's wrong coordinate claim for Mooney Falls but left
-- the group identity_certain, so coordinate_confidence still counts the
-- wrong reading as a valid independent point and reports 'disputed' at
-- 101 km apart -- accepted and identity_certain are separate flags, and
-- unaccepting one claim doesn't remove the group from that count.
--
-- This is the exact gap MATCHING.md #8 already names: "identity_certain is
-- a group-level verdict established from one field." No per-field version
-- exists, so the group-level flag is set to false here, same as migration
-- 051 did for ncwaterfalls groups with a bad coordinate but otherwise-fine
-- data. The group's other accepted claims (height, ratings, accessibility,
-- hike distance) are untouched -- accepted and identity_certain are
-- independent, and those fields were never in question.

BEGIN;

UPDATE claim_groups SET identity_certain = false
WHERE feature_id = 668 AND source = 'hikingwnc';

INSERT INTO schema_migrations (filename) VALUES ('075_mooney_falls_identity_certain.sql');

COMMIT;
