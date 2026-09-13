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
