-- A stable address for every feature and area.
--
-- Derived from the name once and then stored, never recomputed. A slug that
-- moves costs whatever ranking it had earned, so renaming a waterfall must not
-- silently rehome its page; the column is the record, and a rename is a
-- deliberate second act.
--
-- Names collide here -- three Twin Falls, four Rainbow Falls -- so duplicates
-- take a numeric suffix in id order, which is deterministic and does not
-- reshuffle when a later fall is added.

BEGIN;

ALTER TABLE features ADD COLUMN IF NOT EXISTS slug text;
ALTER TABLE areas    ADD COLUMN IF NOT EXISTS slug text;

-- No unaccent extension on a hosted database without superuser, and the names
-- here are ASCII apart from a stray curly apostrophe, so this is a stand-in
-- rather than a transliterator.
CREATE OR REPLACE FUNCTION unaccent_fallback(name text) RETURNS text AS $$
    SELECT translate(name, E'’‘“”', '''''""');
$$ LANGUAGE sql IMMUTABLE;

CREATE OR REPLACE FUNCTION slugify(name text) RETURNS text AS $$
    SELECT trim(both '-' from
           regexp_replace(
           regexp_replace(
           regexp_replace(lower(unaccent_fallback(name)),
             '&', ' and ', 'g'),
             '[^a-z0-9]+', '-', 'g'),
             '-{2,}', '-', 'g'));
$$ LANGUAGE sql IMMUTABLE;

UPDATE features f SET slug = s.slug
FROM (
    SELECT id,
           CASE WHEN n = 1 THEN base ELSE base || '-' || n END AS slug
    FROM (
        SELECT id, slugify(name) AS base,
               row_number() OVER (PARTITION BY slugify(name) ORDER BY id) AS n
        FROM features
    ) numbered
) s
WHERE f.id = s.id;

UPDATE areas a SET slug = s.slug
FROM (
    SELECT id,
           CASE WHEN n = 1 THEN base ELSE base || '-' || n END AS slug
    FROM (
        SELECT id, slugify(name) AS base,
               row_number() OVER (PARTITION BY slugify(name) ORDER BY id) AS n
        FROM areas
    ) numbered
) s
WHERE a.id = s.id;

ALTER TABLE features ALTER COLUMN slug SET NOT NULL;
ALTER TABLE areas    ALTER COLUMN slug SET NOT NULL;
CREATE UNIQUE INDEX features_slug_key ON features (slug);
CREATE UNIQUE INDEX areas_slug_key    ON areas (slug);

COMMIT;
