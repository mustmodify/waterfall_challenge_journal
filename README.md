# Wanderfall

A map and logbook for the waterfalls and lookout towers of Western North
Carolina. Find somewhere to go, record that you went, and track progress
against the challenge lists that people actually hike.

Currently **956 places** — 934 waterfalls and 22 lookout towers — across four
challenges. 464 of them are published on the map; the rest are held back until
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

```sh
createdb wc_journey_db
for f in db/migrations/*.sql; do psql -d wc_journey_db -v ON_ERROR_STOP=1 -f "$f"; done
go run .
```

Then <http://localhost:8080>.

Database connection details are constants at the top of `main.go`
(`DB_USER`, `DB_PASSWORD`, `DB_NAME`) — change them there for now.

### Signing in

Sign-in is passwordless. Enter an email address and the server issues a
single-use link that expires in 20 minutes; following it signs you in, and
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
sources put it in the same place, which is why 464 of 956 places appear. The
rest are real waterfalls we are not yet confident enough to send somebody to.

Known problems in the upstream data are written up in
[docs/hikingwnc-data-issues.md](docs/hikingwnc-data-issues.md) — including six
waterfalls recorded one degree of longitude too far east.

See [ARCHITECTURE.md](ARCHITECTURE.md) for the schema and how the pieces fit.

## Status

Early, and worked on for fun. Things that exist in the database but not yet in
the interface: areas, landowner, deprecation reasons, notes, and user-submitted
corrections.
