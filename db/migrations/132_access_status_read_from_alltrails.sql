-- Access status read off AllTrails, one waterfall at a time.
--
-- The regex in 131 failed its first honest test. Run against Kevin's 23 real
-- Helene paragraphs it returned 'detour' zero times -- the one verdict the
-- whole field exists for -- and called Pearsons Falls inaccessible off a
-- sentence that says it reopened in summer 2026. Temporal and causal reading
-- is not what patterns do. jw: "AI should look at reviews for waterfalls,
-- store any relevant bits as an AI claim for access_status and add a detour
-- if info is available."
--
-- So these are read, not matched. Six to start, chosen because we already
-- carry a closure note for four of them and a stale closure is the most
-- expensive thing on the site.
--
-- WHERE THE SIGNAL ACTUALLY IS, which the reading turned up: AllTrails does
-- not bury closures in review prose. It puts them in two places, both
-- reliable --
--
--   the trail name       "Melrose Falls Trail [CLOSED]"
--   the description head "• Partial closure: As of May 2025, this area ...
--                         is closed indefinitely due to damage from
--                         Hurricane Helene"
--
-- review_summary is the weakest of the three and is sometimes null outright,
-- as it is for High Shoals. That is worth knowing before anyone writes a
-- scraper: the structured fields carry the closure, the reviews mostly carry
-- opinions about stairs.
--
-- SOURCING. Where the words are AllTrails', the source is alltrails and value
-- holds their sentence, the same rule 128 and 129 followed. Where the verdict
-- rests on an ABSENCE -- a busy trail with no closure marker anywhere -- the
-- words are ours, so the source is wanderfall and the value says plainly what
-- the evidence was. Nobody should be able to mistake "we found no closure"
-- for "AllTrails said it is open".
--
-- Nothing is accepted. These are readings, and the two 'ok' verdicts are the
-- weakest of the six by some distance.

BEGIN;

-- ---------------------------------------------------- closed: their words --
INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, observed_on, note) VALUES
('alltrails|537|access-2026-09-23', 537, 'alltrails',
 'https://www.alltrails.com/trail/us/north-carolina/bradley-falls-lower-trail', true, '2026-09-23',
 'Read from AllTrails on 2026-09-23. The trail is listed as "Big Bradley Falls Lower Trail [CLOSED]" -- the closure is in the name itself.'),
('alltrails|363|access-2026-09-23', 363, 'alltrails',
 'https://www.alltrails.com/trail/us/north-carolina/high-shoals-falls', true, '2026-09-23',
 'Read from AllTrails on 2026-09-23. Still closed: the notice sits at the head of the trail description and names Helene as the cause.'),
('alltrails|424|access-2026-09-23', 424, 'alltrails',
 'https://www.alltrails.com/trail/us/north-carolina/melrose-falls-trail', true, '2026-09-23',
 'Read from AllTrails on 2026-09-23. Listed as "Melrose Falls Trail [CLOSED]".'),
('alltrails|423|access-2026-09-23', 423, 'alltrails',
 'https://www.alltrails.com/trail/us/north-carolina/little-bearwallow-falls', true, '2026-09-23',
 'Read from AllTrails on 2026-09-23. Listed as "Little Bearwallow Falls [CLOSED]".')
ON CONFLICT (ref) DO NOTHING;

INSERT INTO claims (group_id, feature_id, field, value, normalized_value, accepted)
SELECT g.id, v.fid, 'access_status', to_jsonb(v.txt), to_jsonb('inaccessible'::text), false
FROM (VALUES
  ('alltrails|537|access-2026-09-23', 537,
   'Listed as "Big Bradley Falls Lower Trail [CLOSED]". Our own note from 2026-09-14 reads "As of May 2026, the trailhead is closed and there is damage along the trail leading to the falls."'),
  ('alltrails|363|access-2026-09-23', 363,
   'Partial closure: As of May 2025, this area (High Shoals Falls Loop Trail, including the waterfall viewing area) is closed indefinitely due to damage from Hurricane Helene and ongoing safety hazards.'),
  ('alltrails|424|access-2026-09-23', 424,
   'Listed as "Melrose Falls Trail [CLOSED]". Our own note from 2026-09-14 reads "Trails are temporarily closed to assess conditions and address damage following Hurricane Helene."'),
  ('alltrails|423|access-2026-09-23', 423,
   'Listed as "Little Bearwallow Falls [CLOSED]". Our own note from 2026-09-14 reads "Trails are temporarily closed to assess conditions and address damage following Hurricane Helene."')
) AS v(ref, fid, txt)
JOIN claim_groups g ON g.ref = v.ref
ON CONFLICT DO NOTHING;

-- ------------------------------------------- open: an absence, so our words --
INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, observed_on, note) VALUES
('wanderfall|405|access-2026-09-23', 405, 'wanderfall',
 'https://www.alltrails.com/trail/us/north-carolina/catawba-falls-trail', true, '2026-09-23',
 'Our reading of AllTrails on 2026-09-23, not a statement AllTrails made. Catawba Falls was hit hard by Helene -- Kevin Adams writes that much of the moss and vegetation washed away -- so the question was whether it is reachable, and nothing on the page says otherwise.'),
('wanderfall|339|access-2026-09-23', 339, 'wanderfall',
 'https://www.alltrails.com/trail/us/north-carolina/skinny-dip-falls', true, '2026-09-23',
 'Our reading of AllTrails on 2026-09-23, not a statement AllTrails made. Worth checking because the trail leaves the Blue Ridge Parkway at Looking Glass Rock Overlook and stretches of the Parkway did close.')
ON CONFLICT (ref) DO NOTHING;

INSERT INTO claims (group_id, feature_id, field, value, normalized_value, accepted, note)
SELECT g.id, v.fid, 'access_status', to_jsonb(v.txt), to_jsonb('ok'::text), false,
       'Weaker evidence than a closure notice: it rests on nothing being said. A trail can go quietly unmaintained in a way no page records.'
FROM (VALUES
  ('wanderfall|405|access-2026-09-23', 405,
   'No closure marker in the trail name and no closure notice in the description, on a trail carrying 7,766 reviews and 23,560 recorded hikes. The review summary describes "many steep stairs and heavy crowds", which reads as rebuilt and busy rather than shut.'),
  ('wanderfall|339|access-2026-09-23', 339,
   'No closure marker in the trail name and no closure notice in the description, on a trail carrying 2,079 reviews and 6,340 recorded hikes. The review summary complains only of steep sections and slippery rocks.')
) AS v(ref, fid, txt)
JOIN claim_groups g ON g.ref = v.ref
ON CONFLICT DO NOTHING;

INSERT INTO schema_migrations (filename) VALUES ('132_access_status_read_from_alltrails.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
