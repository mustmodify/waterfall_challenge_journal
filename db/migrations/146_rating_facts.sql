-- Beauty, photo and solitude become facts.
--
-- jw: "average if the spread is less than 5 otherwise see if there's a
-- consensus etc", and then "which for two there can't be".
--
-- These three fields held 2,916 claims and produced no fact at all, so the
-- feature page fell back to whatever the original import happened to mark
-- accepted. Feature 471 showed beauty 8 for no better reason than that
-- hikingwnc was imported first; Kevin Adams's 6 sat underneath it looking
-- rejected.
--
-- Nothing is normalized on the way in. Both raters already publish 1 to 10,
-- so there is no scale to convert and a normalizer here would be a no-op
-- dressed up as a step.
--
-- What is different from every other fact: there is no right answer. Two
-- people disagreeing about where a waterfall is means one of them is wrong.
-- Two people disagreeing about whether it is a 6 or an 8 means they have
-- different taste, and averaging them is the honest summary rather than a
-- verdict. So the grade here says how close the raters were, not how likely
-- the number is to be correct.
--
-- Where they are five or more apart, there is nothing to average that would
-- mean anything, so the fact keeps the range and is marked disputed. With
-- three or more raters you could instead look for the ones that cluster and
-- set the outlier aside. That is not written here because it has nowhere to
-- run: after collapsing hikingwnc and its supplement into one rater, no
-- waterfall has more than two.
--
-- Rerunnable.

BEGIN;

-- The key is the claim's field name, unchanged. Everywhere else a fact is
-- looked up by the field the claims use -- the feature page joins on exactly
-- that -- so shortening these to "beauty" would make them the only three
-- facts nothing could find.
DELETE FROM facts WHERE key IN ('beauty_rating', 'photo_rating', 'solitude_rating',
                                'beauty', 'photo', 'solitude');

WITH per_source AS (
    -- One opinion per rater. hikingwnc and hikingwnc-supplement are the same
    -- person reading the same site twice, which coordinate_confidence already
    -- collapses; counting them as two would manufacture agreement.
    SELECT DISTINCT ON (c.feature_id, c.field, s.rater)
           c.feature_id, c.field, s.rater,
           (coalesce(c.normalized_value, c.value) #>> '{}')::numeric AS score
    FROM claims c
    JOIN claim_groups cg ON cg.id = c.group_id
    CROSS JOIN LATERAL (SELECT CASE WHEN cg.source LIKE 'hikingwnc%'
                                    THEN 'hikingwnc' ELSE cg.source END) AS s(rater)
    WHERE c.field IN ('beauty_rating', 'photo_rating', 'solitude_rating')
      AND cg.identity_certain
      AND c.superseded_by IS NULL
      AND (coalesce(c.normalized_value, c.value) #>> '{}') ~ '^[0-9]+(\.[0-9]+)?$'
    ORDER BY c.feature_id, c.field, s.rater, c.accepted DESC, c.id DESC
),
summary AS (
    SELECT feature_id, field,
           count(*) AS raters,
           round(avg(score), 1) AS mean,
           min(score) AS lo,
           max(score) AS hi,
           max(score) - min(score) AS spread
    FROM per_source GROUP BY feature_id, field
)
INSERT INTO facts (feature_id, key, value, value_type, units,
                   confidence_stage, confidence_score, notes)
SELECT s.feature_id,
       s.field,
       CASE WHEN s.spread >= 5 THEN s.lo || ' - ' || s.hi
            ELSE trim_scale(s.mean)::text END,
       CASE WHEN s.spread >= 5 THEN 'string' ELSE 'decimal' END,
       'out of 10',
       CASE WHEN s.raters = 1  THEN 'single_source'
            WHEN s.spread >= 5 THEN 'disputed'
            ELSE agreement_stage(s.raters::int, s.raters::int) END,
       CASE WHEN s.raters = 1  THEN 1.7
            WHEN s.spread >= 5 THEN 1.0
            ELSE agreement_score(s.raters::int, s.raters::int) END,
       CASE
         WHEN s.raters = 1 THEN
           'One rater. Not a consensus, just the only opinion anyone published.'
         WHEN s.spread >= 5 THEN
           s.raters || ' raters, ' || trim_scale(s.spread)
             || ' points apart. Too far apart to average into anything meaningful, '
             || 'and with two raters there is no majority to fall back on, so both '
             || 'readings stand and neither is the answer.'
         WHEN s.spread = 0 THEN
           s.raters || ' raters, and they gave the same score.'
         ELSE
           s.raters || ' raters, ' || trim_scale(s.spread)
             || ' point' || CASE WHEN s.spread = 1 THEN '' ELSE 's' END
             || ' apart, averaged. Neither is wrong -- this is taste, not a '
             || 'measurement, so the grade says how close they were.'
       END
FROM summary s;

INSERT INTO schema_migrations (filename) VALUES ('146_rating_facts.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
