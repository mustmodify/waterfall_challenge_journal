# Sources, and how they get matched to a waterfall

None of the data here is authored. It is read from other people's work and
filed under their name. This document covers where each source comes from, how
a page on somebody else's site gets attached to a row in `features`, the ways
that attachment goes wrong, and what is in place to catch it.

The short version of the hard part: **a name tells you what shares a name, not
what a thing is.** Every serious data error in this project so far has come
from treating those as the same question.

## The sources

| Source | Groups | Features | What it contributes |
|---|---|---|---|
| `hikingwnc` | 943 | 913 | Names, hike distance, all three ratings, accessibility, coordinates, some heights. The backbone. |
| `openstreetmap` | 640 | 611 | A second independent coordinate for 609 falls, plus names, aliases, heights, and viewpoints. |
| `ncwaterfalls` | 147 | 125 | Kevin Adams. Hike distance, accessibility, owner, elevation, beauty, parking, heights. |
| `dwhike` | 114 | 100 | Hike distance, vertical gain, trailheads, and the WC100 KML points. |
| `hikingwnc-supplement` | 24 | 24 | Later additions from the same site, kept separate so the original scrape stays reproducible. |
| `wanderfall` | 6 | 6 | Our own corrections, recorded as a source so they can be argued with. |
| `jw` | 3 | 3 | Hand observations. |
| `google-maps` | 2 | 1 | |
| `waterfallshiker` | 1 | 1 | |

Five fields have exactly one source, so losing that source loses the field
entirely:

- `elevation_ft` and `owner` — only ncwaterfalls
- `elevation_gain_ft` and `petzoldt` — only dwhike
- `view_coordinate` — only OpenStreetMap

### How each was obtained, and whether that was allowed

This matters enough to write down, because the polite answer is different for
each site and the impolite version of any of them would get us blocked.

- **hikingwnc** — scraped once to JSON under `data/`. The claims are built from
  that JSON rather than from the `features` columns, because those columns have
  been corrected repeatedly and would otherwise report our own conclusions back
  to us as hikingwnc's.
- **ncwaterfalls** — the site allows crawling and publishes a sitemap. Pages
  were fetched one at a time, a quarter second apart, and cached under
  `data/spider-cache`. Later work reads the cache and refetches nothing.
- **dwhike** — a SmugMug site. SmugMug refuses all crawlers because the servers
  cannot take it, but it does allowlist `archive.org_bot`, so the copies we read
  are Wayback's. They were made with permission and reading them costs his
  servers nothing. The links still work for an ordinary visitor: SmugMug blocks
  crawlers, not people.
- **OpenStreetMap** — an Overpass extract. Adds no new features, only a third
  reading of points we already carry.

## Why claims are not merged

A claim is one source's assertion about one field of one feature. They are
stored side by side and never reconciled at import time, because a
disagreement is information. Two sources differing on a height tells you the
height is uncertain; picking a winner at import throws that away and leaves
behind a number that looks confident.

`accepted` marks the single claim per `(feature, field)` that the published
columns reflect. A partial unique index enforces that there is only ever one.

The coordinate is the exception, and it is the one that decides whether a
waterfall is published at all — see `coordinate_confidence` in
[ARCHITECTURE.md](../ARCHITECTURE.md).

## The matching problem

A source publishes a page about "Silver Run Falls". We have a feature called
"Silver Run Falls". Attaching one to the other looks like string equality and
is not.

Adams covers all of North Carolina; we carry the western end. NC has more than
one of most waterfall names. So the question "which of our features is this
page about" has a wrong answer that is always available and always plausible.

### How it goes wrong

Four distinct failure modes, each with a real instance from this project:

**1. The name matches a different waterfall.** Adams' Silver Run Falls is 396
km from ours, in Cumberland County. His Jones Falls is 305 km away, his Cedar
Falls 280 km. Seven of 115 candidates were wrong this way — about 6%, which is
far too high to accept and far too low to notice by spot-checking.

**2. Two matchers agree, and agreement means nothing.** The seven above were
found by two lists built independently, months apart, by different people. Both
lists contained all seven errors. They agreed because both had matched on the
name, so both made the same mistake. **Corroboration only counts when the two
readings can fail differently.**

