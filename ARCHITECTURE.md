# Architecture

A Go binary serving a JSON API and three static pages, over PostgreSQL. No
build step, no framework, no bundler: the pages are hand-written HTML that
fetch JSON and render it.

```
main.go        routes, /features and /locations handlers, DB connection
auth.go        sessions, password signup/login (legacy), /me
magiclink.go   passwordless sign-in
visits.go      visits, batch visits, challenges
static/        index.html (map), bulk.html, account.html + shared assets
mailer.go      the Mailer interface and transport selection
mailgun.go     the Mailgun HTTP transport
db/migrations/ numbered SQL, applied by script/migrate
script/        the migration runner, plus one-off importers
```

## Data model

`features` is the centre: a waterfall, a lookout tower, or eventually a vista.
Everything else hangs off it.

```
features ──< goals >── challenges        which lists a place belongs to
         ──< feature_areas >── areas     where it is, as flat tags
         ──< claim_groups >── claims     what each source says, unmerged
         ──< links                       the URLs the card shows, derived
         ──< notes                       free text, with provenance
         ──< visits >── users            who went, when, and what they thought
         ──  locations                   latitude/longitude
```

Current size: 956 features, 1,011 locations, 704 goals across 4 challenges, 56
areas over 661 assignments, 1,880 claim groups carrying 9,198 claims from nine
sources, 61 visits. Of the 934 waterfalls, 442 are published — see the
confidence tiers below.

### Provenance: claim groups and claims

Nothing here is stored as a single agreed fact. Every source we read becomes a
`claim_group` — one source's reading of one feature, with the URL it came from
and the date it was observed — holding `claims`, one row per field. Sixteen
fields are claimable, from `coordinate` and `height_ft` to `petzoldt` and
`alias`.

**Claims are not merged.** Two sources disagreeing about a height is a fact
worth keeping, not a conflict to settle at import time. `accepted` marks the
one claim per (feature, field) that the published columns reflect, and a
partial unique index enforces that there is only ever one of those.

**The coordinate is the exception, and it decides what gets published at all.**
`coordinate_confidence` is a view that counts how many sources put a feature in
the same place and measures how far apart they are, then tiers it: confirmed,
corroborated, single source, disputed, unverified, no coordinate. The
`/features` handler serves only `confirmed` and `corroborated` waterfalls, plus
every tower — towers carry no source claims at all, so tiering them would hide
all 22.

That is worth saying plainly, because it is easy to read the tables and miss
it: **the published set is defined by corroboration.** Asking whether most of
the published falls have two sources is asking what the publication rule is,
and the answer is yes by construction.

The sources themselves, how each was obtained and whether that was allowed,
and the rules for deciding whether a source's page is about one of our
waterfalls are all in [docs/MATCHING.md](docs/MATCHING.md).

**`identity_certain` asks a different question from whether the data is
right.** A group matched to its feature by name and never confirmed against a
coordinate is marked uncertain — the source may be describing a different
waterfall entirely. Those groups are kept rather than deleted, because a source
saying something about the wrong fall is still a thing the source said, and
deleting it invites the next importer to make the same match again.

### Facts: confidence beyond the coordinate (designed, not yet built)

`coordinate_confidence` only tiers one field. Everything else -- the name,
whether the links actually point at this waterfall and not a namesake,
whether the access point is where we say, whether the difficulty info is
accurate -- has no confidence tracking at all today. `facts` generalizes the
idea: one row per `(feature, key)`, holding the value itself (a fact *is*
what the page shows, not a log of an action taken) plus two independent
measures of how sure we are of it.

```
facts(id, feature_id, key, value, value_type, confidence_stage,
      confidence_score, notes, created_at, updated_at)
```

Two axes on purpose, because they answer different questions and can
disagree:

- **`confidence_stage`** -- the method used to get here, an ordinal ladder
  that only ever moves forward: `unverified` -> `one_source_reviewed` ->
  `disambiguated` (two or more sources, a minority still disagrees) ->
  `corroborated` (two or more sources, none disagree) -> `ai_reviewed` ->
  `human_reviewed` -> `confirmed_irl`.
