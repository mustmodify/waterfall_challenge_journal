-- The first confusion set, and the one that motivated the whole idea.
--
-- Four unrelated waterfalls, all correctly named, scattered across the state,
-- that a person searching "Toms Falls" cannot tell apart. We have already got
-- this wrong twice in ways that reached the data, so the journal starts with
-- what we currently believe and how we got there.

BEGIN;

INSERT INTO confusion_sets (name) VALUES ('Falls Named Tom');

INSERT INTO confusion_set_members (confusion_set_id, feature_id)
SELECT cs.id, v.feature_id
FROM confusion_sets cs, (VALUES (398), (1268), (484), (366)) AS v(feature_id)
WHERE cs.name = 'Falls Named Tom';

INSERT INTO confusion_set_entries (confusion_set_id, body, author)
SELECT cs.id, $body$Four different waterfalls, none of them variants of each other.

Tom's Creek Falls (398) is near Marion, northeast of Asheville, and is hikingwnc's #201. Toms Falls (1268) is near Hendersonville, southeast, and is CMC hike 115. Tom Branch Falls (484) is near Cherokee, in the Deep Creek area of the Smokies. Tom's Spring Falls (366) is southwest, off the Daniel Ridge trailhead in Pisgah, and also answers to Daniel Ridge Falls and Jackson Falls -- hikingwnc lists it as "Tom Springs (Daniel Ridge) Falls" and notes it is on Toms Spring Branch rather than Daniel Ridge Creek, which is where that second name comes from.

Two mistakes reached the data before we untangled this. Migration 068 created a second "Toms Creek Falls" while disambiguating, because it checked the new name against Tom's Spring Falls but not against the Tom's Creek Falls we already had 50 m away; migration 087 merged them back. Separately, the official CMC WC100 list has an entry literally named "Upper & Lower Bubbling Springs", and a feature happened to carry that same name by coincidence -- unrelated to this cluster, but the same class of error, and worth remembering that an exact name match is not evidence of identity.

The general rule this cluster taught us: when a waterfall's name is a person's name, the name travels further than the waterfall does. Toms Creek Falls is on Toms Creek and Tom's Spring Falls is on Toms Spring Branch, so the creek is a better discriminator than the fall's own name.$body$, 'claude'
FROM confusion_sets cs WHERE cs.name = 'Falls Named Tom';

INSERT INTO schema_migrations (filename) VALUES ('101_falls_named_tom.sql') ON CONFLICT (filename) DO NOTHING;

COMMIT;
