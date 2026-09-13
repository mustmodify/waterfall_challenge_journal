-- Where a note came from, and two editorial notes from the CMC WC100 form.
--
-- notes currently holds four rows, all transcribed from the "my notes" column
-- of seed.csv -- i.e. the account owner's own. There is no user_id and no
-- provenance, so anything added from a published source would be
-- indistinguishable from something the owner wrote. `source` fixes that
-- cheaply: NULL keeps meaning "the owner's own note".

BEGIN;

ALTER TABLE notes ADD COLUMN source varchar(30);

COMMENT ON COLUMN notes.source IS
    'Where the note came from. NULL = written by the account owner.';

-- Both notes are truncated as published on the CMC form; recorded as found.
INSERT INTO notes (feature_id, text, source)
SELECT id,
       'CMC WC100 form (rev. 18 Feb 2024): "Skinny Dip Falls was severely '
       || 'damaged during Tropical Storm Fred, Aug 11-17, 2021." Still listed '
       || 'on the Kevin Adams 500 and 100, so it remains a destination here '
       || 'even though the falls may no longer be what the listing describes.',
       'cmc'
FROM features WHERE name = 'Skinny Dip Falls';

INSERT INTO notes (feature_id, text, source)
SELECT id,
       'CMC WC100 form (rev. 18 Feb 2024): removed from the WC100. "The '
       || 'waterfall is pretty but hardly worth the effort of the off trail '
       || 'descent."',
       'cmc'
FROM features WHERE name = 'Enloe Creek Falls';

COMMIT;
