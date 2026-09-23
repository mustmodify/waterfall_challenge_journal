-- Explain the OpenStreetMap height conversion instead of just citing the tag.
--
-- The note read "OpenStreetMap tag height=10." beside an observed value of
-- 33, which looks like a contradiction and is really a unit conversion with
-- the middle step missing. OSM's height key is metres unless the value says
-- otherwise, so 10 m became 32.8 ft and was rounded to 33.
--
-- This is the same shape as the ncwaterfalls distance note 120 fixed: the
-- importer recorded what it read but not what it did, so anyone reading the
-- row has to reconstruct the arithmetic before they can judge it.
--
-- Three of these are probably wrong, and they get told so. Where OSM and
-- another source both give a height, the metres reading is closer in 29 of 33
-- cases -- so the convention holds and the importer is right to apply it --
-- but in three the raw number matches the other source almost exactly, which
-- is what you would see if the mapper typed feet:
--
--   Wildcat Falls (Flat Laurel Creek)  tag 60  ->  197 ft   others say 60
--   Upper Creek Falls                  tag 30  ->   98 ft   others say 31
--   Windy Falls                        tag 60  ->  197 ft   others say 70
--
-- None of the three is accepted, so nothing wrong is published. They stay as
-- claims with the doubt recorded rather than being quietly corrected, because
-- the correction belongs in a jw or wanderfall claim that wins arbitration,
-- not in an edit to what a source said.

BEGIN;

UPDATE claims c
SET note = 'OpenStreetMap''s height tag is metres unless it says otherwise, so '
        || 'this page''s height='
        || substring(c.note from 'height=([0-9]+(?:\.[0-9]+)?)')
        || ' is ' || (c.value #>> '{}') || ' feet.'
FROM claim_groups cg
WHERE cg.id = c.group_id
  AND cg.source = 'openstreetmap'
  AND c.field = 'height_ft'
  AND substring(c.note from 'height=([0-9]+(?:\.[0-9]+)?)') IS NOT NULL;

-- The three where the raw number, not the conversion, matches everyone else.
UPDATE claims c
SET note = c.note || ' Treat this one with suspicion: the untouched tag value '
        || 'matches what other sources say in feet, which is what a mapper '
        || 'entering feet rather than metres would leave behind.'
FROM claim_groups cg, features f
WHERE cg.id = c.group_id AND f.id = c.feature_id
  AND cg.source = 'openstreetmap'
  AND c.field = 'height_ft'
  AND f.name IN ('Wildcat Falls (Flat Laurel Creek)', 'Upper Creek Falls', 'Windy Falls');

INSERT INTO schema_migrations (filename) VALUES ('121_osm_height_note_explains_conversion.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
