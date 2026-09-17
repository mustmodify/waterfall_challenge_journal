-- jw asked for a safety caution on Midnight Hole (feature 839): cold-water
-- shock plus the hydraulics under the falls have put people in real danger,
-- with at least one reported death, though it's popular enough that this
-- isn't a reason to single it out as unusually dangerous -- just to know
-- before you jump.

BEGIN;

INSERT INTO feature_notes (feature_id, severity, text, source, observed_on)
VALUES (
  839,
  'urgent',
  'The physiological shock from extremely cold water coupled with the ' ||
  'underwater hydraulics below the falls can be hazardous. There are ' ||
  'several reports of dangerous situations and at least one reported ' ||
  'death. Given the popularity of the site, it isn''t unusually ' ||
  'dangerous -- people get hurt at all sorts of places -- but be aware.',
  'jw',
  CURRENT_DATE
);

INSERT INTO schema_migrations (filename) VALUES ('086_midnight_hole_caution.sql');

COMMIT;
