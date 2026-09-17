-- Every table gets created_at and updated_at, with one exception explained
-- below. Where we cannot know the real value, it is set to now() rather than
-- guessed at -- these are metadata about the record, not about the place,
-- so a wrong guess would be worse than an honest "we started tracking this
-- today."
--
-- updated_at was already decorative on notes (a DEFAULT that only fires on
-- INSERT, never touched again by anything). That is fixed everywhere at
-- once: a single trigger function sets updated_at on every UPDATE, so the
-- column means what its name says from here on.
--
-- schema_migrations is the one table left alone. It is a ledger, not a
-- record of a place or a person: applied_at already answers "when", rows are
-- never updated, and adding updated_at to a table that is only ever
-- INSERTed once per row would just be a second column saying the same thing
-- as the first.
--
-- links also gets reviewed_at: a link is a claim that some outside page is
-- still there and still about this place, and that claim goes stale. NULL
-- means never reviewed, not "reviewed just now" -- backfilling every
-- existing link to now() would hide the entire backlog from the review
-- queue on day one, which defeats the point of having one. See
-- script/review_links for what "reasonable interval" means in practice.
--
-- Originally one BEGIN/COMMIT wrapping every table. That deadlocked in
-- production on every attempt (2026-09-17): preDeployCommand runs before the
-- new version takes traffic, but the *old* version is still up and being
-- health-checked against /features the whole time, which reads several of
-- these same tables in one join. A single transaction taking
-- AccessExclusiveLock on table after table, while a live read holds a lock
-- on one and waits on another, is exactly the shape a deadlock needs. Never
-- happened in dev because nothing else was ever querying the database while
-- a migration ran. Split into one small transaction per table instead: at
-- no point does this migration hold an exclusive lock on more than one table
-- at a time, which removes the two-table wait cycle a deadlock requires.
--
-- Splitting into separate transactions means a deadlock partway through
-- leaves earlier tables already committed, so every statement below is
-- written to be safe to run again from the top regardless of how far a
-- previous attempt got -- IF NOT EXISTS, IF EXISTS, and a WHERE guard on the
-- backfill UPDATE, rather than relying on the whole file being all-or-nothing.

CREATE OR REPLACE FUNCTION touch_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Tables with created_at already, missing only updated_at: backfill from
-- created_at, since "last touched" and "first touched" are the same fact
-- for a row nothing has updated since.

BEGIN;
ALTER TABLE areas ADD COLUMN IF NOT EXISTS updated_at timestamp without time zone;
UPDATE areas SET updated_at = COALESCE(created_at, CURRENT_TIMESTAMP) WHERE updated_at IS NULL;
ALTER TABLE areas ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP;
CREATE OR REPLACE TRIGGER touch_updated_at BEFORE UPDATE ON areas
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
COMMIT;

BEGIN;
ALTER TABLE challenges ADD COLUMN IF NOT EXISTS updated_at timestamp without time zone;
UPDATE challenges SET updated_at = COALESCE(created_at, CURRENT_TIMESTAMP) WHERE updated_at IS NULL;
ALTER TABLE challenges ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP;
CREATE OR REPLACE TRIGGER touch_updated_at BEFORE UPDATE ON challenges
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
COMMIT;

BEGIN;
ALTER TABLE claim_groups ADD COLUMN IF NOT EXISTS updated_at timestamp without time zone;
UPDATE claim_groups SET updated_at = COALESCE(created_at, CURRENT_TIMESTAMP) WHERE updated_at IS NULL;
ALTER TABLE claim_groups ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP;
CREATE OR REPLACE TRIGGER touch_updated_at BEFORE UPDATE ON claim_groups
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
COMMIT;

BEGIN;
ALTER TABLE claims ADD COLUMN IF NOT EXISTS updated_at timestamp without time zone;
UPDATE claims SET updated_at = COALESCE(created_at, CURRENT_TIMESTAMP) WHERE updated_at IS NULL;
ALTER TABLE claims ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP;
CREATE OR REPLACE TRIGGER touch_updated_at BEFORE UPDATE ON claims
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
COMMIT;

BEGIN;
ALTER TABLE corrections ADD COLUMN IF NOT EXISTS updated_at timestamp without time zone;
UPDATE corrections SET updated_at = COALESCE(created_at, CURRENT_TIMESTAMP) WHERE updated_at IS NULL;
ALTER TABLE corrections ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP;
CREATE OR REPLACE TRIGGER touch_updated_at BEFORE UPDATE ON corrections
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
COMMIT;

