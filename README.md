# Wanderfall

A map and logbook for the waterfalls and lookout towers of Western North
Carolina. Find somewhere to go, record that you went, and track progress
against the challenge lists that people actually hike.

Currently **966 places** — 944 waterfalls and 22 lookout towers — across four
challenges. 495 of them are published on the map; the rest are held back until
a second source agrees on where they are. See *Data* below.

A hobby project by jw. Feedback: <jw@mustmodify.com>

## What it does

- **A map of everything**, clustered so 900 pins are legible rather than a
  smear. Groups are sized by how much they hold and sliced by what is in them.
- **Three basemaps** — daylight, night, and Stamen Watercolor — remembered per
  browser.
- **Filters** by type (waterfalls, towers), by challenge, and by whether you
  have been. Or color the map by HikingWNC's beauty, photo and solitude
  ratings, including two at once, which averages them.
- **Visit logging**, one at a time from the map or a page at a time in bulk,
  with optional ratings of your own.
- **Challenge progress** on the account page, measured against what each
  challenge actually asks for.

## Running it

Requires Go 1.25+ and PostgreSQL.

`db/migrations` is the history of how this database changed, not a recipe for
building one — migration 001 adds users to a schema that already had
`features`, `goals` and `locations` in it, so replaying it against an empty
database fails on the first file. Build from the dumps instead, then record the
migrations as already applied:

```sh
createdb wc_journey_db
psql -d wc_journey_db -v ON_ERROR_STOP=1 -f db/schema.sql
psql -d wc_journey_db -v ON_ERROR_STOP=1 -f db/reference_data.sql
DATABASE_URL="postgres:///wc_journey_db?host=/var/run/postgresql&sslmode=disable" \
  go run ./script/migrate -baseline
go run .
```

Then <http://localhost:8080>.

`db/schema.sql` carries every table, view, index and constraint;
`db/reference_data.sql` carries the waterfalls. No account data is in either,
so users, sessions, visits and magic links start empty. [DEPLOY.md](DEPLOY.md)
has the rest, including how to regenerate both dumps after a schema change.

The server reads `DATABASE_URL` when it is set and otherwise falls back to the
constants at the top of `main.go` (`DB_USER`, `DB_PASSWORD`, `DB_NAME`), which
is why `go run .` needs no environment locally. The migration runner has no
such fallback — it requires `DATABASE_URL`, hence the longer line above. On a
local socket install, `host=/var/run/postgresql` is what gets you peer
authentication; `postgres://user:pass@host/db` works anywhere else.

### Branches

Work goes on a branch named for the work, and that branch is opened as a pull
request and merged once. `ty-feedback` was reused four times — merged, then
committed to again, then merged again — which is how forty-four commits ended
up sitting unmerged with no pull request open and nothing deployed. A branch
name that describes what is on it can't be reused that way, because the next
piece of work needs a different name.

Merging is jw's; nobody else merges.

### Signing in

Sign-in is passwordless. Enter an email address and the server issues a
single-use link that expires in two days; following it signs you in, and
creates the account if the address is new.

**With no mail transport configured**, the link is written to the server log:

```
2026/09/13 00:50:33 magic link for you@example.com: http://localhost:8080/auth/callback?token=...
```

For local use you can have it returned in the HTTP response instead:

```sh
WANDERFALL_ECHO_LINKS=1 go run .
```

Leave that off anywhere other people can reach — it lets anyone sign in as
anyone by requesting a link for their address.

## The challenges

| Challenge | Listed | Linked here | Needed to finish |
|---|---|---|---|
| CMC WC100 | 115 | 116 | any **100** |
| CMC Lookout Tower Challenge | 22 | 22 | all |
| Kevin Adams 100 | 100 | 94 | all |
| Kevin Adams 500 | 500 | 471 | all |

"Linked here" is lower than "listed" for the Adams challenges because matching
published lists to our features is done by name, and 35 entries could not be
resolved with confidence. They are deliberately left unlinked rather than
guessed — a wrong link awards badge progress nobody earned. See
`db/migrations/008`–`010`.

That caution earned itself again in September 2026, on a different job. Seven
waterfalls were matched to a second source by name and the pages turned out to
describe falls up to 396 km away. Two independently built lists agreed on all
seven, which proved nothing: both had matched on the name, so both made the
same mistake. **Agreement between two matchers that share a flaw is not
corroboration.** The arbiter is the coordinate each source publishes, and a
name match more than 20 km from ours is now refused.

The WC100 asks for any 100 of its 115, so progress is measured against 100, not
against the list length.

## Data

None of it is authored here. It is read from nine sources — HikingWNC,
OpenStreetMap, NC Waterfalls, dwhike, a seed spreadsheet and the published
challenge lists among them — and **kept unmerged**. Each source's reading of
each waterfall is stored as its own set of claims, so where two sources
disagree about a height or a trail length, the database records the
disagreement rather than picking a winner at import time.

