-- Record why the Skinny Dip Falls link is right.
--
-- Re-checking the 159 of Kevin's cached pages that no claim group points at
-- turned up one that passes both of MATCHING.md's tests: skinny-dip-falls
-- names our waterfall exactly once normalised and sits 84 m from our
-- coordinate. The link was already live -- it came in through import_links
-- rather than through claims -- so this adds the missing provenance, not
-- coverage. Worth doing anyway: a link with no claim group behind it has
-- never been through the identity checks, and cannot be re-arbitrated later
-- because there is nothing to re-arbitrate.
--
-- The other 158 are not headroom, and this is worth writing down because the
-- numbers invite the opposite conclusion. Twenty-one of them sit within 250 m
-- of one of our waterfalls, which looks like easy coverage until you read the
-- titles: Upper Stick Falls, Pulpit Falls, Upper Dill Falls, Lower Briefcase
-- Falls, Upper Moore Cove Falls, Kalakalaski Falls #1 and #3, and both
-- nameless waterfalls on Log Hollow Branch. Those are precisely the sibling
-- pages 109 and 110 refused. Matching them on proximity would re-create the
-- bug those two migrations just fixed, so proximity alone stays disqualifying
-- exactly as MATCHING.md says. Another 29 pages carry no coordinate and 106
-- are waterfalls we do not have -- he covers the whole state.
--
-- So ncwaterfalls coverage stays at 133 features, and is finished until
-- either his site gains pages or ours gains waterfalls.

BEGIN;

INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('ncwaterfalls|339|skinny-dip-falls', 339, 'ncwaterfalls',
 'https://ncwaterfalls.com/waterfalls/skinny-dip-falls', true,
 'Page we had never matched. Name matches ours exactly once normalised and it sits 84 m from our coordinate -- both tests, per MATCHING.md.')
ON CONFLICT (ref) DO NOTHING;

INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, 339, 'coordinate', '{"lat": 35.32222, "lon": -82.83357}'::jsonb, false
FROM claim_groups g WHERE g.ref = 'ncwaterfalls|339|skinny-dip-falls'
ON CONFLICT DO NOTHING;

INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, 339, 'parking_coordinate', '{"lat": 35.322412, "lon": -82.833664}'::jsonb, false
FROM claim_groups g WHERE g.ref = 'ncwaterfalls|339|skinny-dip-falls'
ON CONFLICT DO NOTHING;

INSERT INTO links (feature_id, url, rel)
SELECT cg.feature_id, cg.url, 'ncwaterfalls'
FROM claim_groups cg
WHERE cg.source = 'ncwaterfalls' AND cg.identity_certain AND cg.url IS NOT NULL
ON CONFLICT (feature_id, url) DO NOTHING;

INSERT INTO schema_migrations (filename) VALUES ('111_ncwaterfalls_skinny_dip.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
