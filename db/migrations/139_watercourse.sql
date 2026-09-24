-- watercourse: which creek the waterfall is on.
--
-- jw noticed it on an OpenStreetMap node -- Alarka Falls is "part of" the way
-- for Alarka Creek -- and it is the discriminator this project keeps reaching
-- for. Falls Named Tom concluded that "when a waterfall's name is a person's
-- name, the name travels further than the waterfall does", and that the creek
-- separates them. Falls On Or Near Laurel Fork turned entirely on which of
-- two watercourses each fall sat on, which only Kevin Adams's prose knew.
--
-- We had it from two sources and were storing it from neither.
--
-- ncwaterfalls publishes a Watercourse on every page. The importer has listed
-- it in FIELDS since 043, extracted it, and dropped it on the floor for want
-- of somewhere to put it -- 241 of the 282 cached pages carry a real one, the
-- rest an em dash meaning he does not know. 121 of those match a claim group
-- we are certain about, and those are filed here, into the same group as the
-- rest of that page's claims.
--
-- OpenStreetMap has it too, as the parent way of the waterfall node, and we
-- have none of it: the Overpass extract is 2,385 nodes and zero ways, because
-- the query never asked for parents. That is a second pass and a second
-- source, which is the point -- a creek agreed on by two sources is worth a
-- great deal more than a name agreed on by two sources, since names collide
-- and creeks mostly do not.
--
-- Filed as raw text, unaccepted. "Yellowstone Prong of East Fork Pigeon
-- River" is a real value and normalizing it into something shorter is a
-- decision for later, not for import.

BEGIN;

ALTER TABLE claims DROP CONSTRAINT claims_field_known;
ALTER TABLE claims ADD CONSTRAINT claims_field_known CHECK (
  field = ANY (ARRAY[
    'coordinate','parking_coordinate','view_coordinate','coordinate_raw',
    'trailhead_coordinate',
    'detour_parking_coordinate','detour_trailhead_coordinate','detour_hike_distance',
    'access_status','disambiguator','watercourse',
    'height','elevation_ft','elevation_gain_ft','petzoldt',
    'beauty_rating','photo_rating','solitude_rating',
    'hike_distance','accessibility','owner','name','alias',
    'photos_count','completed_hikes_count','reviews_count']::text[]));

