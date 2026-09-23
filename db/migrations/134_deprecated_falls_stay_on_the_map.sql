-- A damaged waterfall is still a waterfall, and still belongs on the map.
--
-- coordinate_confidence excluded deprecated features, so they were given no
-- tier at all, and /features publishes on tier -- which meant a deprecation
-- silently removed a waterfall from the site. That was never the intent.
-- Skinny Dip Falls carries the only deprecation we have and its own note says
-- what it is for: "Reported still present, but no longer the feature it was --
-- worth setting expectations rather than skipping."
--
-- It has two sources agreeing on where it is, 84 m apart, so it tiers as
-- corroborated the moment the filter comes off. AllTrails shows it as an easy
-- 0.9-mile walk with 2,079 reviews. It was the WC100 that dropped it, and the
-- goals table already records that correctly -- it is listed on the Adams 500
-- and 100 and not on the WC100. The deprecation was never supposed to do that
-- job as well.
--
-- The map already knows how to show it: the card renders deprecated_reason and
-- deprecated_note as a warning. It simply never got the chance.

BEGIN;

DROP VIEW coordinate_confidence;
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
          WHERE c.field = 'coordinate'::text AND cg.identity_certain
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

INSERT INTO schema_migrations (filename) VALUES ('134_deprecated_falls_stay_on_the_map.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
