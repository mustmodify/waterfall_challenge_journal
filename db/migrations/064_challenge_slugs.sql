-- Add URL-safe slugs to challenges so each gets a browseable page at
-- /challenges/<slug>.

BEGIN;

ALTER TABLE challenges ADD COLUMN slug text;
ALTER TABLE challenges ADD CONSTRAINT challenges_slug_key UNIQUE (slug);

UPDATE challenges SET slug = 'wc100'    WHERE name = 'WC100';
UPDATE challenges SET slug = 'ltc'      WHERE name = 'LTC';
UPDATE challenges SET slug = 'adams100' WHERE name = 'ADAMS100';
UPDATE challenges SET slug = 'adams500' WHERE name = 'ADAMS500';

ALTER TABLE challenges ALTER COLUMN slug SET NOT NULL;

INSERT INTO schema_migrations (filename) VALUES ('064_challenge_slugs.sql');

COMMIT;
