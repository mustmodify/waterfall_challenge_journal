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
db/migrations/ numbered SQL, applied by hand with psql
script/        one-off importers, not part of the server
```

## Data model

`features` is the centre: a waterfall, a lookout tower, or eventually a vista.
Everything else hangs off it.

```
features ──< goals >── challenges        which lists a place belongs to
         ──< feature_areas >── areas     where it is, as flat tags
         ──< links                       hikingwnc.com and other URLs
         ──< notes                       free text, with provenance
         ──< visits >── users            who went, when, and what they thought
         ──  locations                   latitude/longitude
```

Current size: 957 features, 991 locations, 703 goals across 4 challenges, 56
areas over 661 assignments, 958 links, 61 visits.

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

**Marker colors live in CSS custom properties**, not in JavaScript, so the
legend swatches and the map cannot drift apart. JS reads them back via
`getComputedStyle`, which is also how the palette changes with the theme.

## Auth

Passwordless. `POST /auth/request` creates the user if the address is unknown,
issues a 32-byte token, stores **only its SHA-256**, and emits a link.
`GET /auth/callback` consumes it — single use and 20-minute expiry enforced in
one `UPDATE ... WHERE used_at IS NULL AND expires_at > now() RETURNING`, so two
simultaneous clicks cannot both succeed.

Sessions are the opposite: a ten-year cookie, no server-side expiry. Losing one
costs somebody their waterfall list and nothing else.

`/signup` and `/login` still exist and still work; `users.password_digest` is
nullable and unused by the new flow.

**Not done:** no mail transport (links go to the log), and no rate limiting on
`/auth/request`.

## API

| Method | Path | Notes |
|---|---|---|
| GET | `/features` | every place, with challenges, links, ratings, location, `last_visited` for the current user |
| GET | `/challenges` | name, goal count, target |
| GET | `/visits` | the signed-in user's visits |
| POST | `/visits` | one visit |
| POST | `/visits/batch` | up to 200; each row succeeds or fails independently |
| DELETE | `/visits/{id}` | |
| POST | `/auth/request` | issue a sign-in link |
| GET | `/auth/callback` | consume one, redirects to `/?auth=…` |
| GET | `/me`, POST `/logout` | |
| GET | `/`, `/bulk`, `/account` | pages |

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

There is no test suite. During development the inline scripts were exercised by
a harness that runs them in Node against stubbed Leaflet and DOM objects with
real feature data, which catches load-order and init errors that a syntax check
cannot. It lives outside the repo and is worth committing if this continues.

`go build ./...` fails on `script/`: three one-off importers share one directory
as `package main`, so `main` is declared three times. Run them individually
with `go run script/import_x.go`. `go build .` and `go vet .` are clean.
