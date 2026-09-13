-- Six imported names end in an asterisk, a hikingwnc footnote marker whose
-- footnote we never imported. It points at nothing here.

BEGIN;

UPDATE features
SET name = rtrim(name, '*')
WHERE name LIKE '%*';

COMMIT;
