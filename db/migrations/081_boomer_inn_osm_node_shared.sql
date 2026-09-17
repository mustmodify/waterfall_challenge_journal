-- The Boomer Inn Falls cluster (2nd/3rd/4th Floor, plus siblings not
-- affected here) has only one OpenStreetMap node for "Boomer Inn Falls" in
-- general, but it was attached as an identity-certain coordinate claim to
-- three different floor-specific features at once (35.3735549,
-- -82.9638051): 163 m from 3rd Floor's hikingwnc point, 276 m from 2nd
-- Floor's, 538 m from 4th Floor's (already flagged in migration 079). One
-- point cannot corroborate three different specific places simultaneously
-- -- it is closest to 3rd Floor, but not confidently so, and OSM's own tag
-- doesn't distinguish floors at all. Flagged on all three rather than
-- picked for one, since picking would just relocate the same uncertainty.

BEGIN;

UPDATE claim_groups
SET identity_certain = false,
    note = coalesce(note || ' ', '') ||
           'Re-arbitrated 2026-09-17: this is OSM''s one generic "Boomer Inn Falls" node, also ' ||
           'attached to the 3rd and 4th Floor features -- it cannot confirm which specific floor ' ||
           'it describes, so it is left uncertain on all three rather than picked for one.'
WHERE feature_id IN (1137, 1138) AND source = 'openstreetmap';

INSERT INTO schema_migrations (filename) VALUES ('081_boomer_inn_osm_node_shared.sql');

COMMIT;
