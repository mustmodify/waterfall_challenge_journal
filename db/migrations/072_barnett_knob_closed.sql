-- jw checked Google Maps for Barnett Knob (fire tower) while working through
-- the unsourced-tier towers: it's listed "Permanently Closed."
--
-- Recorded as a feature_note rather than deprecating the feature outright --
-- the closure as far as we know applies to the tower structure itself, not
-- necessarily the knob or the hike to it, and deprecated_reason means "the
-- place is gone, unreachable or unsafe" (ARCHITECTURE.md), a stronger claim
-- than what's confirmed here.

BEGIN;

INSERT INTO feature_notes (feature_id, severity, text, source, observed_on)
SELECT id, 'closed', 'Google Maps lists this as "Permanently Closed."', 'google-maps', CURRENT_DATE
FROM features WHERE name = 'Barnett Knob';

INSERT INTO schema_migrations (filename) VALUES ('072_barnett_knob_closed.sql');

COMMIT;
