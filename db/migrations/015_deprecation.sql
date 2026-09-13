-- Why a fall is no longer worth routing someone to.
--
-- Distinct from features.owner. owner = 'Private' describes who holds the land
-- and often just means a fee -- Pearsons Falls is private, charges $5, and is
-- one of the better stops on the WC100. Deprecation means the destination
-- itself is gone, unreachable, or unsafe.
--
-- Also distinct from challenge membership. Enloe Creek Falls was dropped from
-- the WC100 because CMC judged it "hardly worth the effort of the off trail
-- descent" -- the fall still exists and is still reachable, so it is NOT
-- deprecated here. Delisting is modelled by the absence of a goals row.
--
-- NULL reason means nothing is wrong with it.

BEGIN;

ALTER TABLE features
    ADD COLUMN deprecated_reason varchar(24),
    ADD COLUMN deprecated_note   text,
    ADD COLUMN deprecated_on     date;

ALTER TABLE features ADD CONSTRAINT features_deprecated_reason_check
    CHECK (deprecated_reason IS NULL OR deprecated_reason IN (
        'destroyed',         -- the waterfall itself is gone or unrecognisable
        'damaged',           -- still there, materially changed
        'private_property',  -- access withdrawn by the landowner
        'access_closed',     -- trail/road closed, permanently or indefinitely
        'hazard'             -- reachable, but people get hurt doing it
    ));

-- a note explaining it only makes sense if there is a reason
ALTER TABLE features ADD CONSTRAINT features_deprecated_note_check
    CHECK (deprecated_note IS NULL OR deprecated_reason IS NOT NULL);

CREATE INDEX features_deprecated_idx ON features (deprecated_reason)
    WHERE deprecated_reason IS NOT NULL;

UPDATE features
SET deprecated_reason = 'damaged',
    deprecated_on     = DATE '2021-08-11',
    deprecated_note   = 'Severely damaged during Tropical Storm Fred, '
                     || 'Aug 11-17 2021 (CMC WC100 form, rev. 18 Feb 2024). '
                     || 'Reported still present, but no longer the feature it '
                     || 'was -- worth setting expectations rather than skipping. '
                     || 'Still listed on the Kevin Adams 500 and 100.'
WHERE name = 'Skinny Dip Falls';

COMMIT;
