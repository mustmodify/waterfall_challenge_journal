-- Glassmine Falls: the falls and the place you stand are a kilometre apart.
--
-- jw's reading off Google Maps, plus his recollection that you cannot walk to
-- this one -- it is high on a sheer cliff, seen from a Blue Ridge Parkway
-- overlook across the valley.
--
-- That single fact explains a discrepancy 109 had to hedge about. The two
-- sources were never in conflict; they were answering different questions:
--
--   hikingwnc     35.7343  , -82.3442    the overlook   127 m from jw's view point
--   ncwaterfalls  35.73507 , -82.33193   the falls      124 m from jw's falls point
--
-- and those two sit 1112 m apart, which is why 109 accepted the ncwaterfalls
-- page only after a second look. Both are right. Our accepted coordinate is
-- currently hikingwnc's, so the feature is pinned at the overlook.
--
-- Left as unaccepted claims on purpose. Promoting the falls coordinate would
-- move a published pin and would also strand elevation_ft, which USGS read at
-- the overlook, so it is an arbitration decision rather than an import. The
-- claims are recorded so the decision has something to act on.
--
-- The hike is 0: hikingwnc independently says "Roadside" and rates access
-- Easy, which agrees.

BEGIN;

INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('google-maps|572|glassmine-falls', 572, 'google-maps', NULL, true,
 'Coordinates read off Google Maps by jw. The waterfall itself is high on a sheer cliff with no way to walk to it; the primary view is a Blue Ridge Parkway overlook about 1048 m away, which is also the parking. jw noted the cliff and the lot from memory; the coordinates themselves are read values.')
ON CONFLICT (ref) DO NOTHING;

INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, 572, v.field, v.value::jsonb, false
FROM claim_groups g,
     (VALUES
       ('coordinate',         '{"lat": 35.736094633160235, "lon": -82.33139194841556}'),
       ('view_coordinate',    '{"lat": 35.73463154718885,  "lon": -82.34285034475656}'),
       ('parking_coordinate', '{"lat": 35.73463154718885,  "lon": -82.34285034475656}'),
       ('hike_distance',      '"0"')
     ) AS v(field, value)
WHERE g.ref = 'google-maps|572|glassmine-falls'
ON CONFLICT DO NOTHING;

-- Record why the ncwaterfalls match survives a 1112 m gap, so the next reader
-- does not "fix" it back.
UPDATE claim_groups
SET note = coalesce(note || ' ', '') ||
    'The 1112 m from our accepted coordinate is not an error: that coordinate is the Parkway overlook and this page gives the falls, which cannot be reached on foot. Confirmed against jw''s Google Maps reading, 124 m from this page''s coordinate.'
WHERE feature_id = 572 AND source = 'ncwaterfalls';

INSERT INTO schema_migrations (filename) VALUES ('113_glassmine_falls_google_maps.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
