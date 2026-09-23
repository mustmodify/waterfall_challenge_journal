-- Say on the page why ncwaterfalls distances get doubled.
--
-- The note these claims have carried since 043 asserted the convention
-- without evidence -- "One way unless it says otherwise" -- which is why jw
-- reasonably doubted it on sight. It was right, but nothing on the page said
-- how anyone knew, and nothing acted on it until 119.
--
-- So the note now carries the measurement instead of the assertion. The
-- figure is 0.57, from the 80 features where ncwaterfalls and hikingwnc both
-- give a distance and hikingwnc marks round trip explicitly: 41 of those 80
-- fall between 0.4 and 0.6 of hikingwnc's figure, and only 5 come within 20%
-- of equal.
--
-- Kept short, because it renders under every one of the 147 observed values.

BEGIN;

UPDATE claims c
SET note = 'ncwaterfalls measures one way: across the 80 waterfalls where '
        || 'hikingwnc also gives a distance, its figures run at about 0.57 of '
        || 'hikingwnc''s round-trip numbers. So this source is doubled when '
        || 'normalized.'
FROM claim_groups cg
WHERE cg.id = c.group_id
  AND cg.source = 'ncwaterfalls'
  AND c.field = 'hike_distance';

INSERT INTO schema_migrations (filename) VALUES ('120_ncwaterfalls_distance_footnote.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
