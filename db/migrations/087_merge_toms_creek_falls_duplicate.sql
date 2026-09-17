-- Migration 068's Toms/Toms Creek/Toms Spring disambiguation only checked
-- the new "Toms Creek Falls" against feature 366 (Tom's Spring Falls) before
-- creating it -- it never checked against feature 398, "Tom's Creek Falls",
-- which was already the same waterfall (hikingwnc #201, near Marion NC):
-- coordinates 50 m apart, and both hold the identical AllTrails
-- "toms-creek-falls-trail" link. 1267 was a duplicate from the moment it was
-- created. jw caught it on the map.
--
-- 398 survives: it carries hikingwnc's full write-up (ratings, height,
-- accessibility, hike distance), which 1267 never had. 1267's only real
-- content -- jw's own visited-and-confirmed coordinate reading -- moves over
-- as corroboration, unaccepted so it doesn't fight 398's existing accepted
-- hikingwnc coordinate for the one-winner slot. Its duplicate AllTrails claim
-- group and link are dropped outright: 398 already holds the same claim and
-- the same URL.
--
-- claims and claim_groups share a composite FK (group_id, feature_id), so a
-- claim_group can't just be re-pointed to a different feature_id in place --
-- delete and reinsert instead.

BEGIN;

DELETE FROM claims
WHERE group_id = (SELECT id FROM claim_groups WHERE ref = 'jw|1267|toms-creek-falls');

DELETE FROM claim_groups WHERE ref = 'jw|1267|toms-creek-falls';

WITH grp AS (
    INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note)
    VALUES ('jw|398|toms-creek-falls', 398, 'jw', NULL, true,
        'Originally recorded against feature 1267, a duplicate of this waterfall created in ' ||
        'error by migration 068 (it only checked the new "Toms Creek Falls" against Tom''s ' ||
        'Spring Falls, feature 366, not against this already-existing "Tom''s Creek Falls"). ' ||
        'jw''s own visited-and-confirmed coordinate reading, kept here as corroboration; not ' ||
        'accepted since 398 already has an accepted hikingwnc coordinate.')
    RETURNING id
)
INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT grp.id, 398, 'coordinate', '{"lat": 35.7776747249305, "lon": -82.06198593646882}'::jsonb, false FROM grp
UNION ALL
SELECT grp.id, 398, 'name', '"Toms Creek Falls"'::jsonb, false FROM grp;

DELETE FROM claims
WHERE group_id = (SELECT id FROM claim_groups WHERE ref = 'alltrails|1267|toms-creek-falls-trail');

DELETE FROM claim_groups WHERE ref = 'alltrails|1267|toms-creek-falls-trail';

DELETE FROM links WHERE feature_id = 1267;

DELETE FROM features WHERE id = 1267;

DELETE FROM locations WHERE id = 1013;

INSERT INTO schema_migrations (filename) VALUES ('087_merge_toms_creek_falls_duplicate.sql');

COMMIT;
