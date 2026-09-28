-- Challenge lists get their real names, their home page, and a note.
--
-- Kevin Adams, who publishes three of these, asked for two things when he
-- gave permission for his data to be used:
--
--   "Please use their full official names: NCWaterfalls.com 100 Waterfalls
--    Challenge, NCWaterfalls.com 500 Waterfalls Challenge, and
--    NCWaterfalls.com 100 Easy Waterfalls Challenge. I know they're long, but
--    the full names help prevent confusion."
--
--   "Please also make it clear that your map simply shows the waterfalls
--    included in each challenge. To officially participate and receive a
--    completion certificate, users must download the list from
--    NCWaterfalls.com and follow the instructions there."
--
-- We were calling them "Adams 100" and "Adams 500", which is exactly the
-- confusion he is asking us to avoid -- it reads as though the challenge is
-- named after a person rather than published by a site.
--
-- notes is prose meant to be edited, not assembled. A sentence built out of
-- fragments cannot say "download the list and follow the instructions there"
-- in the publisher's own terms, and that sentence is the point.
--
-- The CMC row is deliberately incomplete: this records what we have been
-- told, and nobody has told us the Carolina Mountain Club's official name or
-- list page. Better an empty column than an invented one.

BEGIN;

ALTER TABLE challenges ADD COLUMN IF NOT EXISTS full_name text;
ALTER TABLE challenges ADD COLUMN IF NOT EXISTS url text;
ALTER TABLE challenges ADD COLUMN IF NOT EXISTS notes text;
-- Which kind of place the list is about, so a waterfall view can offer the
-- waterfall lists and leave the tower one out.
ALTER TABLE challenges ADD COLUMN IF NOT EXISTS feature_kind text NOT NULL DEFAULT 'waterfall';

COMMENT ON COLUMN challenges.full_name IS
  'The name the publisher uses, in full. Shown wherever a person sees the '
  'list named. Kevin Adams asked for these specifically.';
COMMENT ON COLUMN challenges.notes IS
  'Prose about the list, written to be read and edited by hand. Says who '
  'publishes it and how somebody actually takes part, which is not something '
  'this app administers.';

UPDATE challenges SET
  full_name = 'NCWaterfalls.com 100 Waterfalls Challenge',
  url = 'https://ncwaterfalls.com/',
  notes = 'This challenge list is published by NCWaterfalls.com, Kevin Adams''s '
       || 'site. Wanderfall only shows you which waterfalls are on it. To take '
       || 'part officially and receive a completion certificate, download the '
       || 'list from NCWaterfalls.com and follow the instructions there.'
WHERE name = 'ADAMS100';

UPDATE challenges SET
  full_name = 'NCWaterfalls.com 500 Waterfalls Challenge',
  url = 'https://ncwaterfalls.com/',
  notes = 'This challenge list is published by NCWaterfalls.com, Kevin Adams''s '
       || 'site. Wanderfall only shows you which waterfalls are on it. To take '
       || 'part officially and receive a completion certificate, download the '
       || 'list from NCWaterfalls.com and follow the instructions there.'
WHERE name = 'ADAMS500';

UPDATE challenges SET
  full_name = 'CMC Waterfall Challenge (WC100)',
  notes = 'This challenge list is published by the Carolina Mountain Club. '
       || 'Wanderfall only shows you which waterfalls are on it; taking part '
       || 'officially is arranged through the club, not here. It asks for any '
       || '100 of the waterfalls it lists rather than all of them.'
WHERE name = 'WC100';

UPDATE challenges SET
  full_name = 'CMC Lookout Tower Challenge',
  feature_kind = 'tower',
  notes = 'This challenge list is published by the Carolina Mountain Club. '
       || 'Wanderfall only shows you which towers are on it; taking part '
       || 'officially is arranged through the club, not here.'
WHERE name = 'LTC';

INSERT INTO schema_migrations (filename) VALUES ('147_challenge_identity.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
