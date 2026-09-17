-- Same bug as migration 020, recurred for a newer table. feature_notes (060)
-- was applied by hand with psql, connecting as the OS user (jw), while the
-- app and script/migrate connect as johnathonwright. The table came out
-- owned by jw, and johnathonwright gets "permission denied" on it -- not
-- even SELECT, since 020's fix never covered a table added four years later.
--
-- Needs a superuser (jw) to run, same as any ALTER ... OWNER TO reassigning
-- away from the current owner; script/migrate's default connection
-- (johnathonwright) cannot apply this one itself.
--
-- "johnathonwright" is a role name specific to jw's local dev machine. It
-- does not exist on Render's production database, and this migration was
-- hardcoded to it -- every deploy from 2026-09-14 through 2026-09-17 failed
-- at this exact migration with "role \"johnathonwright\" does not exist",
-- because production's `preDeployCommand` runs migrations in order and
-- refuses to skip a failed one. Production never had the manual-psql
-- ownership bug in the first place: every table there, including
-- feature_notes, was created by script/migrate connecting as the app's own
-- role, so it was never misowned. Guarded so it does nothing where the role
-- (and therefore the bug) does not exist, and still fixes the real problem
-- on the one database that has it.

BEGIN;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'johnathonwright') THEN
    ALTER TABLE feature_notes OWNER TO johnathonwright;
    ALTER SEQUENCE feature_notes_id_seq OWNER TO johnathonwright;
  END IF;
END $$;

INSERT INTO schema_migrations (filename) VALUES ('073_fix_feature_notes_ownership.sql');

COMMIT;
