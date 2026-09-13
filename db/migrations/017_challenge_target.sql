-- How many you must actually visit to finish a challenge.
--
-- Not the same as the number of goals. The CMC WC100 lists 115 waterfalls
-- (116 here) and asks you to visit any 100 of them -- "pick 100". Treating the
-- goal count as the target understates progress all the way along and only
-- hands out the badge if you do fifteen more than the challenge requires.
--
-- NULL means "all of them", which is the ordinary case.

BEGIN;

ALTER TABLE challenges ADD COLUMN target integer;

COMMENT ON COLUMN challenges.target IS
    'Visits needed to complete. NULL = every goal on the list.';

ALTER TABLE challenges ADD CONSTRAINT challenges_target_positive
    CHECK (target IS NULL OR target > 0);

UPDATE challenges SET target = 100 WHERE name = 'WC100';

COMMIT;
