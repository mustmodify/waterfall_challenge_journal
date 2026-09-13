-- Adams challenge links resolved through hikingwnc URLs.
--
-- 008 matched Adams listing names against feature names. These are the ones
-- that pass could not settle, recovered a different way: the Adams name is
-- looked up in the hikingwnc source data, and that record's url is matched
-- against links.url, which already maps every imported fall to its page.
-- Exact, no fuzzy scoring -- it goes through the identifier both sides share.

BEGIN;

INSERT INTO goals (challenge_id, feature_id)
SELECT (SELECT id FROM challenges WHERE name = 'ADAMS500'), f.id
FROM features f WHERE f.id IN (334,354,384,392,433,774)
ON CONFLICT (challenge_id, feature_id) DO NOTHING;

INSERT INTO goals (challenge_id, feature_id)
SELECT (SELECT id FROM challenges WHERE name = 'ADAMS100'), f.id
FROM features f WHERE f.id IN (334,433)
ON CONFLICT (challenge_id, feature_id) DO NOTHING;

COMMIT;
