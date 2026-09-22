# Matching: deciding whether two records are the same waterfall

Every serious data error in this project has come from one mistake, made in
several disguises: **treating "shares a name" as "is the same thing".**

This document is the consolidated version of what we have learned doing that
wrong. It covers why waterfall names repeat, what evidence we hold, how the
evidence is combined, what each source needs, and every failure that has
actually happened here with its real numbers.

> **Forward reference.** This document describes `name_core` / `name_key` and
> the 200 m ncwaterfalls rule, which live in migration 058 — open in PR #29 and
> not yet merged. Until it lands, those two sections describe a rule with no
> code behind it. Everything else here is implemented.

Related: [hikingwnc-data-issues.md](hikingwnc-data-issues.md) for defects in
the upstream data; [ARCHITECTURE.md](../ARCHITECTURE.md) for the claims
schema.

---

## 0. The sources

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
- **AllTrails** — see §7. Read through their MCP server, not a crawler:
  `robots.txt` disallows `ClaudeBot`, `Claude-User` and `Claude-SearchBot` from
  all of `/`, and `/api/` from everybody. `https://www.alltrails.com/mcp`
  is the door they built for this instead, no key required. It means the
  harvest runs one call at a time through a model rather than a loop, and 934
  waterfalls is a long afternoon. Cache everything under `data/alltrails/` and
  never ask twice.

### Why claims are not merged

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

### Adding a new source

1. Check `robots.txt` and honour it. If the site refuses crawlers, look for an
   archive that was allowed in, and say so in the migration header.
2. Cache what you fetch under `data/spider-cache` and read the cache
   afterwards. Later passes should cost the source nothing.
3. Import as claims under a new `source` name. Do not write to `features`.
4. Match by name to get candidates; arbitrate on coordinates per the rule in
   §3. Mark anything you could not arbitrate as `identity_certain = false`.
5. **Report what you rejected, not just what you kept.** A matcher that only
   reports successes cannot be reviewed — the interesting number is how many
   candidates it threw away and why.
6. Add a `LINK_LABELS` entry in `static/index.html` if the source has URLs.
   Read the label off the site's own `<title>` or `og:site_name`: two people
   independently guessed at waterfallshiker.com's name and both were wrong.
7. Re-run migration 052 to publish the new URLs.

---

## 1. Why waterfall names repeat

A name is a real name. "Rainbow Falls" is not a nickname or a placeholder —
somebody named that waterfall, and they meant it. The problem is not that the
name is descriptive. **The problem is that it is not unique**, and it is not
unique for a reason that keeps recurring.

Waterfalls get named for what they look like or what they do:

- **Rainbow Falls** — a fall throwing enough spray will refract sunlight into a
  rainbow from some angles. Any high-spray fall does this, so any of them can
  be called Rainbow Falls.
- **Stairway Falls** — a cascade running down regular stepped rock looks like a
  staircase. Any stepped cascade can be called Stairway Falls.
- **High Falls, Big Falls, Little Falls** — relative size, assigned by whoever
  was standing there.
- **Twin, Double, Triple Falls** — a count of visible drops.
- **Bridal Veil, Dry Falls, Cascade Falls** — shape, behaviour, form.
- **Upper, Lower, Middle, Second, Third Falls** — position in a sequence on one
  creek. The worst of the lot, because they are *relative*: "Second Falls"
  means nothing without knowing second on what, and every creek with a run of
  drops generates its own Upper and Lower. **190 of our 934 waterfalls carry
  one of these words** — upper 80, lower 55, little 23, middle 23, big 21 —
  which is one in five.

Two people who have never heard of each other, standing at two different
stepped cascades two counties apart, will both arrive at "Stairway Falls",
because it is the obvious thing to call it. **The collisions are generated
independently and are therefore predictable rather than accidental.** The same
physics that makes a waterfall worth visiting is what produces its name, so
names pile up exactly where the features most resemble each other.

### Aliases come from the same pressure

The same mechanism explains why waterfalls have alternate names at all. Someone
arrives at a fall, does not know what it is called — or heard the name once and
did not remember it — and coins one. Being a person looking at a waterfall,
they coin it the way everyone else does: from spray, shape, size, or position.

So an alias is usually **a second independently-invented obvious name**, and it
collides as readily as the first. This is not a tidy one-name-per-fall world
with occasional nicknames; it is several naming events per fall, each drawing
on the same small vocabulary.

It also explains name drift between catalogues. **170 of 279 ncwaterfalls pages
matched nothing of ours** — not because those waterfalls are absent from our
list, but because two catalogues recorded two different coinages for the same
water.

