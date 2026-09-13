-- Our own conclusions, recorded as claims beside the sources they overrode.
--
-- Everything here is already in features; this is the reasoning, moved out of
-- migration comments and into rows. 033 left the hikingwnc claim for each of
-- these unaccepted because it no longer matches what we serve.
--
-- Note how the ncwaterfalls page at the end forms a single group: one page,
-- read once, asserting nine things about one waterfall.

BEGIN;

INSERT INTO claim_groups (ref, feature_id, source, url, note) VALUES
('wanderfall|471',  471,  'wanderfall', NULL,
 'hikingwnc has -82.06420, exactly one degree east. Each of these six has a name-sibling whose latitude agrees to four decimals and whose longitude differs by exactly 1.00000; moved one degree west each lands 0.2-0.6 km from the fall it is named after.'),
('wanderfall|856',  856,  'wanderfall', NULL, 'One degree east in the source; corrected beside Lower Waddle Branch Falls.'),
('wanderfall|1112', 1112, 'wanderfall', NULL, 'One degree east in the source; corrected beside Shoal Creek Falls.'),
('wanderfall|508',  508,  'wanderfall', NULL, 'One degree east in the source; corrected into Stone Mountain State Park.'),
('wanderfall|509',  509,  'wanderfall', NULL, 'One degree east in the source; corrected beside Lower Falls at Stone Mountain.'),
('wanderfall|1199', 1199, 'wanderfall', NULL, 'One degree east in the source; corrected beside Twin Falls on the Thompson River.'),

('google-maps|406|falls',     406, 'google-maps', NULL,
 'Read off Google Maps, which labels this Reedy Cove Falls. Twin Falls sits on Reedy Cove Creek and carries both names; the identification is the one inference, the distances are not.'),
('google-maps|406|trailhead', 406, 'google-maps', NULL,
 'The Twin Falls trailhead, 69 m from the coordinate we had.'),
('jw|483',  483,  'jw', NULL,
 'Read off Google Maps. Agreed with hikingwnc to within 46 m; taken as the more precise of the two.'),
('jw|1006', 1006, 'jw', NULL,
 'hikingwnc has 35.03063, -82.77601, a point shared by five separate multi-mile hikes and therefore an access point, not a waterfall. The position is still disputed: the two readings are 3.9 km apart.'),

('hikingwnc|1028|eden-parking', 1028, 'hikingwnc', 'https://hikingwnc.com/096-eden-falls/',
 'Quoted from the Eden Falls hike description: "The GPS on the parking area is 35.02937, -82.79939."'),
('hikingwnc|1029|eden-parking', 1029, 'hikingwnc', 'https://hikingwnc.com/096-eden-falls/', 'Same hike, same parking area.'),
('hikingwnc|1030|eden-parking', 1030, 'hikingwnc', 'https://hikingwnc.com/096-eden-falls/', 'Same hike, same parking area.'),
('hikingwnc|1031|eden-parking', 1031, 'hikingwnc', 'https://hikingwnc.com/096-eden-falls/', 'Same hike, same parking area.'),

('jw|908', 908, 'jw', NULL,
 'Read off Google satellite imagery. hikingwnc publishes no coordinate for this one.'),
('waterfallshiker|908', 908, 'waterfallshiker', 'https://waterfallshiker.com/2012/06/07/shacktown-falls/',
 'Trip report naming the fall twice over.'),
('ncwaterfalls|909', 909, 'ncwaterfalls', 'https://ncwaterfalls.com/waterfalls/jumping-fish-falls/',
 'One page, read 2026-09-13, asserting everything below.');

