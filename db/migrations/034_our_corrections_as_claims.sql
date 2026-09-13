-- Our own conclusions, recorded as claims beside the sources they overrode.
--
-- Everything here is already in features; this is the reasoning, moved out of
-- migration comments and into rows. 033 left the hikingwnc claim for each of
-- these unaccepted because it no longer matches what we serve -- these are the
-- claims that won, and the note says why.

BEGIN;

-- 011: one degree of longitude too far east, upstream in hikingwnc's own data.
INSERT INTO claims (feature_id, field, value, source, accepted, note) VALUES
(471,  'coordinate', '{"lat": 35.0672,  "lon": -83.0642}',  'wanderfall', true,
 'hikingwnc has -82.06420, exactly one degree east. Each of these six has a name-sibling whose latitude agrees to four decimals and whose longitude differs by exactly 1.00000; moved one degree west each lands 0.2-0.6 km from the fall it is named after.'),
(856,  'coordinate', '{"lat": 35.04219, "lon": -83.02631}', 'wanderfall', true,
 'One degree east in the source; corrected beside Lower Waddle Branch Falls.'),
(1112, 'coordinate', '{"lat": 35.63313, "lon": -82.76205}', 'wanderfall', true,
 'One degree east in the source; corrected beside Shoal Creek Falls.'),
(508,  'coordinate', '{"lat": 36.381,   "lon": -81.0342}',  'wanderfall', true,
 'One degree east in the source; corrected into Stone Mountain State Park.'),
(509,  'coordinate', '{"lat": 36.3816,  "lon": -81.0395}',  'wanderfall', true,
 'One degree east in the source; corrected beside Lower Falls at Stone Mountain.'),
(1199, 'coordinate', '{"lat": 35.07811, "lon": -83.00639}', 'wanderfall', true,
 'One degree east in the source; corrected beside Twin Falls on the Thompson River.');

-- 022: the recorded point was the trailhead, 69 m from it and 431 m from the water.
INSERT INTO claims (feature_id, field, value, source, accepted, note) VALUES
(406, 'coordinate', '{"lat": 35.01371329, "lon": -82.81874907}', 'google-maps', true,
 'Read off Google Maps, which labels this Reedy Cove Falls. Twin Falls sits on Reedy Cove Creek and carries both names; the identification is the one inference, the distances are not.');
INSERT INTO claims (feature_id, field, value, source, note) VALUES
(406, 'coordinate', '{"lat": 35.00979902, "lon": -82.82135347}', 'google-maps',
 'The Twin Falls trailhead, 69 m from the coordinate we had. Kept as parking, not as the falls.');
INSERT INTO claims (feature_id, field, value, source, accepted) VALUES
(406, 'parking_coordinate', '{"lat": 35.00979902, "lon": -82.82135347}', 'google-maps', true);
INSERT INTO claims (feature_id, field, value, source, accepted, note) VALUES
(406, 'alias', '"Reedy Cove Falls"', 'google-maps', true, 'The name Google Maps uses for it.');

-- 021: Juney Whank, checked rather than corrected -- 46 m from where we had it.
INSERT INTO claims (feature_id, field, value, source, accepted, note) VALUES
(483, 'coordinate', '{"lat": 35.46650487, "lon": -83.43470479}', 'jw', true,
 'Read off Google Maps. Agreed with hikingwnc to within 46 m; taken as the more precise of the two.');

-- 024/025: Eastatoe Narrows, moved to the water and then given a real trailhead.
INSERT INTO claims (feature_id, field, value, source, accepted, note) VALUES
(1006, 'coordinate', '{"lat": 35.03200855, "lon": -82.81900106}', 'jw', true,
 'On Eastatoe Creek near a confluence and away from any road. hikingwnc has 35.03063, -82.77601, a point shared by five separate multi-mile hikes and therefore an access point, not a waterfall. The position is still disputed: the two readings are 3.9 km apart.'),
(1006, 'parking_coordinate', '{"lat": 35.0504593, "lon": -82.81643513}', 'jw', true,
 'Eastatoe Gorge Spur Trailhead, 2.06 km from the falls. Consistent with hikingwnc listing the walk as 5.4 miles down a switchbacked gorge.');

