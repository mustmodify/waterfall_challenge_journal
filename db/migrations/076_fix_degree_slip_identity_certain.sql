-- Six features carry the "one degree east" hikingwnc typo migration 034
-- diagnosed and corrected (471, 508, 509, 856, 1112, 1199) plus one more
-- with a differently-wrong hikingwnc coordinate (406, Twin Falls (SC)).
-- Each already has an accepted correction claim (wanderfall or google-maps)
-- sitting right next to the wrong one. But 034 only ever added the
-- correction; it never flipped the original bad claim's identity_certain,
-- so coordinate_confidence still counted the wrong point as a valid
-- independent reading and reported these as 'disputed' at ~90,000 m apart
-- ever since -- the exact bug this session found and fixed for Mooney
-- Falls (075), recurring at six times the scale.
--
-- jw asked whether hikingwnc's own page text clarified anything further
-- here, the way it did for Mooney Falls. It doesn't need to: a coordinate
-- landing exactly 1.00000 degrees off a name-sibling to four decimal places
-- (034's finding) is arithmetic, not an identity question:
--
--   471, 508, 509, 856, 1112, 1199: hikingwnc's claim
--   406 (Twin Falls, SC): also hikingwnc's claim, wrong a different way
--   (35.4666, -83.4352 vs the accepted 35.0137, -82.8187 -- not a clean
--   degree slip, just wrong)
--
-- Same treatment as Mooney Falls: identity_certain = false on the group,
-- leaving its other accepted claims (name, ratings, height, etc.) untouched.

BEGIN;

UPDATE claim_groups
SET identity_certain = false,
    note = coalesce(note || ' ', '') ||
           'Re-arbitrated 2026-09-17: coordinate claim is wrong (see the accepted correction ' ||
           'claim on this feature) and was still counting toward coordinate_confidence as an ' ||
           'independent reading. identity_certain set false so it stops contaminating corroboration; ' ||
           'this group''s other accepted claims are unaffected.'
WHERE feature_id IN (856, 471, 1199, 1112, 508, 509, 406)
  AND source = 'hikingwnc';

INSERT INTO schema_migrations (filename) VALUES ('076_fix_degree_slip_identity_certain.sql');

COMMIT;