The opposite case is a name that records something arbitrary — a creek, a
landowner, a person: **Poundingmill Branch Falls, Rufus Morgan Falls, Joe Pack
Falls, Catheys Creek Falls**. Nothing else is called that, because the naming
had no generative rule behind it.

### A name that carries a creek carries a coordinate check with it

**If a fall is called "XYZ Creek Falls", it is almost certainly on XYZ Creek.**
That sounds too obvious to write down until you notice it is a free,
independent check on the coordinate: the name tells you which water the fall
should be sitting on, and OpenStreetMap will tell you what water is actually
at the point we hold. A "Catheys Creek Falls" whose coordinate sits on
Davidson River is either the wrong coordinate or the wrong name, and either
way it wants a human.

It cuts the other way too, and that is where it earns its keep. hikingwnc on
Tom's Spring Falls:

> This may be confusing but this waterfall goes by several different names. It
> is known as Daniel Ridge Falls even though it isn't on the nearby Daniel
> Ridge Creek. The waterfall in on the Toms Spring Branch so many refer to it
> as Toms Spring Falls. It's also known as Jackson Falls. [...] When in doubt,
> I like to refer to them by the body of water they reside on.

So one of that fall's three names is actively misleading about its own
location, and the creek is what settles it. That generalises: **where a
cluster of falls share a person's name, the creek discriminates better than
the name does.** Toms Creek Falls is on Toms Creek and Tom's Spring Falls is
on Toms Spring Branch — different water, 80 km apart, and nothing about
"Tom" separates them. See the "Falls Named Tom" confusion set for the
worked case.

### Elevation is a check on the coordinate

USGS's point service answers with the ground elevation **at the coordinate we
hold**, not at the waterfall — so when it disagrees badly with a source's
stated elevation for the same fall, the argument is really about the
coordinate.

Across the 116 features where both USGS and ncwaterfalls give an elevation,
they agree to 2.6% on average, 83 ft. Two do not:

| | usgs | ncwaterfalls | our coordinate |
|---|---|---|---|
| Big Bearwallow Falls | 3,681 ft | 2,420 ft | single source |
| Cutler Falls | 2,492 ft | 3,819 ft | single source |

Both are features where only one source has ever said where the waterfall is,
so nothing corroborates the pin — and Cutler Falls is already in §3's table as
an ncwaterfalls match refused at 118 km. A 1,300 ft disagreement about a
waterfall in mountains that top out around 6,700 ft is not a measurement
dispute; it is two parties describing different places.

This generalises the same way the creek rule does: a field we were not
treating as evidence about position turns out to be exactly that, for free,
because it was measured *at* the position.

### Read the prose, not just the fields

Related, and worth saying because it is easy to write an importer that only
reads the structured bits: hikingwnc's driving directions are of no use for
matching, but its prose regularly carries the alias and disambiguation
information nothing else has. The paragraph above is the only place any of
our sources says that Daniel Ridge Falls, Toms Spring Falls and Jackson
Falls are one waterfall. Coordinates remain the arbiter — but the thing that
tells you *which candidates to arbitrate between* is often a sentence.

### What that means for a matcher

Name agreement is real evidence. It is just a different *quantity* of evidence
depending on the name, and the quantity is measurable.

```
934 waterfalls, reduced to a base name (parentheticals and
disambiguating suffixes removed):

  811 of 857 base names are unique
  118 waterfalls share a base name with at least one other

  most reused:  5  Big        5  High       5  Rainbow
                4  Twin       4  Grassy     4  Little     4  Boomer Inn
                3  Buck       3  Camp       3  Cascades   3  Indian
                3  Laurel     3  Long       3  Mill
```

So roughly one waterfall in eight carries a name somebody else also used — and
that is within our own 934, covering one corner of one state. Kevin Adams
covers all of North Carolina; AllTrails covers the world.

**The rule that follows: how far apart two records may sit and still be the
same waterfall should depend on how many things share the name.** An exact
match on "Ramsey Cascades" 5 km from our point is safe, because almost nothing
is called that. An exact match on "High Falls" 5 km away is worth nothing at
all. Both are currently treated identically, which is the largest known gap in
this document — see §8.

### Disambiguators are the existing workaround

Because the base names repeat, lists add a qualifier, and different lists add
different ones:

