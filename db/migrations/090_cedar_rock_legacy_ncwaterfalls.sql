-- jw found https://legacy.ncwaterfalls.com/cedar_rock1.htm -- an older Kevin
-- Adams page distinct from the current ncwaterfalls.com (kept as its own
-- source, same reasoning as hikingwnc-supplement: the site changed and this
-- is a different scrape of different content, not a re-read of the same
-- page). No GPS on this page at all, just trail directions -- so it adds no
-- coordinate evidence, but it's independent confirmation of two names and
-- carries a safety warning worth recording.
--
-- Cedar Rock Falls (381): already confirmed tier, just gets the extra link.
-- Upper Waterfall on Cedar Rock Creek (466): this page calls the same place
-- "Upper Cedar Rock Falls", matching hikingwnc's own sequential description
-- (immediately past Cedar Rock Falls, before a primitive campsite). Still no
-- coordinate, so still hidden -- this is corroboration of identity, not of
-- position.
-- Grogan Creek Falls (383): already on the map. The page's own words:
-- "Stay away from the top of the waterfall! If you fall here you will die."
-- That's not hyperbole worth softening -- recorded verbatim as a caution.

BEGIN;

INSERT INTO links (feature_id, url, rel)
VALUES (381, 'https://legacy.ncwaterfalls.com/cedar_rock1.htm', 'ncwaterfalls-legacy')
ON CONFLICT (feature_id, url) DO NOTHING;

INSERT INTO links (feature_id, url, rel)
VALUES (383, 'https://legacy.ncwaterfalls.com/cedar_rock1.htm', 'ncwaterfalls-legacy')
ON CONFLICT (feature_id, url) DO NOTHING;

INSERT INTO links (feature_id, url, rel)
VALUES (466, 'https://legacy.ncwaterfalls.com/cedar_rock1.htm', 'ncwaterfalls-legacy')
ON CONFLICT (feature_id, url) DO NOTHING;

INSERT INTO claim_groups (ref, feature_id, source, url, identity_certain, note) VALUES
('ncwaterfalls-legacy|466|cedar-rock1', 466, 'ncwaterfalls-legacy',
 'https://legacy.ncwaterfalls.com/cedar_rock1.htm', true,
 'Calls this "Upper Cedar Rock Falls" -- matches hikingwnc''s "Upper Waterfall on Cedar Rock ' ||
 'Creek" by trail sequence: immediately past Cedar Rock Falls, just before a primitive ' ||
 'campsite, in both descriptions. No GPS given on this page, so identity only, not position.');

INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT g.id, g.feature_id, 'name', '"Upper Cedar Rock Falls"'::jsonb, false
FROM claim_groups g WHERE g.ref = 'ncwaterfalls-legacy|466|cedar-rock1';

INSERT INTO feature_notes (feature_id, severity, text, source, observed_on)
VALUES (
  383,
  'urgent',
  'The top of the waterfall is dangerous: "Stay away from the top of the waterfall! ' ||
  'If you fall here you will die." (legacy.ncwaterfalls.com''s own words.)',
  'ncwaterfalls-legacy',
  CURRENT_DATE
);

INSERT INTO schema_migrations (filename) VALUES ('090_cedar_rock_legacy_ncwaterfalls.sql');

COMMIT;
