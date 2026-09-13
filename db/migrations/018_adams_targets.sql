-- Adams challenges require the whole list.
--
-- From the official log (kadamsphoto.com, Kevin-Adams-Waterfalls-Challenges.pdf):
--
--   "If a waterfall is not accessible to the public when you've checked off all
--    other falls, you may substitute any other falls from another list, or
--    choose one of these alternates."
--
-- So the target is the list length, not a subset: 100 and 500. Ours currently
-- hold 94 and 471 goals because that is as far as name matching got, not
-- because the lists are shorter. Setting the target to the true length means
-- the bar cannot reach the end until those links are resolved -- which is the
-- honest failure. Targeting our own match count would hand out a badge for
-- finishing the subset we happened to map.
--
-- Contrast with the CMC WC100, which genuinely asks for any 100 of 115.

BEGIN;

UPDATE challenges SET target = 100 WHERE name = 'ADAMS100';
UPDATE challenges SET target = 500 WHERE name = 'ADAMS500';

COMMIT;
