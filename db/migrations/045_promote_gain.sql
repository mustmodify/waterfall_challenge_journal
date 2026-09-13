-- Take dwhike's vertical gain, where he walked to exactly one fall we carry.
--
-- His gain is for his route, which is not always the shortest way in, so this
-- is accepted only where a single gallery is attached to the feature. Where two
-- routes reach the same waterfall the claims stay on the table unaccepted, and
-- the fall keeps no rating rather than an arbitrary one.
--
-- petzoldt is generated from gain and distance, so it appears on its own.

BEGIN;

CREATE TEMP TABLE only_gain ON COMMIT DROP AS
SELECT c.feature_id, min(c.id) AS claim_id, (min(c.value#>>'{}'))::int AS gain
FROM claims c
JOIN claim_groups cg ON cg.id = c.group_id
WHERE c.field = 'elevation_gain_ft' AND cg.identity_certain
GROUP BY c.feature_id
HAVING count(DISTINCT c.value) = 1;

UPDATE features f SET elevation_gain_ft = g.gain FROM only_gain g WHERE f.id = g.feature_id;

UPDATE claims SET accepted = true WHERE id IN (SELECT claim_id FROM only_gain);

COMMIT;
