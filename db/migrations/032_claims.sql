-- What each source says, kept beside what we decided.
--
-- features stays the resolved record and the app keeps reading it unchanged.
-- These two tables are the layer under it, so a disagreement is a query rather
-- than a paragraph in a migration comment.
--
-- A source does not assert a coordinate on its own. It publishes a page, or a
-- mapper drops a node, and that one act asserts several things at once: this
-- fall is called X, it is here, it is this tall. claim_groups is that act;
-- claims are the name/value pairs it carries. The name is one of the pairs,
-- which is what makes the group checkable -- a group that calls the fall
-- something else is a group about a different fall.
--
-- Splitting them this way also puts identity where it belongs. Whether a
-- source is talking about the feature we attached it to is a property of the
-- attachment, not of each number in it: a node matched to us only by being
-- nearby is uncertain in all of its claims at once.
--
-- A coordinate is one claim holding two numbers, not two claims. Split into
-- latitude and longitude, nothing would stop us accepting one source's
-- latitude beside another's longitude -- a point neither source ever saw, and
-- exactly the shape of the one-degree slips in 011.
--
-- Nothing a source says is discarded. A coordinate we cannot parse into a
-- point is kept verbatim as coordinate_raw rather than dropped, because a
-- reading we cannot use is still a reading someone took.
--
-- note carries the reasoning either way: why a claim lost, or what had to be
-- assumed to accept the one that won.

BEGIN;

CREATE TABLE claim_groups (
    id               serial PRIMARY KEY,
    ref              text NOT NULL UNIQUE,
    feature_id       integer NOT NULL REFERENCES features(id) ON DELETE CASCADE,
    source           varchar(30) NOT NULL,
    url              text,
    observed_on      date,
    identity_certain boolean NOT NULL DEFAULT true,
    note             text,
    created_at       timestamp DEFAULT CURRENT_TIMESTAMP,

    -- lets claims carry feature_id without it being able to drift from the
    -- group's, which is what makes one-accepted-per-field enforceable
    UNIQUE (id, feature_id)
);

CREATE TABLE claims (
    id         serial PRIMARY KEY,
    group_id   integer NOT NULL,
    feature_id integer NOT NULL,
    field      varchar(24) NOT NULL,
    value      jsonb NOT NULL,
    accepted   boolean NOT NULL DEFAULT false,
    note       text,
    created_at timestamp DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (group_id, feature_id)
        REFERENCES claim_groups (id, feature_id) ON DELETE CASCADE,

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

-- One group should not say the same thing twice.
CREATE UNIQUE INDEX claims_one_value_per_group ON claims (group_id, field, value);

CREATE INDEX claims_feature_idx ON claims (feature_id);
CREATE INDEX claims_field_idx ON claims (field);
CREATE INDEX claim_groups_feature_idx ON claim_groups (feature_id);
CREATE INDEX claim_groups_source_idx ON claim_groups (source);

COMMIT;
