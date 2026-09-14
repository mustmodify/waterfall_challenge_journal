# Matching: deciding whether two records are the same waterfall

Every serious data error in this project has come from one mistake, made in
several disguises: **treating "shares a name" as "is the same thing".**

This document is the consolidated version of what we have learned doing that
wrong. It covers why waterfall names repeat, what evidence we hold, how the
evidence is combined, what each source needs, and every failure that has
actually happened here with its real numbers.

Related: [sources-and-matching.md](sources-and-matching.md) for where each
source came from and whether reading it was allowed;
[hikingwnc-data-issues.md](hikingwnc-data-issues.md) for defects in the
upstream data; [ARCHITECTURE.md](../ARCHITECTURE.md) for the claims schema.

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

Ours does not, quite. `name_core` in migration 058 deletes a parenthetical
outright while leaving a hyphenated qualifier in place:

```
High Falls (Beech Creek)  ->  "high falls"
High Falls- Little River  ->  "high falls little river"
```

Both still matched, because the comparison also accepts one key being a prefix
of the other — so the prefix test is quietly carrying an inconsistent
normalisation. Worth fixing before anything else depends on `name_core`.

---

## 2. What evidence we hold

| Evidence | Where | Good for | Fails when |
|---|---|---|---|
| Our coordinate | `locations` via `features.feature_location_id` | everything | 55 features have none |
| The source's own published coordinate | `claims` where `field='coordinate'`, per `claim_group` | the arbiter | the source publishes none |
| Our name | `features.name` | proposing candidates | the name is a common one |
| The source's name | `claims` where `field='name'` | confirming a candidate | page titles carry SEO tails |
| Aliases | `claims` where `field='alias'` | alternate names | 45 claims, all `accepted=false` |
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

Migration 058 tightened the accept band to **200 m** for ncwaterfalls
specifically, because every candidate there already sat inside 196 m and a
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

**Aliases are all unaccepted.** All 45 alias claims carry `accepted = false`,
including ones written deliberately to record a *conflict* — Adams calls our
Quarry Falls "Bust-Your-Butt Falls", a name we hold on Drift Falls 27 km east.
So "an alias matched" cannot currently distinguish a name we endorse from a
name we are disputing. Any rule consuming aliases must filter on `accepted`
until that is resolved.

**Stage 2, an AI pass, is designed and not built.** A second pass over what
distance and name cannot settle: different names for the same fall, a page
covering several falls, a source whose coordinate is the parking area three
ridges over. Working target was 99% of candidates settled by the end of it. No
code in this repository calls a model.

**170 of 279 ncwaterfalls pages matched nothing of ours.** Name drift rather
than absence, and the pages are already cached, so it is the cheapest remaining
win.

**Our own list has internal collisions.** 74 features share 35 coordinates —
trailheads recorded once per waterfall — and nine features are named
`Waterfall #N (04-14-2022)` and are unidentifiable.
