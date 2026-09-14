# Page harness

This is the front-end harness only. The Go tests are separate and run with
`go test ./...` — see *Testing* in [ARCHITECTURE.md](../ARCHITECTURE.md).

`index.html` carries its logic in an inline `<script>`, so there is nothing to
import and nothing to unit test. This runs that script for real — in Node,
against stubbed Leaflet and DOM objects and the actual feature data — and
reports what it did.

It exists because the failures that actually happened here were not the kind a
syntax check finds. It has caught:

- a `let` read before its declaration, which left the map blank
- `markerClusterGroup` added before the map had a `maxZoom`
- markers going into one cluster group instead of one per kind
- filter combinations returning the wrong counts

## Running it

Needs a running server to produce the fixture, which is too large to commit.

```sh
go run .                                     # in another shell
curl -s localhost:8080/features > test/features.json
node test/harness.js static/index.html test/features.json 8
```

The last argument is the map zoom to pretend to be at.

Expected output is one line per filter combination, for example:

```
Everything, no filters   900 clustered 878 in 1 group(s) [878], 22 unclustered
Only towers               22 clustered   0 in 0 group(s), 22 unclustered
```

## What it does not do

Nothing about CSS or layout, and nothing about what the page looks like —
every `L.*` is a stub written by hand, so it only checks invariants that
someone thought to model. Several real bugs this session were invisible to it
for exactly that reason.
