-- Passwordless sign-in.
--
-- A waterfall journal does not warrant a password. The worst case if someone
-- reads your account is that they learn which waterfalls you have been to --
-- while the password itself is a real liability, because people reuse them and
-- a leak here would hurt them somewhere that matters.
--
-- Only a hash of the token is stored. The token is 32 random bytes, so a plain
-- SHA-256 is enough -- there is nothing to brute force and no need for bcrypt's
-- work factor. A dump of this table cannot be used to sign in as anyone.

BEGIN;

CREATE TABLE magic_links (
    id         serial PRIMARY KEY,
    user_id    integer NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash text NOT NULL UNIQUE,
    expires_at timestamp NOT NULL,
    used_at    timestamp,
    created_at timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX magic_links_user_idx ON magic_links (user_id, created_at DESC);

-- Sign-in no longer sets one; existing rows keep whatever they have so nobody
-- is locked out mid-migration.
ALTER TABLE users ALTER COLUMN password_digest DROP NOT NULL;

COMMIT;
