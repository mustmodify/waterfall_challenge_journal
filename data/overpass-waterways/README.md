# Overpass waterway probes

Small query results kept as evidence, not as a cache. The bulk cache lives in
`data/spider-cache/overpass/` and is gitignored, because anything there can be
fetched again; these are here because a written conclusion cites them.

- `ways-*` — Alarka Creek is 60 distinct ways and Big Creek is 96 across
  western NC, and there are no waterway relations in the region. So an OSM
  parent way identifies a segment rather than a creek. See MATCHING.md §9.7.
- `count-*` — 1,430 waterfall nodes in the escarpment, 1,249 inside the box
  our extract actually covered, against the 1,238 we hold.

The sweep those counts were asking about has since been run:
`script/import/osm_escarpment.py` walks the whole escarpment in tiles and writes
`data/osm-escarpment.tsv`, 1,425 nodes with the name of the way each one
belongs to. 1,046 of them sit on a named way, which is where migration 144's
watercourse claims come from.

Each `.overpass` file is the query that produced the `.json` beside it.