-- 026: parking for the Eden Falls group, stated outright on hikingwnc's own page.
INSERT INTO claims (feature_id, field, value, source, accepted, note) VALUES
(1028, 'parking_coordinate', '{"lat": 35.02937, "lon": -82.79939}', 'hikingwnc', true,
 'Quoted from the Eden Falls hike description: "The GPS on the parking area is 35.02937, -82.79939."'),
(1029, 'parking_coordinate', '{"lat": 35.02937, "lon": -82.79939}', 'hikingwnc', true,
 'Same hike, same parking area.'),
(1030, 'parking_coordinate', '{"lat": 35.02937, "lon": -82.79939}', 'hikingwnc', true,
 'Same hike, same parking area.'),
(1031, 'parking_coordinate', '{"lat": 35.02937, "lon": -82.79939}', 'hikingwnc', true,
 'Same hike, same parking area.');

-- Mountain Cat is passed at 1.9 miles while Eden is the 8.0 mile turnaround, yet
-- hikingwnc gives both the same point. One of the two is wrong and we cannot
-- tell which, so nothing is accepted for it.
INSERT INTO claims (feature_id, field, value, source, note) VALUES
(1028, 'coordinate', '{"lat": 35.02984, "lon": -82.77171}', 'hikingwnc',
 'Identical to Eden Falls, six miles further along the same hike. Both cannot be right.');

-- 029/031: the two Central and Eastern NC falls we have since located.
INSERT INTO claims (feature_id, field, value, source, url, accepted, note) VALUES
(908, 'coordinate', '{"lat": 36.12426046, "lon": -80.59321432}', 'jw', NULL, true,
 'Read off Google satellite imagery. hikingwnc publishes no coordinate for this one.'),
(908, 'alias', '"Waterfall on North Deep Creek"', 'waterfallshiker',
 'https://waterfallshiker.com/2012/06/07/shacktown-falls/', true, NULL),
(908, 'alias', '"Styer Mill Falls"', 'waterfallshiker',
 'https://waterfallshiker.com/2012/06/07/shacktown-falls/', true, NULL);

INSERT INTO claims (feature_id, field, value, source, url, accepted, note) VALUES
(909, 'coordinate', '{"lat": 35.48122, "lon": -78.91025}', 'ncwaterfalls',
 'https://ncwaterfalls.com/waterfalls/jumping-fish-falls/', true, NULL),
(909, 'parking_coordinate', '{"lat": 35.48344, "lon": -78.90395}', 'ncwaterfalls',
 'https://ncwaterfalls.com/waterfalls/jumping-fish-falls/', true, 'Given as Trailhead GPS.'),
(909, 'height_ft', '5', 'ncwaterfalls',
 'https://ncwaterfalls.com/waterfalls/jumping-fish-falls/', true, NULL),
(909, 'elevation_ft', '135', 'ncwaterfalls',
 'https://ncwaterfalls.com/waterfalls/jumping-fish-falls/', true, NULL),
(909, 'beauty_rating', '4', 'ncwaterfalls',
 'https://ncwaterfalls.com/waterfalls/jumping-fish-falls/', true,
 'Accepted on the assumption that ncwaterfalls scores out of ten like hikingwnc, the source of every other rating here. Unverified.'),
(909, 'hike_distance', '"About 0.6 miles"', 'ncwaterfalls',
 'https://ncwaterfalls.com/waterfalls/jumping-fish-falls/', true,
 'One way. Stored as 1.2 round trip in features. The two coordinates are 0.39 miles apart in a straight line, which fits a 0.6 mile walk and rules out 0.6 being the round trip.'),
(909, 'accessibility', '"Moderate"', 'ncwaterfalls',
 'https://ncwaterfalls.com/waterfalls/jumping-fish-falls/', true,
 'Their Hike Difficulty. Their separate Accessibility field says "Hiking trail", which is not what this column means.'),
(909, 'owner', '"State"', 'ncwaterfalls',
 'https://ncwaterfalls.com/waterfalls/jumping-fish-falls/', true,
 'Landowner given as Raven Rock State Park; this column holds a category, not a name.');

COMMIT;
