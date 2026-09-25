#!/usr/bin/env python3
"""Check the matcher against the verdicts a model reached by hand.

103 features were matched by reading AllTrails responses one at a time and
writing a verdict. That is the only labelled set this rule has, so it is worth
asking where the script and the model disagree -- in both directions. The
script agreeing everywhere would mean it had learned nothing the reading did
not already encode; disagreeing everywhere would mean the rule is wrong.

Neither side is ground truth. A disagreement is a question, not a defect.

    python3 script/import/alltrails/compare.py
"""

import json
import pathlib
from collections import Counter

HAND = pathlib.Path("data/alltrails/pilot.jsonl")
AUTO = pathlib.Path("data/alltrails/verdicts.jsonl")


def family(verdict):
    """Both sides use finer labels than the comparison needs."""
    v = verdict.split(":")[0].split(" ")[0]
    if v.startswith("accept"):
        return "accept"
    if v.startswith("flag") or v == "second-route-same-fall":
        return "flag"
    if v.startswith("reject"):
        return "reject"
    if v.startswith("no-match"):
        return "no-match"
    return v


def main():
    hand = {}
    for line in HAND.read_text().splitlines():
        if not line.strip():
            continue
        r = json.loads(line)
        # keep the strongest verdict a feature got by hand
        rank = {"accept": 3, "flag": 2, "reject": 1, "no-match": 0}
        f = family(r["verdict"])
        prev = hand.get(r["feature_id"])
        if prev is None or rank.get(f, 0) > rank.get(prev[0], 0):
            hand[r["feature_id"]] = (f, r.get("trail_id"), r["feature"])

    auto = {}
    for line in AUTO.read_text().splitlines():
        if not line.strip():
            continue
        r = json.loads(line)
        rank = {"accept": 3, "flag": 2, "reject": 1, "no-match": 0}
        f = family(r["verdict"])
        prev = auto.get(r["feature_id"])
        if prev is None or rank.get(f, 0) > rank.get(prev[0], 0):
            auto[r["feature_id"]] = (f, r.get("trail_id"), r.get("feature"))

    shared = sorted(set(hand) & set(auto))
    agree = [i for i in shared if hand[i][0] == auto[i][0]]
    differ = [i for i in shared if hand[i][0] != auto[i][0]]

    print(f"{len(shared)} features judged both ways: "
          f"{len(agree)} agree, {len(differ)} differ "
          f"({100*len(agree)/len(shared):.0f}% agreement)")

    same_trail = [i for i in agree
                  if hand[i][0] == "accept" and hand[i][1] == auto[i][1]]
    accepts = [i for i in agree if hand[i][0] == "accept"]
    if accepts:
        print(f"  of {len(accepts)} mutual accepts, {len(same_trail)} chose the same trail")

    if differ:
        print(f"\n  disagreements (hand -> script):")
        for i in differ:
            print(f"    {hand[i][2][:38]:<38} {hand[i][0]:>9} -> {auto[i][0]}")

    print()
    print("  hand:  ", dict(Counter(v[0] for v in hand.values())))
    print("  script:", dict(Counter(v[0] for v in auto.values())))


if __name__ == "__main__":
    main()