INSERT INTO claims (group_id, feature_id, field, value, accepted)
SELECT v.group_id, cg.feature_id, 'watercourse', to_jsonb(v.name), false
FROM (VALUES
  (1699, 'Courthouse Creek'),
  (1701, 'Chestnut Creek'),
  (1704, 'Clear Creek'),
  (1707, 'Little Cove Creek'),
  (1709, 'Falling Water Branch'),
  (1710, 'Big Creek'),
  (1714, 'Tributary of Hungry River'),
  (4911, 'Moore Creek? See “Naming” for a discussion about the creek name'),
  (1743, 'Wolf Creek'),
  (1766, 'Cliff Branch'),
  (4916, 'Glassmine Branch'),
  (1769, 'Tributary of North Fork French Broad River'),
  (4917, 'Kiesee Creek'),
  (4918, 'Yellowstone Prong of East Fork Pigeon River'),
  (4919, 'Toxaway River'),
  (4920, 'Yellowstone Prong of East Fork Pigeon River'),
  (1713, 'Little Creek (tributary to Big Creek)'),
  (1717, 'Bear Creek'),
  (1719, 'North Prong Lewis Fork'),
  (1723, 'Burgan Creek'),
  (1724, 'Bear Creek'),
  (1725, 'Tributary of Looking Glass Creek'),
  (1729, 'Tributary of Big Bearpen Branch'),
  (1734, 'Moore Creek? See “Naming” for a discussion about the creek name'),
  (1741, 'Tributary of Looking Glass Creek Gaia lists it as Looking Glass Creek, but all other references, including the USGS topo map, has it unnamed'),
  (1728, 'Tributary of Cullasaja River'),
  (1747, 'Big Creek'),
  (1732, 'Green River'),
  (1749, 'Tributary of Looking Glass Creek'),
  (1752, 'Cullasaja River'),
  (1753, 'Bee Branch'),
  (1758, 'Mill Station Creek'),
  (1793, 'Bald Springs Branch'),
  (1774, 'Indian Camp Creek'),
  (3977, 'Cullasaja River'),
  (1780, 'Cape Fear River'),
  (1760, 'Kuykendall Creek'),
  (1794, 'Kiesee Creek'),
  (1797, 'Elk River'),
  (1801, 'Williamson Creek'),
  (1802, 'Log Hollow Branch'),
  (1809, 'Log Hollow Branch'),
  (1818, 'Little River (tributary of French Broad River)'),
  (1820, 'Burnett Branch'),
  (1810, 'Big Creek'),
  (1826, 'South Prong Glady Fork'),
  (1812, 'Silver Run Creek'),
  (1816, 'Beetree Fork'),
  (1821, 'Unnamed tributary of Cape Fear River'),
  (1822, 'Little Creek'),
  (1823, 'Avents Creek'),
  (1795, 'Horsepasture River'),
  (3978, 'Tributary of Looking Glass Creek'),
  (1694, 'Horsepasture River'),
  (1712, 'Looking Glass Creek'),
  (1828, 'Green Mountain Creek'),
  (1835, 'Greenfield Branch'),
  (1836, 'Flat Creek (Tributary of Swannanoa River)'),
  (1756, 'South Fork New River'),
  (1764, 'Fletcher Creek'),
  (1777, 'Tributary of Looking Glass Creek'),
  (1779, 'West Fork Pigeon River'),
  (1787, 'Colt Creek'),
  (1829, 'Bubbling Spring Branch'),
  (1830, 'Moore Creek? See “Naming” for a discussion about the creek name'),
  (1831, 'Big Creek and Fletcher Creek'),
  (1838, 'North Fork French Broad River'),
  (1695, 'Poundingmill Branch'),
  (1698, 'Pot Branch'),
  (1700, 'Silver Run Creek'),
  (1702, 'Horsepasture River'),
  (1705, 'Looking Glass Creek'),
  (1711, 'Mill Creek'),
  (1716, 'Little River (tributary of French Broad River)'),
  (1718, 'East Fork Overflow Creek'),
  (1720, 'Fall Creek'),
  (1727, 'North Fork French Broad River'),
  (1730, 'Cullasaja River'),
  (1731, 'Catawba River'),
  (1733, 'Tributary of Little Cove Creek'),
  (1735, 'East Fork French Broad River'),
  (1737, 'Cullasaja River'),
  (1739, 'Little Whitewater Creek'),
  (1740, 'Cullasaja River'),
  (1742, 'Chattooga River'),
  (1745, 'Catawba River'),
  (1748, 'Catheys Creek'),
  (1750, 'Linville River'),
  (1751, 'Big Creek'),
  (1755, 'Leatherwood Branch'),
  (1757, 'Wolf Creek'),
  (1759, 'Sols Creek'),
  (1762, 'Bald Springs Branch'),
  (1763, 'Sam Branch'),
  (1765, 'Mingo Creek'),
  (1767, 'Wolf Creek'),
  (1768, 'Carson Creek'),
  (1771, 'Looking Glass Creek'),
  (1772, 'East Fork French Broad River'),
  (1773, 'Courthouse Creek'),
  (1775, 'Stairstep Creek'),
  (1776, 'Yellowstone Prong of East Fork Pigeon River'),
  (1778, 'Horsepasture River'),
  (1781, 'Courthouse Creek'),
  (1786, 'Little River (tributary of French Broad River)'),
  (1789, 'Lamance Creek'),
  (1790, 'Little River (tributary of French Broad River)'),
  (1791, 'Soco Creek & Brush Creek'),
  (1798, 'Yellowstone Prong of East Fork Pigeon River'),
  (1799, 'Cullasaja River'),
  (1803, 'Bald Springs Branch'),
  (1804, 'Fall Creek'),
  (1805, 'East Fork Laurel Creek'),
  (1806, 'Tributary of Log Hollow Branch'),
  (1808, 'North Fork French Broad River'),
  (1811, 'Tributary of Big Bearpen Branch'),
  (1813, 'Wolf Creek'),
  (1817, 'Tanasee Creek'),
  (1824, 'Cove Creek'),
  (1825, 'Thompson River'),
  (1827, 'Whitewater River')
) AS v(group_id, name)
JOIN claim_groups cg ON cg.id = v.group_id
ON CONFLICT DO NOTHING;

-- Tidy the new rows the way every other text claim is tidied.
UPDATE claims c
SET normalized_value = CASE
      WHEN normalize_claim_value(c.value #>> '{}', c.field, cg.source)
           IS DISTINCT FROM (c.value #>> '{}')
       AND normalize_claim_value(c.value #>> '{}', c.field, cg.source) IS NOT NULL
        THEN to_jsonb(normalize_claim_value(c.value #>> '{}', c.field, cg.source))
      ELSE NULL
    END,
    parenthetical = CASE
      WHEN name_parenthetical(c.value #>> '{}') IS NOT NULL
       AND coalesce(normalize_claim_value(c.value #>> '{}', c.field, cg.source), '')
           NOT LIKE '%(' || name_parenthetical(c.value #>> '{}') || ')%'
        THEN name_parenthetical(c.value #>> '{}')
      ELSE NULL
    END
FROM claim_groups cg
WHERE cg.id = c.group_id AND c.field = 'watercourse';

INSERT INTO schema_migrations (filename) VALUES ('139_watercourse.sql')
ON CONFLICT (filename) DO NOTHING;

COMMIT;
