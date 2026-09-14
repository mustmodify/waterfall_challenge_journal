# Deploying

The app is one Go binary and a Postgres database. It serves `static/` from the
working directory, so the repository is the deployment.

## Why there is a schema.sql

`db/migrations` is the history of how this database changed, not a recipe for
building one. Migration 001 adds users to a schema that already had features,
goals and locations in it -- those tables were made by hand before the numbered
files started, and nothing in the repository creates them. Replaying all 53
against an empty database fails on the first one.

So a new database is built from two dumps and then told the migrations are
already applied:

| file | what it is |
|---|---|
| `db/schema.sql` | every table, view, index and constraint |
| `db/reference_data.sql` | the waterfalls: features, locations, areas, challenges, links, notes, claims |

No account data is in either one. Users, sessions, visits, magic links and
correction reports start empty.

Regenerate them from a database you trust:

```sh
pg_dump -d wc_journey_db --schema-only --no-owner --no-privileges > db/schema.sql
pg_dump -d wc_journey_db --data-only --no-owner \
  -t features -t locations -t areas -t feature_areas -t challenges -t goals \
  -t links -t notes -t claim_groups -t claims > db/reference_data.sql
```

## First deploy

1. Create the Render services from `render.yaml` (Blueprint), or by hand: a Go
   web service and a Postgres instance.
2. Set `WANDERFALL_MAILGUN_KEY` in the dashboard. Everything else is in the
   blueprint. See the configuration table in README.md.
3. Load the database, from a machine with `psql` and the external connection
   string Render shows:

   ```sh
   psql "$DATABASE_URL" -f db/schema.sql
   psql "$DATABASE_URL" -f db/reference_data.sql
   DATABASE_URL="$DATABASE_URL" go run ./script/migrate -baseline
   ```

   `-baseline` records all 53 files as applied without running them, which is
   correct: `schema.sql` already contains everything they would have done.
4. Point wanderfall.app at the service and let Render issue the certificate.
5. Sign in once to confirm mail arrives, then make that account an admin:

   ```sh
   psql "$DATABASE_URL" -c "UPDATE users SET is_admin = true WHERE email = 'you@example.com'"
   ```

## Afterwards

Migrations run themselves. `preDeployCommand` in render.yaml runs the runner
after each build and before the new version takes traffic, so a schema change
arrives with the code that needs it. A failed migration fails the deploy and
the previous version keeps serving.

Nothing connected the two before, and it showed: the area pages were merged,
deployed, and served 500s until someone noticed, because the binary asking for
a `slug` column shipped four migrations ahead of the database that had one.

To look, or to run them by hand against any database:

```sh
DATABASE_URL="..." go run ./script/migrate          # apply what is pending
DATABASE_URL="..." go run ./script/migrate -status  # what has run, what has not
```

Never set `WANDERFALL_ECHO_LINKS` in production. It returns sign-in links in
the HTTP response, which lets anyone sign in as anyone.
