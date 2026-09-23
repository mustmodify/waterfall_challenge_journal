-- Somewhere to say "you can't get there the usual way right now".
--
-- A storm closes a road, the trail is still fine, and the walk goes from 0.9
-- miles to 6.8 because you now park at a gate two miles down. Today both
-- numbers land in hike_distance and grade as a dispute, because the model has
-- no way to say they are the same trail at different times. jw: "we don't
-- know if data is temporary or bad data. Keep the rubric, fix the data if
-- possible."
--
-- So the temporary situation gets its own fields and stops contaminating the
-- permanent ones:
--
--   hike_distance              the normal walk, which does not change
--   detour_hike_distance       the walk while access is impaired
--   trailhead_coordinate       where the trail starts, which does not move
--   parking_coordinate         where you leave the car
--   detour_parking_coordinate  where you leave the car while the gate is shut
--   detour_trailhead_coordinate where the walk now begins
--   access_status              ok | detour | inaccessible | unverified
--
-- The pairing matters: when the road reopens you retire the detour claims and
-- the real numbers are still underneath, unedited. Nothing has to be
-- re-derived, which is the whole problem with writing the temporary figure
-- into hike_distance and hoping to remember.
--
-- TRAILHEAD IS NOT PARKING, and we have been filing one as the other. Every
-- ncwaterfalls page publishes a "Trailhead GPS" and the importer stored it as
-- parking_coordinate -- the claim note says so in as many words, "Given as
-- Trailhead GPS." 115 claims of ncwaterfalls plus one of jw's, re-filed here
-- against the field they always meant.
--
-- Usually the two are the same spot and the conflation costs nothing. A
-- detour is exactly when it costs something, because the trailhead stays put
-- and the parking moves, and the extra distance IS the gap between them.
-- Kevin's Big Cliff page states both in one paragraph: the trailhead on Horse
-- Pasture Road, and "the parking it right about here: 35.04401, -82.83826".
--
-- access_status is a claim like any other, because sources assert it -- an
-- AllTrails notice, a line in Kevin's prose, jw standing at a gate -- and a
-- claim carries a source and a date, which is what a perishable fact needs.
-- 'unverified' is storable for a source that says it does not know, but the
-- ordinary way to be unverified is to have no claim at all.

BEGIN;

-- detour_trailhead_coordinate is 27 characters and the column was
-- varchar(24), so the CHECK would have allowed a name the column could not
-- store. The enumeration is the real guard on what belongs here; the width
-- was only ever an accident of the longest name we happened to have.
-- Five views read claims.field, and Postgres will not retype a column any
-- view depends on, so they come off and go back on unchanged. Their bodies
-- are reproduced verbatim from pg_get_viewdef.
DROP VIEW IF EXISTS claim_conflicts;
DROP VIEW IF EXISTS claim_coordinate_spread;
DROP VIEW IF EXISTS coordinate_confidence;
DROP VIEW IF EXISTS route_ratings;
DROP VIEW IF EXISTS trail_engagement;

ALTER TABLE claims ALTER COLUMN field TYPE text;

ALTER TABLE claims DROP CONSTRAINT claims_field_known;
ALTER TABLE claims DROP CONSTRAINT claims_value_shape;

ALTER TABLE claims ADD CONSTRAINT claims_field_known CHECK (
  field::text = ANY (ARRAY[
    'coordinate','parking_coordinate','view_coordinate','coordinate_raw',
    'trailhead_coordinate',
    'detour_parking_coordinate','detour_trailhead_coordinate','detour_hike_distance',
    'access_status',
    'height','elevation_ft','elevation_gain_ft','petzoldt',
    'beauty_rating','photo_rating','solitude_rating',
    'hike_distance','accessibility','owner','name','alias',
    'photos_count','completed_hikes_count','reviews_count']::text[]));

