-- Put the source's own words back in the height claims.
--
-- jw, looking at an OpenStreetMap row reading 33 with a note saying
-- height=10: "I would expect observed to be 10 meters."
--
-- Quite right, and it is the same objection as "claims is supposed to be raw
-- data". The height importers converted to feet on the way IN and stored the
-- result, so value held a number nobody wrote, while the source's own text
-- survived only in a note -- or, for hikingwnc, not at all. Observed was
-- showing our arithmetic and calling it an observation.
--
-- So the columns swap roles, which is what 115 through 119 set up: value goes
-- back to what the source said, normalized_value takes the feet.
--
--   openstreetmap  10 m                                       ->   33
--   hikingwnc      Approx 50' (4 drops)                       ->   50
--   ncwaterfalls   Steep, cascading falls about 18 feet high  ->   18
--
-- NO NUMBER CHANGES HERE. normalized_value is set from the figure the
-- importer already computed and the site already publishes, not from a fresh
-- parse of the restored text. Re-parsing 400 heights and silently moving the
-- ones that came out different would be a data change wearing the clothes of
-- a provenance fix. height_feet() is defined so that comparison can be made
-- deliberately, and a later migration can act on what it finds.
--
-- Where the raw is recoverable: OpenStreetMap 59 of 59 and ncwaterfalls 106
-- of 107 from their own notes, hikingwnc 218 of 241 from
-- data/hiking_wnc_falls.json matched on the group url. The 24 that are not
-- keep the bare number, because inventing text for them would be worse than
-- admitting we dropped it.
--
-- OpenStreetMap is written "10 m" rather than the tag's bare "10". The metre
-- is part of that key's definition rather than our inference -- a bare height
-- tag means metres by specification -- and writing the unit down is the whole
-- point here, since leaving it unrecorded is what produced a 197-foot Wildcat
-- Falls.

BEGIN;

CREATE OR REPLACE FUNCTION height_feet(raw text) RETURNS numeric
    LANGUAGE plpgsql IMMUTABLE AS $fn$
DECLARE
    t   text;
    num numeric;
BEGIN
    t := lower(coalesce(raw, ''));
    IF t = '' OR t ~ '^\s*[—–-]\s*$' THEN
        RETURN NULL;
    END IF;

    -- First number wins: the rule hike_distance_feet() uses, with the same
    -- weakness. "Upper 7-foot drop with a lower long slide about 16 feet
    -- high" takes the 7. Predictable beats clever.
    num := nullif(substring(t from '([0-9]+(?:\.[0-9]+)?)'), '')::numeric;
    IF num IS NULL THEN
        RETURN NULL;
    END IF;

    -- A foot mark or the word: already feet.
    IF t ~ '\yft\y|foot|feet' OR t LIKE '%''%' THEN
        RETURN round(num);
    END IF;
    -- Metres, spelled out or the bare unit OpenStreetMap implies.
    IF t ~ 'metre|meter|\ym\y' THEN
        RETURN round(num * 3.28084);
    END IF;
    -- Bare number: feet, which is what every source here writes in.
    RETURN round(num);
END;
$fn$;

COMMENT ON FUNCTION height_feet(text) IS
    'Height in feet from whatever the source wrote. Metres only when said, '
    'because a bare number in these sources means feet -- except '
    'OpenStreetMap, whose values carry an explicit m once 122 restores them.';

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'johnathonwright') THEN
    ALTER FUNCTION height_feet(text) OWNER TO johnathonwright;
  END IF;
END $$;

-- 0. Both constraints encode the old shape, so they come off first and go
--    back on at the end. claims_field_known simply lists height_ft;
--    claims_value_shape is the interesting one -- it requires a height to be
--    a JSON number greater than zero, which is the schema itself insisting
--    that a height claim IS a number of feet. With the field renamed, height
--    falls through to the general rule: a non-empty string, like every other
--    field that keeps what its source wrote.
ALTER TABLE claims DROP CONSTRAINT claims_field_known;
ALTER TABLE claims DROP CONSTRAINT claims_value_shape;

-- 1. Keep the published figure before value is overwritten. It is already
--    the number the site shows, so nothing here changes what anyone sees.
UPDATE claims c SET normalized_value = c.value
WHERE c.field = 'height_ft' AND jsonb_typeof(c.value) = 'number';

