-- The facts table: one row per (feature, key) holding what we currently
-- think, with how confident we are of it. See ARCHITECTURE.md.
--
-- facts is a cache. Everything in it is derived from claims and can be
-- rebuilt from them; nothing originates here. Review work does not land in
-- this table, it lands in claims as its own source, which is what keeps a
-- rebuild lossless.
--
-- Two measures ride along with each value. confidence_stage names how we got
-- here and confidence_score is that stage as a number, on jw's GPA-shaped
-- scale: disputed 1.0, single_source 1.7, disambiguated 2.3, corroborated
-- 3.0, ai_reviewed 3.3, human_reviewed 3.7, confirmed_irl 4.0. Stage usually
-- rises as evidence accumulates, but it can fall -- discovering that two
-- sources corroborated the wrong waterfall is exactly how.
--
-- value is text rather than jsonb, with value_type saying how to read it and
-- units saying what it is in. Structure lives in sibling columns instead of
-- inside a blob so the table stays legible in psql, which matters for a
-- table whose whole purpose is supporting review by eye.
--
-- text + CHECK rather than CREATE TYPE, matching claims.field,
-- feature_notes.severity and features.deprecated_reason. Adding a value to a
-- Postgres enum cannot happen in the same transaction that uses it, and
-- removing one is not possible at all, which fights this project's habit of
-- wrapping every migration in BEGIN/COMMIT.

BEGIN;

CREATE TABLE facts (
    id               serial PRIMARY KEY,
    feature_id       integer NOT NULL REFERENCES features(id) ON DELETE CASCADE,
    key              text NOT NULL,
    value            text,
    value_type       text NOT NULL DEFAULT 'string',
    units            text,
    confidence_stage text NOT NULL DEFAULT 'single_source',
    confidence_score numeric(2,1),
    notes            text,
    created_at       timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at       timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,

    CONSTRAINT facts_value_type_known CHECK (
        value_type IN ('string', 'integer', 'decimal', 'coordinate')),

    CONSTRAINT facts_stage_known CHECK (
        confidence_stage IN ('disputed', 'single_source', 'disambiguated',
                             'corroborated', 'ai_reviewed', 'human_reviewed',
                             'confirmed_irl')),

    CONSTRAINT facts_score_range CHECK (
        confidence_score IS NULL OR (confidence_score >= 0 AND confidence_score <= 4.3)),

    -- Latitude always comes first, matching locations(latitude, longitude),
    -- claims' {"lat","lon"}, L.marker([lat,lon]) and every source page we
    -- read. Rather than trusting that, check it: everything we carry is in
    -- western North Carolina or upstate South Carolina, so a swapped pair
    -- lands far outside these bands and fails at write time instead of
    -- quietly plotting a waterfall in the Indian Ocean.
    CONSTRAINT facts_coordinate_lat_first CHECK (
        value_type <> 'coordinate' OR value IS NULL OR (
            split_part(value, ',', 1)::numeric BETWEEN 30 AND 40
        AND split_part(value, ',', 2)::numeric BETWEEN -90 AND -75))
);

-- key is not unique per feature: aka is deliberately multi-valued.
CREATE INDEX facts_feature_key ON facts (feature_id, key);

CREATE TRIGGER touch_updated_at BEFORE UPDATE ON facts
    FOR EACH ROW EXECUTE FUNCTION touch_updated_at();

COMMENT ON TABLE facts IS
    'What we currently think about each feature, derived from claims. A cache: '
    'rebuildable from claims at any time. Review work belongs in claims, not here.';

-- ON DELETE SET NULL, not CASCADE: claims are the raw record and must outlive
-- any fact built from them.
ALTER TABLE claims ADD COLUMN fact_id integer REFERENCES facts(id) ON DELETE SET NULL;

-- Same ownership guard as migrations 073 and 083. Applied by hand with psql
-- this table would belong to the OS user rather than the app role, which is
-- the bug those two exist to fix. The role name is local-only, so the guard
-- keeps this a no-op on Render.
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'johnathonwright') THEN
    ALTER TABLE facts OWNER TO johnathonwright;
    ALTER SEQUENCE facts_id_seq OWNER TO johnathonwright;
  END IF;
END $$;

INSERT INTO schema_migrations (filename) VALUES ('095_facts_table.sql');

COMMIT;
