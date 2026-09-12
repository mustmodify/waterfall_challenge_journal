-- Split "the place" from "the intent".
--
--   features  the place itself: a waterfall, a lookout tower. Was `goals`.
--   goals     a feature's membership in a challenge. Was `challenge_goals`.
--   links     external references for a feature (hikingwnc, wikipedia, ...).
--
-- achievements/notes/visits move to features rather than goals. A goal is now
-- (challenge, feature), so a waterfall on no challenge list has no goal row --
-- and you must still be able to log a visit to one. Challenge progress becomes
-- "features achieved that appear in this challenge's goals".
--
-- Ids are preserved throughout: this is renames only, no rows move.

BEGIN;

-- 1. goals -> features -------------------------------------------------------
ALTER TABLE goals RENAME TO features;
ALTER SEQUENCE goals_id_seq RENAME TO features_id_seq;  -- frees the name for the new goals

ALTER TABLE achievements RENAME COLUMN goal_id TO feature_id;
ALTER TABLE notes        RENAME COLUMN goal_id TO feature_id;
ALTER TABLE visits       RENAME COLUMN goal_id TO feature_id;

ALTER INDEX goals_pkey RENAME TO features_pkey;
ALTER TABLE features RENAME CONSTRAINT goals_difficulty_rating_check
                                    TO features_difficulty_rating_check;

ALTER TABLE achievements RENAME CONSTRAINT achievements_goal_id_fkey
                                        TO achievements_feature_id_fkey;
ALTER TABLE notes  RENAME CONSTRAINT notes_goal_id_fkey  TO notes_feature_id_fkey;
ALTER TABLE visits RENAME CONSTRAINT visits_goal_id_fkey TO visits_feature_id_fkey;

-- NOTE: renaming this constraint breaks the string match in achievements.go:49.
-- That handler is being switched to the pq error code (23505) in the same change.
ALTER TABLE achievements RENAME CONSTRAINT achievements_user_id_goal_id_achieved_on_key
                                        TO achievements_user_feature_date_key;
ALTER INDEX achievements_user_goal_idx RENAME TO achievements_user_feature_idx;

-- 2. what kind of place is it? ----------------------------------------------
-- Tower-ness is currently inferred from LTC membership (index.html isTower),
-- so a tower the CMC drops from the list silently becomes a waterfall.
ALTER TABLE features ADD COLUMN kind varchar(20) NOT NULL DEFAULT 'waterfall'
    CHECK (kind IN ('waterfall', 'tower', 'vista', 'other'));

UPDATE features SET kind = 'tower'
WHERE id IN (SELECT cg.goal_id
             FROM challenge_goals cg
             JOIN challenges c ON c.id = cg.challenge_id
             WHERE c.name = 'LTC');

-- 3. columns for the spidered data ------------------------------------------
-- hikingwnc's accessibility has 12 values (Roadside, Moderate+, Hard+, ...);
-- kept raw so the "+" distinction survives. difficulty_rating stays the
-- hand-curated E/M/D field.
ALTER TABLE features
    ADD COLUMN accessibility varchar(20),
    ADD COLUMN height_ft     integer;

-- the source data contains a Beauty of 46
ALTER TABLE features
    ADD CONSTRAINT features_beauty_range   CHECK (beauty_rating   BETWEEN 1 AND 10),
    ADD CONSTRAINT features_photo_range    CHECK (photo_rating    BETWEEN 1 AND 10),
    ADD CONSTRAINT features_solitude_range CHECK (solitude_rating BETWEEN 1 AND 10);

-- 4. challenge_goals -> goals ------------------------------------------------
ALTER TABLE challenge_goals RENAME TO goals;
ALTER TABLE goals RENAME COLUMN goal_id TO feature_id;

ALTER TABLE goals RENAME CONSTRAINT challenge_goals_challenge_id_fkey
                                 TO goals_challenge_id_fkey;
ALTER TABLE goals RENAME CONSTRAINT challenge_goals_goal_id_fkey
                                 TO goals_feature_id_fkey;

ALTER TABLE goals DROP CONSTRAINT challenge_goals_pkey;
ALTER TABLE goals ADD COLUMN id serial PRIMARY KEY;
ALTER TABLE goals ADD CONSTRAINT goals_challenge_feature_key
    UNIQUE (challenge_id, feature_id);

-- 5. links -------------------------------------------------------------------
-- One feature, many references: a fall can carry its hikingwnc page, a second
-- hikingwnc page where the site listed it twice, and a Wikipedia article.
-- url is deliberately NOT globally unique -- hikingwnc page "436-439" covers
-- four separate falls.
CREATE TABLE links (
    id         serial PRIMARY KEY,
    feature_id integer NOT NULL REFERENCES features(id) ON DELETE CASCADE,
    url        text NOT NULL,
    rel        varchar(30),
    comments   text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (feature_id, url)
);

CREATE INDEX links_feature_idx ON links (feature_id);
CREATE INDEX links_url_idx     ON links (url);

-- Every other table is owned by johnathonwright, which is who the app connects
-- as. Applying this migration as anyone else leaves links unreadable to it.
ALTER TABLE    links        OWNER TO johnathonwright;
ALTER SEQUENCE links_id_seq OWNER TO johnathonwright;

COMMIT;
