#!/usr/bin/env python3
"""Decide which cached AllTrails trail is which of our waterfalls.

Reads data/alltrails/raw/, applies the rule in docs/MATCHING.md, and writes a
verdict per (feature, trail) to data/alltrails/verdicts.jsonl. No network, no
database writes -- run it as often as you like, change the rule, run it again.

THE RULE, both halves required:

  name      the same core once punctuation and noise are gone, or one side
            carrying a disambiguator the other omits, or a recorded alias
  position  the trail's own published coordinate close enough to ours

AllTrails publishes two points and they answer different questions. `pins`
carries the trail's coordinate, which is comparable to ours. trail_head_distance
measures to the car park, and a waterfall four miles up a trail has a trailhead
four miles away -- Ramsey Cascades is 5,280 m out and is still the right match.
So pins arbitrates and trailhead distance is recorded, never tested.

    python3 script/alltrails/match.py
    python3 script/alltrails/match.py --explain 378
"""

import argparse
import json
import math
import pathlib
import re
import subprocess

RAW = pathlib.Path("data/alltrails/raw")
OUT = pathlib.Path("data/alltrails/verdicts.jsonl")

ACCEPT_KM = 2.0     # docs/MATCHING.md §3
FLAG_KM = 20.0

# Words that carry no identity. "Falls" is in every name; the rest are the
# generic halves of descriptive names.
NOISE = {"falls", "fall", "waterfall", "waterfalls", "trail", "trails", "loop",
         "via", "the", "to", "and", "at", "on", "of", "a"}


def core(name):
    """Reduce a name to the tokens that identify it.

    Parenthetical and hyphenated qualifiers are both dropped -- our own list
    writes the same convention two ways (21 hyphenated, 122 parenthesised), so
    normalising only one of them would make High Falls (Beech Creek) and
    High Falls- Little River compare differently.
    """
    # A route is named for what it reaches, then how you get there:
    # "Douglas Falls Trail via Big Ivy Road". Everything after "via" is
    # the approach, and keeping it let "Nellie's Falls via Flat Creek
    # Road" match our Flat Creek Falls on the name of a ROAD.
    name = re.split(r"\s+via\s+", name, maxsplit=1, flags=re.I)[0]
    name = re.sub(r"\([^)]*\)", " ", name)
    name = re.sub(r"\s*[-–—]\s*.*$", " ", name)
    name = name.lower()
    # Apostrophes close up rather than split. "Tom's" and "Toms" are one
    # name spelled two ways, and turning the apostrophe into a space made
    # them ['tom','s'] and ['toms'] -- a non-match on punctuation alone.
    name = re.sub(r"[’']", "", name)
    name = re.sub(r"[^a-z0-9 ]", " ", name)
    return [w for w in name.split() if w not in NOISE]


def km(lat1, lon1, lat2, lon2):
    r = math.radians
    return 6371 * math.acos(min(1, max(-1,
        math.cos(r(lat1)) * math.cos(r(lat2)) * math.cos(r(lon2) - r(lon1))
        + math.sin(r(lat1)) * math.sin(r(lat2)))))


def names_agree(ours, theirs, aliases):
    """Ours and theirs as token lists; aliases as a list of token lists."""
    if not ours or not theirs:
        return None
    if ours == theirs:
        return "exact"
    # one side carries a disambiguator the other omits
    if ours[:len(theirs)] == theirs or theirs[:len(ours)] == ours:
        return "qualifier"
    # our name appears whole inside theirs: "Aunt Sally and Rhapsodie Falls"
    # is about our Rhapsodie, and about Aunt Sally as well -- which is a
    # multi-fall route rather than a non-match, and the two are not the same
    # finding. A prefix test alone calls this a stranger.
    for i in range(len(theirs) - len(ours) + 1):
        if theirs[i:i + len(ours)] == ours:
            return "contained"
    for alias in aliases:
        if alias and (alias == theirs or theirs[:len(alias)] == alias):
            return "alias"
    return None


def multi_fall(trail_name):
    """A route named for several waterfalls. Its counts describe one walk past
    all of them, so they cannot be attributed to any single one.

    Counting "and" was too eager: "Raven Cliff Falls and Dismal Trail Loop"
    joins a waterfall to a TRAIL, and "Pearson's Falls and Glen" to a glen.
    What makes a route multi-fall is two waterfall NAMES, so require either two
    occurrences of falls/cascades, or a comma list, or an "and" whose right
    side is itself a waterfall.
    """
    name = trail_name.lower()
    if len(re.findall(r"\b(falls|cascades)\b", name)) > 1:
        return True
    if re.search(r",.*\b(falls|cascades)\b", name):
        return True
    tail = name.split(" and ", 1)
    return len(tail) == 2 and bool(re.search(r"\b(falls|cascades)\b", tail[1]))


