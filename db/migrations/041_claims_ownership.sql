-- Hand the claims layer to the role the application connects as.
--
-- Same trap as 020: psql creates these as the OS user, main.go reads them as
-- johnathonwright, and the first query fails with "permission denied for view
-- coordinate_confidence". Views are the easy ones to forget, since nothing
-- owns them until something reads them.

BEGIN;

ALTER TABLE claims       OWNER TO johnathonwright;
ALTER TABLE claim_groups OWNER TO johnathonwright;

ALTER SEQUENCE claims_id_seq       OWNER TO johnathonwright;
ALTER SEQUENCE claim_groups_id_seq OWNER TO johnathonwright;

ALTER VIEW claim_conflicts          OWNER TO johnathonwright;
ALTER VIEW claim_coordinate_spread  OWNER TO johnathonwright;
ALTER VIEW coordinate_confidence    OWNER TO johnathonwright;

COMMIT;