INSERT INTO claims (group_id, feature_id, field, value, accepted, note)
SELECT g.id, g.feature_id, v.field, v.value::jsonb, v.accepted, v.note::text
FROM (VALUES
  ('wanderfall|471',  'coordinate', '{"lat": 35.0672,  "lon": -83.0642}',  true, NULL),
  ('wanderfall|856',  'coordinate', '{"lat": 35.04219, "lon": -83.02631}', true, NULL),
  ('wanderfall|1112', 'coordinate', '{"lat": 35.63313, "lon": -82.76205}', true, NULL),
  ('wanderfall|508',  'coordinate', '{"lat": 36.381,   "lon": -81.0342}',  true, NULL),
  ('wanderfall|509',  'coordinate', '{"lat": 36.3816,  "lon": -81.0395}',  true, NULL),
  ('wanderfall|1199', 'coordinate', '{"lat": 35.07811, "lon": -83.00639}', true, NULL),

  ('google-maps|406|falls',     'coordinate', '{"lat": 35.01371329, "lon": -82.81874907}', true, NULL),
  ('google-maps|406|falls',     'alias',      '"Reedy Cove Falls"',                       true,
   'The name Google Maps uses for it.'),
  ('google-maps|406|trailhead', 'coordinate', '{"lat": 35.00979902, "lon": -82.82135347}', false,
   'Kept as parking, not as the falls.'),
  ('google-maps|406|trailhead', 'parking_coordinate', '{"lat": 35.00979902, "lon": -82.82135347}', true, NULL),

  ('jw|483',  'coordinate', '{"lat": 35.46650487, "lon": -83.43470479}', true, NULL),
  ('jw|1006', 'coordinate', '{"lat": 35.03200855, "lon": -82.81900106}', true,
   'On Eastatoe Creek near a confluence and away from any road.'),
  ('jw|1006', 'parking_coordinate', '{"lat": 35.0504593, "lon": -82.81643513}', true,
   'Eastatoe Gorge Spur Trailhead, 2.06 km from the falls. Consistent with hikingwnc listing the walk as 5.4 miles down a switchbacked gorge.'),

  ('hikingwnc|1028|eden-parking', 'parking_coordinate', '{"lat": 35.02937, "lon": -82.79939}', true, NULL),
  ('hikingwnc|1029|eden-parking', 'parking_coordinate', '{"lat": 35.02937, "lon": -82.79939}', true, NULL),
  ('hikingwnc|1030|eden-parking', 'parking_coordinate', '{"lat": 35.02937, "lon": -82.79939}', true, NULL),
  ('hikingwnc|1031|eden-parking', 'parking_coordinate', '{"lat": 35.02937, "lon": -82.79939}', true, NULL),

  ('jw|908',              'coordinate', '{"lat": 36.12426046, "lon": -80.59321432}', true, NULL),
  ('waterfallshiker|908', 'alias', '"Waterfall on North Deep Creek"', true, NULL),
  ('waterfallshiker|908', 'alias', '"Styer Mill Falls"',              true, NULL),

  ('ncwaterfalls|909', 'name',        '"Jumping Fish Falls"', true, NULL),
  ('ncwaterfalls|909', 'coordinate',  '{"lat": 35.48122, "lon": -78.91025}', true, NULL),
  ('ncwaterfalls|909', 'parking_coordinate', '{"lat": 35.48344, "lon": -78.90395}', true,
   'Given as Trailhead GPS.'),
  ('ncwaterfalls|909', 'height_ft',    '5',   true, NULL),
  ('ncwaterfalls|909', 'elevation_ft', '135', true, NULL),
  ('ncwaterfalls|909', 'beauty_rating', '4',  true,
   'Accepted on the assumption that ncwaterfalls scores out of ten like hikingwnc, the source of every other rating here. Unverified.'),
  ('ncwaterfalls|909', 'hike_distance', '"About 0.6 miles"', true,
   'One way. Stored as 1.2 round trip in features. The two coordinates are 0.39 miles apart in a straight line, which fits a 0.6 mile walk and rules out 0.6 being the round trip.'),
  ('ncwaterfalls|909', 'accessibility', '"Moderate"', true,
   'Their Hike Difficulty. Their separate Accessibility field says "Hiking trail", which is not what this column means.'),
  ('ncwaterfalls|909', 'owner', '"State"', true,
   'Landowner given as Raven Rock State Park; this column holds a category, not a name.')
) AS v(ref, field, value, accepted, note)
JOIN claim_groups g ON g.ref = v.ref;

-- Mountain Cat is passed at 1.9 miles while Eden is the 8.0 mile turnaround,
-- yet hikingwnc gives both the same point. One of the two is wrong and we
-- cannot tell which, so the claim keeps its doubt rather than an answer.
UPDATE claims SET note = 'Identical to Eden Falls, six miles further along the same hike. Both cannot be right.'
WHERE feature_id = 1028 AND field = 'coordinate'
  AND value = '{"lat": 35.02984, "lon": -82.77171}'::jsonb;

COMMIT;
