-- jw read Cedar Rock Falls (feature 381) off Google Maps: 31-58 m from our
-- existing hikingwnc and OpenStreetMap readings, all three well inside the
-- confirmed-tier bounds (spread and nearest both under 100 m). That's a
-- third independent source, promoting this waterfall from "corroborated"
-- to "confirmed".

BEGIN;

INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('jw|381|google-maps-check', 381, 'google-maps', NULL, true,
 'Read off Google Maps by jw. 32 m from the accepted hikingwnc coordinate, 52 m from ' ||
 'OpenStreetMap''s -- a third independent reading agreeing with both.');

INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, g.feature_id, 'coordinate', '{"lat": 35.278451828059424, "lon": -82.79974332271614}'::jsonb, false
FROM claim_groups g WHERE g.ref = 'jw|381|google-maps-check';

INSERT INTO schema_migrations (filename) VALUES ('089_cedar_rock_falls_google_maps.sql');

COMMIT;
