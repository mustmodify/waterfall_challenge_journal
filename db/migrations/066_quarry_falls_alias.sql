-- "Quarry Falls" is a third name for feature 359, alongside "Drift Falls" and
-- "Bust-Your-Butt Falls" -- all the same spot on the Cullasaja River near
-- Highlands, between Dry Falls and Bridal Veil Falls.
--
-- Source is a Facebook "fb-answers" page; Facebook's robots.txt prohibits
-- automated collection outright ("Collection of data on Facebook through
-- automated means is prohibited unless you have express written permission"),
-- so this was never spidered -- jw read the page and pasted its text into
-- conversation. Recorded as a direct claim rather than run through a scraper
-- that was never used.
--
-- This also rules out a name collision we almost made ourselves: "The Quarry
-- at Carrigan Farms" (an artificial, fee-based spring-fed quarry in
-- Mooresville, ~150 miles away) is a completely different place that merely
-- shares the word "quarry" -- not this feature, despite what naive name
-- matching suggested while building the swimming-hole list.

BEGIN;

INSERT INTO claim_groups (ref, feature_id, source, url, note) VALUES
('jw|359|quarry-falls-alias', 359, 'jw',
 'https://www.facebook.com/fb-answers/quarry-falls-north-carolina-swimming-hole/',
 'Facebook disallows automated collection; jw read and transcribed the page manually.');

INSERT INTO claims (group_id, feature_id, field, value, accepted, note)
SELECT g.id, g.feature_id, 'alias', '"Quarry Falls"', true,
    'About 6.5 miles west of Highlands on US 64 along the Cullasaja River, Macon County -- a natural rock slide and swimming pool, not to be confused with The Quarry at Carrigan Farms (Mooresville).'
FROM claim_groups g WHERE g.ref = 'jw|359|quarry-falls-alias';

INSERT INTO schema_migrations (filename) VALUES ('066_quarry_falls_alias.sql');

COMMIT;
