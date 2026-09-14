# Where things stand

Written 2026-09-14, after the first deploy. This is the page to read before
picking the project up again; the others describe how a part works, this one
says what is true right now and what is still open.

## Live

https://wanderfall.app, on Render, since 2026-09-13.

| Piece | What | Where |
|---|---|---|
| Web | Go binary, auto-deploys on merge to main | Render, "My Workspace" |
| Database | Postgres 16 | Render, same workspace |
| Mail | Mailgun HTTP API, `Wanderfall <wanderful@mustmodify.com>` | apex domain, verified |
| Tiles | Stadia, authorised by domain allowlist | no key in the page |
| Basemaps | Alidade Smooth, Alidade Smooth Dark, USGS Topo | |

Migrations run from `preDeployCommand`, so schema changes ship with the code
that needs them. That was added after merging a PR deployed the binary four
migrations ahead of the database and every area page served a 500.

## What it serves

464 of 956 features. The map publishes a waterfall only when two or more
independent sources put it in the same place — `coordinate_confidence` tiers
them, and `/features` returns the `confirmed` and `corroborated` tiers plus all
22 towers, which carry no source claims and would otherwise vanish.

The other 396 are not wrong. They rest on one source, and the tier lifts itself
when a second one agrees.

## Still open

- **Google Search Console.** Nothing else moves the needle until the sitemap is
  submitted. Needs JW's Google account. `robots.txt` and `sitemap.xml` are
  live; the site has simply never been discovered.
- **Sign-in has never been tested in production.** Mailgun is configured and
  the startup log confirms the transport, but no magic link has been sent for
  real. It is the last unexercised path.
- **No admin account exists.** After the first sign-in:
  `UPDATE users SET is_admin = true WHERE email = ...`
- **Four towers have no hike data**: Clingmans Dome, Moores Knob, Mt. Cammerer,
  Shuckstack. hikingwnc has no page for them and dwhike walked neither.
- **59 features have no usable hike distance**, of which seven say something
  else instead — "Private", "No access", "Scramble from the road".
- **55 features have no coordinate at all**, including nine named
  `Waterfall #N (04-14-2022)`, which are somebody's unsorted trip log.
- **74 features sit on 35 shared coordinates.** Those are trailheads recorded
  once per waterfall. Kevin Adams places some of them properly; most are
  unresolved.
- **AllTrails publishes an MCP server** at `https://www.alltrails.com/mcp`, no
  key, with `elevation_gain_feet` on every trail. That is the field that keeps
  `features.petzoldt` at 24 of 955. Their terms want reading before any bulk
  use, and a trail is not a waterfall — the gain belongs to a route.

## Things that are true and not obvious

**The database is not the source.** Nine sources are recorded as claims and
kept unmerged; `features` is the resolved answer and `claims` is why. 9,198
claims in 1,880 groups. Never rebuild a source's claims from `features` — those
columns have been corrected repeatedly and would report our own conclusions
back to us as hikingwnc's.

**A Petzoldt rating belongs to a route, not to a waterfall.** dwhike reaches
Cedar Rock Falls on a 13.8 mile loop; hikingwnc walks 1.6 miles straight to it.
Pairing one source's gain with the other's mileage produced a rating for a hike
nobody has taken.

**Ratings display as words.** The 1-10 scores are hikingwnc's work and stay out
of published pages until he agrees. `wjBand()` and `band()` must agree.

**Names collide, and coordinates settle it.** Four Rainbow Falls, four Twin
Falls, and every source covers more ground than we do. See
[sources-and-matching.md](sources-and-matching.md).

## Running it

Local setup, the challenges, and the configuration table: [../README.md](../README.md).
Schema and how the pieces fit: [../ARCHITECTURE.md](../ARCHITECTURE.md).
Deploying, and why a new database is built from a dump: [../DEPLOY.md](../DEPLOY.md).
