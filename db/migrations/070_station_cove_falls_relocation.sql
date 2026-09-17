-- Station Cove Falls was placed 50 km from where it actually is.
--
-- The only claim we held (dwhike) put it at 34.849467, -83.085608 and was
-- marked identity_certain = false with a note flagging the 50.1 km gap as
-- possibly a different waterfall of the same name. It wasn't a different
-- waterfall -- it was the right one. jw checked sctrails.net (South
-- Carolina's own trail registry) and got 34.849670016655075,
-- -83.08542663834179 for the falls and 34.849080102077785,
-- -83.07411844604276 for the trailhead: within about 30 m of dwhike's
-- reading. Our stored point (35.2717, -82.8957, in NC) was the wrong one,
-- not dwhike's.
--
-- Corrected in place rather than deprecating and re-adding, since this is
-- the same feature (same name, same falls) with a wrong coordinate, not a
-- collision between two different places -- unlike Toms Creek/Toms Falls/
-- Tom's Spring Falls in the prior migration, which really were three
-- different waterfalls.

BEGIN;

UPDATE locations SET latitude = 34.849670016655075, longitude = -83.08542663834179
WHERE id = (SELECT feature_location_id FROM features WHERE id = 404);

UPDATE claim_groups
SET identity_certain = true,
    note = coalesce(note || ' ', '') ||
           'Re-arbitrated 2026-09-17: confirmed correct. jw checked sctrails.net ' ||
           'and got 34.849670016655075, -83.08542663834179 for the falls, within ' ||
           '30 m of this claim. Our stored coordinate was the wrong one and has ' ||
           'been corrected to match.'
WHERE feature_id = 404 AND source = 'dwhike' AND NOT identity_certain;

UPDATE claims SET accepted = true
WHERE group_id = (SELECT id FROM claim_groups WHERE feature_id = 404 AND source = 'dwhike')
  AND field IN ('coordinate', 'name');

INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('jw|404|sctrails', 404, 'jw', 'https://www.sctrails.net/Trails/Trail/Station-Cove-Falls', true,
 'South Carolina''s own trail registry. 0.5 mi one way, 1 mi round trip. Trailhead ' ||
 'at 34.849080102077785, -83.07411844604276, about 1.2 km from the falls.');

INSERT INTO claims (group_id, feature_id, field, value, accepted, note)
SELECT g.id, g.feature_id, v.field, v.value::jsonb, v.accepted, v.note
FROM (VALUES
  ('coordinate', '{"lat": 34.849670016655075, "lon": -83.08542663834179}', false, 'Agrees with dwhike within 30 m; not accepted twice over, one claim per field.'),
  ('parking_coordinate', '{"lat": 34.849080102077785, "lon": -83.07411844604276}', true, NULL),
  ('hike_distance', '"1 mile"', true, 'Round trip, per sctrails.net.')
) AS v(field, value, accepted, note)
JOIN claim_groups g ON g.ref = 'jw|404|sctrails';

INSERT INTO links (feature_id, url, rel)
VALUES (404, 'https://www.sctrails.net/Trails/Trail/Station-Cove-Falls', 'sctrails')
ON CONFLICT (feature_id, url) DO NOTHING;

UPDATE features SET rt_hike_distance = '1' WHERE id = 404;

INSERT INTO schema_migrations (filename) VALUES ('070_station_cove_falls_relocation.sql');

COMMIT;
