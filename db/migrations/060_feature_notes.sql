-- A place to record things worth knowing before you visit a waterfall:
-- closures, fees, permit requirements, hazards, seasonal conditions.
--
-- severity values, in ascending urgency:
--   info        nice to know but does not limit access
--   fee         entry costs money or requires a pass
--   restricted  partial closure, limited hours, or permit required
--   urgent      safety hazard; proceed only if you know what you are doing
--   closed      inaccessible; do not attempt
--
-- source is freeform but should name the origin so the note can be
-- re-checked: 'alltrails', 'hikingwnc', 'ranger station', etc.
--
-- observed_on is when we saw this condition. It is not an expiry date;
-- the application should surface the note and let visitors judge
-- whether it is still current. A NULL means we found it in a cache
-- and do not know when it was written.
--
-- A feature can have many notes. The same condition from two different
-- sources is two rows, not one update; that way the source provenance
-- is visible and duplicate detection is the reader's call.

BEGIN;

CREATE TABLE feature_notes (
    id          serial PRIMARY KEY,
    feature_id  integer NOT NULL REFERENCES features(id),
    severity    text NOT NULL CHECK (severity IN ('info','fee','restricted','urgent','closed')),
    text        text NOT NULL,
    source      text NOT NULL,
    observed_on date,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX feature_notes_feature_id ON feature_notes(feature_id);

COMMENT ON TABLE feature_notes IS
    'Conditions worth knowing before visiting: closures, fees, hazards, seasonal notes. '
    'severity is one of closed/urgent/restricted/fee/info. observed_on is when the condition '
    'was seen, not an expiry; surface the note and let the visitor judge currency.';

INSERT INTO schema_migrations (filename) VALUES ('060_feature_notes.sql');

COMMIT;
