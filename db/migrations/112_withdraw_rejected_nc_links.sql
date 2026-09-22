-- Two links survived their own rejection.
--
-- On 2026-09-17 both of these ncwaterfalls matches were re-arbitrated as
-- describing a different waterfall, and the right waterfall was split out
-- into its own feature. The claim groups were marked uncertain, the new
-- features got the pages, and the original links were never withdrawn -- so
-- the site has been sending people from one waterfall to Kevin's page about
-- another one several kilometres away:
--
--   Highlands Falls     -> highlands-falls      4865 m  (a private fall
--                          inside Highlands Falls Country Club; ours is the
--                          roadside one hikingwnc calls Satulah Falls)
--   Climbing Wall Falls -> climbing-wall-falls   3842 m  (a Class III
--                          bushwhack off Looking Glass Creek; ours is
--                          roadside)
--
-- Features 1270 and 1271 already carry these pages, so nothing is lost.
--
-- Deliberately narrow. Eleven other live links sit on uncertain groups and
-- are left alone, because identity_certain is currently carrying two
-- different meanings. The seven hikingwnc ones say "coordinate claim is
-- wrong (see the accepted correction claim)" -- the page is about our
-- waterfall, only its GPS is bad, and the flag was used to keep that bad
-- coordinate out of coordinate_confidence. Dropping those links would throw
-- away good pages. The four OSM ones are a generic node shared by several
-- features, which is ambiguous rather than wrong. Both groups are worth
-- revisiting, but not by a rule that cannot tell "wrong waterfall" from
-- "right waterfall, wrong pin".

BEGIN;

DELETE FROM links l
USING claim_groups cg
WHERE cg.feature_id = l.feature_id
  AND rtrim(cg.url, '/') = rtrim(l.url, '/')
  AND cg.source = 'ncwaterfalls'
  AND NOT cg.identity_certain
  AND NOT EXISTS (
    SELECT 1 FROM claim_groups ok
    WHERE ok.feature_id = l.feature_id
      AND rtrim(ok.url, '/') = rtrim(l.url, '/')
      AND ok.identity_certain
  );

INSERT INTO schema_migrations (filename) VALUES ('112_withdraw_rejected_nc_links.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
