-- feature_views was missed by 082 because it isn't in db/schema.sql at all
-- (the same drift that hid feature_notes until this session) and so never
-- turned up in the table survey behind that migration. Also the same
-- ownership bug as feature_notes (060) and four tables before that (020):
-- applied by hand with psql, connecting as jw, while the app and
-- script/migrate connect as johnathonwright.
--
-- Found immediately by script/migrate's new auto-dump step (082) trying to
-- pg_dump the database and hitting "permission denied for table
-- feature_views" -- exactly the kind of drift that step exists to surface
-- before it becomes a surprise at deploy time.

BEGIN;

ALTER TABLE feature_views OWNER TO johnathonwright;

ALTER TABLE feature_views ADD COLUMN created_at timestamp without time zone
    DEFAULT CURRENT_TIMESTAMP NOT NULL;
ALTER TABLE feature_views ADD COLUMN updated_at timestamp without time zone
    DEFAULT CURRENT_TIMESTAMP NOT NULL;
CREATE TRIGGER touch_updated_at BEFORE UPDATE ON feature_views
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

INSERT INTO schema_migrations (filename) VALUES ('083_feature_views_ownership_and_timestamps.sql');

COMMIT;