ALTER TABLE claims ADD CONSTRAINT claims_value_shape CHECK (
  CASE
    WHEN field::text = ANY (ARRAY['coordinate','parking_coordinate','view_coordinate',
                                  'trailhead_coordinate','detour_parking_coordinate',
                                  'detour_trailhead_coordinate']::text[])
      THEN jsonb_typeof(value -> 'lat') = 'number'
       AND jsonb_typeof(value -> 'lon') = 'number'
       AND (value ->> 'lat')::numeric BETWEEN -90 AND 90
       AND (value ->> 'lon')::numeric BETWEEN -180 AND 180
    WHEN field::text = 'access_status'
      THEN jsonb_typeof(value) = 'string'
       AND (value #>> '{}') = ANY (ARRAY['ok','detour','inaccessible','unverified']::text[])
    WHEN field::text = ANY (ARRAY['elevation_ft','elevation_gain_ft']::text[])
      THEN jsonb_typeof(value) = 'number'
    WHEN field::text = 'petzoldt'
      THEN jsonb_typeof(value) = 'number' AND (value #>> '{}')::numeric >= 0
    WHEN field::text = ANY (ARRAY['beauty_rating','photo_rating','solitude_rating']::text[])
      THEN jsonb_typeof(value) = 'number'
       AND (value #>> '{}')::numeric BETWEEN 1 AND 10
    WHEN field::text = ANY (ARRAY['photos_count','completed_hikes_count','reviews_count']::text[])
      THEN jsonb_typeof(value) = 'number' AND (value #>> '{}')::numeric >= 0
    ELSE jsonb_typeof(value) = 'string' AND (value #>> '{}') <> ''
  END);

-- Re-file the coordinates that were always trailheads.
UPDATE claims c
SET field = 'trailhead_coordinate'
FROM claim_groups cg
WHERE cg.id = c.group_id
  AND c.field = 'parking_coordinate'
  AND (c.note = 'Given as Trailhead GPS.' OR c.note ILIKE '%trailhead%');

-- A detour walk is a distance like any other, so it normalizes and reports
-- units the same way.
CREATE OR REPLACE FUNCTION claim_units(raw text, field text) RETURNS text
    LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN field IN ('height', 'elevation_ft', 'elevation_gain_ft') THEN 'feet'
    WHEN field IN ('hike_distance', 'detour_hike_distance') THEN 'feet'
    WHEN field IN ('coordinate', 'parking_coordinate', 'view_coordinate',
                   'coordinate_raw', 'trailhead_coordinate',
                   'detour_parking_coordinate', 'detour_trailhead_coordinate')
      THEN 'degrees'
    WHEN field IN ('beauty_rating', 'photo_rating', 'solitude_rating') THEN 'of 10'
    ELSE NULL
  END;
$$;

CREATE OR REPLACE FUNCTION normalize_claim_value(raw text, field text, source text)
    RETURNS text LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN field IN ('name', 'alias') THEN name_display(raw)
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

CREATE VIEW claim_conflicts AS
SELECT c.feature_id,
    f.name,
    c.field,
    count(DISTINCT c.value) AS distinct_values,
    count(*) FILTER (WHERE c.accepted) AS accepted,
    string_agg(DISTINCT cg.source::text, ', '::text ORDER BY (cg.source::text)) AS sources
   FROM claims c
     JOIN claim_groups cg ON cg.id = c.group_id
     JOIN features f ON f.id = c.feature_id
  WHERE c.field::text <> 'alias'::text
  GROUP BY c.feature_id, f.name, c.field
 HAVING count(DISTINCT c.value) > 1 OR count(*) FILTER (WHERE c.accepted) = 0;

CREATE VIEW claim_coordinate_spread AS
WITH pts AS (
         SELECT c.feature_id,
            cg.source,
            c.accepted,
            (c.value ->> 'lat'::text)::numeric AS lat,
            (c.value ->> 'lon'::text)::numeric AS lon
           FROM claims c
             JOIN claim_groups cg ON cg.id = c.group_id
          WHERE c.field::text = 'coordinate'::text
        )
 SELECT s.feature_id,
    f.name,
    round(max(111320::double precision * sqrt(power(a.lat - b.lat, 2::numeric)::double precision + power((a.lon - b.lon)::double precision * cos(radians(a.lat::double precision)), 2::double precision)))) AS metres_apart,
    max(s.sources) AS sources,
    bool_or(s.decided) AS decided
   FROM ( SELECT pts.feature_id,
            count(DISTINCT pts.source) AS sources,
            bool_or(pts.accepted) AS decided
           FROM pts
          GROUP BY pts.feature_id) s
     JOIN pts a ON a.feature_id = s.feature_id
     JOIN pts b ON b.feature_id = s.feature_id AND b.source::text > a.source::text
     JOIN features f ON f.id = s.feature_id
  GROUP BY s.feature_id, f.name;

CREATE VIEW coordinate_confidence AS
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
          WHERE c.field::text = 'coordinate'::text AND cg.identity_certain
        ), stored AS (
         SELECT f.id AS feature_id,
            f.name,
            l.latitude AS lat,
            l.longitude AS lon
           FROM features f
             LEFT JOIN locations l ON l.id = f.feature_location_id
          WHERE f.deprecated_reason IS NULL
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

CREATE VIEW route_ratings AS
SELECT cg.id AS group_id,
    cg.feature_id,
    f.name,
    cg.source,
    cg.url,
    regexp_replace(d.value #>> '{}'::text[], '[^0-9.].*$'::text, ''::text)::numeric AS miles,
    (g.value #>> '{}'::text[])::integer AS gain_ft,
    round(regexp_replace(d.value #>> '{}'::text[], '[^0-9.].*$'::text, ''::text)::numeric + ((g.value #>> '{}'::text[])::integer)::numeric / 500.0, 2) AS petzoldt,
    petzoldt_band(round(regexp_replace(d.value #>> '{}'::text[], '[^0-9.].*$'::text, ''::text)::numeric + ((g.value #>> '{}'::text[])::integer)::numeric / 500.0, 2)) AS band
   FROM claim_groups cg
     JOIN features f ON f.id = cg.feature_id
     JOIN claims d ON d.group_id = cg.id AND d.field::text = 'hike_distance'::text
     JOIN claims g ON g.group_id = cg.id AND g.field::text = 'elevation_gain_ft'::text
  WHERE (d.value #>> '{}'::text[]) ~ '^[0-9]'::text;

CREATE VIEW trail_engagement AS
SELECT cg.id AS group_id,
    cg.feature_id,
    f.name AS feature_name,
    cg.source,
    cg.url,
    cg.identity_certain,
    (p.value #>> '{}'::text[])::integer AS photos,
    (h.value #>> '{}'::text[])::integer AS hikes,
    (r.value #>> '{}'::text[])::integer AS reviews,
    round(((p.value #>> '{}'::text[])::numeric) / ((h.value #>> '{}'::text[])::numeric), 4) AS photos_per_hike
   FROM claim_groups cg
     JOIN features f ON f.id = cg.feature_id
     JOIN claims p ON p.group_id = cg.id AND p.field::text = 'photos_count'::text
     JOIN claims h ON h.group_id = cg.id AND h.field::text = 'completed_hikes_count'::text
     LEFT JOIN claims r ON r.group_id = cg.id AND r.field::text = 'reviews_count'::text
  WHERE ((h.value #>> '{}'::text[])::numeric) > 0::numeric AND cg.identity_certain;

INSERT INTO schema_migrations (filename) VALUES ('130_detour_and_access_status.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
