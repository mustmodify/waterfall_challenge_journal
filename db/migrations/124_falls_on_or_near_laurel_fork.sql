-- A confusion set for the Laurel Fork cluster (SC), where the source itself
-- catalogued one waterfall twice.
--
-- Unlike Falls Named Tom, nothing here is a name collision across the state.
-- These are seven waterfalls inside 400 m of each other on two watercourses
-- that meet, and the only way to tell which is which is to know the creek.

BEGIN;

INSERT INTO confusion_sets (name) VALUES ('Falls On Or Near Laurel Fork');

INSERT INTO confusion_set_members (confusion_set_id, feature_id)
SELECT cs.id, v.feature_id
FROM confusion_sets cs,
     (VALUES (1206), (1073), (1072), (1074), (1071), (1094), (1098)) AS v(feature_id)
WHERE cs.name = 'Falls On Or Near Laurel Fork';

INSERT INTO confusion_set_entries (confusion_set_id, body, author)
SELECT cs.id, $body$Chute Falls and Christopher Falls are the same waterfall.

The Big Cliff page:

  we went up the ridge that divides Laurel Fork from an unnamed drainage
  where you can find Bella Falls and Evil Ducky Falls, very close to where
  the trib meets Laurel Fork

The Christopher Falls page:

  Bella Falls, Christopher Falls, and Evil Ducky Falls are clustered together
  at the confluence of an unnamed trib and Laurel Fork. Two are on the trib
  and the third is on Laurel Fork.

Put those together: Bella and Evil Ducky are the two on the trib, so
Christopher is the one on Laurel Fork. And Chute Falls is the bottom-most of
the four Laurel Fork falls, right at the confluence -- "Upper Big Cliff Falls
at the top of the grouping and Chute Falls at the bottom."

Same creek, same spot, 4 m apart. Chute Falls and Christopher Falls are one
waterfall, catalogued twice by Kevin himself -- #793 in 2021 as Christopher,
#945 in 2024 as Chute. The heights differ because the measurements are three
years apart: 25 feet then, 16 feet now.

What this means for our data. Feature 1073 is that waterfall. It should carry
Chute Falls as an alias, a second height reading of 16 feet against the
existing 25, and an elevation of 2100 ft -- not a new feature 4 m from
itself, which is the duplicate this set exists to prevent.

The rest of the cluster. hikingwnc's 942-945 page lists four falls on Laurel
Fork with their own coordinates, and only two of them exist here:

  Upper Big Cliff Falls  16 ft  2297 ft  35.05473, -82.84459   MISSING
  Big Cliff Falls        30 ft  2231 ft  35.05459, -82.84494   feature 1206
  Split Falls            12 ft  2198 ft  35.05418, -82.84523   MISSING
  Chute Falls            16 ft  2100 ft  35.05368, -82.84584   feature 1073

Feature 1206 is named "945 Big Cliff Falls etc. (SC)", which is not a name at
all: 945 is hikingwnc's counter for the last fall on a page covering 942
through 945, and "etc." is him saying the page is about several. The feature
sits on Big Cliff Falls' own coordinate, so it is Big Cliff Falls.

Membership is wider than the evidence. Bella (1072), Christopher (1073),
Evil Ducky (1074) and Big Cliff (1206) are placed on a watercourse by the
prose above. Upper Laurel Fork Falls (1071) names its creek. Louie Falls
(1094) and Overhang Falls (1098) are simply within 300 m and have not been
placed on either creek -- they are here because the set is about which fall
is which in this cluster, and leaving them out would imply we had checked.

The rule this one teaches. Falls Named Tom was about a name travelling
further than the waterfall. This is the opposite failure: no name collision,
seven distinct names, and the confusion comes from position alone. A source
naming the same drop twice years apart looks exactly like two adjacent falls,
because that is what the coordinates say. The creek is what separates them,
and only the prose knows the creek.$body$, 'claude'
FROM confusion_sets cs WHERE cs.name = 'Falls On Or Near Laurel Fork';

INSERT INTO schema_migrations (filename) VALUES ('124_falls_on_or_near_laurel_fork.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
