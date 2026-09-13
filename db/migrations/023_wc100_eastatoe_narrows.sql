-- CMC WC100 #99, "Eastotoee Gorge (The Narrows)", Pickens Co, SC.
--
-- One of nine entries on the official form that name matching could not place.
-- "Eastotoee Gorge (The Narrows)" against "Eastatoe Narrows" scored too low to
-- accept automatically -- the CMC form spells Eastatoe with two Es and an extra
-- E, and adds "Gorge" -- but it is the only feature in Pickens County carrying
-- the distinguishing word at all. Narrow Canyon Falls is the only other
-- candidate by name and shares none of it.
--
-- Note the coordinate is unsettled: hikingwnc #719 puts it at -82.776, while
-- Google labels "The Narrows Falls" 3.9 km west at -82.819. Not resolved here,
-- and membership does not depend on it.

BEGIN;

INSERT INTO goals (challenge_id, feature_id)
SELECT (SELECT id FROM challenges WHERE name = 'WC100'), 1006
ON CONFLICT (challenge_id, feature_id) DO NOTHING;

COMMIT;
