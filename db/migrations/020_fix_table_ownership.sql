-- Hand the newer tables to the role the application actually connects as.
--
-- Migrations here are applied with psql, which connects as the OS user, while
-- main.go connects as DB_USER ("johnathonwright"). Tables created by the former
-- are owned by it, and the app gets "permission denied" the first time it
-- touches one. That stayed invisible for areas, feature_areas and corrections
-- only because nothing in the app reads them yet; magic_links failed
-- immediately, which is how it was found.

BEGIN;

ALTER TABLE areas         OWNER TO johnathonwright;
ALTER TABLE feature_areas OWNER TO johnathonwright;
ALTER TABLE corrections   OWNER TO johnathonwright;
ALTER TABLE magic_links   OWNER TO johnathonwright;

ALTER SEQUENCE areas_id_seq       OWNER TO johnathonwright;
ALTER SEQUENCE corrections_id_seq OWNER TO johnathonwright;
ALTER SEQUENCE magic_links_id_seq OWNER TO johnathonwright;

COMMIT;
