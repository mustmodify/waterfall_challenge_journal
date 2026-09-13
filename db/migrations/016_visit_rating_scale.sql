-- Visit ratings move from 1-10 to a 4-point scale.
--
-- The 10-point scale is HikingWNC's, and it stays on features -- those are
-- imported numbers describing the fall in the abstract. A person logging a trip
-- is a different case: ten positions is more discrimination than anyone
-- actually has, and the cost of asking for it is that people skip the field.
--
--   beauty    1 disappointing  2 fine       3 beautiful     4 unforgettable
--   photo     1 nope           2 mediocre   3 nice!         4 stunning
--   solitude  1 crowded        2 a few      3 had it to self 4 bushwhacked
--
-- Beauty keeps a genuine floor. A scale whose lowest option is "eh" collects
-- nothing but praise, because nobody picks "eh" for somewhere they drove two
-- hours to reach. Photo and solitude are worded descriptively rather than
-- evaluatively, so they cannot drift upward at all.
--
-- Free to do now: no visit carries a rating yet.

BEGIN;

ALTER TABLE visits DROP CONSTRAINT visits_beauty_range;
ALTER TABLE visits DROP CONSTRAINT visits_photo_range;
ALTER TABLE visits DROP CONSTRAINT visits_solitude_range;

ALTER TABLE visits
    ADD CONSTRAINT visits_beauty_range
        CHECK (beauty_rating BETWEEN 1 AND 4),
    ADD CONSTRAINT visits_photo_range
        CHECK (photo_rating BETWEEN 1 AND 4),
    ADD CONSTRAINT visits_solitude_range
        CHECK (solitude_rating BETWEEN 1 AND 4);

COMMIT;
