-- Reconcile WC100 with the official CMC list (revised Feb 18 2024, 115 items;
-- "pick 100"), and add the CMC/FFLA Lookout Tower Challenge (LTC, 22 towers —
-- Chambers Mountain and Mt. Noble were removed from the LTC by the CMC).
--
-- Applied 2026-08-04. Kept for the record; the statements below assume the
-- pre-reconciliation state and are not idempotent.

-- WC100: remove falls not on the official list (they remain as goals,
-- and any recorded visits are untouched)
DELETE FROM challenge_goals
WHERE challenge_id = (SELECT id FROM challenges WHERE name = 'WC100')
  AND goal_id IN (SELECT id FROM goals WHERE name IN
    ('Enloe Creek Falls','Middle Falls- Snowbird Creek','Rainbow Falls (Gorges)','Skinny Dip Falls'));

-- WC100: existing goals that are on the official list
INSERT INTO challenge_goals (challenge_id, goal_id)
SELECT (SELECT id FROM challenges WHERE name = 'WC100'), id
FROM goals WHERE name IN ('Hooker Falls','Upper Log Hollow Falls')
ON CONFLICT DO NOTHING;

-- WC100: official-list falls that were missing from goals entirely
WITH new_goals AS (
  INSERT INTO goals (name) VALUES
    ('Crab Orchard Falls'),('Glen Burney Falls'),('Jones Falls'),
    ('Hickory Branch Falls'),('Little Bearwallow Falls'),('Melrose Falls'),
    ('Slate Rock Creek Falls'),('Mt Hardy Falls'),('Upper & Lower Bubbling Springs'),
    ('Wildcat Falls (Flat Laurel Creek)'),('Lower Bearwallow Falls'),
    ('Warden Falls (Jim Burrell Falls)'),('High Falls (Cullowhee Falls)'),
    ('Alarka Falls'),('Sassafras Falls- Snowbird Creek'),('Virginia Hawkins Falls'),
    ('Rainbow Falls (GSMNP)'),('Spruce Flats Falls')
  RETURNING id
)
INSERT INTO challenge_goals (challenge_id, goal_id)
SELECT (SELECT id FROM challenges WHERE name = 'WC100'), id FROM new_goals;

-- Lookout Tower Challenge
INSERT INTO challenges (name) VALUES ('LTC');

WITH new_goals AS (
  INSERT INTO goals (name) VALUES
    ('Wayah Bald'),('Panther Top'),('Joanna Bald'),('Albert Mountain'),
    ('Wesser Bald'),('Cowee Bald'),('Yellow Mountain'),('Shuckstack'),
    ('Clingmans Dome'),('Mt. Cammerer'),('Mt. Sterling'),('Barnett Knob'),
    ('Rich Mountain'),('Camp Creek Bald'),('Fryingpan Mountain'),
    ('Bearwallow Mountain'),('Little Snowball'),('Mt. Mitchell'),
    ('Green Knob'),('Flat Top Mountain'),('Rendezvous Mountain'),('Moores Knob')
  RETURNING id
)
INSERT INTO challenge_goals (challenge_id, goal_id)
SELECT (SELECT id FROM challenges WHERE name = 'LTC'), id FROM new_goals;
