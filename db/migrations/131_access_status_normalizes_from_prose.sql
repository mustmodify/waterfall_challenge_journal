-- access_status is raw prose that normalizes to a verdict, like every other
-- claim.
--
-- 130 constrained value itself to the four words, which had it backwards. jw:
-- "a raw claim should be something like the raw input ie 'closure notice' and
-- the normalized claim is ok|detour|inaccessible|unverified -- and the
-- normalizer should create an 'unverified' fact if we don't have any claims
-- about a detour."
--
-- So value keeps what the source actually published:
--
--   "Trails are temporarily closed to assess conditions and address damage
--    following Hurricane Helene"                        -> inaccessible
--   "The road to the trailhead is closed and will probably never re-open.
--    It's an easy hike on the road, just longer."       -> detour
--   "As of June 2024, this area is closed indefinitely" -> inaccessible
--
-- and normalized_value carries the verdict the map can act on. That keeps the
-- rule we have been applying all day: claims hold what was said, normalizing
-- decides what it means, and the raw text survives so a wrong reading can be
-- seen and argued with rather than silently baked in.
--
-- READING A CLOSURE IS NOT EASY, and the normalizer is deliberately cautious
-- about it. A road closed with the trail still walkable is a detour; a trail
-- or area closed is inaccessible. Those differ by which noun the word
-- "closed" attaches to, which a regex reads badly. So anything that mentions
-- a closure without clearly saying you can still walk in comes out
-- inaccessible, because the costly mistake is telling someone a shut trail is
-- open. Review can promote a detour to its proper reading; nobody is harmed
-- by an over-cautious default.
--
-- EVERY WATERFALL GETS AN ACCESS FACT, even with nothing to go on, because
-- that is the point jw is making about a fluid situation. Silence is not the
-- same as "fine" -- after a storm it is the most common state and the least
-- safe assumption -- so a feature with no access claim gets an unverified
-- fact saying so out loud. Its score is null rather than zero: we are not
-- grading the access badly, we have not graded it at all.

BEGIN;

