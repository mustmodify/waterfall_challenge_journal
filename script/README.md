# Importers

One-off programs that loaded the data. They are not part of the server and are
kept for provenance — so it is possible to see where each field came from.

Each lives in its own directory because Go allows one `main` per package; they
shared `script/` until now, which broke `go build ./...`.

```sh
go run ./script/import_hiking_wnc_falls
go run ./script/import_my_data
go run ./script/import_waterfalls
```

They write directly to the database and are not idempotent. Read one before
running it.
