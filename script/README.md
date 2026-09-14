# Scripts

Everything here is outside the server. Two kinds live side by side: the
migration runner, which is part of deploying, and the importers, which are
one-off programs kept for provenance — so it stays possible to see where each
field came from.

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
go run ./script/import_hiking_wnc_falls
go run ./script/import_my_data
go run ./script/import_waterfalls
```

They write directly to the database and are **not idempotent**. Read one before
running it.

## The Python side

| Directory | What it does |
|---|---|
| `spider/` | fetches and caches pages under `data/spider-cache` (gitignored), one at a time and politely — `ncwaterfalls.py`, and `dwhike_wayback.py` for the SmugMug site that only Wayback was allowed to crawl |
| `backfill_claims/` | turns cached pages and extracts into `claim_groups` and `claims`, one module per source |
| `import_links/` | matches a source's pages to our features and publishes the URLs it is confident about |

The matching rules these follow are in [docs/MATCHING.md](../docs/MATCHING.md),
which any new importer should be read against. The short version: match by name to get candidates, then arbitrate on the coordinate the
source itself publishes, and report what you rejected rather than only what you
kept.
