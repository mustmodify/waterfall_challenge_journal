-- Turns data/swimming_holes_working.csv into real data: 27 rows are
-- swimming holes at waterfalls we already carry (swimmable = true), the
-- rest are genuinely separate places (new swimming_hole features).
--
-- Every match was checked against this database directly this session --
-- by coordinate where the CSV had one, by cross-referencing an unambiguous
-- independent detail (landowner, region, a name-source's own description)
-- where it didn't. Not a repeat of the over-eager fuzzy matching that
-- caused the Toms Creek/Mooney Falls mess earlier -- see that thread for
-- why this pass was done by hand instead.

BEGIN;

UPDATE features SET swimmable = true WHERE id = 407; -- Courthouse Falls
UPDATE features SET swimmable = true WHERE id = 1266; -- Granny Burrell Falls
UPDATE features SET swimmable = true WHERE id = 431; -- High Falls (Lake Glenville)
UPDATE features SET swimmable = true WHERE id = 417; -- Hooker Plunge
UPDATE features SET swimmable = true WHERE id = 369; -- Jawbone Falls
UPDATE features SET swimmable = true WHERE id = 391; -- Schoolhouse Plunge
UPDATE features SET swimmable = true WHERE id = 323; -- Silver Run Plunge
UPDATE features SET swimmable = true WHERE id = 326; -- Big Laurel Falls
UPDATE features SET swimmable = true WHERE id = 569; -- Duggers Creek Falls
UPDATE features SET swimmable = true WHERE id = 314; -- Elk River Falls
UPDATE features SET swimmable = true WHERE id = 387; -- Huntfish Falls
UPDATE features SET swimmable = true WHERE id = 410; -- Little Bradley Falls
UPDATE features SET swimmable = true WHERE id = 334; -- Turtleback Falls
UPDATE features SET swimmable = true WHERE id = 359; -- Bust Your Butt Falls
UPDATE features SET swimmable = true WHERE id = 839; -- Midnight Hole
UPDATE features SET swimmable = true WHERE id = 397; -- Mouse Creek Plunge
UPDATE features SET swimmable = true WHERE id = 504; -- Sunburst Swimming Hole
UPDATE features SET swimmable = true WHERE id = 463; -- Sliding Rock (Brevard)
UPDATE features SET swimmable = true WHERE id = 591; -- Sliding Rock (Cashiers)
UPDATE features SET swimmable = true WHERE id = 384; -- High Falls (DuPont)
UPDATE features SET swimmable = true WHERE id = 362; -- High Falls (Thompson River)
UPDATE features SET swimmable = true WHERE id = 490; -- Flat Laurel Creek
UPDATE features SET swimmable = true WHERE id = 386; -- Upper Creek Falls
UPDATE features SET swimmable = true WHERE id = 332; -- Secret Falls (Highlands)
UPDATE features SET swimmable = true WHERE id = 888; -- Big Creek
UPDATE features SET swimmable = true WHERE id = 350; -- Graveyard Fields Plunge
UPDATE features SET swimmable = true WHERE id = 339; -- Skinny Dip Falls

-- Azalea Park
WITH
loc AS (
    INSERT INTO locations (latitude, longitude) VALUES (35.573264, -82.491287) RETURNING id
),
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Azalea Park', 'swimming_hole', (SELECT id FROM loc), NULL, slugify('Azalea Park'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://riverlink.org/splash-into-summer-asheville-swim-guide/', 'swimming-hole-research', 'type: Pool; source owner text: City of Asheville' FROM feat;

-- Bear Creek and Wolf Creek Lakes
WITH
loc AS (
    INSERT INTO locations (latitude, longitude) VALUES (35.24440, -83.01530) RETURNING id
),
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Bear Creek and Wolf Creek Lakes', 'swimming_hole', (SELECT id FROM loc), 'Federal', slugify('Bear Creek and Wolf Creek Lakes'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://secretswimmingholes.com/directory/?state=NC', 'swimming-hole-research', 'type: Cove; source owner text: Nantahala National Forest' FROM feat;

-- Bent Creek / Lake Powhatan
WITH
loc AS (
    INSERT INTO locations (latitude, longitude) VALUES (35.4816287, -82.6260661) RETURNING id
),
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Bent Creek / Lake Powhatan', 'swimming_hole', (SELECT id FROM loc), 'Federal', slugify('Bent Creek / Lake Powhatan'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://riverlink.org/splash-into-summer-asheville-swim-guide/', 'swimming-hole-research', 'type: Cove; source owner text: Pisgah National Forest' FROM feat;

-- Big Laurel Creek
WITH
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Big Laurel Creek', 'swimming_hole', NULL, 'Federal', slugify('Big Laurel Creek'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://secretswimmingholes.com/directory/?state=NC', 'swimming-hole-research', 'type: Chute; source owner text: Nantahala National Forest' FROM feat;

-- Boone Fork Trail Falls
WITH
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Boone Fork Trail Falls', 'swimming_hole', NULL, NULL, slugify('Boone Fork Trail Falls'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://www.alltrails.com/trail/us/north-carolina/boone-fork-trail--8', 'swimming-hole-research', 'type: Pool; source owner text: Blue Ridge Parkway (Julian Price Park)' FROM feat;

-- The Bullhole
WITH
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('The Bullhole', 'swimming_hole', NULL, NULL, slugify('The Bullhole'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://secretswimmingholes.com/directory/?state=NC', 'swimming-hole-research', 'type: Pool; source owner text: River Park at Cooleemee Falls' FROM feat;

-- Cascade Falls (Deep Gap)
WITH
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Cascade Falls (Deep Gap)', 'swimming_hole', NULL, NULL, slugify('Cascade Falls (Deep Gap)'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://familydestinationsguide.com/known-swimming-north-carolina/', 'swimming-hole-research', 'type: Chute; source owner text: unconfirmed — swimmability disputed, see note' FROM feat;

-- Charles D. Owen Park
WITH
loc AS (
    INSERT INTO locations (latitude, longitude) VALUES (35.6102626, -82.4281787) RETURNING id
),
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Charles D. Owen Park', 'swimming_hole', (SELECT id FROM loc), NULL, slugify('Charles D. Owen Park'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://riverlink.org/splash-into-summer-asheville-swim-guide/', 'swimming-hole-research', 'type: Pool; source owner text: Buncombe County' FROM feat;

-- Deep Creek
WITH
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Deep Creek', 'swimming_hole', NULL, 'GSMNP', slugify('Deep Creek'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://secretswimmingholes.com/directory/?state=NC', 'swimming-hole-research', 'type: Chute; source owner text: Great Smoky Mountains National Park' FROM feat;

-- Dupont State Forest Spots
WITH
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Dupont State Forest Spots', 'swimming_hole', NULL, NULL, slugify('Dupont State Forest Spots'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://secretswimmingholes.com/directory/?state=NC', 'swimming-hole-research', 'type: Plunge; source owner text: DuPont State Recreational Forest' FROM feat;

-- Elk Shoals
WITH
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Elk Shoals', 'swimming_hole', NULL, 'State', slugify('Elk Shoals'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://secretswimmingholes.com/directory/?state=NC', 'swimming-hole-research', 'type: Basin; source owner text: New River State Park' FROM feat;

-- Eno River / Quarry
WITH
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Eno River / Quarry', 'swimming_hole', NULL, 'State', slugify('Eno River / Quarry'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://secretswimmingholes.com/directory/?state=NC', 'swimming-hole-research', 'type: Basin; source owner text: Eno River State Park' FROM feat;

-- Falls Lake S.R.A.
WITH
loc AS (
    INSERT INTO locations (latitude, longitude) VALUES (36.01170, -78.68800) RETURNING id
),
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Falls Lake S.R.A.', 'swimming_hole', (SELECT id FROM loc), 'State', slugify('Falls Lake S.R.A.'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://secretswimmingholes.com/directory/?state=NC', 'swimming-hole-research', 'type: Cove; source owner text: Falls Lake State Recreation Area' FROM feat;

-- Fires Creek
WITH
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Fires Creek', 'swimming_hole', NULL, 'Federal', slugify('Fires Creek'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://secretswimmingholes.com/directory/?state=NC', 'swimming-hole-research', 'type: Pool; source owner text: Nantahala National Forest' FROM feat;

-- Fort Hamby Park
WITH
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Fort Hamby Park', 'swimming_hole', NULL, NULL, slugify('Fort Hamby Park'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://highcountryhost.com/NC-High-Country-Where-to-Swim', 'swimming-hole-research', 'type: Cove; source owner text: Kerr Scott Reservoir (USACE)' FROM feat;

-- Goose Creek S.P.
WITH
loc AS (
    INSERT INTO locations (latitude, longitude) VALUES (35.48185, -76.90141) RETURNING id
),
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Goose Creek S.P.', 'swimming_hole', (SELECT id FROM loc), 'State', slugify('Goose Creek S.P.'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://secretswimmingholes.com/directory/?state=NC', 'swimming-hole-research', 'type: Cove; source owner text: Goose Creek State Park' FROM feat;

-- Hominy Creek Greenway
WITH
loc AS (
    INSERT INTO locations (latitude, longitude) VALUES (35.5642627, -82.5982015) RETURNING id
),
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Hominy Creek Greenway', 'swimming_hole', (SELECT id FROM loc), NULL, slugify('Hominy Creek Greenway'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://riverlink.org/splash-into-summer-asheville-swim-guide/', 'swimming-hole-research', 'type: Pool; source owner text: City of Asheville' FROM feat;

-- Jones Lake
WITH
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Jones Lake', 'swimming_hole', NULL, 'State', slugify('Jones Lake'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'http://ourstate.com/9-north-carolina-swimming-spots/', 'swimming-hole-research', 'type: Lake; source owner text: Jones Lake State Park' FROM feat;

-- Lake James Swimming Spots
WITH
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Lake James Swimming Spots', 'swimming_hole', NULL, 'State', slugify('Lake James Swimming Spots'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://secretswimmingholes.com/directory/?state=NC', 'swimming-hole-research', 'type: Cove; source owner text: Lake James State Park' FROM feat;

-- Laurel River Trail
WITH
loc AS (
    INSERT INTO locations (latitude, longitude) VALUES (35.9126133, -82.7568528) RETURNING id
),
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Laurel River Trail', 'swimming_hole', (SELECT id FROM loc), 'Federal', slugify('Laurel River Trail'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://riverlink.org/splash-into-summer-asheville-swim-guide/', 'swimming-hole-research', 'type: Chute; source owner text: Pisgah National Forest' FROM feat;

-- Little Uwharrie River
WITH
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Little Uwharrie River', 'swimming_hole', NULL, 'Federal', slugify('Little Uwharrie River'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://secretswimmingholes.com/directory/?state=NC', 'swimming-hole-research', 'type: Pool; source owner text: Uwharrie National Forest' FROM feat;

-- Looking Glass Rock Spots
WITH
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Looking Glass Rock Spots', 'swimming_hole', NULL, 'Federal', slugify('Looking Glass Rock Spots'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://secretswimmingholes.com/directory/?state=NC', 'swimming-hole-research', 'type: Chute; source owner text: Pisgah National Forest' FROM feat;

-- Neuse River
WITH
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Neuse River', 'swimming_hole', NULL, 'Federal', slugify('Neuse River'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://secretswimmingholes.com/directory/?state=NC', 'swimming-hole-research', 'type: Basin; source owner text: Croatan National Forest' FROM feat;

-- Paradise Falls
WITH
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Paradise Falls', 'swimming_hole', NULL, 'Federal', slugify('Paradise Falls'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'http://travelguidesasheville.com/allguides/the-best-swimming-holes-near-asheville-nc', 'swimming-hole-research', 'type: Plunge; source owner text: Nantahala National Forest (unconfirmed)' FROM feat;

-- Pines Recreation Area
WITH
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Pines Recreation Area', 'swimming_hole', NULL, NULL, slugify('Pines Recreation Area'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://www.discoverjacksonnc.com/listing/pines-recreation-area/463/', 'swimming-hole-research', 'type: Cove' FROM feat;

-- Reems Creek at Lake Louise
WITH
loc AS (
    INSERT INTO locations (latitude, longitude) VALUES (35.687963, -82.571280) RETURNING id
),
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Reems Creek at Lake Louise', 'swimming_hole', (SELECT id FROM loc), NULL, slugify('Reems Creek at Lake Louise'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://riverlink.org/splash-into-summer-asheville-swim-guide/', 'swimming-hole-research', 'type: Plunge; source owner text: Town of Weaverville' FROM feat;

-- South Toe River Spots
WITH
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('South Toe River Spots', 'swimming_hole', NULL, 'Federal', slugify('South Toe River Spots'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://secretswimmingholes.com/directory/?state=NC', 'swimming-hole-research', 'type: Pool; source owner text: Pisgah National Forest' FROM feat;

-- The Quarry at Carrigan Farms
WITH
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('The Quarry at Carrigan Farms', 'swimming_hole', NULL, NULL, slugify('The Quarry at Carrigan Farms'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'http://ourstate.com/9-north-carolina-swimming-spots/', 'swimming-hole-research', 'type: Quarry' FROM feat;

-- Whaleback
WITH
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Whaleback', 'swimming_hole', NULL, 'Federal', slugify('Whaleback'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://www.blueridgeoutdoors.com/hiking/swimmers-guide-blue-ridge-parkway/', 'swimming-hole-research', 'type: Pool; source owner text: Pisgah National Forest' FROM feat;

-- White Lake
WITH
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('White Lake', 'swimming_hole', NULL, NULL, slugify('White Lake'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://familydestinationsguide.com/known-swimming-north-carolina/', 'swimming-hole-research', 'type: Lake; source owner text: Town of White Lake' FROM feat;

-- Wildcat Lake
WITH
feat AS (
    INSERT INTO features (name, kind, feature_location_id, owner, slug)
    VALUES ('Wildcat Lake', 'swimming_hole', NULL, NULL, slugify('Wildcat Lake'))
    RETURNING id
)
INSERT INTO links (feature_id, url, rel, comments)
SELECT id, 'https://highcountryhost.com/NC-High-Country-Where-to-Swim', 'swimming-hole-research', 'type: Lake; source owner text: Lees-McRae College / Banner Elk' FROM feat;

INSERT INTO schema_migrations (filename) VALUES ('084_swimming_holes.sql');

COMMIT;
