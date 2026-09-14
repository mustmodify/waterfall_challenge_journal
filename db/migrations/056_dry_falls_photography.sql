-- Why Dry Falls rates 8 for beauty and 6 for photography.
--
-- The gap between those two numbers is the whole point of having both axes,
-- and nothing in the record said what causes it here: there is no angle that
-- works, the walkway's fence is in the frame from most of them, and the place
-- is busy enough that people are in the rest.
--
-- Only the crowding is captured anywhere else, as solitude 2. A fence is not a
-- rating, a distance or a coordinate; it is a sentence, and this database has
-- eight of those.

BEGIN;

INSERT INTO notes (feature_id, text, source)
SELECT id,
  'Pretty, and hard to photograph. There is no good angle on it, the fence along the walkway '
  'ends up in most frames, and it is busy enough that people are in the rest. Worth seeing, '
  'and worth leaving the tripod in the car.',
  'jw'
FROM features WHERE name = 'Dry Falls'
  AND NOT EXISTS (SELECT 1 FROM notes n JOIN features f ON f.id = n.feature_id
                  WHERE f.name = 'Dry Falls' AND n.source = 'jw');

COMMIT;