ALTER TABLE claims DROP CONSTRAINT claims_value_shape;
ALTER TABLE claims ADD CONSTRAINT claims_value_shape CHECK (
  CASE
    WHEN field = ANY (ARRAY['coordinate','parking_coordinate','view_coordinate',
                            'trailhead_coordinate','detour_parking_coordinate',
                            'detour_trailhead_coordinate']::text[])
      THEN jsonb_typeof(value -> 'lat') = 'number'
       AND jsonb_typeof(value -> 'lon') = 'number'
       AND (value ->> 'lat')::numeric BETWEEN -90 AND 90
       AND (value ->> 'lon')::numeric BETWEEN -180 AND 180
    WHEN field = ANY (ARRAY['elevation_ft','elevation_gain_ft']::text[])
      THEN jsonb_typeof(value) = 'number'
    WHEN field = 'petzoldt'
      THEN jsonb_typeof(value) = 'number' AND (value #>> '{}')::numeric >= 0
    WHEN field = ANY (ARRAY['beauty_rating','photo_rating','solitude_rating']::text[])
      THEN jsonb_typeof(value) = 'number'
       AND (value #>> '{}')::numeric BETWEEN 1 AND 10
    WHEN field = ANY (ARRAY['photos_count','completed_hikes_count','reviews_count']::text[])
      THEN jsonb_typeof(value) = 'number' AND (value #>> '{}')::numeric >= 0
    -- access_status falls here with the rest of the prose fields.
    ELSE jsonb_typeof(value) = 'string' AND (value #>> '{}') <> ''
  END);

-- The verdict the map acts on, read out of whatever the source wrote.
CREATE OR REPLACE FUNCTION access_verdict(raw text) RETURNS text
    LANGUAGE plpgsql IMMUTABLE AS $fn$
DECLARE
    t         text;
    blocked   boolean;   -- something is shut
    walkable  boolean;   -- but you can still get there on foot
BEGIN
    t := coalesce(raw, '');
    IF btrim(t) = '' THEN
        RETURN 'unverified';
    END IF;
    -- Already a verdict: a claim we wrote ourselves.
    IF lower(btrim(t)) = ANY (ARRAY['ok','detour','inaccessible','unverified']::text[]) THEN
        RETURN lower(btrim(t));
    END IF;

    blocked := t ~* ('(closed|closure|gated|inaccessible|no access|impassable|'
                  || 'destroyed|washed out|do not (enter|visit))');

    -- Two signals rather than one pattern, because a detour notice almost
    -- always contains a closure notice inside it. "The road to the trailhead
    -- is closed ... it''s an easy hike on the road, just longer" is shut AND
    -- walkable, and reading only the first half gets it exactly wrong.
    walkable := t ~* ('((just|but|only|simply)\s+longer|longer (hike|walk|route|by)|'
                   || 'walk(ing)? (in|up|around|the road|on the road|from the gate)|'
                   || 'hik(e|ing) (in|up|around|the road|on the road|from the gate)|'
                   || 'on foot|by foot|'
                   || 'add(s|ing|ed)?[^.]{0,24}[0-9.]+\s*(mile|mi\y|km|yard|feet|foot)|'
                   || 'park(ing)? (at|before|by) the (gate|closure)|'
                   || 'detour|re-?route)');

    IF blocked AND walkable THEN RETURN 'detour'; END IF;
    IF blocked                THEN RETURN 'inaccessible'; END IF;
    IF walkable               THEN RETURN 'detour'; END IF;
    IF t ~* '(reopen|re-open|is open|now open|accessible|no (issues|damage)|passable|in good condition)'
        THEN RETURN 'ok';
    END IF;
    RETURN 'unverified';
END;
$fn$;

COMMENT ON FUNCTION access_verdict(text) IS
    'ok | detour | inaccessible | unverified, read out of a source''s prose. '
    'Two signals, not one pattern: whether something is shut, and whether you '
    'can still walk in. A detour notice nearly always contains a closure '
    'notice inside it, so reading only the first half gets it backwards. Shut '
    'with no sign of a way in comes out inaccessible, because the costly '
    'mistake is telling someone a closed trail is open.';

CREATE OR REPLACE FUNCTION normalize_claim_value(raw text, field text, source text)
    RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN field IN ('name', 'alias') THEN name_display(raw)
    WHEN field = 'access_status' THEN access_verdict(raw)
    WHEN field IN ('hike_distance', 'detour_hike_distance') THEN
      (hike_distance_feet(
         coalesce(
           nullif(btrim(regexp_replace(
             regexp_replace(
               regexp_replace(
                 regexp_replace(coalesce(raw, ''),
                   '\((?![^)]*(each way|one way|out and back|round trip))[^)]*\)',
                   ' ', 'gi'),
                 '\m(approx\.?|approximately|about|around|roughly|est\.?|estimated|circa|ca\.?)\M',
                 ' ', 'gi'),
               '~', ' ', 'g'),
             '\s+', ' ', 'g'), ' .,;'), ''),
           coalesce(raw, '')))
       * CASE WHEN source = 'ncwaterfalls'
                AND coalesce(raw, '') !~* 'each way|one way|out and back|round trip'
              THEN 2 ELSE 1 END)::text
    ELSE nullif(btrim(regexp_replace(
      regexp_replace(
        regexp_replace(
          regexp_replace(coalesce(raw, ''),
            '\((?![^)]*(each way|one way|out and back|round trip))[^)]*\)',
            ' ', 'gi'),
          '\m(approx\.?|approximately|about|around|roughly|est\.?|estimated|circa|ca\.?)\M',
          ' ', 'gi'),
        '~', ' ', 'g'),
      '\s+', ' ', 'g'), ' .,;'), '')
  END;
$$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'johnathonwright') THEN
    ALTER FUNCTION access_verdict(text) OWNER TO johnathonwright;
  END IF;
END $$;

-- unverified rejoins the ladder it was on in ARCHITECTURE.md's first draft.
ALTER TABLE facts DROP CONSTRAINT facts_stage_known;
ALTER TABLE facts ADD CONSTRAINT facts_stage_known CHECK (
  confidence_stage = ANY (ARRAY[
    'unverified',
    'disputed', 'single_source', 'two_sources', 'corroborated',
    'four_sources', 'five_sources',
    'ai_reviewed', 'human_reviewed', 'confirmed_irl', 'confirmed_and_agreed',
    'disambiguated']::text[]));

-- Rerunnable.
DELETE FROM facts WHERE key = 'access_status';

WITH pts AS (
    SELECT DISTINCT ON (c.feature_id, s.src)
           c.feature_id, s.src,
           coalesce(c.normalized_value #>> '{}',
                    access_verdict(c.value #>> '{}')) AS verdict
    FROM claims c
    JOIN claim_groups cg ON cg.id = c.group_id
    CROSS JOIN LATERAL (SELECT CASE WHEN cg.source LIKE 'hikingwnc%'
                                    THEN 'hikingwnc' ELSE cg.source END) AS s(src)
    WHERE c.field = 'access_status' AND cg.identity_certain
    ORDER BY c.feature_id, s.src, c.accepted DESC, c.id
),
agreement AS (
    SELECT a.feature_id, a.verdict, count(*) AS agreeing
    FROM pts a JOIN pts b ON b.feature_id = a.feature_id AND b.verdict = a.verdict
    GROUP BY a.feature_id, a.verdict
),
totals AS (SELECT feature_id, count(*) AS n FROM pts GROUP BY feature_id),
winner AS (
    SELECT DISTINCT ON (a.feature_id) a.feature_id, a.verdict, a.agreeing, t.n
    FROM agreement a JOIN totals t ON t.feature_id = a.feature_id
    -- A tie goes to the least optimistic reading, for the same reason the
    -- normalizer does.
    ORDER BY a.feature_id, a.agreeing DESC,
             array_position(ARRAY['inaccessible','detour','ok','unverified'], a.verdict)
)
INSERT INTO facts (feature_id, key, value, value_type, units,
                   confidence_stage, confidence_score, notes)
SELECT f.id, 'access_status',
       coalesce(w.verdict, 'unverified'), 'string', NULL,
       CASE WHEN w.feature_id IS NULL THEN 'unverified'
            ELSE agreement_stage(w.agreeing::int, w.n::int) END,
       CASE WHEN w.feature_id IS NULL THEN NULL
            ELSE agreement_score(w.agreeing::int, w.n::int) END,
       CASE WHEN w.feature_id IS NULL
            THEN 'No source has said anything about getting here, which after a storm is the '
              || 'commonest state and the least safe assumption.'
            ELSE agreement_note(w.agreeing::int, w.n::int, 'on how accessible this is')
       END
FROM features f
LEFT JOIN winner w ON w.feature_id = f.id
WHERE f.kind = 'waterfall' AND f.deprecated_reason IS NULL;

INSERT INTO schema_migrations (filename) VALUES ('131_access_status_normalizes_from_prose.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
