-- Users, sessions, and achievements (per-user visits of goals).
-- The legacy single-user `visits` table is left in place; the app now
-- reads and writes `achievements` instead.

CREATE TABLE users (
    id serial PRIMARY KEY,
    name varchar(100) NOT NULL,
    email varchar(255) NOT NULL UNIQUE,
    password_digest text NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE sessions (
    token text PRIMARY KEY,
    user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE achievements (
    id serial PRIMARY KEY,
    user_id integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    goal_id integer NOT NULL REFERENCES goals(id) ON DELETE CASCADE,
    achieved_on date NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (user_id, goal_id, achieved_on)
);

CREATE INDEX achievements_user_goal_idx ON achievements (user_id, goal_id);
