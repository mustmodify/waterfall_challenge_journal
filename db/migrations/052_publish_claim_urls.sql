-- Publish the URLs the claims layer has been holding all along.
--
-- links is what the details card reads. claim_groups is where provenance
-- lives, and every source we have ever read is recorded there with its URL.
-- Only hikingwnc was ever copied across, so the card showed a single source
-- for almost every fall while the database knew two or three. That is a
-- display gap rather than a sourcing gap, and this closes it: about 460 falls
-- gain an OpenStreetMap link and 28 gain dwhike.
--
-- identity_certain is the guard, and it is the whole reason this is a
-- migration rather than one line. A group marked uncertain was matched to its
-- feature by NAME and never confirmed against a coordinate — 163 OpenStreetMap
-- groups and 103 ncwaterfalls groups are in that state. Publishing those would
-- put a link to a different waterfall on the card, silently, which is the
-- failure 051 exists to clean up. A name answers "what shares this name", not
-- "what is this", and only the second question is the one a link answers.
--
-- Sources with no URL (jw, wanderfall, google-maps) contribute nothing here by
-- construction, which is correct: they are observations, not pages.
--
-- Re-runnable. The unique constraint on (feature_id, url) makes a second run a
-- no-op, so this can be applied again after any future claim import rather
-- than being copied into it.

INSERT INTO links (feature_id, url, rel)
SELECT DISTINCT cg.feature_id, cg.url, cg.source
FROM claim_groups cg
WHERE cg.url IS NOT NULL
  AND cg.identity_certain
ON CONFLICT (feature_id, url) DO NOTHING;
