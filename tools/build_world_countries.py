"""Country outlines for the Journal's world map ("shaded countries" style), in the world map's own coordinates.

Source: Natural Earth 1:50m admin-0 countries (public domain), /home/user/ne/ne_50m_admin_0_countries.geojson.
Output: Jeroboam/Resources/Maps/world-countries.json  {"countries": [{"n": name, "a": [aliases], "p": [[x, y, x, y, ...], ...]}]}
The world map is a plain lat/lon grid: x = 2331 + 13.71 * lon, y = 372 - 13.74 * (lat - 44.84) (see JournalInsights.mapPoint).
Run: python3 tools/build_world_countries.py
"""
import json, os
from shapely.geometry import shape, Polygon, MultiPolygon

SRC = os.environ.get("NE_COUNTRIES", "/home/user/ne/ne_50m_admin_0_countries.geojson")
OUT = os.path.join(os.path.dirname(__file__), "..", "Jeroboam", "Resources", "Maps", "world-countries.json")

def xy(lon, lat):
    return round(2331 + 13.71 * lon, 1), round(372 - 13.74 * (lat - 44.84), 1)

out = []
for f in json.load(open(SRC))["features"]:
    p = f["properties"]
    g = shape(f["geometry"]).simplify(0.06, preserve_topology=True)
    polys = list(g.geoms) if isinstance(g, MultiPolygon) else [g] if isinstance(g, Polygon) else []
    rings = []
    for poly in polys:
        if poly.area < 0.02:          # islands smaller than about 1.5 x 1.5 km at the equator... at this scale, invisible
            continue
        flat = []
        for lon, lat in poly.exterior.coords:
            flat += xy(lon, lat)
        rings.append(flat)
    if not rings:
        continue
    names = {p.get(k) for k in ("ADMIN", "NAME", "NAME_LONG", "NAME_EN", "SOVEREIGNT", "FORMAL_EN") if p.get(k)}
    names |= {p.get(k) for k in ("ISO_A2", "ISO_A3", "ADM0_A3") if p.get(k) and p.get(k) != "-99"}
    name = p.get("NAME_EN") or p.get("ADMIN")
    out.append({"n": name, "a": sorted(n for n in names if n != name), "p": rings})

json.dump({"countries": out}, open(OUT, "w"), separators=(",", ":"), ensure_ascii=False)
print(len(out), "countries,", os.path.getsize(OUT) // 1024, "KB")
