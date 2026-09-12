-- Per-visit ratings.
--
-- features.{beauty,photo,solitude}_rating are HikingWNC's numbers: imported
-- once, identical for every user, and describing the fall in the abstract.
-- These are the visitor's own, recorded against a particular trip, so the same
-- fall can score differently in a drought than in the spring melt.
--
-- All three are optional. Logging a visit stays a one-field action.

BEGIN;

ALTER TABLE visits
    ADD COLUMN beauty_rating   integer,
    ADD COLUMN photo_rating    integer,
    ADD COLUMN solitude_rating integer;

-- Same 1-10 scale the features table already uses. NULL passes a CHECK, so
-- these constrain the ratings that are given without requiring any.
ALTER TABLE visits
    ADD CONSTRAINT visits_beauty_range
        CHECK (beauty_rating >= 1 AND beauty_rating <= 10),
    ADD CONSTRAINT visits_photo_range
        CHECK (photo_rating >= 1 AND photo_rating <= 10),
    ADD CONSTRAINT visits_solitude_range
        CHECK (solitude_rating >= 1 AND solitude_rating <= 10);

COMMIT;