| ours | Kevin Adams | what the qualifier is |
|---|---|---|
| `High Falls- Little River` | `High Falls` | the river |
| `Rainbow Falls- Horsepasture River` | `Rainbow Falls` | the river |
| `Rainbow Falls (Camp Greenville)` | — | the property |
| `Rainbow Falls (Gorges)` | — | the park |
| `Drift Falls (Bust-Your-Butt Falls)` | `Quarry Falls-A.K.A. Bust-Your-Butt Falls` | an alias, attached to a *different* fall |

A qualifier one side carries and the other omits **is name agreement**, not
disagreement. "Which High Falls?" is a question the coordinate answers.

**The two formats mean the same thing, and our own list uses both.** All five
of our High Falls are disambiguated, three with a hyphen and two with
parentheses:

```
High Falls- Little River            High Falls (Beech Creek)
High Falls- South Fork Mills River  High Falls (Cullowhee Falls)
High Falls- Thompson River
```

Across all 934 waterfalls: 21 names use a hyphenated qualifier, 122 use a
parenthesised one. One convention, two spellings, mixed inside a single base
name — so a matcher has to reduce both to the same key.

Ours does not, quite. `name_core` in migration 058 (**not yet merged**) deletes a parenthetical
outright while leaving a hyphenated qualifier in place:

```
High Falls (Beech Creek)  ->  "high falls"
High Falls- Little River  ->  "high falls little river"
```

Both still matched, because the comparison also accepts one key being a prefix
of the other — so the prefix test is quietly carrying an inconsistent
normalisation. Worth fixing before anything else depends on `name_core`.

**Update, migration 098.** Something now does depend on it, and building that
turned up what the comparison actually needs: `name_core` **and** the spaces
taken out. `name_core` renders punctuation as a space, so "Pearson's" becomes
`pearson s` while ncwaterfalls' "Pearsons" becomes `pearsons`, and they still
fail to match. Removing the spaces is migration 088's rule — the one that
recovered "4 X 4 Falls" against "4x4 Falls" with nothing false inside 3.8 km.

Pearson's Falls is the case that needs both halves. Three sources claim it as
"Pearson's Falls", "Pearsons Falls-Visiting Guide, Photos, Map", and
"Pearson's Falls and Glen". Raw equality sees three different names.
`name_core` alone still sees three, because of the apostrophe. Together they
see two agreeing and AllTrails describing a trail rather than the fall, which
is the right answer.

Applied across the catalogue, that combination moved **57 features out of
disputed and into corroborated** — they had only ever been disagreeing about
punctuation and marketing.

Two other things that pass for agreement and are not:

- **Counting claim rows instead of sources.** `hikingwnc` and
  `hikingwnc-supplement` are one site twice, so two readings from them is not
  corroboration — §5.2's rule, in a new disguise. Deduplicate by source before
  counting.
- **Treating two as a majority.** Two sources that contradict each other are a
  dispute, not a consensus; there is no majority in a group of two. Requiring
  three before calling anything consensus is what separates the two cases, and
  omitting it produced zero disputed coordinates where the existing
  `coordinate_confidence` view found five.

---

## 2. What evidence we hold

| Evidence | Where | Good for | Fails when |
|---|---|---|---|
| Our coordinate | `locations` via `features.feature_location_id` | everything | 55 features have none |
| The source's own published coordinate | `claims` where `field='coordinate'`, per `claim_group` | the arbiter | the source publishes none |
| Our name | `features.name` | proposing candidates | the name is a common one |
| The source's name | `claims` where `field='name'` | confirming a candidate | page titles carry SEO tails |
| Aliases | `claims` where `field='alias'` | alternate names | 43 claims, only 3 accepted |
| Trail position | AllTrails `_meta.pins` | the arbiter for a trail match | it is a point on a ROUTE, median 653 m from the fall |
| Trailhead position | AllTrails `trail_head_distance_meters` | proximity only | **is not the waterfall** — see §4 |
| Hike distance | `claims`, `features.rt_hike_distance` | sanity-checking a route | one-way vs round-trip prose |
| Elevation, height, gain | `claims` | weak corroboration | sparse, and sources disagree |

**`claim_groups.identity_certain` is where doubt is recorded.** False means the
group was attached by name and never confirmed against a coordinate. The source
may be describing a different waterfall entirely, and if so then *everything*
that group asserts is about the wrong fall at once — not just one field.

---

## 3. The rule

Two tests, and **both** must pass. Not either.

**Name.** The same core once page-title noise is removed, or one side carrying
a disambiguator the other omits, or a recorded alias matching.

**Position.** The source's own published coordinate close enough to ours.

