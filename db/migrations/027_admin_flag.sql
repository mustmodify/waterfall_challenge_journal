-- Someone has to be able to work the corrections queue.
--
-- There is no notion of privilege in the app at all: every signed-in user can
-- do exactly the same things. Reading other people's reports, marking them
-- accepted and deleting them is the first thing that genuinely should not be
-- open to everyone, so this is the smallest flag that expresses it.
--
-- Not a role system. If a second kind of privilege ever appears, replace it.

BEGIN;

ALTER TABLE users ADD COLUMN is_admin boolean NOT NULL DEFAULT false;

UPDATE users SET is_admin = true WHERE email = 'jw@mustmodify.com';

COMMIT;
