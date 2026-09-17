-- Two "disputed" pairs turned out to be OpenStreetMap nodes matched to the
-- wrong sibling in a tight name cluster (Upper/Lower/Middle/Nth-Floor
-- variants sitting a few hundred metres apart on the same creek) rather
-- than a real disagreement about this feature specifically.
--
-- Sugar Creek Falls (657): OSM's coordinate (35.3098879, -83.0368756) sits
-- 252 m from Upper Sugar Creek Falls (feature 659, hikingwnc 35.30935,
-- -83.03417) but 694 m from this feature's own accepted coordinate. It is
-- almost certainly describing 659, not 657.
--
-- Boomer Inn Falls (4th Floor) (1139): OSM's coordinate (35.3735549,
-- -82.9638051) sits 163 m from Boomer Inn Falls (3rd Floor) (hikingwnc
-- 35.373141, -82.968668) and 276 m from (2nd Floor), both closer than the
-- 538 m to this feature's own accepted "4th Floor" coordinate.
--
-- Marked uncertain rather than moved to the sibling feature outright --
-- "which floor" among near-identical stacked cascades is exactly the kind
-- of call that deserves a human look, not an automatic reassignment.
--
-- Left open, deliberately not forced to a verdict here: Upper Courthouse
-- Falls (496, ~1.1 km gap, plausibly the same fall read imprecisely twice
-- rather than two different places -- see ncwaterfalls' own text, which
-- describes reaching it from the same trailhead system as Courthouse Falls
-- proper), Sleepy Hollow Falls (829, 769 m, no sibling or source text found
-- to explain it), Rock Slab Falls (942, 671 m, no cached source text to
-- check), and Waterfall on Log Hollow Branch (377, part of a five-name
-- Upper/Middle/Lower cluster on Log Hollow Branch that needs a careful pass
-- of its own rather than a rushed one at the end of this session).

BEGIN;

UPDATE claim_groups
SET identity_certain = false,
    note = coalesce(note || ' ', '') ||
           'Re-arbitrated 2026-09-17: 252 m from Upper Sugar Creek Falls (feature 659) but ' ||
           '694 m from this feature -- likely describes 659, not this one.'
WHERE feature_id = 657 AND source = 'openstreetmap';

UPDATE claim_groups
SET identity_certain = false,
    note = coalesce(note || ' ', '') ||
           'Re-arbitrated 2026-09-17: 163 m from Boomer Inn Falls (3rd Floor) and 276 m from ' ||
           '(2nd Floor), both closer than the 538 m to this feature -- likely describes a ' ||
           'different floor, not this one.'
WHERE feature_id = 1139 AND source = 'openstreetmap';

INSERT INTO schema_migrations (filename) VALUES ('079_sibling_cluster_mismatches.sql');

COMMIT;