**3. Proximity answers a different question than identity.** The mirror of the
name problem. Matching Wikipedia articles by geosearch around our coordinates
returned Looking Glass Rock for "Sliding Rock" (1,022 m away) and the town of
Lake Toxaway for "Toxaway Falls" (959 m). Nearby is not the same as this. Only
2 of 10 well-known falls matched correctly, and the failures were confident.

**4. A bad match masquerades as a source disagreement.** This is the expensive
one. Once a wrong page is attached, the claims layer shows two sources
disagreeing about where a waterfall is — which is exactly what it is designed
to record. Two of the seven had been reported as genuine coordinate conflicts
between Adams and hikingwnc. They were never about the same waterfall.

## The pipeline

Three stages, and only the first is built today.

### Stage 1 — distance and name (built)

Propose candidates by name, then require the source's own published coordinate
to agree with ours. `script/import_links/ncwaterfalls.py` is the reference
implementation:

- under **2 km** — accept. Trailhead-versus-water accounts for the gap.
- **2–20 km** — accept with a note. Shared-coordinate trailhead groups live
  here legitimately.
- over **20 km** — refuse. A different waterfall that happens to share a name.

Where neither side publishes a coordinate there is nothing to arbitrate with,
and those go through unverified and flagged. They are also, by definition, the
features we know least about.

### Stage 2 — an AI pass over what stage 1 could not settle (NOT BUILT)

The intent is a second pass that reads the candidate pages and decides the ones
distance and name cannot: different names for the same fall, a page covering
several falls at once, a source whose coordinate is the parking area three
ridges over. Expected to resolve the great majority of the remainder — the
working target is 99% of all candidates settled by the end of stage 2.

**None of this exists yet.** No code in this repository calls a model. Written
down here so the design is on record, not because it is running.

### Stage 3 — jw (built, in the sense that jw exists)

Whatever survives two passes is a genuine judgement call and goes to a person.
The volume is meant to be small enough that this is an afternoon, not a
project.

## What is in place to catch a bad match

- **`identity_certain` on `claim_groups`.** False means matched by name and
  never confirmed against a coordinate. 163 OpenStreetMap groups and 103
  ncwaterfalls groups are currently in that state.
- **Uncertain groups are never published as links.** Migration 052 harvests
  claim-group URLs into `links`, filtered on `identity_certain`. A source
  saying something about the wrong fall must not become a link on a real card.
- **Bad matches are marked, not deleted.** Migration 051 flags rather than
  removes. A source saying something about the wrong waterfall is still a thing
  that source said, and deleting the record invites the next importer to make
  the same match again with nothing to warn them.
- **The published set requires corroboration.** A waterfall reaches the map
  only when two independent sources agree on where it is.

## Adding a new source

1. Check `robots.txt` and honour it. If the site refuses crawlers, look for an
   archive that was allowed in, and say so in the migration header.
2. Cache what you fetch under `data/spider-cache` and read the cache
   afterwards. Later passes should cost the source nothing.
3. Import as claims under a new `source` name. Do not write to `features`.
4. Match by name to get candidates; arbitrate on coordinates. Mark anything you
   could not arbitrate as `identity_certain = false`.
5. **Report what you rejected, not just what you kept.** A matcher that only
   reports successes cannot be reviewed — the interesting number is how many
   candidates it threw away and why.
6. Add a `LINK_LABELS` entry in `static/index.html` if the source has URLs.
   Read the label off the site's own `<title>` or `og:site_name`: two people
   independently guessed at waterfallshiker.com's name and both were wrong.
7. Re-run migration 052 to publish the new URLs.

## Known gaps

- `script/import_links/ncwaterfalls.py` reads a candidate list from
  `/tmp/_jw/`, so it does not run from a clean clone. The cached pages it
  arbitrates against are in the repository; the candidate list should be too.
- 170 of the 279 ncwaterfalls pages matched nothing of ours. That is name
  drift rather than absence, and it is the cheapest remaining win — the pages
  are already cached.
- 54 links created before the coordinate check exists sit on groups later
  marked uncertain, Silver Run Falls among them.
