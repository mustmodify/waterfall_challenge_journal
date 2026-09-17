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

BEGIN;

CREATE OR REPLACE FUNCTION touch_updated_at() RETURNS trigger AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Tables with created_at already, missing only updated_at: backfill from
-- created_at, since "last touched" and "first touched" are the same fact
-- for a row nothing has updated since.
DO $$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['areas', 'challenges', 'claim_groups', 'claims',
                              'corrections', 'feature_notes', 'links',
                              'magic_links', 'sessions', 'users', 'visits']
    LOOP
        EXECUTE format('ALTER TABLE %I ADD COLUMN updated_at timestamp without time zone', t);
        EXECUTE format('UPDATE %I SET updated_at = COALESCE(created_at, CURRENT_TIMESTAMP)', t);
        EXECUTE format('ALTER TABLE %I ALTER COLUMN updated_at SET DEFAULT CURRENT_TIMESTAMP', t);
        EXECUTE format('CREATE TRIGGER touch_updated_at BEFORE UPDATE ON %I
                         FOR EACH ROW EXECUTE FUNCTION touch_updated_at()', t);
    END LOOP;
END $$;

-- Tables missing both: neither can be known, so both become now().
DO $$
DECLARE
    t text;
BEGIN
    FOREACH t IN ARRAY ARRAY['features', 'locations', 'goals', 'feature_areas']
    LOOP
        EXECUTE format('ALTER TABLE %I ADD COLUMN created_at timestamp without time zone
                         DEFAULT CURRENT_TIMESTAMP NOT NULL', t);
        EXECUTE format('ALTER TABLE %I ADD COLUMN updated_at timestamp without time zone
                         DEFAULT CURRENT_TIMESTAMP NOT NULL', t);
        EXECUTE format('CREATE TRIGGER touch_updated_at BEFORE UPDATE ON %I
                         FOR EACH ROW EXECUTE FUNCTION touch_updated_at()', t);
    END LOOP;
END $$;

-- Links: last-reviewed tracking, separate from created_at/updated_at above.
ALTER TABLE links ADD COLUMN reviewed_at timestamp without time zone;

INSERT INTO schema_migrations (filename) VALUES ('082_created_updated_everywhere.sql');

COMMIT;