The coordinate is the one field where agreement is required rather than
recorded. A waterfall is published on the map only when two or more independent
sources put it in the same place, which is why 495 of 966 places appear. The
rest are real waterfalls we are not yet confident enough to send somebody to.

### Who owns the ground

`features.owner` answers the question the rest of the record cannot: whether you
can legally go. It is a category rather than a name — the name of the park or
the family belongs in a note.

| Value | Falls | Means |
|---|---|---|
| `Federal` | 72 | National forest, mostly Pisgah and Nantahala |
| `State` | 21 | State parks and state forests |
| `GSMNP` | 6 | Great Smoky Mountains National Park, which has its own rules |
| `Private` | 7 | Private land. Some welcome visitors, some do not |
| `Conservancy` | 4 | Land trusts and conservancies |
| `Cherokee` | 2 | The Qualla Boundary, which is sovereign land and not a park |
| unset | 843 | Not established. Usually national forest, but unverified |

`Private` does not mean "do not go" on its own — Pearson's Falls charges
admission and Bird Rock Falls is walked to daily. It means the question has an
owner, and the answer is theirs. Two of the seven, English Falls and Twin Falls
on the Thompson River, are recorded as having no public access at all.

**How we decide whether two records describe the same waterfall** — where
each source comes from and whether reading it was allowed, why waterfall
names repeat, what evidence we hold, and every way it has gone wrong here:
[docs/MATCHING.md](docs/MATCHING.md). Read that before touching any importer.

Known problems in the upstream data are written up in
[docs/hikingwnc-data-issues.md](docs/hikingwnc-data-issues.md) — including six
waterfalls recorded one degree of longitude too far east.

### Verifying a place is real

Being published answers "do two sources agree on where this is." It does not
answer "has anyone actually checked it out" -- that is a separate, ongoing,
deliberately manual review, one feature at a time, not a script. What
"checked it out" means is still being worked out; this is jw's list so far,
and he expects to add to it.

For a given feature, has anyone verified that:

1. the coordinate actually has a waterfall at it
2. there is some consensus around its name
3. the links we provide are about that same waterfall, not a namesake
4. it has the access point (trailhead/parking) we say it does
5. its difficulty/access-point info is accurate -- needs a word that isn't
   "accessibility", since that name is already taken by the hike-difficulty
   field (`Easy`, `Moderate+`, `Hard`, ...). Candidate: *reachability*.

These are independent, and a single check rarely answers all five at once.
jw, visiting Bubbling Springs Branch (Upper and Lower falls) in person: no
signs were posted, so nothing confirmed which name belongs to which fall --
(2) stayed unverified. But there were definitely waterfalls there, and he
could get to them, which does confirm (1) and (4). A visit strengthens
whichever of the five it actually touched, not all of them at once.

Settled on a small checklist rather than one summary field, generalized into
a `facts` table (one row per feature/key, holding the value itself, not a
log of an action) with two independent confidence measures: a method ladder
(never checked, up through a human confirming it in person) and a 0-4.3
outcome score, since the two can genuinely disagree -- see *Facts* in
[ARCHITECTURE.md](ARCHITECTURE.md).

See [ARCHITECTURE.md](ARCHITECTURE.md) for the schema and how the pieces fit.

## Looking after it

Two pages exist for whoever runs the site rather than for visitors. Both are
disallowed in `robots.txt`.

**The guard is on the data, not on the URL.** Both pages are static HTML served
to anybody who asks; each is an empty shell whose first `fetch` hits an
endpoint that calls `requireAdmin` and answers 401 or 403, at which point the
page shows a sign-in prompt instead of a table. Nothing is rendered into the
HTML server-side, so an unauthenticated request gets markup and no data. That
is deliberate — a bare 403 tells a signed-out admin nothing about what to do
next — but it does mean the URLs are not secrets and should not be treated as
one.

| Page | What it is for |
|---|---|
| `/corrections/queue` | reports people have sent about places that look wrong |
| `/admin/users` | every account, and whether the person ever actually got in |

The accounts page exists because of a specific failure. For as long as
passwordless sign-in had been deployed, the handler built a link, wrote it to
the database, logged that it had been sent, and never gave it to the mailer, so
not one link was ever delivered. Nothing in the app could see that. A row
showing links issued and none used is what that looks like from the outside,
and the page marks those accounts **stranded**.

Admin is `users.is_admin`, set by hand:

```sh
psql "$DATABASE_URL" -c "UPDATE users SET is_admin = true WHERE email = '...'"
```

## Status

Early, and worked on for fun. Areas, deprecation reasons, notes and
user-submitted corrections have all reached the interface since this list was
first written. `features.owner` is the one that has not: it is served in the
`/features` payload and documented above, but no page displays it.

There is a test suite now — ten tests, some needing a scratch database. See
*Testing* in [ARCHITECTURE.md](ARCHITECTURE.md) for how to run them.