- **`confidence_score`** -- the outcome, a decimal 0-4.3 (jw's convention
  from other projects, GPA-shaped): 0 critical, 0.7 "get to a hospital now",
  1 significant problem, 2 borderline, 3 acceptable, 4 perfect, 4.3
  unrealistically good -- reserved for a fact every source agrees on, the
  signage agrees with, and there is no spelling inconsistency anywhere
  (Crabtree Falls, Looking Glass Falls, Linville Falls). 4.0 is a perfectly
  fine ceiling in practice.

They are allowed to disagree, and that is the point, not a bug: jw visited
Bubbling Springs Branch (Upper and Lower) in person -- `confirmed_irl`, the
highest stage there is -- but no signage meant the *name* fact stayed barely
more certain than before (a low score despite the high stage), while the
*reachability* fact ("is there a waterfall here, can you get to it") jumped
on both axes from that same single visit. One method, two facts, two
different results.

`claims.fact_id` will be a nullable FK once this lands. The bottom four
stages (`unverified` through `corroborated`) are mechanically derivable from
claims already in the database -- the same logic `coordinate_confidence`
already runs, just generalized -- so those get backfilled across *all*
existing history immediately, not just new work: computing them is safe,
because it is the same trusted computation we already run, and skipping it
would leave old, never-actually-looked-at data looking no different from
reviewed data by default, which is exactly backwards after Bubbling Springs.
`ai_reviewed` / `human_reviewed` / `confirmed_irl` are never backfilled --
those stages can only come from someone actually looking, and claiming
otherwise would be the same false confidence in a new column.

`key` is not unique per feature. `aka` is explicitly multi-valued -- one row
per alternate name. Tom's Spring Falls gets two: "Daniel Ridge Falls" and
"Jackson Falls", straight out of hikingwnc's own paragraph naming both.
Another example key, unrelated to confidence: `fall_type`, one of `cascade`,
`drop`, `slide`, `mixed`, describing the shape of the water rather than how
sure we are of anything.

A single wrong name attached to one real place (someone calling Bubbling
Springs Cascades "the upper/lower falls") is a `false_aka` fact -- on
reflection, not worth a dedicated key yet. A plain note carries that fine
until a real pattern shows up asking for more structure than that.

This does not replace `accepted`/`field` on `claims`; `facts` sits above it
as a generalization of what `coordinate_confidence` already does for one
field, extended to any field worth tracking.

### Confusion sets (designed, not yet built)

Some name collisions aren't "one place, one wrong name attached to it" --
they're several genuinely different, correctly-named real waterfalls that
share a confusing family resemblance. "Toms in WNC" is the first one: Tom's
Creek Falls (feature 398, near Marion), Toms Falls (1268, near
Hendersonville), Tom Branch Falls (484, near Cherokee), and Tom's Spring
Falls (366, aka Daniel Ridge Falls, aka Jackson Falls) -- four unrelated
places, not variants of each other. That doesn't fit `facts`: the useful
thing to show someone landing on any one of the four is the same shared
write-up every time, and a shared narrative duplicated across four rows is
exactly the drift risk this project already avoids elsewhere (claims are
never merged into one row for that reason).

```
confusion_sets(id, name, created_at, updated_at)
confusion_set_members(confusion_set_id, feature_id)
confusion_set_entries(id, confusion_set_id, body, created_at)
```

`confusion_set_entries` is a journal, not a field to overwrite: append-only,
dated, never edited or deleted. When our understanding changes, a new entry
gets added saying so -- it does not replace the old one. That mirrors how
`claim_groups` already treats a bad match ("marked, not deleted") and applies
it to our own reasoning about a cluster, which matters most exactly when
we've already been wrong here once (the Toms Creek Falls duplicate feature,
merged in migration 087).

### Decisions worth knowing

