-- Twin Falls (SC) exists twice, and one copy has the wrong coordinates.
--
--   406  35.01022, -82.82077  Pickens County -- correct. Carries the WC100
--                             goal, a logged visit, an area and an owner, but
--                             no link to its hikingwnc page.
--   510  35.46660, -83.43520  Juney Whank Falls' coordinates, about 100 km
--                             north in the Smokies. Carries the hikingwnc link
--                             and nothing else.
--
-- One waterfall split across two rows: the import matched the challenge list to
-- 406 and the hikingwnc catalogue to 510. Merge the link onto 406 and drop the
-- duplicate. Its location row (281) is used by nothing else, so it goes too.
--
-- Juney Whank itself is fine -- checked against Google Maps, 46 m from where we
-- have it -- and is nudged to the more precise reading while we are here.

BEGIN;

INSERT INTO links (feature_id, url, rel, comments)
SELECT 406, url, rel, comments FROM links WHERE feature_id = 510
ON CONFLICT (feature_id, url) DO NOTHING;

DELETE FROM features WHERE id = 510;
DELETE FROM locations WHERE id = 281;

UPDATE locations SET latitude = 35.46650487, longitude = -83.43470479
WHERE id = (SELECT feature_location_id FROM features WHERE name = 'Juney Whank Falls');

COMMIT;
