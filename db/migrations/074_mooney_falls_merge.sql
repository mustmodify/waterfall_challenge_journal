-- Migration 071 treated jw's Mooney Falls reading near Albert Mountain as a
-- second, distinct waterfall from feature 668 -- wrong. jw read the actual
-- hikingwnc page behind feature 668's one claim group and it says: "Mooney
-- Falls is 50'-60' foot high waterfall very close to Big Laurel Falls in
-- Franklin NC." That's exactly where jw's reading is (106 m from AllTrails'
-- own "Mooney Falls" trail, and near feature 326, Big Laurel Falls) -- and
-- nowhere near feature 668's stored coordinate up by Boone.
--
-- So hikingwnc's own page contradicts its own coordinate field: the prose
-- correctly places the fall near Franklin, the structured coordinate claim
-- does not. The claim is left exactly as scraped -- it is still a real
-- thing hikingwnc's data said -- but unaccepted, with a note explaining why,
-- the same "mark, don't delete" treatment as every other bad match here.
--
-- This corrects the mistake migration 071 made in the other direction: it
-- proposed a new feature where the right move was fixing this one's
-- location.

BEGIN;

UPDATE claims SET accepted = false
WHERE group_id = (SELECT id FROM claim_groups WHERE feature_id = 668 AND source = 'hikingwnc')
  AND field = 'coordinate';

UPDATE claim_groups
SET note = coalesce(note || ' ', '') ||
    'Re-arbitrated 2026-09-17: this claim''s own coordinate (35.7704, -82.8419, near Boone) ' ||
    'contradicts the same hikingwnc page''s own text, which places the fall "very close to ' ||
    'Big Laurel Falls in Franklin NC" -- jw read the live page and confirmed. Coordinate claim ' ||
    'unaccepted; the rest of this group (height, ratings, hike distance) is unaffected.'
WHERE feature_id = 668 AND source = 'hikingwnc';

UPDATE locations SET latitude = 35.0297854883662, longitude = -83.49729535676491
WHERE id = (SELECT feature_location_id FROM features WHERE id = 668);

INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('jw|668|franklin-relocation', 668, 'jw', 'https://hikingwnc.com/334-mooney-falls/', true,
 'jw read hikingwnc''s own page text ("very close to Big Laurel Falls in Franklin NC") and ' ||
 'supplied the corrected coordinate, confirmed by AllTrails'' own "Mooney Falls" trail ' ||
 '(id 10287629, Nantahala National Forest) 106 m away. On the road, so parking and the falls ' ||
 'share one coordinate.');

INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, g.feature_id, 'coordinate', '{"lat": 35.0297854883662, "lon": -83.49729535676491}'::jsonb, true
FROM claim_groups g WHERE g.ref = 'jw|668|franklin-relocation';

INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, g.feature_id, 'parking_coordinate', '{"lat": 35.0297854883662, "lon": -83.49729535676491}'::jsonb, true
FROM claim_groups g WHERE g.ref = 'jw|668|franklin-relocation';

INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note)
VALUES ('alltrails|668|mooney-falls', 668, 'alltrails',
    'https://www.alltrails.com/trail/us/north-carolina/mooney-falls', true,
    'Trailhead 106 m from jw''s coordinate; name matches exactly.');

INSERT INTO links (feature_id, url, rel)
VALUES (668, 'https://www.alltrails.com/trail/us/north-carolina/mooney-falls', 'alltrails')
ON CONFLICT (feature_id, url) DO NOTHING;

-- Undo the mistaken duplicate from migration 071.
DELETE FROM links WHERE feature_id = (SELECT id FROM features WHERE name = 'Mooney Falls (Nantahala)');
DELETE FROM claims WHERE feature_id = (SELECT id FROM features WHERE name = 'Mooney Falls (Nantahala)');
DELETE FROM claim_groups WHERE feature_id = (SELECT id FROM features WHERE name = 'Mooney Falls (Nantahala)');
DELETE FROM features WHERE name = 'Mooney Falls (Nantahala)';
DELETE FROM locations WHERE id = 1015 AND NOT EXISTS (SELECT 1 FROM features WHERE feature_location_id = 1015);

INSERT INTO schema_migrations (filename) VALUES ('074_mooney_falls_merge.sql');

COMMIT;
