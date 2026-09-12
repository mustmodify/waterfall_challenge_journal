-- Challenges (e.g. the WC100) and which goals belong to them.
-- Goals with a blank/UNKNOWN/NONE "Challenge List" in the source spreadsheet
-- are real waterfalls that simply aren't part of any challenge.

CREATE TABLE challenges (
    id serial PRIMARY KEY,
    name varchar(100) NOT NULL UNIQUE,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE challenge_goals (
    challenge_id integer NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
    goal_id integer NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
    PRIMARY KEY (challenge_id, goal_id)
);

INSERT INTO challenges (name) VALUES ('WC100');

INSERT INTO challenge_goals (challenge_id, goal_id)
SELECT (SELECT id FROM challenges WHERE name = 'WC100'), id
FROM goals
WHERE name NOT IN (
    'Upper Logging Road Falls',
    'Slippery Witch Falls',
    'John''s Jump Falls',
    'Aunt Sally''s Falls',
    'Dismal Falls',
    'Lower Dismal Falls',
    'Lower Rhapsodie Falls',
    'Hooker Falls',
    'Upper Log Hollow Falls'
);
