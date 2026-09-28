-- Where each challenge list actually lives.
--
-- jw supplied these. 147 left the Carolina Mountain Club row's url empty on
-- the grounds that an invented address is worse than none, and the
-- NCWaterfalls rows pointed at the site's front page rather than the page
-- about the challenges.
--
-- The three NCWaterfalls challenges share one page, which is why both of the
-- rows we carry get the same address. The third, the 100 Easy Waterfalls
-- Challenge, is not in this database at all.
--
-- The Lookout Tower Challenge is still without one. It is a Carolina Mountain
-- Club list too, but nobody has given us its page and it is off the site for
-- now anyway.

BEGIN;

UPDATE challenges
SET url = 'https://carolinamountainclub.org/hiking/hiking-challenges/waterfall-cascade-100-wc100/'
WHERE name = 'WC100';

UPDATE challenges
SET url = 'https://ncwaterfalls.com/plan-your-visit/waterfall-challenges'
WHERE name IN ('ADAMS100', 'ADAMS500');

INSERT INTO schema_migrations (filename) VALUES ('148_challenge_official_pages.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
