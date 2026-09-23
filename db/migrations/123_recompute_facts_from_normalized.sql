-- Recompute the facts that normalizing changed, and fix a formatting bug
-- that had been quietly wrecking heights.
--
-- THE BUG. 105 wrote a height with:
--
--     trim(trailing '.' from trim(trailing '0' from s.feet::text))
--
-- meant to turn 100.0 into 100. When the number rendered without a decimal
-- point it stripped significant zeros instead, so Triple Falls' "about 100
-- feet" became a height fact of 1, and 250 became 25. 123 of 265 numeric
-- height facts were wrong -- every height ending in a zero -- which is why
-- 24 waterfalls each appeared to be exactly 1, 2 and 3 feet tall. Nothing
-- published it: features.height_ft is filled separately and facts is not
-- read by the site, so this only ever showed on the admin pages.
--
-- THE REWIRE. The backfills each re-parsed the raw text themselves, which
-- was the only option before claims had a normalized_value. Now that it
-- exists they should read it, and they must, because two rules live only
-- there: 119 doubles ncwaterfalls distances and strips AllTrails "via"
-- tails. Until now facts has been grading un-doubled distances and
-- route-shaped names.
--
-- Three keys are recomputed. coordinate and accessibility are left alone --
-- their inputs did not change shape, so rerunning them would only risk
-- moving numbers for no reason.
--
-- Stage thresholds are carried over untouched. Two agreeing sources still
-- produce 'corroborated', which contradicts jw's three-source rule and
-- affects 594 facts; that is a decision he has not made yet, and quietly
-- changing it inside a bug fix would be the wrong way to make it.

BEGIN;

DELETE FROM facts WHERE key IN ('height', 'hike_distance', 'name');

