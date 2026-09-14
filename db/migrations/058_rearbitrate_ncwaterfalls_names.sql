-- The ncwaterfalls groups were never really name disagreements.
--
-- 54 groups carrying published links sit at identity_certain = false with a
-- note saying "matched on position, with no name agreement". The name
-- agreement was there the whole time. Kevin Adams titles his pages for search
-- engines -- "Silver Run Falls-Visit Guide, Photos", "Pot Branch Falls-Hiking,
-- Photos, Map" -- and the original matcher compared that whole string against
-- "Silver Run Falls".
--
-- Two shapes of real difference survive the tail:
--
--   * A disambiguator we carry and he does not. Ours is "High Falls- Little
--     River"; his is "High Falls". We hold five High Falls and five Rainbow
--     Falls, so the qualifier is how our list tells them apart, not a
--     different name. It is exactly the case where the base name alone decides
--     nothing -- which is why the coordinate has to agree as well, and why
--     this migration will not flip a group on either test on its own.
--   * A parenthetical alias, e.g. "Drift Falls (Bust-Your-Butt Falls)".
--
-- So: strip his SEO tail, strip our parentheses, compare the cores, and
-- require the coordinate he publishes to be within 200 m of ours. 200 m rather
-- than the usual 2 km band because every one of these is already inside it --
-- the furthest is 196 m, the mean 42 m -- and a threshold set where the data
-- actually sits will not quietly admit something looser later.
--
-- What this deliberately does NOT do is flip anything on position alone. Two
-- sources putting a pin in the same clearing is how Moore Cove Falls got a
-- page about a different creek. Position is the arbiter between candidates the
-- name has already proposed, never the proposer.

-- The core of a name: no parenthetical, no SEO tail, no punctuation, folded.
-- Word boundary is \y, not \b: in Postgres's regexes \b is a backspace
-- character, so a pattern written with \b silently never matches and the tail
-- survives. The first draft of this did exactly that and the prefix tests
-- below covered for it everywhere except the two names that diverge after the
-- base -- High Falls and Rainbow Falls, the two it most needed to get right.
CREATE OR REPLACE FUNCTION name_core(raw text) RETURNS text AS $$
  SELECT nullif(trim(regexp_replace(
    regexp_replace(
      regexp_replace(
        regexp_replace(lower(coalesce(raw, '')), '\([^)]*\)', ' ', 'g'),
        '\s*[-—–]\s*(a\.k\.a\.|hiking|photos?|maps?|guides?|directions?|history|visit(ing)?|info)\y.*$', '', ''),
      '\s+(visiting|visit|info|hiking\s+guide.*)$', '', ''),
    '[^a-z0-9 ]', ' ', 'g')), '')
$$ LANGUAGE sql IMMUTABLE;

COMMENT ON FUNCTION name_core(text) IS
    'Reduces a source page title to the name it is actually about: drops '
    'parentheticals, the SEO tail ncwaterfalls appends, and punctuation. Used '
    'to compare a source name against ours without comparing their marketing.';

-- Squeeze runs of whitespace the character class above may have opened up.
CREATE OR REPLACE FUNCTION name_key(raw text) RETURNS text AS $$
  SELECT nullif(regexp_replace(name_core(raw), '\s+', ' ', 'g'), '')
$$ LANGUAGE sql IMMUTABLE;

WITH candidate AS (
    SELECT cg.id AS group_id,
           name_key(f.name) AS ours,
           name_key((SELECT c.value #>> '{}' FROM claims c
                      WHERE c.group_id = cg.id AND c.field = 'name' LIMIT 1)) AS theirs,
           -- accepted matters here. Every alias claim in the reference data
           -- carries accepted = false, and the last statement in this file
           -- deliberately writes another one to record a DISPUTE: Adams calls
           -- our Quarry Falls "Bust-Your-Butt Falls", a name we hold on Drift
           -- Falls 27 km east. Without this filter the first statement would
           -- read a contested name as agreement, which is the opposite of what
           -- the last statement wrote it down to mean.
           (SELECT array_agg(name_key(c.value #>> '{}')) FROM claims c
             WHERE c.feature_id = cg.feature_id AND c.field = 'alias'
               AND c.accepted) AS aliases,
           (6371000 * acos(least(1, greatest(-1,
                cos(radians(loc.latitude)) * cos(radians((co.value ->> 'lat')::numeric))
              * cos(radians((co.value ->> 'lon')::numeric) - radians(loc.longitude))
              + sin(radians(loc.latitude)) * sin(radians((co.value ->> 'lat')::numeric))
            )))) AS metres
    FROM claim_groups cg
    JOIN features f ON f.id = cg.feature_id
    JOIN locations loc ON loc.id = f.feature_location_id
    JOIN claims co ON co.group_id = cg.id AND co.field = 'coordinate'
    WHERE cg.source = 'ncwaterfalls'
      AND cg.identity_certain = false
)
UPDATE claim_groups cg
   SET identity_certain = true,
       note = coalesce(cg.note || ' ', '')
              || 'Re-arbitrated by migration 058: the name agreed once the page '
              || 'title''s SEO tail was removed, and the coordinate agrees too.'
  FROM candidate c
 WHERE c.group_id = cg.id
   AND c.metres <= 200
   AND c.ours IS NOT NULL AND c.theirs IS NOT NULL
   AND (
        c.ours = c.theirs                                    -- the same name
     OR c.ours LIKE c.theirs || ' %'                         -- ours adds a disambiguator
     OR c.theirs LIKE c.ours || ' %'                         -- theirs does
     OR c.theirs = ANY (coalesce(c.aliases, ARRAY[]::text[])) -- a recorded alias
   );

-- Kevin Adams calls our Quarry Falls "Bust-Your-Butt Falls"; we have that name
-- on Drift Falls, 27 km east. One of the two is wrong and this migration does
-- not guess which -- it records what he says so the conflict is visible in the
-- claims layer rather than waiting in a page title for the next matcher to
-- trip over. Both features keep the names they have.
INSERT INTO claims (group_id, feature_id, field, value, accepted, note)
SELECT cg.id, cg.feature_id, 'alias', to_jsonb('Bust-Your-Butt Falls'::text), false,
       'ncwaterfalls titles this page "Quarry Falls-A.K.A. Bust-Your-Butt Falls". '
       'We carry that alias on Drift Falls instead, 27 km away. Unresolved: '
       'recorded here so the disagreement is in the data.'
-- Keyed off the group that actually carries the title, not off the feature:
-- Quarry Falls has a second ncwaterfalls group for a page called "Cullasaja
-- River Waterfall", and attaching this claim there would have that page saying
-- something it never said.
FROM claim_groups cg
WHERE cg.source = 'ncwaterfalls'
  AND EXISTS (
      SELECT 1 FROM claims c
       WHERE c.group_id = cg.id AND c.field = 'name'
         AND c.value #>> '{}' ILIKE '%Bust-Your-Butt%')
ON CONFLICT DO NOTHING;
