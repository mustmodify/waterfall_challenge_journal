-- 099's append-only trigger was too absolute: it blocked the cascade too, so
-- a confusion set created by mistake could never be deleted -- its entries
-- refused to go, and the parent could not go without them.
--
-- The thing worth preventing is rewriting history: silently editing an entry,
-- or deleting one out of a set that still exists, so the record reads as if
-- we always thought today's answer. Removing an entire set is a different and
-- visible act.
--
-- So: UPDATE is always refused. DELETE is refused while the parent set still
-- exists, and allowed when it does not -- which is exactly the cascade case,
-- because Postgres deletes the parent row before cascading to children, so
-- by the time this fires on a cascade the set is already gone.

BEGIN;

CREATE OR REPLACE FUNCTION confusion_set_entries_are_append_only() RETURNS trigger
    LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE'
       AND NOT EXISTS (SELECT 1 FROM confusion_sets WHERE id = OLD.confusion_set_id) THEN
        -- The set itself is being removed; the journal goes with it.
        RETURN OLD;
    END IF;
    RAISE EXCEPTION
        'confusion_set_entries is append-only: add a new entry correcting the old one';
END;
$$;

INSERT INTO schema_migrations (filename) VALUES ('100_confusion_entries_allow_cascade.sql');

COMMIT;
