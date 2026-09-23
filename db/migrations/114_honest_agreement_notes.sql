-- "1 of 3 sources agree" is not a sentence about agreement.
--
-- The backfills count agreement with a self-join, and a row always matches
-- itself, so the count includes the reading being described. Three sources
-- that all contradict each other therefore produce "1 of 3 sources agree"
-- for each of them, which reads like weak agreement and is actually none.
-- Worse is "1 of 1 sources agree", which is a single source agreeing with
-- itself, printed 2,808 times.
--
-- The stages were right throughout -- those rows are correctly disputed and
-- single_source -- so this is a wording bug, not an arbitration one. But the
-- note is the part a person reads before deciding, and a note that overstates
-- agreement is worse than no note.
--
--   1 of 1  ->  only one source has a value
--   1 of N  ->  N sources, no two agree
--   X of N  ->  unchanged; that one was always true
--
-- agreement_note() is here so the next backfill stops reinventing the
-- sentence. The five already-applied backfills keep their literals, since
-- they are applied history; re-running one reintroduces the old wording,
-- and re-running this fixes it again.

BEGIN;

CREATE OR REPLACE FUNCTION agreement_note(agreeing int, n int, tolerance text)
    RETURNS text LANGUAGE sql IMMUTABLE AS $$
    SELECT CASE
      WHEN n <= 1 THEN
        'Only one source has a value, so there is nothing to compare it with.'
      WHEN agreeing <= 1 THEN
        'No two of the ' || n || ' sources agree ' || tolerance || '.'
      ELSE
        agreeing || ' of ' || n || ' sources agree ' || tolerance || '.'
    END;
$$;

COMMENT ON FUNCTION agreement_note(int, int, text) IS
    'The sentence under a fact''s grade. Counts come from a self-join that '
    'includes the row itself, so an agreeing count of 1 means nothing agreed '
    'and must not be printed as though something did.';

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'johnathonwright') THEN
    ALTER FUNCTION agreement_note(int, int, text) OWNER TO johnathonwright;
  END IF;
END $$;

-- Rewrite what is already stored. The counts and the tolerance clause are
-- both recoverable from the existing text, so this needs no re-arbitration.
UPDATE facts
SET notes = agreement_note(
      (regexp_match(notes, '^([0-9]+) of ([0-9]+) sources agree (.*)$'))[1]::int,
      (regexp_match(notes, '^([0-9]+) of ([0-9]+) sources agree (.*)$'))[2]::int,
      rtrim((regexp_match(notes, '^([0-9]+) of ([0-9]+) sources agree (.*)$'))[3], '.')
    )
WHERE notes ~ '^[0-9]+ of [0-9]+ sources agree ';

INSERT INTO schema_migrations (filename) VALUES ('114_honest_agreement_notes.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
