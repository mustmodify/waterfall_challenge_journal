#!/usr/bin/env python3
"""Harvest AllTrails into a raw cache. No decisions, no database.

Speaks MCP over HTTP to https://www.alltrails.com/mcp, which AllTrails publishes
without a key for agent access. This fetches and writes JSON to disk; deciding
which trail is which waterfall is match.py's job, and writing claims is
build.py's. Keeping those apart is the point: a fetch is expensive and
repeatable, a decision is cheap and revisable.

POLITENESS. One request a second, and nothing is ever fetched twice -- a
response on disk is never re-requested, so a re-run after an interruption costs
the far end nothing. robots.txt disallows ClaudeBot, Claude-User and
Claude-SearchBot from the web site and /api/ from everybody; this touches
neither. If AllTrails would rather we did not, the cache means stopping costs
us nothing either.

    python3 script/alltrails/fetch.py            # every published waterfall
    python3 script/alltrails/fetch.py --limit 50
    python3 script/alltrails/fetch.py --all      # unpublished ones too

Writes:
    data/alltrails/raw/search/<feature_id>.json
    data/alltrails/raw/trail/<trail_id>.json
"""

import argparse
import json
import os
import pathlib
import subprocess
import sys
import time
import urllib.error
import urllib.request

ENDPOINT = "https://www.alltrails.com/mcp"
RAW = pathlib.Path("data/alltrails/raw")
DELAY = 1.0          # seconds between requests
RADIUS = 3000        # metres; wide enough for a trailhead a walk away
LIMIT = 10           # results sorted by distance, not relevance

PUBLISHED = """
SELECT f.id, f.name, l.latitude, l.longitude
  FROM features f
  JOIN locations l ON l.id = f.feature_location_id
  JOIN coordinate_confidence c ON c.feature_id = f.id
 WHERE f.kind = 'waterfall' {tier}
 ORDER BY f.id
"""


class Client:
    """Minimal MCP client. Initialises once, then calls tools."""

    def __init__(self):
        self.session = None
        self._rpc("initialize", {
            "protocolVersion": "2025-06-18",
            "capabilities": {},
            "clientInfo": {"name": "wanderfall-harvest", "version": "0.1"},
        }, want_id=1)
        self._rpc("notifications/initialized", None, notify=True)

    def _rpc(self, method, params, want_id=None, notify=False):
        body = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            body["params"] = params
        if not notify:
            body["id"] = want_id or 1
        req = urllib.request.Request(
            ENDPOINT, data=json.dumps(body).encode(),
            headers={"Content-Type": "application/json",
                     "Accept": "application/json, text/event-stream",
                     "User-Agent": "wanderfall-harvest/0.1 (+https://wanderfall.app)"},
            method="POST")
        if self.session:
            req.add_header("Mcp-Session-Id", self.session)
        with urllib.request.urlopen(req, timeout=30) as resp:
            if not self.session:
                self.session = resp.headers.get("Mcp-Session-Id")
            if notify:
                return None
            return json.loads(resp.read().decode())

    def call(self, tool, arguments):
        """Returns (payload, meta). The payload arrives as JSON inside a text
        block, which is how MCP carries structured results."""
        out = self._rpc("tools/call", {"name": tool, "arguments": {"input": arguments}})
        result = out.get("result", {})
        meta = result.get("_meta", {})
        for block in result.get("content", []):
            if block.get("type") == "text":
                return json.loads(block["text"]), meta
        return {}, meta


def features(all_tiers):
    tier = "" if all_tiers else "AND c.tier IN ('confirmed','corroborated')"
    sql = PUBLISHED.format(tier=tier)
    out = subprocess.run(["psql", "-tA", "-F", "\t", "-d", "wc_journey_db", "-c", sql],
                         capture_output=True, text=True, check=True).stdout
    rows = []
    for line in out.strip().split("\n"):
        if not line.strip():
            continue
        fid, name, lat, lon = line.split("\t")
        rows.append({"id": int(fid), "name": name, "lat": float(lat), "lon": float(lon)})
    return rows


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, help="stop after this many features")
    ap.add_argument("--all", action="store_true", help="include unpublished features")
    args = ap.parse_args()

    (RAW / "search").mkdir(parents=True, exist_ok=True)
    (RAW / "trail").mkdir(parents=True, exist_ok=True)

    todo = features(args.all)
    if args.limit:
        todo = [f for f in todo
                if not (RAW / "search" / f"{f['id']}.json").exists()][:args.limit]

    client = None
    searched = fetched = skipped = 0
    for f in todo:
        path = RAW / "search" / f"{f['id']}.json"
        if path.exists():
            skipped += 1
        else:
            if client is None:
                client = Client()
            try:
                payload, meta = client.call("find_trails_near_location", {
                    "latitude": f["lat"], "longitude": f["lon"],
                    "max_radius_meters": RADIUS, "limit": LIMIT,
                    "sort": "closest", "locale": "en-US",
                    "filters": {"attractions": ["waterfall"]}})
            except (urllib.error.URLError, TimeoutError) as e:
                print(f"  ! {f['id']} {f['name']}: {e}", file=sys.stderr)
                continue
            # pins carry the trail's own coordinate as [lon, lat], which is a
            # better arbiter than trail_head_distance_meters -- that measures to
            # the car park, and a waterfall four miles up a trail is not there.
            path.write_text(json.dumps(
                {"feature": f, "trails": payload.get("trails", []),
                 "pins": meta.get("pins", {}),
                 "fetched_at": time.strftime("%Y-%m-%d")}, indent=1))
            searched += 1
            time.sleep(DELAY)

        found = json.loads(path.read_text())
        for trail in found.get("trails", []):
            tpath = RAW / "trail" / f"{trail['id']}.json"
            if tpath.exists():
                continue
            if client is None:
                client = Client()
            try:
                detail, _ = client.call("get_trail_details",
                                        {"trail_id": trail["id"], "locale": "en-US"})
            except (urllib.error.URLError, TimeoutError) as e:
                print(f"  ! trail {trail['id']}: {e}", file=sys.stderr)
                continue
            tpath.write_text(json.dumps(detail.get("trail", detail), indent=1))
            fetched += 1
            time.sleep(DELAY)

        if (searched + fetched) and (searched + fetched) % 25 == 0:
            print(f"  {searched} searches, {fetched} trails, {skipped} already cached")

    print(f"done: {searched} searches, {fetched} trail details, {skipped} skipped")


if __name__ == "__main__":
    main()
