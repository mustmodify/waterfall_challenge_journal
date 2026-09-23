-- Point our ncwaterfalls links at the right page, and publish the ones that
-- were already correct but never harvested.
--
-- Kevin Adams is about to look at the site, so a link landing on the wrong
-- one of his own pages is the specific thing to avoid. Checking the cached
-- copy of his site against our matches found 18 where we had matched a
-- position-only candidate while a page named exactly like our waterfall sat
-- in the same cache: upper-stick-falls where stick-falls exists,
-- lower-waterfall-on-chestnut-creek where chestnut-falls exists,
-- pulpit-falls where bird-rock-falls exists. All eighteen are the
-- upper/lower/middle sibling confusion MATCHING.md warns about, and in every
-- case the exact-name page is also the closer one -- most within 30 m,
-- against the 130-200 m of the page we had picked.
--
-- None of them had been published as links, so nothing wrong was on the site.
--
-- The bad matches are marked rather than rewritten, per MATCHING.md: a
-- deleted bad match invites the next importer to make it again. They stay
-- visible under "rejected candidates" on the admin claims page.
--
-- Four genuinely new matches are added from pages we had never matched at
-- all. A fifth, Milton Bradley Falls, matched by name and was refused: the
-- page is 45 km away, which is the Silver Run Falls trap in a new costume.

BEGIN;

UPDATE claim_groups SET identity_certain = false,
    note = coalesce(note || ' ', '') || 'Re-arbitrated: matched on position alone to a sibling page while balsam-falls names this waterfall exactly and sits 12 m away. That page is claimed separately.'
WHERE id = 1819;
INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('ncwaterfalls|962|balsam-falls', 962, 'ncwaterfalls', 'https://ncwaterfalls.com/waterfalls/balsam-falls', true,
 'Name matches ours exactly once normalised, and the page sits 12 m from our coordinate -- both tests, per MATCHING.md. Replaces an earlier position-only match to a sibling page.')
ON CONFLICT (ref) DO NOTHING;
INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, 962, 'coordinate', '{"lat": 35.266154, "lon": -82.96941}'::jsonb, false FROM claim_groups g WHERE g.ref = 'ncwaterfalls|962|balsam-falls'
ON CONFLICT DO NOTHING;

UPDATE claim_groups SET identity_certain = false,
    note = coalesce(note || ' ', '') || 'Re-arbitrated: matched on position alone to a sibling page while beetree-fork-falls names this waterfall exactly and sits 17 m away. That page is claimed separately.'
WHERE id = 1754;
INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('ncwaterfalls|579|beetree-fork-falls', 579, 'ncwaterfalls', 'https://ncwaterfalls.com/waterfalls/beetree-fork-falls', true,
 'Name matches ours exactly once normalised, and the page sits 17 m from our coordinate -- both tests, per MATCHING.md. Replaces an earlier position-only match to a sibling page.')
ON CONFLICT (ref) DO NOTHING;
INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, 579, 'coordinate', '{"lat": 35.251294, "lon": -82.890552}'::jsonb, false FROM claim_groups g WHERE g.ref = 'ncwaterfalls|579|beetree-fork-falls'
ON CONFLICT DO NOTHING;

UPDATE claim_groups SET identity_certain = false,
    note = coalesce(note || ' ', '') || 'Re-arbitrated: matched on position alone to a sibling page while bird-rock-falls names this waterfall exactly and sits 43 m away. That page is claimed separately.'
WHERE id = 1696;
INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('ncwaterfalls|364|bird-rock-falls', 364, 'ncwaterfalls', 'https://ncwaterfalls.com/waterfalls/bird-rock-falls', true,
 'Name matches ours exactly once normalised, and the page sits 43 m from our coordinate -- both tests, per MATCHING.md. Replaces an earlier position-only match to a sibling page.')
ON CONFLICT (ref) DO NOTHING;
INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, 364, 'coordinate', '{"lat": 35.22112, "lon": -82.86074}'::jsonb, false FROM claim_groups g WHERE g.ref = 'ncwaterfalls|364|bird-rock-falls'
ON CONFLICT DO NOTHING;

UPDATE claim_groups SET identity_certain = false,
    note = coalesce(note || ' ', '') || 'Re-arbitrated: matched on position alone to a sibling page while bradley-cooper-falls names this waterfall exactly and sits 18 m away. That page is claimed separately.'
