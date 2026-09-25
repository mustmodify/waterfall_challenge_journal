#!/usr/bin/env python3
"""Fetch USGS NLDI drainage area for every waterfall with an accepted coordinate.

For each waterfall:
  1. Call the NLDI position endpoint to snap the coordinate to an NHD stream
     reach and get its COMID.
  2. Call the basin endpoint for that COMID, which returns a watershed polygon.
  3. Compute drainage area in square miles from the polygon (Shoelace formula
     scaled to miles at the basin's mean latitude).

Output: data/nldi/drainage.jsonl, one JSON object per waterfall.
Already-fetched rows (by feature_id) are skipped so the script can resume.

    DATABASE_URL="..." python3 script/import/nldi/fetch.py

Then build the migration:

    python3 script/import/nldi/build.py > db/migrations/064_nldi_drainage_area.sql

Rate: ~1 req/s, two per waterfall. Expect ~30 min for the full set.
"""

import json
import math
import os
import sys
import time
import urllib.request
import urllib.error
from datetime import date

OUTFILE = "data/nldi/drainage.jsonl"
NLDI = "https://api.water.usgs.gov/nldi"
DELAY = 0.5  # seconds between requests; NLDI is a public API, be polite


def polygon_area_sqmi(coords):
    """Shoelace area of a lon/lat polygon, scaled to square miles at mean lat."""
    lats = [p[1] for p in coords]
    lons = [p[0] for p in coords]
    mean_lat = sum(lats) / len(lats)
    lat_mi = 69.0
    lon_mi = 69.0 * math.cos(math.radians(mean_lat))
    n = len(coords)
    area = 0.0
    for i in range(n):
        j = (i + 1) % n
        xi = coords[i][0] * lon_mi
        yi = coords[i][1] * lat_mi
        xj = coords[j][0] * lon_mi
        yj = coords[j][1] * lat_mi
        area += xi * yj - xj * yi
    return abs(area) / 2.0


def fetch_json(url, retries=5):
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, headers={"Accept": "application/json"})
            with urllib.request.urlopen(req, timeout=20) as r:
                return json.loads(r.read())
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            wait = 30 if e.code == 429 else 2 ** attempt
            if attempt < retries - 1:
                print(f"HTTP {e.code}, waiting {wait}s...", end=" ", flush=True)
                time.sleep(wait)
                continue
            raise
        except Exception:
            if attempt < retries - 1:
                time.sleep(2 ** attempt)
                continue
            raise
    return None


def get_comid(lat, lon):
    url = f"{NLDI}/linked-data/comid/position?coords=POINT({lon}%20{lat})"
    d = fetch_json(url)
    if not d or not d.get("features"):
        return None
    return d["features"][0]["properties"]["comid"]


def get_drainage_area(comid):
    url = f"{NLDI}/linked-data/comid/{comid}/basin"
    d = fetch_json(url)
    if not d or not d.get("features"):
        return None
    geom = d["features"][0].get("geometry", {})
    gtype = geom.get("type")
    coords = geom.get("coordinates", [])
    if gtype == "Polygon" and coords:
        return polygon_area_sqmi(coords[0])
    if gtype == "MultiPolygon" and coords:
        return sum(polygon_area_sqmi(poly[0]) for poly in coords)
    return None


def load_existing(path):
    seen = {}
    if not os.path.exists(path):
        return seen
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                row = json.loads(line)
                seen[row["feature_id"]] = row
            except Exception:
                pass
    return seen


def load_waterfalls():
    db_url = os.environ.get("DATABASE_URL")
    if not db_url:
        sys.exit("DATABASE_URL not set")
    import subprocess
    sql = """
        SELECT f.id, f.name,
               (c.value->>'lat')::float AS lat,
               (c.value->>'lon')::float AS lon
        FROM features f
        JOIN claim_groups cg ON cg.feature_id = f.id
        JOIN claims c ON c.group_id = cg.id
            AND c.field = 'coordinate'
            AND c.accepted = true
        WHERE f.deprecated_reason IS NULL
          AND f.kind = 'waterfall'
        GROUP BY f.id, f.name, c.value
        ORDER BY f.id
    """
    result = subprocess.run(
        ["psql", db_url, "-t", "-A", "-F", "\t", "-c", sql],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        sys.exit(f"psql failed: {result.stderr}")
    rows = []
    for line in result.stdout.strip().split("\n"):
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) != 4:
            continue
        try:
            rows.append({
                "feature_id": int(parts[0]),
                "name": parts[1],
                "lat": float(parts[2]),
                "lon": float(parts[3]),
            })
        except ValueError:
            pass
    return rows


def main():
    existing = load_existing(OUTFILE)
    waterfalls = load_waterfalls()
    total = len(waterfalls)
    skipped = sum(1 for w in waterfalls if w["feature_id"] in existing)
    print(f"{total} waterfalls, {skipped} already fetched, {total - skipped} to fetch")

    with open(OUTFILE, "a") as out:
        for i, wf in enumerate(waterfalls):
            fid = wf["feature_id"]
            if fid in existing:
                continue

            lat, lon = wf["lat"], wf["lon"]
            name = wf["name"]
            n_remaining = total - skipped - i
            print(f"  [{i+1}/{total}] {name} ({lat:.4f}, {lon:.4f}) ...", end=" ", flush=True)

            comid = get_comid(lat, lon)
            time.sleep(DELAY)
            if comid is None:
                print("no COMID")
                row = {"feature_id": fid, "name": name, "lat": lat, "lon": lon,
                       "comid": None, "drainage_area_sqmi": None,
                       "error": "no_comid", "fetched_at": str(date.today())}
                out.write(json.dumps(row) + "\n")
                out.flush()
                continue

            area = get_drainage_area(comid)
            time.sleep(DELAY)

            row = {
                "feature_id": fid,
                "name": name,
                "lat": lat,
                "lon": lon,
                "comid": comid,
                "drainage_area_sqmi": round(area, 3) if area is not None else None,
                "fetched_at": str(date.today()),
            }
            out.write(json.dumps(row) + "\n")
            out.flush()
            print(f"COMID {comid}, {area:.2f} sqmi" if area else f"COMID {comid}, no area")

    print("Done.")


if __name__ == "__main__":
    main()
