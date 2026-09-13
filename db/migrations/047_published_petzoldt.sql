-- dwhike publishes the rating itself, not just the numbers behind it.
--
-- His difficulty line often reads "Moderate (Petzoldt Rating: 3.20)". That is
-- his answer, and it belongs beside ours rather than under it: where the two
-- differ, one of the numbers we parsed is off.
--
-- Taken from claims already in the table, so nothing is fetched again.

BEGIN;

INSERT INTO claims (group_id, feature_id, field, value, note)
SELECT c.group_id, c.feature_id, 'petzoldt',
       to_jsonb((regexp_match(c.value#>>'{}', 'Petzoldt Rating:\s*([0-9.]+)'))[1]::numeric),
       'Published on the gallery page rather than computed from distance and gain.'
FROM claims c
JOIN claim_groups cg ON cg.id = c.group_id
WHERE cg.source = 'dwhike' AND c.field = 'accessibility'
  AND c.value#>>'{}' ~ 'Petzoldt Rating:\s*[0-9.]+'
ON CONFLICT DO NOTHING;

COMMIT;