WHERE id = 1721;
INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('ncwaterfalls|586|bradley-cooper-falls', 586, 'ncwaterfalls', 'https://ncwaterfalls.com/waterfalls/bradley-cooper-falls', true,
 'Name matches ours exactly once normalised, and the page sits 18 m from our coordinate -- both tests, per MATCHING.md. Replaces an earlier position-only match to a sibling page.')
ON CONFLICT (ref) DO NOTHING;
INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, 586, 'coordinate', '{"lat": 35.283361, "lon": -82.274573}'::jsonb, false FROM claim_groups g WHERE g.ref = 'ncwaterfalls|586|bradley-cooper-falls'
ON CONFLICT DO NOTHING;

UPDATE claim_groups SET identity_certain = false,
    note = coalesce(note || ' ', '') || 'Re-arbitrated: matched on position alone to a sibling page while case-falls names this waterfall exactly and sits 21 m away. That page is claimed separately.'
WHERE id = 1837;
UPDATE claim_groups SET identity_certain = false,
    note = coalesce(note || ' ', '') || 'Re-arbitrated: matched on position alone to a sibling page while case-falls names this waterfall exactly and sits 21 m away. That page is claimed separately.'
WHERE id = 1703;
INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('ncwaterfalls|590|case-falls', 590, 'ncwaterfalls', 'https://ncwaterfalls.com/waterfalls/case-falls', true,
 'Name matches ours exactly once normalised, and the page sits 21 m from our coordinate -- both tests, per MATCHING.md. Replaces an earlier position-only match to a sibling page.')
ON CONFLICT (ref) DO NOTHING;
INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, 590, 'coordinate', '{"lat": 35.288686, "lon": -82.359215}'::jsonb, false FROM claim_groups g WHERE g.ref = 'ncwaterfalls|590|case-falls'
ON CONFLICT DO NOTHING;

UPDATE claim_groups SET identity_certain = false,
    note = coalesce(note || ' ', '') || 'Re-arbitrated: matched on position alone to a sibling page while chestnut-falls names this waterfall exactly and sits 32 m away. That page is claimed separately.'
WHERE id = 1744;
UPDATE claim_groups SET identity_certain = false,
    note = coalesce(note || ' ', '') || 'Re-arbitrated: matched on position alone to a sibling page while chestnut-falls names this waterfall exactly and sits 32 m away. That page is claimed separately.'
WHERE id = 1722;
INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('ncwaterfalls|498|chestnut-falls', 498, 'ncwaterfalls', 'https://ncwaterfalls.com/waterfalls/chestnut-falls', true,
 'Name matches ours exactly once normalised, and the page sits 32 m from our coordinate -- both tests, per MATCHING.md. Replaces an earlier position-only match to a sibling page.')
ON CONFLICT (ref) DO NOTHING;
INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, 498, 'coordinate', '{"lat": 35.27882, "lon": -82.88733}'::jsonb, false FROM claim_groups g WHERE g.ref = 'ncwaterfalls|498|chestnut-falls'
ON CONFLICT DO NOTHING;

UPDATE claim_groups SET identity_certain = false,
    note = coalesce(note || ' ', '') || 'Re-arbitrated: matched on position alone to a sibling page while dill-falls names this waterfall exactly and sits 61 m away. That page is claimed separately.'
WHERE id = 1785;
INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('ncwaterfalls|349|dill-falls', 349, 'ncwaterfalls', 'https://ncwaterfalls.com/waterfalls/dill-falls', true,
 'Name matches ours exactly once normalised, and the page sits 61 m from our coordinate -- both tests, per MATCHING.md. Replaces an earlier position-only match to a sibling page.')
ON CONFLICT (ref) DO NOTHING;
INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, 349, 'coordinate', '{"lat": 35.28296, "lon": -82.94363}'::jsonb, false FROM claim_groups g WHERE g.ref = 'ncwaterfalls|349|dill-falls'
ON CONFLICT DO NOTHING;

UPDATE claim_groups SET identity_certain = false,
    note = coalesce(note || ' ', '') || 'Re-arbitrated: matched on position alone to a sibling page while little-moore-cove-falls names this waterfall exactly and sits 9 m away. That page is claimed separately.'
WHERE id = 1783;
UPDATE claim_groups SET identity_certain = false,
    note = coalesce(note || ' ', '') || 'Re-arbitrated: matched on position alone to a sibling page while little-moore-cove-falls names this waterfall exactly and sits 9 m away. That page is claimed separately.'
WHERE id = 1697;
INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('ncwaterfalls|505|little-moore-cove-falls', 505, 'ncwaterfalls', 'https://ncwaterfalls.com/waterfalls/little-moore-cove-falls', true,
 'Name matches ours exactly once normalised, and the page sits 9 m from our coordinate -- both tests, per MATCHING.md. Replaces an earlier position-only match to a sibling page.')
