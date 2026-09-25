# Scripts

Everything here is outside the server. Three kinds: the migration runner,
which is part of deploying; the importers under `import/`, which are one-off
programs kept for provenance, so it stays possible to see where each field
came from; and a few tools that check what is already here rather than adding
to it.

Anything that fetches from a source, or turns what was fetched into claims,
belongs under `import/`. It used to be spread across `script/spider/`,
`script/backfill_claims/`, six `script/import_*` directories and a handful of
loose files, which meant the answer to "where does a new scraper go" depended
on which of them you had seen.

## The migration runner

The one thing here that runs in production. `render.yaml` calls it from
`preDeployCommand`, so a schema change arrives with the code that needs it.

```sh
DATABASE_URL="..." go run ./script/migrate           # apply what is pending
DATABASE_URL="..." go run ./script/migrate -status   # what has run, what has not
DATABASE_URL="..." go run ./script/migrate -baseline # record all as applied, run none
```

It requires `DATABASE_URL` and has no fallback to the constants in `main.go`,
unlike the server. `-baseline` is for a database built from `db/schema.sql`,
which already contains everything the migrations would have done — see
[DEPLOY.md](../DEPLOY.md).

## The importers

Go, one directory each because Go allows one `main` per package. They share
`script/` only as a parent; putting them in one package is what used to break
`go build ./...`.

```sh
go run ./script/import/hiking_wnc_falls
go run ./script/import/my_data
go run ./script/import/waterfalls
```

They write directly to the database and are **not idempotent**. Read one before
running it.

## The Python side, all under `import/`

| Directory | What it does |
|---|---|
| `spider/` | fetches and caches pages under `data/spider-cache` (gitignored), one at a time and politely — `ncwaterfalls.py`, and `dwhike_wayback.py` for the SmugMug site that only Wayback was allowed to crawl. `cache.py` is the archive format and `overpass.py` the Overpass client; a new scraper should use both rather than inventing its own |
| `claims/` | turns cached pages and extracts into `claim_groups` and `claims`, one module per source. Each one writes a migration rather than writing to the database |
| `links/` | matches a source's pages to our features and publishes the URLs it is confident about |
| `alltrails/` | the whole AllTrails path in order: `fetch.py`, then `match.py`, then `build.py`. `compare.py` checks the matcher against verdicts reached by hand |
| `nldi/` | drainage area, fetched then built |
| `usgs_elevation.py` | ground elevation for anything with a coordinate |
| `osm_escarpment.py` | every OpenStreetMap waterfall in the region, with the creek each one sits on |

Migration headers written before 2026-09-25 cite the older paths in their
comments; those have been rewritten to point at the new ones, since a comment
naming a directory that no longer exists helps nobody.

## Checking rather than importing

These read what we already have and report. Nothing here writes claims.

```sh
python3 script/water_check.py --feature-id 398   # is there mapped water near a point
python3 script/water_sweep.py --single-source    # the same question, for hundreds
python3 script/review_links.py                   # links due for review, and whether they resolve
```

The matching rules the importers follow are in [docs/MATCHING.md](../docs/MATCHING.md),
which any new importer should be read against. The short version: match by name to get candidates, then arbitrate on the coordinate the
source itself publishes, and report what you rejected rather than only what you
kept.
