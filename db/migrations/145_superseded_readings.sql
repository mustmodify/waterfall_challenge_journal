-- A wrong reading of the right waterfall is not a rejected candidate.
--
-- jw: "that should be visible. I understand why some things are visible,
-- because like you guessed and were wrong. But this isn't the wrong
-- waterfall, it's the right waterfall with a typo."
--
-- identity_certain answers one question: is this source talking about the
-- same waterfall we are. Seven groups had it set false for a different
-- reason -- the waterfall is right and the coordinate has a typo, six of them
-- the one-degree-of-longitude error written up in docs/hikingwnc-data-issues.
-- Setting the flag was the only lever available for keeping a bad coordinate
-- out of corroboration, and it cost the truth: the admin page files those
-- readings under "rejected candidates -- not counted", which says the source
-- was describing somewhere else. It was not.
--
-- It also hid the most interesting thing on the page. Upper Silver Run Falls
-- now reads "3 of 3 sources agree", which is true and tells you nothing. The
-- fourth reading, 91 km away in South Carolina because of a single wrong
-- digit, is the reason anyone should believe the other three.
--
-- So the two questions get two columns. identity_certain stays as it was,
-- and superseded_by says that this particular reading is known wrong and
-- points at the claim that corrects it. The raw value is untouched, as
-- always; nothing is deleted; and a superseded reading stays on the page
-- where it can be read.

BEGIN;

ALTER TABLE claims ADD COLUMN IF NOT EXISTS superseded_by integer REFERENCES claims(id);

COMMENT ON COLUMN claims.superseded_by IS
  'This reading is wrong and the claim it points at is the correction. The '
  'source is still talking about this feature -- that is identity_certain. '
  'A superseded reading is excluded from corroboration and still displayed, '
  'because a caught error is evidence about the readings that survived.';

-- The seven: right waterfall, bad coordinate.
UPDATE claims c
SET superseded_by = fix.id
FROM claim_groups cg,
     LATERAL (SELECT c2.id FROM claims c2
              WHERE c2.feature_id = cg.feature_id AND c2.field = 'coordinate'
                AND c2.accepted LIMIT 1) AS fix
WHERE c.group_id = cg.id AND c.field = 'coordinate'
  AND NOT cg.identity_certain
  AND cg.note ILIKE '%coordinate claim is wrong%'
  AND fix.id IS DISTINCT FROM c.id;

-- Now that the coordinate is handled properly, give the groups their identity
-- back. Everything else these pages say -- the name, the height, the ratings
-- -- was always about our waterfall and should count.
UPDATE claim_groups
SET identity_certain = true,
    note = coalesce(note || ' ', '') ||
           'Corrected 2026-09-25: identity was never in doubt here. The bad '
        || 'coordinate is now marked superseded_by on the claim itself, which '
        || 'is what keeps it out of corroboration, so the group no longer has '
        || 'to pretend the source was describing a different waterfall.'
WHERE NOT identity_certain AND note ILIKE '%coordinate claim is wrong%';

CREATE OR REPLACE VIEW coordinate_confidence AS
WITH pts AS (
         SELECT c.feature_id,
                CASE
                    WHEN cg.source::text ~~ 'hikingwnc%'::text THEN 'hikingwnc'::character varying
                    ELSE cg.source
                END AS source,
            (c.value ->> 'lat'::text)::numeric AS lat,
            (c.value ->> 'lon'::text)::numeric AS lon
           FROM claims c
             JOIN claim_groups cg ON cg.id = c.group_id
          WHERE c.field = 'coordinate'::text AND cg.identity_certain
           AND c.superseded_by IS NULL
        ), stored AS (
         SELECT f.id AS feature_id,
            f.name,
            l.latitude AS lat,
            l.longitude AS lon
           FROM features f
             LEFT JOIN locations l ON l.id = f.feature_location_id
        ), spread AS (
         SELECT a.feature_id,
            max(111320::double precision * sqrt(power(a.lat - b.lat, 2::numeric)::double precision + power((a.lon - b.lon)::double precision * cos(radians(a.lat::double precision)), 2::double precision))) AS metres
           FROM pts a
             JOIN pts b ON b.feature_id = a.feature_id AND b.source::text > a.source::text
          GROUP BY a.feature_id
        ), nearest AS (
         SELECT p_1.feature_id,
            min(111320::double precision * sqrt(power(s_1.lat - p_1.lat, 2::numeric)::double precision + power((s_1.lon - p_1.lon)::double precision * cos(radians(s_1.lat::double precision)), 2::double precision))) AS metres
           FROM pts p_1
             JOIN stored s_1 ON s_1.feature_id = p_1.feature_id AND s_1.lat IS NOT NULL
          GROUP BY p_1.feature_id
        )
 SELECT s.feature_id,
    s.name,
    count(DISTINCT p.source) AS sources,
    round(COALESCE(spread.metres, 0::double precision)) AS sources_apart_m,
    round(nearest.metres) AS ours_off_by_m,
        CASE
            WHEN s.lat IS NULL THEN 'no coordinate'::text
            WHEN count(p.source) = 0 THEN 'unsourced'::text
            WHEN COALESCE(spread.metres, 0::double precision) > 500::double precision THEN 'disputed'::text
            WHEN count(DISTINCT p.source) >= 3 AND COALESCE(spread.metres, 0::double precision) <= 100::double precision AND nearest.metres <= 100::double precision THEN 'confirmed'::text
            WHEN count(DISTINCT p.source) >= 2 AND COALESCE(spread.metres, 0::double precision) <= 250::double precision AND nearest.metres <= 250::double precision THEN 'corroborated'::text
            WHEN count(DISTINCT p.source) = 1 AND nearest.metres <= 100::double precision THEN 'single source'::text
            ELSE 'unverified'::text
        END AS tier
   FROM stored s
     LEFT JOIN pts p ON p.feature_id = s.feature_id
     LEFT JOIN spread ON spread.feature_id = s.feature_id
     LEFT JOIN nearest ON nearest.feature_id = s.feature_id
  GROUP BY s.feature_id, s.name, s.lat, spread.metres, nearest.metres;

INSERT INTO schema_migrations (filename) VALUES ('145_superseded_readings.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