ON CONFLICT (ref) DO NOTHING;
INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, 505, 'coordinate', '{"lat": 35.31197, "lon": -82.77863}'::jsonb, false FROM claim_groups g WHERE g.ref = 'ncwaterfalls|505|little-moore-cove-falls'
ON CONFLICT DO NOTHING;

UPDATE claim_groups SET identity_certain = false,
    note = coalesce(note || ' ', '') || 'Re-arbitrated: matched on position alone to a sibling page while merry-falls names this waterfall exactly and sits 2 m away. That page is claimed separately.'
WHERE id = 1770;
INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('ncwaterfalls|482|merry-falls', 482, 'ncwaterfalls', 'https://ncwaterfalls.com/waterfalls/merry-falls', true,
 'Name matches ours exactly once normalised, and the page sits 2 m from our coordinate -- both tests, per MATCHING.md. Replaces an earlier position-only match to a sibling page.')
ON CONFLICT (ref) DO NOTHING;
INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, 482, 'coordinate', '{"lat": 35.2006, "lon": -82.64368}'::jsonb, false FROM claim_groups g WHERE g.ref = 'ncwaterfalls|482|merry-falls'
ON CONFLICT DO NOTHING;

UPDATE claim_groups SET identity_certain = false,
    note = coalesce(note || ' ', '') || 'Re-arbitrated: matched on position alone to a sibling page while moore-cove-falls names this waterfall exactly and sits 161 m away. That page is claimed separately.'
WHERE id = 1746;
INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('ncwaterfalls|380|moore-cove-falls', 380, 'ncwaterfalls', 'https://ncwaterfalls.com/waterfalls/moore-cove-falls', true,
 'Name matches ours exactly once normalised, and the page sits 161 m from our coordinate -- both tests, per MATCHING.md. Replaces an earlier position-only match to a sibling page.')
ON CONFLICT (ref) DO NOTHING;
INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, 380, 'coordinate', '{"lat": 35.311774, "lon": -82.777553}'::jsonb, false FROM claim_groups g WHERE g.ref = 'ncwaterfalls|380|moore-cove-falls'
ON CONFLICT DO NOTHING;

UPDATE claim_groups SET identity_certain = false,
    note = coalesce(note || ' ', '') || 'Re-arbitrated: matched on position alone to a sibling page while patricia-falls names this waterfall exactly and sits 17 m away. That page is claimed separately.'
WHERE id = 1715;
UPDATE claim_groups SET identity_certain = false,
    note = coalesce(note || ' ', '') || 'Re-arbitrated: matched on position alone to a sibling page while patricia-falls names this waterfall exactly and sits 17 m away. That page is claimed separately.'
WHERE id = 1807;
INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('ncwaterfalls|964|patricia-falls', 964, 'ncwaterfalls', 'https://ncwaterfalls.com/waterfalls/patricia-falls', true,
 'Name matches ours exactly once normalised, and the page sits 17 m from our coordinate -- both tests, per MATCHING.md. Replaces an earlier position-only match to a sibling page.')
ON CONFLICT (ref) DO NOTHING;
INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, 964, 'coordinate', '{"lat": 35.264255, "lon": -82.970117}'::jsonb, false FROM claim_groups g WHERE g.ref = 'ncwaterfalls|964|patricia-falls'
ON CONFLICT DO NOTHING;

UPDATE claim_groups SET identity_certain = false,
    note = coalesce(note || ' ', '') || 'Re-arbitrated: matched on position alone to a sibling page while quarry-falls names this waterfall exactly and sits 16 m away. That page is claimed separately.'
WHERE id = 1788;
INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('ncwaterfalls|551|quarry-falls', 551, 'ncwaterfalls', 'https://ncwaterfalls.com/waterfalls/quarry-falls', true,
 'Name matches ours exactly once normalised, and the page sits 16 m from our coordinate -- both tests, per MATCHING.md. Replaces an earlier position-only match to a sibling page.')
ON CONFLICT (ref) DO NOTHING;
INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, 551, 'coordinate', '{"lat": 35.09287, "lon": -83.26677}'::jsonb, false FROM claim_groups g WHERE g.ref = 'ncwaterfalls|551|quarry-falls'
ON CONFLICT DO NOTHING;

UPDATE claim_groups SET identity_certain = false,
    note = coalesce(note || ' ', '') || 'Re-arbitrated: matched on position alone to a sibling page while silver-run-falls names this waterfall exactly and sits 29 m away. That page is claimed separately.'
