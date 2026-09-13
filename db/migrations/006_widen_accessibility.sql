-- accessibility was sized for the grade alone (Moderate, Hard+, Roadside).
-- hikingwnc appends a qualifier to about 40 of them, and those are the most
-- useful part: "Moderate+ (with a sketchy rock bit to get a good view)",
-- "Easy (finding the parking area will be hard)". Keep them whole.
ALTER TABLE features ALTER COLUMN accessibility TYPE text;
