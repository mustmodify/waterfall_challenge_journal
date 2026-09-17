-- 068 described jw's Google Maps reading for Tom's Spring Falls in a note
-- but never recorded it as its own claim -- so the second independent
-- coordinate that motivated re-arbitrating the OSM group in the first place
-- was never counted toward corroboration. Recording it properly.

BEGIN;

INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('jw|366|google-maps-check', 366, 'google-maps', NULL, true,
 'Read off Google Maps by jw to check the OSM claim during the Toms Creek/Toms Falls/Tom''s Spring Falls disambiguation. Agreed with our stored coordinate and OSM''s within about 20 m.');

INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, g.feature_id, 'coordinate', '{"lat": 35.28879430838692, "lon": -82.82666219343832}'::jsonb, false
FROM claim_groups g WHERE g.ref = 'jw|366|google-maps-check';

INSERT INTO schema_migrations (filename) VALUES ('069_toms_spring_google_maps.sql');

COMMIT;
