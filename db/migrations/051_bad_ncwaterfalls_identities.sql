-- Seven ncwaterfalls claim groups are attached to the wrong waterfall.
--
-- Kevin Adams covers all of North Carolina and we carry the western end, so the
-- names collide. His Silver Run Falls is in Cumberland County, 396 km from the
-- one near Cashiers; his Jones Falls is 305 km from ours. Our matcher took the
-- name and never checked the coordinate he publishes on the same page.
--
-- The claims stay, because a source saying something about the wrong fall is
-- still a thing the source said, and deleting it would invite the next importer
-- to make the same match again. They are marked uncertain instead, which is
-- what that flag is for, and the note says how far wrong they are.

BEGIN;

UPDATE claim_groups cg
SET identity_certain = false,
    note = coalesce(cg.note || ' ', '') ||
           'Attached by name to a waterfall of the same name elsewhere in the state; ' ||
           'the coordinate on this page is far from ours.'
WHERE cg.source = 'ncwaterfalls'
  AND cg.url IN (
    'https://ncwaterfalls.com/waterfalls/silver-run-falls-cape-fear-river',
    'https://ncwaterfalls.com/waterfalls/jones-falls',
    'https://ncwaterfalls.com/waterfalls/cedar-falls',
    'https://ncwaterfalls.com/waterfalls/cutler-falls',
    'https://ncwaterfalls.com/waterfalls/big-bearwallow-falls',
    'https://ncwaterfalls.com/waterfalls/little-creek-falls-highlands',
    'https://ncwaterfalls.com/waterfalls/waterfall-on-long-branch');

-- Nothing an unseated group asserts should still be the accepted answer.
UPDATE claims c SET accepted = false
FROM claim_groups cg
WHERE cg.id = c.group_id AND NOT cg.identity_certain AND c.accepted;

COMMIT;
