-- Daily view counts per waterfall.
--
-- The client POSTs to /features/:id/view when the drawer opens, whether the
-- visitor arrived via the map, a direct link, or a search result. The server
-- upserts into this table so the count is independent of GA4.
--
-- view_count is the number of drawer opens on that calendar day.
-- There is no user identity here: this counts events, not visitors.

BEGIN;

CREATE TABLE feature_views (
    feature_id  integer NOT NULL REFERENCES features(id),
    date        date    NOT NULL DEFAULT CURRENT_DATE,
    view_count  integer NOT NULL DEFAULT 1,
    PRIMARY KEY (feature_id, date)
);

COMMENT ON TABLE feature_views IS
    'Daily drawer-open counts per waterfall, incremented by POST /features/:id/view. '
    'Counts events; does not identify visitors.';

INSERT INTO schema_migrations (filename) VALUES ('062_feature_views.sql');

COMMIT;
