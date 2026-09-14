-- Five falls say "private" somewhere other than the field meant for it.
--
-- owner is the column that answers "can I legally go here", and it is set on
-- 107 of 955 features. These five announce private ownership or no access in
-- their name, their distance or their difficulty instead, where nothing can
-- filter on it:
--
--   Amelia Falls                        accessibility "Roadside (Private)"
--   Cover Falls (Private)               in the name
--   English Falls (access restricted)   in the name, and "No access" twice
--   Rainbow Falls (Private along US64)  in the name
--   Twin Falls (Thompson River)         distance and difficulty both "Private"
--
-- Ownership is recorded; the names and the free text are left exactly as the
-- sources wrote them, because that is what the sources said and a later import
-- would only put it back.

BEGIN;

UPDATE features SET owner = 'Private'
WHERE deprecated_reason IS NULL
  AND owner IS NULL
  AND (rt_hike_distance ILIKE '%private%'
       OR accessibility ILIKE '%private%'
       OR rt_hike_distance ILIKE '%no access%'
       OR accessibility ILIKE '%no access%'
       OR name ILIKE '%private%'
       OR name ILIKE '%restricted%');

COMMIT;
