# Coordinate issues in the hikingwnc.com waterfall data

Found while cross-referencing the hikingwnc catalogue against the Kevin Adams
500 list and the USGS Blue Ridge province boundary. Everything below is in
hikingwnc's published data, not introduced by our import — the values in
`data/hiking_wnc_falls.json` match what the site serves.

No contact address for the site's author is known, so this is a holding list.

---

## 1. Six records one degree of longitude too far east

Each of these sits exactly `1.00000` east of where it belongs, putting it
roughly 91 km away — usually across a state line. In every case the record has
a name-sibling whose **latitude agrees to four or five decimals** while the
longitude differs by exactly one whole degree:

| # | Name | Published | Sibling | Sibling's longitude |
|---|------|-----------|---------|---------------------|
| 029 | Upper Silver Run Falls | `35.0672, -82.0642` | 019 Silver Run Falls | `-83.0654` |
| 557 | Waddle Branch Falls | `35.04219, -82.02631` | 558 Lower Waddle Branch Falls | `-83.02627` |
| 833 | Upper Shoal Creek Falls | `35.63313, -81.76205` | 834 Shoal Creek Falls | `-82.76541` |
| 093 | Stone Mountain Falls (Little Falls) | `36.381, -80.0342` | 141 Lower Falls at Stone Mountain | `-81.0407` |
| 094 | Middle Falls at Stone Mountain | `36.3816, -80.0395` | 141 Lower Falls at Stone Mountain | `-81.0407` |
| 927 | Joe Pack Falls | `35.07811, -82.00639` | — | see below |

Pages:

- https://hikingwnc.com/029-upper-silver-run-falls/
- https://hikingwnc.com/557-waddle-branch-falls/
- https://hikingwnc.com/833-upper-shoal-creek-falls/
- https://hikingwnc.com/093-stone-mountain-falls/
- https://hikingwnc.com/094-middle-falls/
- https://hikingwnc.com/927-joe-pack-falls/

### Why one degree west is the right correction

Each record is geographically isolated as published, and lands next to the fall
it is named after once moved:

| Name | Nearest neighbour as published | Nearest neighbour, shifted 1° west |
|------|-------------------------------|------------------------------------|
| Upper Silver Run Falls | 4.4 km | **0.2 km** — Silver Run Falls |
| Waddle Branch Falls | 4.4 km | **0.2 km** — Lower Waddle Branch Falls |
| Upper Shoal Creek Falls | 6.4 km | **0.3 km** — Shoal Creek Falls |
| Middle Falls at Stone Mountain | 0.5 km (also-wrong 093) | **0.2 km** — Lower Falls at Stone Mountain |
| Stone Mountain Falls (Little Falls) | 18.3 km | **0.6 km** — Lower Falls at Stone Mountain |
| Joe Pack Falls | 17.1 km | **0.2 km** — Twin Falls (Thompson River) |

Stone Mountain 093 and 094 slipped together, which masks the error: each one's
nearest neighbour is the other, so neither looks isolated on its own. Both are
about 110 km east of Stone Mountain State Park as published, near Elkin.

Joe Pack Falls has no name-sibling, so it was caught only by isolation.

## 2. Twin Falls (SC) carries Juney Whank Falls' coordinates

| # | Name | Published |
|---|------|-----------|
| 057 | Juney Whank Falls | `35.4666, -83.4352` |
| 095 | Twin Falls (SC) | `35.4666, -83.4352` |

Identical to four decimal places. Juney Whank is correct — Deep Creek, near
Bryson City. Twin Falls (SC) is on Reedy Cove Creek in Pickens County, South
Carolina, roughly 100 km south-east, so 095 appears to have inherited 057's
values. No replacement coordinates are suggested here because none could be
confirmed from a source.

- https://hikingwnc.com/057-juney-whank-falls/
- https://hikingwnc.com/095-twin-falls-sc/

---

## Not a problem — flagged so nobody "fixes" it

**Rainbow Falls (Camp Greenville)** trips the same name-sibling test as the six
above: there is another Rainbow Falls a degree away. It is correct as published.
It sits 1.1 km from Jones Gap Falls in the Mountain Bridge Wilderness, which is
right, and is simply a different waterfall from the Rainbow Falls on US 64.

## Unverified — may be intentional

37 coordinate groups in the catalogue have two or more falls sharing an exact
position, e.g. Chasm Falls / Glen Falls Downstream / Waterfall on Trib of Brooks
Creek all at `35.00837, -83.24688`. That is plausible for several falls along
one creek recorded from a single trailhead, so it is noted rather than reported.
Twin Falls (SC) is listed above separately because the two falls involved are
100 km apart and on different watersheds.

