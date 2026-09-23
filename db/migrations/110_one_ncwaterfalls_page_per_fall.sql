-- One waterfall gets one page on ncwaterfalls.com, so a feature carrying two
-- certain ncwaterfalls matches means at least one of them is wrong. Four
-- features had more than one, and all nine of their links were live:
--
--   Waterfall on Log Hollow Branch  20 m  log-hollow-falls
--                                  310 m  nameless-waterfall-no-2-on-log-hollow-branch
--                                  584 m  nameless-waterfall-no-1-on-log-hollow-branch
--   Bridle Veil Falls (Highlands)   21 m  bridal-veil-falls-cullasaja-gorge
--                                  179 m  kalakalski-falls-3
--   Lake Sequoyah Dam Falls         65 m  lake-sequoyah-dam
--                                   95 m  kalakalaski-falls-1
--   Jumping Fish Falls                0 m  jumping-fish-falls
--                                     0 m  jumping-fish-falls/
--
-- The far ones give themselves away. Kevin Adams numbered those nameless
-- Log Hollow falls himself, which is the URL saying they are separate
-- waterfalls on one branch -- exactly the case 109 was about, where position
-- alone cannot separate siblings on a creek that drops several times within a
-- few hundred metres. 109 caught the ones whose correct page existed under an
-- exact name; these survived because the wrong page's name does not normalize
-- to ours.
--
-- Jumping Fish Falls is not that problem. It is the same page twice, once
-- with a trailing slash, so it gets its own note and the tie goes to the form
-- the other 153 ncwaterfalls urls use.
--
-- Keep the nearest page per feature, mark the rest uncertain with the reason
-- (marked, not deleted, per MATCHING.md), and withdraw only those links.

BEGIN;

CREATE TEMP TABLE nc_demoted ON COMMIT DROP AS
WITH ranked AS (
    SELECT cg.id,
           cg.feature_id,
           cg.url,
           first_value(cg.url) OVER w AS kept_url,
           row_number() OVER w AS closeness
    FROM claim_groups cg
    JOIN features f ON f.id = cg.feature_id
    JOIN locations lo ON lo.id = f.feature_location_id
    JOIN claims c ON c.group_id = cg.id AND c.field = 'coordinate'
    WHERE cg.source = 'ncwaterfalls' AND cg.identity_certain
    WINDOW w AS (
      PARTITION BY cg.feature_id
      ORDER BY 111320 * sqrt(
            power(lo.latitude - ((c.value->>'lat')::numeric), 2)
          + power((lo.longitude - ((c.value->>'lon')::numeric))
                  * cos(radians(lo.latitude)), 2)),
        -- Ties: prefer a row that has a url at all, then the site's own
        -- convention of no trailing slash.
        (cg.url IS NULL), (cg.url LIKE '%/'), cg.id
    )
)
SELECT id, feature_id, url,
       -- Same page, different spelling, versus a genuinely different page.
       (rtrim(kept_url, '/') = rtrim(url, '/')) AS is_dup_url
FROM ranked
WHERE closeness > 1;

UPDATE claim_groups cg
SET identity_certain = false,
    note = coalesce(cg.note || ' ', '') ||
           CASE WHEN d.is_dup_url THEN
             'Re-arbitrated: duplicate of the same ncwaterfalls page under a '
             'trailing-slash url. Kept the form the rest of the site uses.'
           ELSE
             'Re-arbitrated: this feature already has a nearer ncwaterfalls page, '
             'and one waterfall has one page there. Position alone cannot separate '
             'siblings on the same creek -- see the nameless-waterfall-no-N pages, '
             'which Kevin Adams numbered precisely because they are different falls.'
           END
FROM nc_demoted d WHERE cg.id = d.id;

-- Withdraw exactly the links these groups produced, and nothing else.
DELETE FROM links l
USING nc_demoted d
WHERE l.feature_id = d.feature_id AND l.url = d.url;

INSERT INTO schema_migrations (filename) VALUES ('110_one_ncwaterfalls_page_per_fall.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
