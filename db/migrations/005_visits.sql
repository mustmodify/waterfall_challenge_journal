-- Rename achievements -> visits.
--
-- "Visit" is what the UI has always called this (log-visit, submitVisit,
-- "Your visits") and what the legacy /visits route posts. "Achievement" only
-- ever appeared in the Go and SQL layers. The challenge is the aspiration;
-- the visit is just what happened.
--
-- The name is currently taken by the legacy single-user `visits` table that
-- 001 left in place. 39 of its 40 rows already exist in achievements; the
-- fortieth (North Harper Creek Falls, 2025-05-05) does not, and is a genuine
-- second visit -- the same fall also has an achievement on 2025-05-04.
--
-- Runs after 004, so both tables already say feature_id rather than goal_id.

BEGIN;

-- 1. rescue anything the 001 cutover left behind -----------------------------
-- The legacy table predates users entirely, so its rows belong to the first
-- (and, today, only) account.
INSERT INTO achievements (user_id, feature_id, achieved_on)
SELECT (SELECT id FROM users ORDER BY id LIMIT 1), v.feature_id, v.visited_on
FROM visits v
WHERE v.visited_on IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM achievements a
                  WHERE a.feature_id = v.feature_id
                    AND a.achieved_on = v.visited_on);

-- 2. retire the legacy table (frees the name, drops visits_id_seq with it) ---
DROP TABLE visits;

-- 3. achievements -> visits --------------------------------------------------
ALTER TABLE achievements RENAME TO visits;
ALTER TABLE visits RENAME COLUMN achieved_on TO visited_on;
ALTER SEQUENCE achievements_id_seq RENAME TO visits_id_seq;

ALTER INDEX achievements_pkey RENAME TO visits_pkey;
ALTER INDEX achievements_user_feature_idx RENAME TO visits_user_feature_idx;

ALTER TABLE visits RENAME CONSTRAINT achievements_user_feature_date_key
                                  TO visits_user_feature_date_key;
ALTER TABLE visits RENAME CONSTRAINT achievements_user_id_fkey
                                  TO visits_user_id_fkey;
ALTER TABLE visits RENAME CONSTRAINT achievements_feature_id_fkey
                                  TO visits_feature_id_fkey;

COMMIT;
