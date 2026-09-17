-- Access conditions found in the AllTrails cache, 2026-09-14.
-- Source: docs/access-notices.md. These are dated readings of AllTrails pages,
-- not independent facts. observed_on records when we saw the condition so a
-- visitor can judge whether it is still current.
--
-- Severity assignments:
--   closed      trail or area explicitly inaccessible
--   restricted  partial closure, seasonal closure, or permit required
--   fee         entry or parking costs money; access is otherwise open
--
-- Nothing here is written into features; it is advisory only.

BEGIN;

INSERT INTO feature_notes (feature_id, severity, text, source, observed_on) VALUES

-- closed: do not go
(537, 'closed',
 'As of May 2026, the trailhead is closed and there is damage along the trail leading to the falls.',
 'alltrails', '2026-09-14'),

(599, 'closed',
 'As of June 2024, this area is closed indefinitely. For more information visit https://southcarolinaparks.com/jones-gap',
 'alltrails', '2026-09-14'),

(423, 'closed',
 'Trails are temporarily closed to assess conditions and address damage following Hurricane Helene.',
 'alltrails', '2026-09-14'),

(424, 'closed',
 'Trails are temporarily closed to assess conditions and address damage following Hurricane Helene.',
 'alltrails', '2026-09-14'),

(928, 'closed',
 'As of August 2026, Otter Falls Park and its parking area are temporarily closed for repairs. For more information visit https://www.sevendevilsnc.gov/parks-and-recreation/page/otter-falls',
 'alltrails', '2026-09-14'),

(363, 'closed',
 'As of May 2025, this area (High Shoals Falls Loop Trail, including the waterfall viewing area) is closed indefinitely due to damage from Hurricane Helene and ongoing safety hazards. For more information visit https://www.ncparks.gov/state-parks/south-mountains-state-park/news/reopened-facilities-after-helene',
 'alltrails', '2026-09-14'),

-- restricted: accessible but not freely
(396, 'restricted',
 'Some Parkway sections remain closed from Hurricane Helene impacts and recovery projects. The landscape remains unstable and no use is allowed in closed areas. For more information visit https://www.nps.gov/blri/planyourvisit/conditions.htm',
 'alltrails', '2026-09-14'),

(790, 'restricted',
 'A section of the Mountains-to-Sea Trail along this route is currently closed. For more information visit https://mountainstoseatrail.org/the-trail/map/',
 'alltrails', '2026-09-14'),

(849, 'restricted',
 'As of May 2025, parts of this route are temporarily inaccessible due to storm damage and ongoing recovery efforts, but other sections of the trail remain open. For more information visit https://www.ncwildlife.gov/connect/ncwrc-operations-closings-and-alerts/game-land-full-and-partial-closings',
 'alltrails', '2026-09-14'),

(327, 'restricted',
 'The road leading up to this trailhead is closed seasonally from January 1 to April 1. For more information visit https://www.fs.usda.gov/recarea/nfsnc/recarea/?recid=48852',
 'alltrails', '2026-09-14'),

(311, 'restricted',
 'A section of the Mountains-to-Sea Trail along this route is currently closed. For more information visit https://mountainstoseatrail.org/the-trail/map/',
 'alltrails', '2026-09-14'),

-- fee: entry or parking costs money
(692, 'fee',
 'Caesars Head State Park charges a fee to enter. For more information visit https://southcarolinaparks.com/caesars-head',
 'alltrails', '2026-09-14'),

(896, 'fee',
 'As of July 1, 2025, there is a $5 contribution for use of parking nearest the trailheads. Funds go towards maintenance of the Montreat Trail system.',
 'alltrails', '2026-09-14'),

(390, 'fee',
 'No entrance fee, but a paid parking tag is required for those who park for longer than 15 minutes. Purchase a daily, weekly, or annual tag online or at the visitor''s center. For more information visit https://www.nps.gov/grsm/planyourvisit/fees.htm',
 'alltrails', '2026-09-14'),

(343, 'fee',
 'Chimney Rock State Park charges a fee to enter. For more information visit https://www.chimneyrockpark.com/plan-your-visit/',
 'alltrails', '2026-09-14'),

(403, 'fee',
 'There is a fee to enter this park. For more information visit https://visitoconeesc.com/stumphouse-park/',
 'alltrails', '2026-09-14'),

(483, 'fee',
 'No entrance fee, but a paid parking tag is required for those who park for longer than 15 minutes. Purchase a daily, weekly, or annual tag online or at the visitor''s center. For more information visit https://www.nps.gov/grsm/planyourvisit/fees.htm',
 'alltrails', '2026-09-14'),

(733, 'fee',
 'Jones Gap State Park requires reservations made 48 hours in advance and charges a fee per entry. For more information visit https://southcarolinaparks.com/jones-gap',
 'alltrails', '2026-09-14'),

(329, 'fee',
 'Jones Gap State Park requires reservations made 48 hours in advance and charges a fee per entry. For more information visit https://southcarolinaparks.com/jones-gap',
 'alltrails', '2026-09-14'),

(1130, 'fee',
 'Jones Gap State Park requires reservations made 48 hours in advance and charges a fee per entry. For more information visit https://southcarolinaparks.com/jones-gap',
 'alltrails', '2026-09-14'),

(394, 'fee',
 'Whitewater Falls charges a fee to enter. For more information visit https://www.fs.usda.gov/recarea/nfsnc/recarea/?recid=48666',
 'alltrails', '2026-09-14');

INSERT INTO schema_migrations (filename) VALUES ('061_access_notices.sql');

COMMIT;