def aliases_by_feature():
    sql = ("SELECT c.feature_id, c.value #>> '{}' FROM claims c "
           "WHERE c.field = 'alias' AND c.accepted")
    out = subprocess.run(["psql", "-tA", "-F", "\t", "-d", "wc_journey_db", "-c", sql],
                         capture_output=True, text=True, check=True).stdout
    by = {}
    for line in out.strip().split("\n"):
        if not line.strip():
            continue
        fid, alias = line.split("\t")
        by.setdefault(int(fid), []).append(core(alias))
    return by


def decide(feature, trail, pin, aliases):
    ours, theirs = core(feature["name"]), core(trail["name"])
    agreement = names_agree(ours, theirs, aliases)
    distance = km(feature["lat"], feature["lon"], pin[1], pin[0]) if pin else None

    row = {
        "feature_id": feature["id"], "feature": feature["name"],
        "trail_id": trail["id"], "trail": trail["name"],
        "slug": trail.get("slug", "").replace("trail/", "", 1),
        "trailhead_m": trail.get("trail_head_distance_meters"),
        "pin_km": round(distance, 3) if distance is not None else None,
        "length_mi": trail.get("length_miles"),
        "gain_ft": trail.get("elevation_gain_feet"),
        "route_type": trail.get("route_type_enum"),
        "avg_rating": trail.get("avg_rating"),
        "name_agreement": agreement,
    }

    if agreement is None:
        row["verdict"] = "reject-position-only"
        row["why"] = f"no name agreement ({' '.join(ours)} vs {' '.join(theirs)})"
    elif distance is None:
        row["verdict"] = "flag-no-coordinate"
        row["why"] = "the search returned no pin for this trail"
    elif distance > FLAG_KM:
        row["verdict"] = "reject-far"
        row["why"] = f"name agrees but the trail is {distance:.0f} km away"
    elif distance > ACCEPT_KM:
        row["verdict"] = "flag-distant"
        row["why"] = f"name agrees at {distance:.1f} km, inside the 2-20 km band"
    elif multi_fall(trail["name"]):
        row["verdict"] = "flag-multi-fall"
        row["why"] = "the route is named for more than one waterfall"
    else:
        row["verdict"] = "accept"
        row["why"] = f"{agreement} name agreement at {distance*1000:.0f} m"
    return row


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--explain", type=int, help="show every candidate for one feature")
    args = ap.parse_args()

    aliases = aliases_by_feature()
    details = {int(p.stem): json.loads(p.read_text())
               for p in (RAW / "trail").glob("*.json")}

    rows = []
    for path in sorted((RAW / "search").glob("*.json"), key=lambda p: int(p.stem)):
        found = json.loads(path.read_text())
        feature = found["feature"]
        if args.explain and feature["id"] != args.explain:
            continue
        if not found["trails"]:
            rows.append({"feature_id": feature["id"], "feature": feature["name"],
                         "verdict": "no-match",
                         "why": "nothing within 3 km with a waterfall tag"})
            continue
        for trail in found["trails"]:
            pin = found.get("pins", {}).get(str(trail["id"]))
            row = decide(feature, trail, pin, aliases.get(feature["id"], []))
            detail = details.get(trail["id"], {})
            stats = detail.get("total_user_content_stats", {})
            row["photos"] = stats.get("photos_count")
            row["hikes"] = stats.get("completed_hikes_count")
            row["reviews"] = stats.get("reviews_count")
            rows.append(row)

    if args.explain:
        for r in rows:
            print(f"  {r['verdict']:22} {r.get('trail','-')[:46]:<46} {r['why']}")
        return

    # One accept per feature: the closest. A second route to the same fall is
    # real but its counts are a different walk, so it is kept and demoted.
    best = {}
    for r in rows:
        if r["verdict"] == "accept":
            prev = best.get(r["feature_id"])
            if prev is None or r["pin_km"] < prev["pin_km"]:
                best[r["feature_id"]] = r
    for r in rows:
        if r["verdict"] == "accept" and best[r["feature_id"]]["trail_id"] != r["trail_id"]:
            r["verdict"] = "second-route-same-fall"
            r["why"] = "another route reaches this fall closer; kept, not counted"

    OUT.write_text("".join(json.dumps(r) + "\n" for r in rows))
    from collections import Counter
    tally = Counter(r["verdict"] for r in rows)
    print(f"{len(rows)} verdicts over {len({r['feature_id'] for r in rows})} features")
    for verdict, n in tally.most_common():
        print(f"  {n:4d}  {verdict}")


if __name__ == "__main__":
    main()