**Areas are flat tags, not a hierarchy.** A fall can be tagged both
`Lake Toxaway` and `Lake Toxaway South`, because two sources describe the same
ground at different grain and both are worth filtering by. A tree would force
us to reconcile them; tagging makes the disagreement harmless. `source` is part
of the primary key, so when two sources independently agree that is recorded as
corroboration rather than collapsed as a duplicate.

**Challenges have a `target` separate from their goal count.** The WC100 lists
115 and asks for any 100. Treating the list length as the target understates
progress the whole way and withholds the badge until fifteen visits past the
requirement.

**Ratings exist at two levels and mean different things.** `features.*_rating`
is HikingWNC's 1–10 for the place in the abstract, imported. `visits.*_rating`
is one person's impression of one trip, on a 4-point worded scale. They are not
comparable and are not merged. The interesting fact — "quieter than usual" — is
the gap between them, and is not computed yet.

**Deprecation is not ownership and not delisting.** `owner = 'Private'` often
just means a $5 fee. `deprecated_reason` means the place is gone, unreachable
or unsafe. A fall dropped from a challenge list is neither: that is modelled by
the absence of a `goals` row.

**`links` is the display layer; `claim_groups` is the record.** The details
card reads `links`, and until migration 052 only hikingwnc had ever been copied
across. So every card offered one source while the database held two or three —
which reads to a visitor as an obsession with one website rather than as the
display gap it actually was. 052 harvests the URL of every *certain* claim
group into `links`, taking most published falls from one source to two or
three. It is re-runnable, so a future import does not have to remember to do
it.

**A name match is not an identification.** Matching a published list to our
features by name is how the challenge lists were linked, and the README records
35 entries left deliberately unlinked rather than guessed. The hazard recurred
in September 2026 with a second source: seven name matches pointed at
waterfalls up to 396 km away, in one case a different county. Both our existing
claim groups and the new list agreed on all seven — worth nothing, because both
had matched on the name and so shared the flaw. **Agreement between two
matchers that share a defect is not corroboration.** The arbiter is the
coordinate the source itself publishes, and the matcher now refuses a name
match more than 20 km from ours.

**Swimming holes: a `swimmable` flag, not a settled design.** Most named
swimming holes turn out to be the plunge pool of a waterfall we already carry
(Silver Run Falls, Schoolhouse Falls) rather than a separate place, so giving
each one its own `swimming_hole`-kind feature would put two pins on one spot.
For now, `features.swimmable` marks that on the existing `waterfall` feature
instead, and `swimming_hole` stays a real `kind` for swim spots that are not
waterfalls at all — lakes, coves, quarries, park beaches. This is a stopgap
picked 2026-09-17, not a settled shape: it costs the ability to list "swimming
holes" as one clean `kind = 'swimming_hole'` query, and jw is not sold on it.

**Marker colors live in CSS custom properties**, not in JavaScript, so the
legend swatches and the map cannot drift apart. JS reads them back via
`getComputedStyle`, which is also how the palette changes with the theme.

## Auth

Passwordless. `POST /auth/request` creates the user if the address is unknown,
issues a 32-byte token, stores **only its SHA-256**, and emits a link.
`GET /auth/callback` consumes it — single use and a two-day expiry enforced in
one `UPDATE ... WHERE used_at IS NULL AND expires_at > now() RETURNING`, so two
simultaneous clicks cannot both succeed.

Sessions are the opposite: a ten-year cookie, no server-side expiry. Losing one
costs somebody their waterfall list and nothing else.

`/signup` and `/login` still exist and still work; `users.password_digest` is
nullable and unused by the new flow.

Mail goes out through whichever transport `mailer.go` finds at startup. With
`WANDERFALL_MAILGUN_DOMAIN` and `WANDERFALL_MAILGUN_KEY` set it is Mailgun's
HTTP API, which is what production uses; with neither set the link is written
to the log instead, which is the local-development path. The startup line says
which one was chosen.

Both endpoints that mail on an anonymous request are rate limited by client
IP, in `ratelimit.go`: a token bucket of 5 burst / 5 per hour on
`/auth/request` and 10 / 10 on `/corrections`, refusing with a 429 and a
`Retry-After`. The limit is per IP rather than per address, so it caps how much
mail one sender can cause rather than how often one mailbox can be targeted
from everywhere.

