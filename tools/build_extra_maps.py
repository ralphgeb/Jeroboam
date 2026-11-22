#!/usr/bin/env python3
"""Maps beyond the atlas: wine regions that are not in the course but are useful (the Journal, curiosity).

Source of truth: content/extra/<map>.yaml (geometry + guide text for one map).
  map, title, bbox [lat0, lon0, lat1, lon1], W, focus [NE ADM0 codes], cities, labels, country {...}, regions [...]
Each region is {id, name, parent?, grapes (atlas grape ids), local (other grape names), summary, climate, soil, styles, facts, history}
plus ONE geometry:
  units: {adm: "GEO/ADM1", names: [...]}     union of admin units (geoBoundaries gbOpen, ~/geo/gb/<ISO>-<ADM>.geojson)
  ava:   [AVA names]                          union of US AVA polygons (UC Davis AVA project)
  within: {adm: "CAN/ADM2", poly: [[lat, lon], ...]}   admin units whose centre lies in the sketch
  poly:  [[lat, lon], ...]                    a hand sketch
  minus: [region ids]                         taken out of the geometry
  clip:  region id                            intersected with another region (used for appellations inside a region)
Run: python3 tools/build_extra_maps.py [map ...]     writes Jeroboam/Resources/Maps/<map>.json
"""
import os, sys, glob, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import yaml
import build_maps2 as B
from shapely.geometry import shape, Polygon
from shapely.ops import unary_union
from shapely.prepared import prep

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "content", "extra")

def poly_ll(pts):
    return Polygon([(lon, lat) for lat, lon in pts]).buffer(0)

def units_of(spec, default_iso):
    adm = spec["adm"]
    iso = default_iso
    if "/" in adm: iso, adm = adm.split("/")
    return B.gb_units(iso, adm)

def geom_of(rid, r, spec, built, avas):
    if "units" in r:
        pool = units_of(r["units"], spec["iso"][0])
        got, miss = [], []
        for n in r["units"]["names"]:
            c = [g for nm, g in pool if nm == n]
            if not c: miss.append(n)
            got += c
        if miss: print(f"   ! {spec['map']}/{rid}: missing units {miss}")
        g = unary_union(got) if got else None
    elif "ava" in r:
        got = []
        for n in r["ava"]:
            f = avas.get(n)
            if not f: print(f"   ! {spec['map']}/{rid}: AVA missing {n}"); continue
            got.append(shape(f["geometry"]).buffer(0))
        g = unary_union(got) if got else None
    elif "within" in r:
        zone = poly_ll(r["within"]["poly"])
        zp = prep(zone)
        pool = units_of(r["within"], spec["iso"][0])
        picked = [g for nm, g in pool if zp.contains(g.representative_point())]
        g = unary_union(picked) if picked else None
        if g is None: print(f"   ! {spec['map']}/{rid}: no units inside the sketch")
    elif "poly" in r:
        g = poly_ll(r["poly"])
    else:
        print(f"   ! {spec['map']}/{rid}: no geometry"); return None
    if g is None or g.is_empty: return None
    c = r.get("clip")
    if isinstance(c, dict):       # trim to admin units (keeps sketches on land)
        pool = units_of(c, spec["iso"][0])
        keep = unary_union([gg for nm, gg in pool if nm in c["names"]])
        g = g.intersection(keep)
    elif c and c in built:
        g = g.intersection(built[c])
    for m in r.get("minus", []):
        if m in built: g = g.difference(built[m].buffer(B.km2deg(0.4)))
    return g

def build_map(spec, avas):
    mid = spec["map"]
    print(f"{mid}…")
    bbox = tuple(spec["bbox"])
    pr = B.Proj(bbox, spec.get("W", 2800))
    tol = 1.0
    land, focus, lk, rv = B.base_layers(pr, bbox, spec["focus"], tol=tol)
    built = {}
    regions = spec["regions"]
    # parents first so children can be clipped to them
    order = sorted(regions, key=lambda r: 1 if r.get("parent") else 0)
    for r in order:
        g = geom_of(r["id"], r, spec, built, avas)
        if g is not None: built[r["id"]] = g
    areas, col = [], {}
    tops = [r for r in regions if not r.get("parent") and r["id"] in built]
    for i, r in enumerate(tops):
        col[r["id"]] = B.cidx(None, i + spec.get("color_shift", 0))
        areas.append(B.area_record(pr, r["id"], r["name"], 0, col[r["id"]], built[r["id"]], tol, min_area=1,
                                   soft=r.get("soft", "units" in r), grapes=r.get("grape_line"), pdo=False))
    for r in regions:
        if r.get("parent") and r["id"] in built:
            p = r["parent"]
            areas.append(B.area_record(pr, r["id"], r["name"], 1, col.get(p, 0), built[r["id"]], tol, parent=p, min_area=1,
                                       soft=r.get("soft", "units" in r), grapes=r.get("grape_line"), pdo=False))
    areas = [a for a in areas if a]
    areas.sort(key=lambda a: a["lv"])
    # internal borders: provinces / states
    fb = []
    for iso in spec["iso"]:
        try: fb += [g for _, g in B.gb_units(iso, "ADM1")]
        except Exception: pass
    if spec.get("states"):
        fb = [shape(f["geometry"]) for f in B.admin1 if f["properties"]["adm0_a3"] in spec["states"]]
    cities = B.cities_of(pr, [(c[0], c[1], c[2], c[3] if len(c) > 3 else 1) for c in spec.get("cities", [])])
    labels = B.labels_of(pr, [tuple(l) for l in spec.get("labels", [])])
    B.write(mid, B.doc(mid, spec["title"], pr, land, focus, lk, rv, areas, cities, labels,
                       B.admin_borders(pr, bbox, fb, tol * 1.5)))

def main():
    only = set(sys.argv[1:])
    avas = B.avas()
    for fp in sorted(glob.glob(os.path.join(SRC, "*.yaml"))):
        spec = yaml.safe_load(open(fp, encoding="utf-8"))
        if only and spec["map"] not in only: continue
        build_map(spec, avas)

if __name__ == "__main__":
    main()