WHERE id = 1815;
INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('ncwaterfalls|323|silver-run-falls', 323, 'ncwaterfalls', 'https://ncwaterfalls.com/waterfalls/silver-run-falls', true,
 'Name matches ours exactly once normalised, and the page sits 29 m from our coordinate -- both tests, per MATCHING.md. Replaces an earlier position-only match to a sibling page.')
ON CONFLICT (ref) DO NOTHING;
INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, 323, 'coordinate', '{"lat": 35.06599, "lon": -83.06558}'::jsonb, false FROM claim_groups g WHERE g.ref = 'ncwaterfalls|323|silver-run-falls'
ON CONFLICT DO NOTHING;

UPDATE claim_groups SET identity_certain = false,
    note = coalesce(note || ' ', '') || 'Re-arbitrated: matched on position alone to a sibling page while stick-falls names this waterfall exactly and sits 24 m away. That page is claimed separately.'
WHERE id = 1796;
INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('ncwaterfalls|639|stick-falls', 639, 'ncwaterfalls', 'https://ncwaterfalls.com/waterfalls/stick-falls', true,
 'Name matches ours exactly once normalised, and the page sits 24 m from our coordinate -- both tests, per MATCHING.md. Replaces an earlier position-only match to a sibling page.')
ON CONFLICT (ref) DO NOTHING;
INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, 639, 'coordinate', '{"lat": 35.020419, "lon": -83.164042}'::jsonb, false FROM claim_groups g WHERE g.ref = 'ncwaterfalls|639|stick-falls'
ON CONFLICT DO NOTHING;

INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('ncwaterfalls|572|glassmine-falls', 572, 'ncwaterfalls', 'https://ncwaterfalls.com/waterfalls/glassmine-falls', true,
 'Page we had never matched. Name matches ours exactly once normalised and it sits 1112 m from our coordinate.')
ON CONFLICT (ref) DO NOTHING;
INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, 572, 'coordinate', '{"lat": 35.73507, "lon": -82.33193}'::jsonb, false FROM claim_groups g WHERE g.ref = 'ncwaterfalls|572|glassmine-falls'
ON CONFLICT DO NOTHING;

INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('ncwaterfalls|574|kiesee-falls', 574, 'ncwaterfalls', 'https://ncwaterfalls.com/waterfalls/kiesee-falls', true,
 'Page we had never matched. Name matches ours exactly once normalised and it sits 335 m from our coordinate.')
ON CONFLICT (ref) DO NOTHING;
INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, 574, 'coordinate', '{"lat": 35.27935, "lon": -82.88205}'::jsonb, false FROM claim_groups g WHERE g.ref = 'ncwaterfalls|574|kiesee-falls'
ON CONFLICT DO NOTHING;

INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('ncwaterfalls|350|second-falls', 350, 'ncwaterfalls', 'https://ncwaterfalls.com/waterfalls/second-falls', true,
 'Page we had never matched. Name matches ours exactly once normalised and it sits 442 m from our coordinate.')
ON CONFLICT (ref) DO NOTHING;
INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, 350, 'coordinate', '{"lat": 35.3223, "lon": -82.84646}'::jsonb, false FROM claim_groups g WHERE g.ref = 'ncwaterfalls|350|second-falls'
ON CONFLICT DO NOTHING;

INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('ncwaterfalls|468|toxaway-falls', 468, 'ncwaterfalls', 'https://ncwaterfalls.com/waterfalls/toxaway-falls', true,
 'Page we had never matched. Name matches ours exactly once normalised and it sits 372 m from our coordinate.')
ON CONFLICT (ref) DO NOTHING;
INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, 468, 'coordinate', '{"lat": 35.122239, "lon": -82.92756}'::jsonb, false FROM claim_groups g WHERE g.ref = 'ncwaterfalls|468|toxaway-falls'
ON CONFLICT DO NOTHING;

-- Publish a link for every ncwaterfalls group we are certain about. This is
-- migration 052's harvest re-run: everything re-arbitrated since then has
-- been sitting unpublished.
INSERT INTO links (feature_id, url, rel)
SELECT cg.feature_id, cg.url, 'ncwaterfalls'
FROM claim_groups cg
WHERE cg.source = 'ncwaterfalls' AND cg.identity_certain AND cg.url IS NOT NULL
ON CONFLICT (feature_id, url) DO NOTHING;

INSERT INTO schema_migrations (filename) VALUES ('109_ncwaterfalls_right_page.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