## Claims

Every source assertion now lives in `claims`, grouped by the act that produced
it. A `claim_groups` row is one page read or one node dropped; the `claims`
under it are the name/value pairs it carried, `accepted` marking the one
promoted into `features`. The name is one of those pairs, so a group can be
checked against the feature it is attached to -- a group that calls the fall
something else is a group about a different fall. 30 groups currently name
something unrelated to the feature they sit on. Views:

- `claim_conflicts` — fields where sources disagree, or where nothing is accepted.
- `claim_coordinate_spread` — how far apart, in metres, the sources put each
  feature. Rounding noise and a real dispute are the same row in
  `claim_conflicts`; this separates them.

What the backfill turned up:

- The eight coordinate disputes over 700 m are all ones we had already settled:
  the six one-degree longitude slips, Twin Falls SC, and Eastatoe Narrows.
- 15 features carry a coordinate that matches no recorded claim, off by 5 to
  229 m. Something edited those values and left no source. Turtleback, Hooker,
  Drift, Rainbow, Schoolhouse and King's Creek are among them.
- Upper Log Hollow Falls has two hikingwnc pages 229 m apart, so the source
  disagrees with itself.
- hikingwnc publishes no coordinate for More Cave, Tranquility, Turbulent and
  Red Butt Falls -- the scrape holds the literal string `LAT 35.???? LONG
  -83.????`. Three more carry a malformed number (`LONG -82.3.9353`). All seven
  are kept verbatim as `coordinate_raw` claims: a reading we cannot parse is
  still a reading someone took, and guessing the missing digit would invent one.
- `hike_distance` has 928 claims and no accepted value anywhere, because
  `features.rt_hike_distance` is a derived round-trip number and the sources
  publish prose one-way distances. Nothing is wrong; nothing has been resolved
  either.

## Confidence tiers

`coordinate_confidence` sorts every feature by how much agreement stands behind
the point we draw. Claims whose attachment is uncertain -- a node matched only
by being nearby, a placemark sharing a name with a fall 60 km away -- are
recorded but left out of the arithmetic.

| tier | features | what it means |
| --- | --- | --- |
| confirmed | 43 | three independent sources within 100 m |
| corroborated | 396 | two sources within 250 m |
| single source | 408 | one source, and we agree with it |
| no coordinate | 55 | nothing to draw |
| unsourced | 25 | a point on the map that no claim supports |
| unverified | 16 | sources 250-500 m apart, or ours away from all of them |
| disputed | 12 | sources over 500 m apart |

The 12 disputes are all known: six one-degree longitude slips, Twin Falls SC,
Eastatoe Narrows, and four falls where hikingwnc and OpenStreetMap differ by
500-800 m. Every one has our chosen value recorded as the accepted claim.

## Sources

| source | groups | what it brings |
| --- | --- | --- |
| hikingwnc | 943 | the catalogue: coordinates, beauty, photo, solitude, distance |
| openstreetmap | 640 | a field reading of most points, plus alternate names and viewpoints |
| ncwaterfalls | 147 | Kevin Adams, author of the Adams lists: falls and trailhead coordinates, beauty 1-10, height, elevation |
| dwhike | 153 | vertical gain and route distance, which nobody else publishes, plus his own Petzoldt ratings |
| the rest | 12 | our own corrections, Google Maps readings, waterfallshiker |

Pages from ncwaterfalls.com and the Wayback copies of dwhike.com are cached
under `data/spider-cache` (gitignored) by `script/spider`, so re-parsing never
costs another fetch.

### Attaching a hike to a waterfall

Two tests, and the name alone fails both ways. "Cedar Rock Falls" and dwhike's
"Cedar Rock" share every word that matters once Falls is set aside as generic,
and they are a waterfall and a mountain -- so a gallery now has to say which
kind of place it visited. And naming the fall is not the same as walking to it:
where his route runs more than half again longer than the walk our other
sources describe, he passed the waterfall on the way somewhere else, and the
group is marked uncertain. His 8.5 mile Bursted Rock lollipop passes Cascades
Falls, which hikingwnc reaches in 1.3 miles.

### Why the rating sits on the route

`route_ratings` computes Petzoldt per claim group, never per feature. dwhike
reaches Cedar Rock Falls on a 13.8 mile loop climbing 2,800 feet; hikingwnc
walks 1.6 miles straight to it. Pairing one source's gain with the other's
mileage produced d=7.20, a number describing no hike anyone has taken. Of the
31 ratings dwhike publishes outright, 29 match ours exactly and two differ by
0.10.
