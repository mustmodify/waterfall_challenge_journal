-- Confusion sets: a named cluster of genuinely different, correctly-named
-- waterfalls that share a confusing family resemblance, with a journal of
-- what we have concluded about them over time.
--
-- This is not the same problem as one place with a wrong name attached --
-- that is a note on the feature. "Falls Named Tom" is four unrelated
-- waterfalls in four parts of the state, all correctly named, and the useful
-- thing to show someone landing on any of them is the same shared write-up.
-- A narrative duplicated across four features would drift the moment one was
-- edited, which is the same reason claims are never merged into one row.
--
-- The journal is the point. We have already been wrong about this cluster
-- once -- migration 068 created a duplicate Toms Creek Falls, 087 merged it
-- back, and 093 moved a WC100 goal off the wrong feature -- so being able to
-- read what we used to think, and when it changed, is worth more here than a
-- single field holding today's answer.

BEGIN;

CREATE TABLE confusion_sets (
    id         serial PRIMARY KEY,
    name       text NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);

COMMENT ON TABLE confusion_sets IS
    'A named cluster of similarly-named but distinct features. Names are written '
    'by hand -- a generated "Falls Named {x}" default was considered and dropped, '
    'since most collisions here are descriptive words (Big, High, Rainbow) where '
    'it reads badly.';

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON confusion_sets
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

CREATE TABLE confusion_set_members (
    confusion_set_id integer NOT NULL REFERENCES confusion_sets(id) ON DELETE CASCADE,
    feature_id       integer NOT NULL REFERENCES features(id) ON DELETE CASCADE,
    PRIMARY KEY (confusion_set_id, feature_id)
);

-- The hot lookup is "what sets is this feature in", asked from a feature page.
CREATE INDEX confusion_set_members_feature ON confusion_set_members (feature_id);

-- Deliberately no updated_at: an entry is never edited, so a column claiming
-- otherwise would be a lie.
CREATE TABLE confusion_set_entries (
    id               serial PRIMARY KEY,
    confusion_set_id integer NOT NULL REFERENCES confusion_sets(id) ON DELETE CASCADE,
    body             text NOT NULL,
    author           text NOT NULL,
    created_at       timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);

CREATE INDEX confusion_set_entries_set ON confusion_set_entries (confusion_set_id, created_at DESC);

COMMENT ON TABLE confusion_set_entries IS
    'Append-only journal. A changed conclusion is a new entry, never an edit. '
    'author may be jw only when the words are his verbatim; anything an agent '
    'composed or paraphrased is authored by the agent, even when the thinking '
    'came from jw.';

-- Enforced rather than trusted. Convention erodes, and this is the one table
-- where losing history defeats the entire purpose of having it.
CREATE FUNCTION confusion_set_entries_are_append_only() RETURNS trigger
    LANGUAGE plpgsql AS $$
BEGIN
    RAISE EXCEPTION
        'confusion_set_entries is append-only: add a new entry correcting the old one';
END;
$$;

CREATE TRIGGER append_only BEFORE UPDATE OR DELETE ON confusion_set_entries
    FOR EACH ROW EXECUTE FUNCTION confusion_set_entries_are_append_only();

-- Same ownership guard as 073, 083 and 095: applied by hand with psql these
-- would belong to the OS user rather than the app role. No-op on Render,
-- where that role does not exist.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'johnathonwright') THEN
    ALTER TABLE confusion_sets OWNER TO johnathonwright;
    ALTER SEQUENCE confusion_sets_id_seq OWNER TO johnathonwright;
    ALTER TABLE confusion_set_members OWNER TO johnathonwright;
    ALTER TABLE confusion_set_entries OWNER TO johnathonwright;
    ALTER SEQUENCE confusion_set_entries_id_seq OWNER TO johnathonwright;
    ALTER FUNCTION confusion_set_entries_are_append_only() OWNER TO johnathonwright;
  END IF;
END $$;

INSERT INTO schema_migrations (filename) VALUES ('099_confusion_sets.sql');

COMMIT;
