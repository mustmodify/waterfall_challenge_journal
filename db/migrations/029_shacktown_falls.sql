-- Shacktown Falls, on North Deep Creek in Yadkin County, had no coordinate.
--
-- JW read the falls off Google satellite imagery. waterfallshiker.com names it
-- twice over: Waterfall on North Deep Creek, and Styer Mill Falls.

BEGIN;

INSERT INTO locations (latitude, longitude)
VALUES (36.12426046, -80.59321432);

UPDATE features
SET feature_location_id = (SELECT id FROM locations
                           WHERE latitude = 36.12426046 AND longitude = -80.59321432)
WHERE id = 908;

INSERT INTO notes (feature_id, text, source)
VALUES (908, 'Also known as Waterfall on North Deep Creek and Styer Mill Falls.', 'jw');

INSERT INTO links (feature_id, url, rel, comments)
VALUES (908, 'https://waterfallshiker.com/2012/06/07/shacktown-falls/', 'waterfallshiker',
        'Trip report and the source of both alternate names.')
ON CONFLICT (feature_id, url) DO NOTHING;

COMMIT;