## API

| Method | Path | Notes |
|---|---|---|
| GET | `/features` | every **published** place — confirmed or corroborated waterfalls, and all towers — with challenges, links, ratings, location, `last_visited` for the current user |
| GET | `/challenges` | name, goal count, target |
| GET | `/visits` | the signed-in user's visits |
| POST | `/visits` | one visit |
| POST | `/visits/batch` | up to 200; each row succeeds or fails independently |
| DELETE | `/visits/{id}` | |
| POST | `/auth/request` | issue a sign-in link |
| GET | `/auth/callback` | consume one, redirects to `/?auth=…` |
| GET | `/me`, POST `/logout` | |
| GET | `/users` | admin only: every account, with links issued and used, sessions and visits |
| GET | `/`, `/bulk`, `/account`, `/admin/users` | pages |

`/locations` and the `/features` write endpoints predate the importers and are
not used by the interface.

## Front end

Three pages sharing `static/app.css` (theme tokens and primitives),
`static/theme.js` (resolves the theme before first paint) and
`static/ratings.js` (the 4-point scale, defined once).

**`index.html` still carries its own inline copy of the tokens and primitives**
rather than linking `app.css`. Until that is resolved, changes to either must
be mirrored in both or the map and the other pages will drift.

Leaflet plus leaflet.markercluster from unpkg, pinned. Basemaps are CARTO for
light and dark and USGS for topo, both of which serve any domain without a key.
Stadia served the first version and refuses a real domain unless it is
registered to an account, which is how the tiles came to be swapped.

Waterfalls cluster; towers never do. With 22 of them clustering bought nothing
and cost legibility — a tower bubble landing on a waterfall bubble read as one
mixed group.

## Testing

`go test ./...`. Ten tests across five files. The ones that touch the database
skip themselves unless `TEST_DATABASE_URL` points at a scratch schema, so a
clean checkout with no Postgres still runs the rest:

```sh
createdb wj_scratch && psql -q -d wj_scratch -f db/schema.sql
TEST_DATABASE_URL="postgres:///wj_scratch?host=/var/run/postgresql&sslmode=disable" go test ./...
```

| file | what it holds | needs a database |
|---|---|---|
| `magiclink_test.go` | the sign-in handler gives its link to a transport, the token stays out of the HTTP response, a failed send answers 502 | yes |
| `users_test.go` | the account list is admin-only through a real session cookie, and an issued-never-used link reads as stranded | yes |
| `mailgun_test.go` | the Mailgun transport posts what Mailgun expects, and reports what went wrong | no |
| `ratelimit_test.go` | the bucket bursts then refills; the envelope sender loses its display name | no |
| `pages_test.go` | `robots.txt` keeps the private pages out and names the sitemap; area descriptions count what they hold | no |

Tests that write must be re-runnable against the same database. Two of these
were not, at first: one collided on a unique `token_hash`, the other asserted a
count that grew by one on every run. Both passed on a fresh database, which is
the failure mode worth knowing about — a test that only passes once is a test
that will be deleted by whoever hits it on a Tuesday.

**What these were written to close.** For a day, `mailgun_test.go` passed while
no mail had ever been sent. It called `mailer.Send` directly and proved the
transport worked; the sign-in handler never called it at all. Every test here
covered a component in isolation, and none asserted that a handler reached its
collaborator, so the bug lived in the seam between two things that were each
fine. **Where a test stubs a collaborator, something must also assert the
collaborator was used.**

The front end has no automated coverage. `test/README.md` documents a harness
that runs `index.html`'s inline script in Node against stubbed Leaflet and DOM
objects with real feature data, which catches load-order and init errors a
syntax check cannot. It needs a running server to produce its fixture and is
not wired into `go test`.

`go build ./...` is clean. It used to fail because three importers shared
`script/` as `package main`; each now has its own directory.