-- 2. Drop the unit from the field name and put the words back in the value,
--    in one statement, because claims_value_shape demands a number while the
--    field is called height_ft and demands a string the moment it is not.
--    That constraint was the schema asserting the thing being fixed here:
--    that a height claim IS a number of feet.
--
--    features.height_ft keeps its name. That column really is feet, and the
--    site reads it.
UPDATE claims c
SET field = 'height',
    value = to_jsonb(COALESCE(
      -- OpenStreetMap: the tag, carrying the unit its specification implies.
      CASE WHEN cg.source = 'openstreetmap'
           THEN substring(c.note from 'height=([0-9]+(?:\.[0-9]+)?)') || ' m' END,
      -- ncwaterfalls: the prose its own note was quoting.
      CASE WHEN cg.source = 'ncwaterfalls'
           THEN substring(c.note from '^From "(.*)"\.?$') END,
      -- Nothing recoverable yet: the bare number as text. hikingwnc's real
      -- words arrive in step 3.
      c.value #>> '{}')),
    -- The ncwaterfalls note only ever quoted the value it now holds.
    note = CASE WHEN cg.source = 'ncwaterfalls'
                 AND substring(c.note from '^From "(.*)"\.?$') IS NOT NULL
                THEN NULL ELSE c.note END
FROM claim_groups cg
WHERE cg.id = c.group_id AND c.field = 'height_ft';

-- 3. hikingwnc kept nothing in the database at all, so its words come from
--    data/hiking_wnc_falls.json, matched on the group url. Separate from
--    step 2 because an UPDATE cannot join its own target table.
UPDATE claims c
SET value = to_jsonb(v.raw)
FROM (VALUES
  (732, 'Approx 50'' (4 drops)'),
  (682, 'Approx 40'''),
  (78, 'Approx 50'''),
  (147, 'Approx 45'''),
  (489, 'Approx 20'''),
  (923, 'Approx 30'''),
  (1234, 'Approx 50'''),
  (1413, 'Approx 50'''),
  (1676, 'Approx 25'''),
  (1704, 'Approx 50''-55'''),
  (1806, 'Approx 70-80'''''),
  (1810, 'Approx 50'''),
  (4953, 'Approx 25'''),
  (6710, 'Approx 75'' (left falls) 100'' (right falls)'),
  (5601, '50'''),
  (764, 'Approx 275'''),
  (556, 'Approx 50'''),
  (1319, 'Approx 55-60'''),
  (1474, 'Approx 58'''),
  (481, 'Approx 20'''),
  (4893, 'Approx 30'''),
  (249, 'Approx 80'' (numerous drops)'),
  (2410, 'Approx 80'''),
  (442, 'Approx 80'''),
  (2426, 'Approx 15'''),
  (4487, '100'''),
  (4032, 'Approx 100'' (above and below trail)'),
  (3880, '15'''),
  (740, 'Approx 125'' (2 drops)'),
  (3792, 'Approx 50'''),
  (2450, 'Approx 60'''),
  (3645, '90-100'''),
  (1305, 'Approx 12-15'''),
  (1783, 'Approx 45'''),
  (1180, 'Approx 120'''),
  (4444, '300'' (but you can''t see all of it from one place)'),
  (1752, 'Approx 50'''),
  (1799, 'Approx 15'''),
  (1698, 'Approx 25''-30'' (cluttered)'),
  (2311, 'Approx 11'''),
  (1728, 'Approx 12'' (100+ feet wide)'),
  (1148, 'Approx 25'''),
  (1712, 'Approx 12'''),
  (2344, 'Approx 6'''),
  (4010, '50'' (2 drops)'),
  (1141, 'Approx 40'''),
  (279, 'Approx 15''-20'''),
  (4121, '50'''),
  (628, 'Approx 20'''),
  (426, 'Approx 120'''),
  (1825, 'Approx 20-25'''),
  (2418, 'Approx 55'''),
  (2495, 'Approx 18'''),
  (1670, 'Approx 12'''),
  (4495, 'Approx 25'''),
  (2287, 'Approx 35'''),
  (1351, 'Approx 30'' (multiple drops)'),
  (1466, 'Approx 50'''),
  (590, 'Approx 20'''),
  (202, 'Approx 345'''),
  (666, 'Approx 18'''),
  (295, 'Approx 50'''),
  (4945, '25'''),
  (434, 'Approx 80'''),
  (1458, 'Approx 30'''),
  (4922, 'Approx 30''-35'' (cluttered)'),
  (1126, 'Approx 15'''),
  (418, 'Approx 35'''),
  (3525, 'Approx 120'''),
  (756, 'Approx 25'''),
  (748, 'Approx 10'''),
  (116, 'Approx 15'''),
  (1791, 'Approx 20'''),
  (505, 'Approx 30''-35'''),
  (210, 'Approx 16'''),
  (497, 'Approx 30'''),
  (155, 'Approx 25'''),
  (2295, 'Approx 25'' (two drops with a cool ledge in the middle)'),
  (1156, 'Approx 30'''),
  (4877, '30''-35'''),
  (1298, 'Approx 25+'' (most hidden in rhodos)'),
  (1419, 'Approx 20'''),
  (3738, 'Approx 25'),
  (3746, '25'''),
  (4930, 'Approx 15''-18'' (cluttered)'),
  (257, 'Approx 30'''),
  (1196, 'Approx 15'''),
  (219, 'Approx 320'''),
  (410, 'Approx 50'''),
  (597, 'Approx 60''-70'''),
  (1291, 'Approx 25'''),
  (1102, 'Approx 18'''),
  (170, 'Approx 12'''),
  (513, 'Approx 350'' (over numerous drops)'),
  (473, 'Approx 15'' drop and 60-80'' rockslide'),
  (4525, 'Approx 30'''),
  (336, 'Approx 80-100'' (numerous drops)'),
  (139, 'Approx 290'' over numerous drops and slides'),
  (1277, 'Approx 15'''),
  (311, 'Approx 25'''),
  (2279, 'Approx 75'''),
  (636, 'Approx 50'''),
  (2503, 'Approx 14'''),
  (109, 'Approx 10''-12'''),
  (1134, 'Approx 55''-60'''),
  (4077, 'Approx 50 (multiple drops)'),
  (124, 'Approx 12'' initial drop 100''-120'' rockslide'),
  (2472, 'Approx 75'''),
  (163, 'Approx 50'' over multiple drops (steps)'),
  (1327, 'Approx 28'''),
  (2335, 'Approx 70'''),
  (70, 'Approx 50'''),
  (2352, 'Approx 40'''),
  (1312, 'Approx 12''-14'''),
  (1118, 'Approx 75''-80'''),
  (241, 'Approx 16''-18'''),
  (344, 'Approx 50'' (if you count from the uppermost drop)'),
  (4885, '20''-25'''),
  (1398, 'Approx 20'''),
  (1250, 'Approx 75'''),
  (2303, 'Approx 50''-60'''),
  (5178, 'Approx 30-35'''),
  (4054, '35'''),
  (4768, '20'''),
  (5186, 'Approx 15'''),
  (1086, 'Approx 80''-90'''),
  (1374, 'Approx 18'''),
  (1382, 'Approx 60'''),
  (1775, 'Approx 30'''),
  (3784, '35'''),
  (4832, 'Approx 35'''),
  (1335, 'Approx 18'''),
  (2319, 'Approx 18'''),
  (94, 'Approx 30'''),
  (1188, 'Approx 180'''),
  (4517, 'Approx 30'''),
  (651, 'Approx 351'''),
  (359, 'Approx 60'''),
  (1212, 'Approx 65'''),
  (450, 'Approx 25'''),
  (1242, 'Approx 45'''),
  (457, 'Approx 15'''),
  (1720, 'Approx 50''-55'''),
  (287, 'Approx 30'''),
  (2511, 'Approx 40'''),
  (2458, 'Approx 120'' but hard to see from one location'),
  (605, 'Approx 25'''),
  (227, 'Approx 20'''),
  (1204, 'Approx 30'''),
  (3776, '30'''),
  (1270, 'Approx 30'''),
  (4960, 'Approx 45'''),
  (402, 'Approx 25'''),
  (327, 'Approx 40'''),
  (1343, 'Approx 18'''),
  (1358, 'Approx 12-15'''),
  (3896, 'Approx 35'''),
  (3872, '25'''),
  (4840, 'Approx 20'''),
  (1172, 'Approx 80'''),
  (1220, 'Approx 60'''),
  (4686, 'Approx 18'''),
  (1482, 'Approx 35'''),
  (1390, 'Approx 120'' total (includes upper drop) / 50''-60'' for main drop'),
  (3754, '18'''),
  (1760, 'Approx 50''-55'''),
  (265, 'Approx 80'''),
  (465, 'Approx 12''-14'''),
  (4062, '50'''),
  (1284, 'Approx 10'''),
  (1833, 'Approx 50'''),
  (1841, 'Approx 15-20'' over numerous widely spaced drops'),
  (4085, 'Approx 90 feet'),
  (186, 'Approx 20'''),
  (3848, '20'''),
  (194, 'Approx 25'''),
  (2582, 'Approx 60'' (two distinct drops)'),
  (351, 'Approx 12''-14'''),
  (3730, 'Approx 8'''),
  (1427, 'Approx 120'''),
  (303, 'Approx 100'''),
  (1406, 'Approx 12'''),
  (1849, 'Approx 20-22'''''),
  (3864, '70'' main drop'),
  (1744, 'Approx 45'''),
  (178, 'Approx 125'''),
  (4694, 'Approx 60'' (maybe more)'),
  (2442, 'Approx 25'' (three sections)'),
  (131, 'Approx 30'''),
  (1164, 'Approx 35'''),
  (1443, 'Approx 25'''),
  (102, 'Approx 30'''),
  (6550, '50+ ft'),
  (1736, 'Approx: 90'''),
  (3722, 'Approx 15'''),
  (272, 'Approx 20'' over a series of drops'),
  (1366, 'Approx 12'''),
  (2434, 'Approx 55'' (Main Drop Only)'),
  (1258, 'Approx 100'''),
  (86, 'Approx 30'' (sliding distance is about 60'')'),
  (1435, 'Approx 70'''),
  (674, 'Approx 45'''),
  (1094, 'Approx 55'''),
  (1110, 'Approx 50''-60'''),
  (620, 'Approx 80-100'''),
  (2360, 'Approx 25'' (3 drops)'),
  (2327, 'Approx 50'''),
  (2368, 'Approx 12-15'''),
  (33, '14'''),
  (3447, 'Approx 30'' (two drops)'),
  (4869, 'Approx 17'''),
  (3939, '30'''),
  (3856, 'Approx 40'''),
  (2487, 'Approx 16'''),
  (319, 'Approx 55'''),
  (1817, 'Approx 15'''),
  (3888, 'Approx 50'''),
  (4678, 'Approx 50''-55''')
) AS v(claim_id, raw)
WHERE c.id = v.claim_id AND c.field = 'height';

-- 4. facts follows, or the feature page stops joining a claim to its grade.
--    The key keeps meaning feet there, which is correct: facts IS the
--    normalized side.
UPDATE facts SET key = 'height' WHERE key = 'height_ft';

-- 5. The units column describes the normalized value, which is still feet.
CREATE OR REPLACE FUNCTION claim_units(raw text, field text) RETURNS text
    LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN field IN ('height', 'elevation_ft', 'elevation_gain_ft') THEN 'feet'
    WHEN field = 'hike_distance' THEN 'feet'
    WHEN field IN ('coordinate', 'parking_coordinate', 'view_coordinate',
                   'coordinate_raw') THEN 'degrees'
    WHEN field IN ('beauty_rating', 'photo_rating', 'solitude_rating') THEN 'of 10'
    ELSE NULL
  END;
$$;

ALTER TABLE claims ADD CONSTRAINT claims_field_known CHECK (
  field::text = ANY (ARRAY[
    'coordinate','parking_coordinate','view_coordinate','coordinate_raw',
    'height','elevation_ft','elevation_gain_ft','petzoldt',
    'beauty_rating','photo_rating','solitude_rating',
    'hike_distance','accessibility','owner','name','alias',
    'photos_count','completed_hikes_count','reviews_count']::text[]));

ALTER TABLE claims ADD CONSTRAINT claims_value_shape CHECK (
  CASE
    WHEN field::text = ANY (ARRAY['coordinate','parking_coordinate','view_coordinate']::text[])
      THEN jsonb_typeof(value -> 'lat') = 'number'
       AND jsonb_typeof(value -> 'lon') = 'number'
       AND (value ->> 'lat')::numeric BETWEEN -90 AND 90
       AND (value ->> 'lon')::numeric BETWEEN -180 AND 180
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

INSERT INTO schema_migrations (filename) VALUES ('122_restore_raw_heights.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
