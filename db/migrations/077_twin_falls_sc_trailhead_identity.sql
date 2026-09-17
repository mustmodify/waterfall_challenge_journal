-- Twin Falls (SC) still showed 'disputed' after 076 fixed the wrong
-- hikingwnc claim. The remaining spread was migration 034's own
-- google-maps|406|trailhead group: its 'coordinate' claim is the trailhead,
-- explicitly "kept as parking, not as the falls" per 034's comment, and is
-- unaccepted for exactly that reason -- but identity_certain is
-- group-level, so coordinate_confidence still counted a parking point as a
-- competing reading of where the waterfall is.
--
-- Fixing only this group, not google-maps|406|falls (the real accepted
-- falls coordinate, which is fine and stays as-is).

BEGIN;

UPDATE claim_groups SET identity_certain = false
WHERE feature_id = 406 AND ref = 'google-maps|406|trailhead';

INSERT INTO schema_migrations (filename) VALUES ('077_twin_falls_sc_trailhead_identity.sql');

COMMIT;
