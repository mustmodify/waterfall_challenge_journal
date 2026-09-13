-- Adams links recovered through the hikingwnc catalogue.
--
-- Exact match on the name with punctuation and spacing removed (Adams writes
-- "High Falls (Little River)", hikingwnc writes "High Falls- Little River"),
-- plus a narrow fuzzy pass for spelling drift (Tuckasegee/Tuskasegee).
--
-- The fuzzy pass refuses a match whose Upper/Lower/Middle qualifiers disagree,
-- or whose base name occurs more than once in the Adams list. Without those
-- guards it paired "Lower Falls" with "Tower Falls" at 0.90.

BEGIN;

INSERT INTO goals (challenge_id, feature_id)
SELECT (SELECT id FROM challenges WHERE name = 'ADAMS500'), f.id
FROM features f WHERE f.id IN (326,334,362,384,392,431,433,757,774)
ON CONFLICT (challenge_id, feature_id) DO NOTHING;

INSERT INTO goals (challenge_id, feature_id)
SELECT (SELECT id FROM challenges WHERE name = 'ADAMS100'), f.id
FROM features f WHERE f.id IN (326,334,362,384,431,433,487,488,860)
ON CONFLICT (challenge_id, feature_id) DO NOTHING;

COMMIT;