-- ---------------------------------------------------------------- height --
WITH pts AS (
    SELECT DISTINCT ON (c.feature_id, s.src)
           c.id AS claim_id, c.feature_id, c.accepted, s.src,
           (c.normalized_value #>> '{}')::numeric AS feet
    FROM claims c
    JOIN claim_groups cg ON cg.id = c.group_id
    CROSS JOIN LATERAL (SELECT CASE WHEN cg.source LIKE 'hikingwnc%'
                                    THEN 'hikingwnc' ELSE cg.source END) AS s(src)
    WHERE c.field = 'height' AND cg.identity_certain
      AND c.normalized_value IS NOT NULL
      AND (c.normalized_value #>> '{}') ~ '^[0-9.]+$'
      AND (c.normalized_value #>> '{}')::numeric > 0
    ORDER BY c.feature_id, s.src, c.accepted DESC, c.id
),
agreement AS (
    SELECT a.claim_id, a.feature_id, a.accepted, a.feet, count(*) AS agreeing
    FROM pts a
    JOIN pts b ON b.feature_id = a.feature_id AND height_gap(a.feet, b.feet) <= 0.15
    GROUP BY a.claim_id, a.feature_id, a.accepted, a.feet
),
totals AS (
    SELECT feature_id, count(*) AS n, min(feet) AS lo, max(feet) AS hi
    FROM pts GROUP BY feature_id
),
winner AS (
    SELECT DISTINCT ON (a.feature_id)
           a.feature_id, a.feet, a.agreeing, t.n, t.lo, t.hi
    FROM agreement a JOIN totals t ON t.feature_id = a.feature_id
    ORDER BY a.feature_id, a.agreeing DESC,
             height_is_approximate(a.feet), a.accepted DESC, a.claim_id
),
staged AS (
    SELECT feature_id, feet, n, agreeing, lo, hi,
           round(lo / CASE WHEN lo < 50 THEN 5 WHEN lo <= 100 THEN 10 ELSE 25 END)
             * CASE WHEN lo < 50 THEN 5 WHEN lo <= 100 THEN 10 ELSE 25 END AS lo_r,
           round(hi / CASE WHEN hi < 50 THEN 5 WHEN hi <= 100 THEN 10 ELSE 25 END)
             * CASE WHEN hi < 50 THEN 5 WHEN hi <= 100 THEN 10 ELSE 25 END AS hi_r,
           CASE
             WHEN n = 1 THEN 'single_source'
             WHEN n - agreeing = 0 THEN 'corroborated'
             WHEN n >= 3 AND agreeing >= 2 AND n - agreeing <= floor(n / 2.0)
               THEN 'disambiguated'
             ELSE 'disputed'
           END AS stage
    FROM winner
)
INSERT INTO facts (feature_id, key, value, value_type, units,
                   confidence_stage, confidence_score, notes)
SELECT s.feature_id, 'height',
       CASE WHEN s.stage = 'disputed'
            -- A range when the sources genuinely disagree, rounded to each
            -- bound's own magnitude. No "approx": every one of these is
            -- approximate, and saying so on some and not others is noise.
            THEN CASE WHEN s.lo_r = s.hi_r THEN round(s.lo_r)::bigint::text
                      ELSE round(s.lo_r)::bigint::text || ' - ' ||
                           round(s.hi_r)::bigint::text END
            -- The formatting bug. round() to a bigint rather than trimming
            -- characters off the end of a rendered number.
            ELSE round(s.feet)::bigint::text
       END,
       CASE WHEN s.stage = 'disputed' THEN 'string' ELSE 'integer' END,
       'feet', s.stage,
       CASE s.stage WHEN 'disputed' THEN 1.0 WHEN 'single_source' THEN 1.7
                    WHEN 'disambiguated' THEN 2.3 WHEN 'corroborated' THEN 3.0 END,
       CASE WHEN s.stage = 'disputed'
            THEN s.n || ' sources spread from ' || round(s.lo)::bigint || ' to ' ||
                 round(s.hi)::bigint || ' ft, more than 15% apart, so no single '
                 || 'reading is claimed'
            ELSE agreement_note(s.agreeing::int, s.n::int, 'within 15%')
       END
FROM staged s;

-- --------------------------------------------------------- hike_distance --
WITH pts AS (
    SELECT DISTINCT ON (c.feature_id, s.src)
           c.id AS claim_id, c.feature_id, c.accepted, s.src,
           (c.normalized_value #>> '{}')::numeric AS feet
    FROM claims c
    JOIN claim_groups cg ON cg.id = c.group_id
    CROSS JOIN LATERAL (SELECT CASE WHEN cg.source LIKE 'hikingwnc%'
                                    THEN 'hikingwnc' ELSE cg.source END) AS s(src)
    WHERE c.field = 'hike_distance' AND cg.identity_certain
      AND c.normalized_value IS NOT NULL
      AND (c.normalized_value #>> '{}') ~ '^[0-9.]+$'
    ORDER BY c.feature_id, s.src, c.accepted DESC, c.id
),
agreement AS (
    SELECT a.claim_id, a.feature_id, a.accepted, a.feet, count(*) AS agreeing
    FROM pts a
    JOIN pts b ON b.feature_id = a.feature_id
      AND ((a.feet = 0 AND b.feet = 0)
           OR (greatest(a.feet, b.feet) > 0
               AND (greatest(a.feet, b.feet) - least(a.feet, b.feet))
                   / greatest(a.feet, b.feet) <= 0.15))
    GROUP BY a.claim_id, a.feature_id, a.accepted, a.feet
),
totals AS (SELECT feature_id, count(*) AS n FROM pts GROUP BY feature_id),
winner AS (
    SELECT DISTINCT ON (a.feature_id) a.feature_id, a.feet, a.agreeing, t.n
    FROM agreement a JOIN totals t ON t.feature_id = a.feature_id
    ORDER BY a.feature_id, a.agreeing DESC, a.feet DESC, a.accepted DESC, a.claim_id
),
staged AS (
    SELECT feature_id, feet, n, agreeing,
           CASE
             WHEN n = 1 THEN 'single_source'
             WHEN n - agreeing = 0 THEN 'corroborated'
             WHEN n >= 3 AND agreeing >= 2 AND n - agreeing <= floor(n / 2.0)
               THEN 'disambiguated'
             ELSE 'disputed'
           END AS stage
    FROM winner
)
INSERT INTO facts (feature_id, key, value, value_type, units,
                   confidence_stage, confidence_score, notes)
SELECT s.feature_id, 'hike_distance', round(s.feet)::bigint::text, 'integer',
       'feet, round trip', s.stage,
       CASE s.stage WHEN 'disputed' THEN 1.0 WHEN 'single_source' THEN 1.7
                    WHEN 'disambiguated' THEN 2.3 WHEN 'corroborated' THEN 3.0 END,
       agreement_note(s.agreeing::int, s.n::int,
                      'within 15% once every source is in round-trip feet')
FROM staged s;

-- ------------------------------------------------------------------ name --
WITH pts AS (
    SELECT DISTINCT ON (c.feature_id, s.src)
           c.id AS claim_id, c.feature_id, c.accepted, s.src,
           coalesce(c.normalized_value, c.value) #>> '{}' AS nm
    FROM claims c
    JOIN claim_groups cg ON cg.id = c.group_id
    CROSS JOIN LATERAL (SELECT CASE WHEN cg.source LIKE 'hikingwnc%'
                                    THEN 'hikingwnc' ELSE cg.source END) AS s(src)
    WHERE c.field = 'name' AND cg.identity_certain
      AND coalesce(c.normalized_value, c.value) #>> '{}' <> ''
    ORDER BY c.feature_id, s.src, c.accepted DESC, c.id
),
agreement AS (
    SELECT a.claim_id, a.feature_id, a.accepted, a.nm, count(*) AS agreeing
    FROM pts a
    JOIN pts b ON b.feature_id = a.feature_id
      AND replace(name_core(b.nm), ' ', '') = replace(name_core(a.nm), ' ', '')
    GROUP BY a.claim_id, a.feature_id, a.accepted, a.nm
),
totals AS (SELECT feature_id, count(*) AS n FROM pts GROUP BY feature_id),
winner AS (
    SELECT DISTINCT ON (a.feature_id) a.feature_id, a.nm, a.agreeing, t.n
    FROM agreement a JOIN totals t ON t.feature_id = a.feature_id
    ORDER BY a.feature_id, a.agreeing DESC, a.accepted DESC, length(a.nm), a.claim_id
),
staged AS (
    SELECT feature_id, nm, n, agreeing,
           CASE
             WHEN n = 1 THEN 'single_source'
             WHEN n - agreeing = 0 THEN 'corroborated'
             WHEN n >= 3 AND agreeing >= 2 AND n - agreeing <= floor(n / 2.0)
               THEN 'disambiguated'
             ELSE 'disputed'
           END AS stage
    FROM winner
)
INSERT INTO facts (feature_id, key, value, value_type, units,
                   confidence_stage, confidence_score, notes)
SELECT s.feature_id, 'name', s.nm, 'string', NULL, s.stage,
       CASE s.stage WHEN 'disputed' THEN 1.0 WHEN 'single_source' THEN 1.7
                    WHEN 'disambiguated' THEN 2.3 WHEN 'corroborated' THEN 3.0 END,
       agreement_note(s.agreeing::int, s.n::int,
                      'once punctuation, case and spacing are ignored')
FROM staged s;

INSERT INTO schema_migrations (filename) VALUES ('123_recompute_facts_from_normalized.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