```
   < 2 km    accept      trailhead-versus-water accounts for the gap
  2 – 20 km  flag        shared-coordinate trailhead groups live here legitimately
   > 20 km   refuse      a different waterfall that happens to share a name
```

Migration 058 (**PR #29, not yet merged**) tightens the accept band to **200 m**
for ncwaterfalls specifically, because every candidate there already sat inside 196 m and a
threshold set where the data actually lies will not quietly admit something
looser later.

### Both halves earn their place

The leftovers after migration 058 prove neither test is decoration:

| ours | theirs | apart | refused by |
|---|---|---|---|
| Silver Run Falls | Silver Run Falls | 395 km | position |
| Jones Falls | Jones Falls | 306 km | position |
| Cedar Falls (Fountain Inn) | Cedar Falls | 279 km | position |
| Cutler Falls | Cutler Falls | 118 km | position |
| Patricia Falls | Waterfall on Wolf Creek Tributary | **0.2 km** | **name** |

Name without position and position without name are both refused.

### Never flip on position alone

Two sources putting a pin in the same clearing is how Moore Cove Falls got a
page about a different creek. **Position is the arbiter between candidates the
name has already proposed. It is never the proposer.**

---

## 3a. What kind of point a source publishes

Measured against the 442 waterfalls whose coordinate two independent sources
already agree on — a calibration set, since those points are known good:

| source | field | n | median | p90 | within 250 m |
|---|---|---|---:|---:|---:|
| hikingwnc | `coordinate` | 432 | 0 m | 0 m | 432/432 |
| openstreetmap | `coordinate` | 432 | 22 m | 72 m | 432/432 |
| ncwaterfalls | `coordinate` | 31 | 24 m | 94 m | 31/31 |
| dwhike | `coordinate` | 61 | 32 m | 109 m | 61/61 |
| ncwaterfalls | `parking_coordinate` | 21 | 1,084 m | 90 km | 3/21 |
| dwhike | `parking_coordinate` | 16 | 1,292 m | 2,950 m | 0/16 |
| **alltrails** | **trail pin** | **106** | **653 m** | **1,657 m** | **24/106** |

Four sources publish a point *for the waterfall* and agree to within about
100 m. The route-shaped fields sit a kilometre out, and an AllTrails trail pin
sits between the two at a median of 653 m — **not noise around a waterfall
coordinate, a different quantity.**

`coordinate_confidence` calls two waterfall sources *corroborated* at 250 m. A
trail pin clears that less than a quarter of the time while being the right
trail, so feeding pins into that view would reject three matches in four and
promote almost nothing.

**The schema already answers this, by field rather than by flag.** dwhike
separates `coordinate` from `parking_coordinate`, and `coordinate_confidence`
counts only the first — so route-shaped readings have been excluded by
construction all along. A trail pin therefore wants its own field too, not a
new confidence tier and not a `source_kind` column. Then pins cannot
contaminate corroboration by accident, and promoting a feature on the strength
of one becomes an explicit decision instead of something that happens quietly.

## 4. Trailhead distance is not a coordinate check

This is the one that looks like the rule above and is not.

When both sides publish a point for the waterfall itself, distance between them
measures disagreement. When one side publishes **where you park**, distance
measures how long the walk is.

- **Ramsey Cascades** — its trail's trailhead is **5,280 m** from the falls,
  because the falls is four miles up a 7.9 mile out-and-back. Under the
  ncwaterfalls rule that is an instant reject. It is in fact an exact name
  match to the only trail that reaches that waterfall.
- **Elk River Falls** — "Elk River Falls Trail" (0.3 mi) and "Jones Falls and
  Splash Dam Falls From Elk River Falls" (5.3 mi) report the **same trailhead
  distance to the metre**. One is about our waterfall, one merely starts there.
  Distance cannot separate them; the name can.

So a matcher has to know which kind of point it is comparing. For trailhead
sources, distance bounds the search and the name decides the match.

---

## 5. The four ways it goes wrong

Each has a real instance from this project.

**1. The name matches a different waterfall.** Adams' Silver Run Falls is 396
km from ours, in Cumberland County. Jones Falls 305 km, Cedar Falls 280 km.
Seven of 115 candidates were wrong this way — about 6%, far too high to accept
and far too low to catch by spot-checking.

**2. Two matchers agree, and the agreement means nothing.** Those seven were
found by two lists built independently, months apart, by different people. Both
contained all seven errors, because both matched on the name and so made the
same mistake. **Corroboration only counts when the two readings can fail
differently.**

**3. Proximity answers a different question than identity.** Matching Wikipedia
articles by geosearch returned Looking Glass Rock for "Sliding Rock" (1,022 m)
and the town of Lake Toxaway for "Toxaway Falls" (959 m). Only 2 of 10
well-known falls matched correctly, and the failures were confident.

**4. A bad match masquerades as a source disagreement.** The expensive one.
Once a wrong page is attached, the claims layer shows two sources disagreeing
about where a waterfall is — exactly what it is built to record. Two of the
seven had been reported as genuine coordinate conflicts between Adams and
hikingwnc. They were never about the same waterfall.

### And one that is about the tool, not the data

**5. The search that never returned the right candidate.** AllTrails'
`find_trails_near_location` sorts by *relevance*, not distance. Called with
`limit: 3`, it silently omitted the correct trail for White Owl Falls; the
match only surfaced because a neighbouring search happened to list it. Four
waterfalls were recorded as "no match" on that basis and one of them —
**Ramsey Cascades** — was wrong. Always `sort: closest` with a generous limit.
A no-match is only a finding if the search could have found it.

### And one that is self-inflicted

**6. Untangling one collision can create another.** Migration 068
disambiguated three tangled names — Tom's Spring Falls, Toms Creek Falls, and
Toms Falls — by checking the new "Toms Creek Falls" it was about to create
against the one collision it already knew about, feature 366 (Tom's Spring
Falls). It never checked the new name against the rest of the `features`
table, where "Tom's Creek Falls" (feature 398, from hikingwnc, 50 m away, with
the identical AllTrails link) had been sitting the whole time. The migration
created a duplicate of a feature that already existed, and the duplicate
carried `identity_certain = true` — it looked exactly as trustworthy as a real
match, because nothing had disagreed with it yet. jw caught it by eye on the
map; migration 087 merged the two back down to one. **A disambiguation
migration is itself a new source, and its own proposed name/coordinate needs
the same check against the existing feature set that any other source's
would get** — checking one known collision is not the same as checking all of
them.

---

## 6. What is in place to catch a bad match

- **Bad matches are marked, not deleted.** Migration 051 flags rather than
  removes. A source saying something about the wrong waterfall is still a thing
  that source said, and deleting the record invites the next importer to make
  the same match again with nothing to warn them.
- **Uncertain groups are never published as links.** Migration 052 harvests
  claim-group URLs into `links` filtered on `identity_certain`. **Verified
  2026-09-14:** seven ncwaterfalls groups sit more than 20 km out and *none of
  them has a link*. The guard works. A safeguard nobody checks is
  indistinguishable from one that does not.
- **The published set requires corroboration.** A waterfall reaches the map
  only when two independent sources agree on where it is.
- **Report what you rejected.** A matcher that only reports successes cannot be
  reviewed. The interesting number is how many candidates it threw away and
  why.
- **Not yet in place: a check before `INSERT`ing a new feature.** §5.6 is a
  duplicate that a name+coordinate search of the existing `features` table,
  run immediately before the `INSERT`, would have caught. No migration does
  this today; it is manual discipline, which is exactly the failure mode this
  document exists to route around everywhere else.

---

## 7. Per source

| Source | Publishes a point for | Matching rule |
|---|---|---|
| `hikingwnc` | the waterfall | the backbone; our names largely come from here |
| `openstreetmap` | the waterfall | name + coordinate; 163 groups still uncertain |
| `ncwaterfalls` | the waterfall | name + coordinate within 200 m (migration 058). Strip the SEO tail from page titles first — `Silver Run Falls-Visit Guide, Photos` |
| `dwhike` | a route | name, plus a route-length sanity check: where his route runs more than half again longer than the walk other sources describe, he passed the fall on the way somewhere else |
| `alltrails` | **a trailhead** | see §4. Search by position with the `waterfall` attraction filter, `sort: closest`; decide on the name |

### AllTrails specifics

Name search is unusable on its own: `search_trails_by_name("Looking Glass
Falls")` returns **Looking Glass Rock Trail** first — a 6 mile climb with 1,699
ft of gain, which is a mountain and not a waterfall. Proximity plus the
`waterfall` filter returns the right thing at 64 m.

Their prose is worth separating from their fields. The Stairway Falls
description gets the *waterfall* exactly right — "a dramatic six-tier waterfall
that drops incrementally like a giant stone staircase", which is what it is —
while placing it on the Oconaluftee River in the Smokies. It is on the
Horsepasture in Gorges State Park, which that same record's `park` and
`location` fields state correctly. Their slugs are unreliable too: Big Laurel
Falls is filed under `us/georgia/` while its own fields say NC, and our
waterfall sits 2,032 m north of the state line.

The attachment is **many-to-many in both directions**, which breaks naive
arithmetic over their counts:

- one fall, several routes — Dry Falls has "Dry Falls Trail" and "Dry Falls
  Viewing Platform"
- one route, several falls — "Cove Creek Falls and Toms Spring Falls"
- one route that merely starts here — see Elk River Falls in §4

---

## 8. Known gaps and open ideas

**Name frequency is not used.** The largest gap. §1 shows collision risk is
measurable, and nothing measures it. Today an exact name match counts the same
whether the name is "Ramsey Cascades" or "High Falls". The distance a match may
tolerate should scale with how many things carry the name — and the frequency
should be computed across the *sources'* names too, not only our 934, since a
name unique in our corner may be common statewide.

**Almost every alias is unaccepted.** Of 43 alias claims, **3 are accepted** —
Reedy Cove Falls for Twin Falls (SC), and two names for Shacktown Falls — and
40 are not. The unaccepted 40 include ones written deliberately to record a
*conflict*: Adams calls our Quarry Falls "Bust-Your-Butt Falls", a name we hold
on Drift Falls 27 km east.

So **any rule consuming aliases must filter on `accepted`**, or a name we are
disputing counts as a name we endorse. The three accepted rows are also what
keeps such a filter from being dead code — a point worth checking before
anyone "simplifies" it away.

Separately: the committed dumps hold 43 alias claims and 3 accepted, while the
development database holds 45 and 5. The dumps have drifted and should be
regenerated — see DEPLOY.md.

**Stage 2, an AI pass, is designed and not built.** A second pass over what
distance and name cannot settle: different names for the same fall, a page
covering several falls, a source whose coordinate is the parking area three
ridges over. Working target was 99% of candidates settled by the end of it. No
code in this repository calls a model.

**170 of 279 ncwaterfalls pages matched nothing of ours.** Name drift rather
than absence, and the pages are already cached, so it is the cheapest remaining
win.

**`identity_certain` is a group-level verdict established from one field.**
The matcher checks the coordinate of the *waterfall*, the group passes, and
every other claim in it — parking coordinate, elevation, owner, ratings —
inherits a certainty from evidence that never touched it. The name says the
group's identity is certain; what was established is that one field of it
agreed.

That is not hypothetical. **11 of 115 ncwaterfalls parking coordinates are a
whole degree of longitude from the waterfall they belong to**, on groups marked
certain:

```
Cascade Falls              longitude off by  -3.003
Poundingmill Branch Falls                    -3.002
Elk River Falls                              -3.001
Catawba Falls                                -2.986
Big Creek Falls                              -2.000
No-Name Cove Falls                           -1.996
...11 in total, every one with its latitude intact
```

They are the same defect class as the six hikingwnc records in
[hikingwnc-data-issues.md](hikingwnc-data-issues.md) — a whole-degree
transcription slip, latitude untouched — in a different source and a different
field. No other source's parking coordinates are affected.

They survived because nothing re-checks a field once its group is certain, so
the absurdity had to be found by someone measuring a distribution for an
unrelated reason. It was: a calibration set built to ask how far AllTrails
trail pins sit from a known-good coordinate.

The fix is per-field validation rather than per-group, or at minimum recording
*which* field was arbitrated so a reader knows what the certainty covers. The
11 look recoverable rather than wrong — the right fall with a parking
coordinate a whole degree out — but they are recorded, not corrected, on the
same principle as every other source defect here.

**Our own list has internal collisions.** 74 features share 35 coordinates —
trailheads recorded once per waterfall — and nine features are named
`Waterfall #N (04-14-2022)` and are unidentifiable.


**54 links sit on groups marked `identity_certain = false`**, which reads
worse than it is. They were checked on 2026-09-14 and every one holds: the
distance from our coordinate to the coordinate Kevin Adams publishes on the
linked page runs 0 to 196 m, mean 42 m. None is beyond 2 km. They are
uncertain because the *name* comparison failed, not the position — Adams
titles his pages "Silver Run Falls-Visit Guide, Photos" and the matcher was
comparing that against "Silver Run Falls". All 54 carry a note saying
"matched on position, with no name agreement". What remains is a judgement,
not a cleanup: whether position agreement inside 200 m with no name
agreement is enough to set `identity_certain = true`. If it is, one
re-arbitration migration settles all 54.
