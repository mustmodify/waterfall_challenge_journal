-- jw: "the hikingwnc link to Bubbling Springs Branch links to the wrong
-- fall." Checked directly -- the link is right, the name is wrong. Feature
-- 427 is a legacy hand-set name ("Upper & Lower Bubbling Springs") never
-- backed by any accepted claim. Its coordinate (35.3136, -82.9096) and its
-- hikingwnc link both belong to a third, separate waterfall on the same
-- stream: hikingwnc's own page (045-bubbling-springs-cascades) calls it
-- "Bubbling Springs Cascades (Guardrail Falls)" and explicitly describes the
-- real Upper and Lower Bubbling Springs Branch falls as a *different* pair,
-- reached from a different parking area 0.4 miles away -- those are already
-- their own correct features (487, 488). ncwaterfalls and OpenStreetMap
-- independently agree on essentially the same name ("Bubbling Spring Branch
-- Cascades"). Three sources on one name, none of them "Upper & Lower".

BEGIN;

UPDATE claims SET accepted = true
WHERE group_id = (SELECT id FROM claim_groups WHERE feature_id = 427 AND source = 'hikingwnc')
  AND field = 'name';

UPDATE features
SET name = 'Bubbling Springs Cascades (Guardrail Falls)'
WHERE id = 427;

INSERT INTO schema_migrations (filename) VALUES ('092_bubbling_springs_cascades_rename.sql');

COMMIT;