BEGIN;
ALTER TABLE feature_notes ADD COLUMN IF NOT EXISTS updated_at timestamp without time zone;
UPDATE feature_notes SET updated_at = COALESCE(created_at, CURRENT_TIMESTAMP) WHERE updated_at IS NULL;
ALTER TABLE feature_notes ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP;
CREATE OR REPLACE TRIGGER touch_updated_at BEFORE UPDATE ON feature_notes
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
COMMIT;

BEGIN;
ALTER TABLE links ADD COLUMN IF NOT EXISTS updated_at timestamp without time zone;
UPDATE links SET updated_at = COALESCE(created_at, CURRENT_TIMESTAMP) WHERE updated_at IS NULL;
ALTER TABLE links ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP;
CREATE OR REPLACE TRIGGER touch_updated_at BEFORE UPDATE ON links
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
COMMIT;

BEGIN;
ALTER TABLE magic_links ADD COLUMN IF NOT EXISTS updated_at timestamp without time zone;
UPDATE magic_links SET updated_at = COALESCE(created_at, CURRENT_TIMESTAMP) WHERE updated_at IS NULL;
ALTER TABLE magic_links ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP;
CREATE OR REPLACE TRIGGER touch_updated_at BEFORE UPDATE ON magic_links
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
COMMIT;

BEGIN;
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS updated_at timestamp without time zone;
UPDATE sessions SET updated_at = COALESCE(created_at, CURRENT_TIMESTAMP) WHERE updated_at IS NULL;
ALTER TABLE sessions ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP;
CREATE OR REPLACE TRIGGER touch_updated_at BEFORE UPDATE ON sessions
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
COMMIT;

BEGIN;
ALTER TABLE users ADD COLUMN IF NOT EXISTS updated_at timestamp without time zone;
UPDATE users SET updated_at = COALESCE(created_at, CURRENT_TIMESTAMP) WHERE updated_at IS NULL;
ALTER TABLE users ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP;
CREATE OR REPLACE TRIGGER touch_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
COMMIT;

BEGIN;
ALTER TABLE visits ADD COLUMN IF NOT EXISTS updated_at timestamp without time zone;
UPDATE visits SET updated_at = COALESCE(created_at, CURRENT_TIMESTAMP) WHERE updated_at IS NULL;
ALTER TABLE visits ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP;
CREATE OR REPLACE TRIGGER touch_updated_at BEFORE UPDATE ON visits
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
COMMIT;

-- Tables missing both: neither can be known, so both become now().

BEGIN;
ALTER TABLE features ADD COLUMN IF NOT EXISTS created_at timestamp without time zone
    DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE features ADD COLUMN IF NOT EXISTS updated_at timestamp without time zone
    DEFAULT CURRENT_TIMESTAMP NOT NULL;
CREATE OR REPLACE TRIGGER touch_updated_at BEFORE UPDATE ON features
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
COMMIT;

BEGIN;
ALTER TABLE locations ADD COLUMN IF NOT EXISTS created_at timestamp without time zone
    DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE locations ADD COLUMN IF NOT EXISTS updated_at timestamp without time zone
    DEFAULT CURRENT_TIMESTAMP NOT NULL;
CREATE OR REPLACE TRIGGER touch_updated_at BEFORE UPDATE ON locations
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
COMMIT;

BEGIN;
ALTER TABLE goals ADD COLUMN IF NOT EXISTS created_at timestamp without time zone
    DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE goals ADD COLUMN IF NOT EXISTS updated_at timestamp without time zone
    DEFAULT CURRENT_TIMESTAMP NOT NULL;
CREATE OR REPLACE TRIGGER touch_updated_at BEFORE UPDATE ON goals
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
COMMIT;

BEGIN;
ALTER TABLE feature_areas ADD COLUMN IF NOT EXISTS created_at timestamp without time zone
    DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE feature_areas ADD COLUMN IF NOT EXISTS updated_at timestamp without time zone
    DEFAULT CURRENT_TIMESTAMP NOT NULL;
CREATE OR REPLACE TRIGGER touch_updated_at BEFORE UPDATE ON feature_areas
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();
COMMIT;

-- Links: last-reviewed tracking, separate from created_at/updated_at above.
BEGIN;
ALTER TABLE links ADD COLUMN IF NOT EXISTS reviewed_at timestamp without time zone;
COMMIT;

INSERT INTO schema_migrations (filename) VALUES ('082_created_updated_everywhere.sql')
ON CONFLICT (filename) DO NOTHING;
