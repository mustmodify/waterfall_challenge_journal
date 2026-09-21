-- Four coordinates we display that no claim asserted. See
-- docs/unattributed-values.md for the other 51, plus 76 unattributed names.
--
-- Feature 366 (Tom's Spring Falls) is the interesting one. Its stored
-- coordinate is 35.2887, -82.8271 -- exactly what hikingwnc publishes as
-- entry #039, "Tom Springs (Daniel Ridge) Falls", and exactly what jw quoted
-- from that page. But no hikingwnc claim was ever imported for this feature:
-- our name is "Tom's Spring Falls" and theirs is "Tom Springs (Daniel Ridge)
-- Falls", which the original name match couldn't bridge. So the backbone
-- source for this waterfall has been missing all along while its number sat
-- in the features table unattributed. Importing it also brings the Daniel
-- Ridge alias, which docs note we were missing.
--
-- The other three are swimming holes from the list jw pasted this session.
-- Each line carried a secretswimmingholes.com link, so that is the source --
-- jw compiled the list, he did not survey the ponds.

BEGIN;

INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('hikingwnc|366|039-tom-springs-daniel-ridge', 366, 'hikingwnc',
 'https://hikingwnc.com/038-tom-springs-daniel-ridge-falls/', true,
 'Missed by the original import: hikingwnc calls this "Tom Springs (Daniel Ridge) Falls" ' ||
 'and we call it "Tom''s Spring Falls", which the name match could not bridge. Its ' ||
 'coordinate is what the features table has been displaying, unattributed, all along.');

INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, 366, 'coordinate', '{"lat": 35.2887, "lon": -82.8271}'::jsonb, false
FROM claim_groups g WHERE g.ref = 'hikingwnc|366|039-tom-springs-daniel-ridge';

INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, 366, 'alias', '"Daniel Ridge Falls"'::jsonb, false
FROM claim_groups g WHERE g.ref = 'hikingwnc|366|039-tom-springs-daniel-ridge';

INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('secretswimmingholes|1273|nc', 1273, 'secretswimmingholes',
 'https://secretswimmingholes.com/directory/?state=NC', true,
 'From the swimming-hole list jw compiled and pasted; this row cited secretswimmingholes.com.'),
('secretswimmingholes|1284|nc', 1284, 'secretswimmingholes',
 'https://secretswimmingholes.com/directory/?state=NC', true,
 'From the swimming-hole list jw compiled and pasted; this row cited secretswimmingholes.com.'),
('secretswimmingholes|1287|nc', 1287, 'secretswimmingholes',
 'https://secretswimmingholes.com/directory/?state=NC', true,
 'From the swimming-hole list jw compiled and pasted; this row cited secretswimmingholes.com.');

INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, g.feature_id, 'coordinate', v.coord::jsonb, false
FROM (VALUES
  ('secretswimmingholes|1273|nc', '{"lat": 35.2444, "lon": -83.0153}'),
  ('secretswimmingholes|1284|nc', '{"lat": 36.0117, "lon": -78.688}'),
  ('secretswimmingholes|1287|nc', '{"lat": 35.48185, "lon": -76.90141}')
) AS v(ref, coord)
JOIN claim_groups g ON g.ref = v.ref;

INSERT INTO schema_migrations (filename) VALUES ('094_attribute_four_coordinates.sql');

COMMIT;
