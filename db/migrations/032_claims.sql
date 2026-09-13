-- What each source says, kept beside what we decided.
--
-- features stays the resolved record and the app keeps reading it unchanged.
-- claims is the layer under it: one row per assertion per source, so a
-- disagreement is a query rather than a paragraph in a migration comment.
--
-- A coordinate is one assertion holding two numbers, not two assertions. Split
-- into latitude and longitude rows, nothing would stop us accepting one
-- source's latitude beside another's longitude -- a point neither source has
-- ever seen, and exactly the shape of the one-degree slips in 011.
--
-- jsonb will hold anything, so the field vocabulary and the shape of each
-- field's value are pinned by check constraint instead of by convention.
--
-- note carries the reasoning either way: why a rejected claim lost, or what
-- had to be assumed to accept the one that won.
--
-- identity_certain is about the attachment rather than the value: a source
-- that names a fall we also carry is one thing, a node matched to it only by
-- being nearby is another. Both are recorded; only the first counts as
-- corroboration, because there are two Long Creek Falls and one is in Georgia.
--
-- Nothing a source says is discarded. A coordinate we cannot parse into a
-- point is kept verbatim as coordinate_raw rather than dropped, because a
-- reading we cannot use is still a reading someone took.

BEGIN;

CREATE TABLE claims (
    id              serial PRIMARY KEY,
    feature_id      integer NOT NULL REFERENCES features(id) ON DELETE CASCADE,
    field           varchar(24) NOT NULL,
    value           jsonb NOT NULL,
    source          varchar(30) NOT NULL,
    url             text,
    observed_on     date,
    accepted        boolean NOT NULL DEFAULT false,
    identity_certain boolean NOT NULL DEFAULT true,
    note            text,
    created_at      timestamp DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT claims_field_known CHECK (field IN (
        'coordinate', 'parking_coordinate', 'height_ft', 'elevation_ft',
        'beauty_rating', 'photo_rating', 'solitude_rating', 'hike_distance',
        'accessibility', 'owner', 'name', 'alias', 'coordinate_raw')),

    CONSTRAINT claims_value_shape CHECK (
        CASE field
        WHEN 'coordinate' THEN
            jsonb_typeof(value->'lat') = 'number' AND
            jsonb_typeof(value->'lon') = 'number' AND
            (value->>'lat')::numeric BETWEEN -90 AND 90 AND
            (value->>'lon')::numeric BETWEEN -180 AND 180
        WHEN 'parking_coordinate' THEN
            jsonb_typeof(value->'lat') = 'number' AND
            jsonb_typeof(value->'lon') = 'number' AND
            (value->>'lat')::numeric BETWEEN -90 AND 90 AND
            (value->>'lon')::numeric BETWEEN -180 AND 180
        WHEN 'height_ft' THEN
            jsonb_typeof(value) = 'number' AND (value#>>'{}')::numeric > 0
        WHEN 'elevation_ft' THEN
            jsonb_typeof(value) = 'number'
        WHEN 'beauty_rating' THEN
            jsonb_typeof(value) = 'number' AND (value#>>'{}')::numeric BETWEEN 1 AND 10
        WHEN 'photo_rating' THEN
            jsonb_typeof(value) = 'number' AND (value#>>'{}')::numeric BETWEEN 1 AND 10
        WHEN 'solitude_rating' THEN
            jsonb_typeof(value) = 'number' AND (value#>>'{}')::numeric BETWEEN 1 AND 10
        ELSE jsonb_typeof(value) = 'string' AND value#>>'{}' <> ''
        END)
);

-- A field can carry many claims but only one answer -- except alias, where a
-- fall genuinely goes by several names and all of them are true at once.
CREATE UNIQUE INDEX claims_one_accepted ON claims (feature_id, field)
WHERE accepted AND field <> 'alias';
CREATE INDEX claims_feature_idx ON claims (feature_id);
CREATE INDEX claims_field_source_idx ON claims (field, source);

COMMIT;
