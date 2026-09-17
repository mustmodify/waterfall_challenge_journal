-- Same bug as migration 020, recurred for a newer table. feature_notes (060)
-- was applied by hand with psql, connecting as the OS user (jw), while the
-- app and script/migrate connect as johnathonwright. The table came out
-- owned by jw, and johnathonwright gets "permission denied" on it -- not
-- even SELECT, since 020's fix never covered a table added four years later.
--
-- Needs a superuser (jw) to run, same as any ALTER ... OWNER TO reassigning
-- away from the current owner; script/migrate's default connection
-- (johnathonwright) cannot apply this one itself.

BEGIN;

ALTER TABLE feature_notes OWNER TO johnathonwright;
ALTER SEQUENCE feature_notes_id_seq OWNER TO johnathonwright;

INSERT INTO schema_migrations (filename) VALUES ('073_fix_feature_notes_ownership.sql');

COMMIT;
