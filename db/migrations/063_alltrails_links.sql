-- Copy AllTrails trail URLs from claim_groups into the links table.
--
-- Every claim_group with source = 'alltrails' and identity_certain = true
-- carries the URL of the AllTrails trail page that was matched to a feature.
-- We want one canonical AllTrails link per feature -- the one whose claim
-- group was matched with confidence. Where a feature has more than one
-- identity_certain AllTrails match (multiple routes reach the same falls),
-- we take the one whose group has the most-accepted claims, breaking ties
-- by group id.
--
-- rel = 'alltrails' so the client can render it with an AllTrails icon.

BEGIN;

INSERT INTO links (feature_id, url, rel)
SELECT DISTINCT ON (cg.feature_id)
    cg.feature_id,
    cg.url,
    'alltrails'
FROM claim_groups cg
WHERE cg.source = 'alltrails'
  AND cg.identity_certain = true
  AND cg.url IS NOT NULL
ORDER BY
    cg.feature_id,
    (SELECT count(*) FROM claims c WHERE c.group_id = cg.id AND c.accepted = true) DESC,
    cg.id
ON CONFLICT (feature_id, url) DO NOTHING;

INSERT INTO schema_migrations (filename) VALUES ('063_alltrails_links.sql');

COMMIT;
