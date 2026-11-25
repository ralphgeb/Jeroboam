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
import sys as _sys
B = _sys.modules.get('__main__') if getattr(_sys.modules.get('__main__'), 'build_gb', None) else None
if B is None:
    import build_maps2 as B
import math
from shapely.geometry import shape, Polygon, Point
from shapely import affinity
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
    elif "circle" in r:           # a village or small zone: centre [lat, lon] and radius in km
        la, lo = r["circle"]["c"]
        g = Point(lo, la).buffer(B.km2deg(r["circle"]["r"]), 32)
        g = affinity.scale(g, xfact=1 / max(0.2, math.cos(math.radians(la))), yfact=1, origin=(lo, la))
    else:
        if not r.get("pdo_name"): print(f"   ! {spec['map']}/{rid}: no geometry")
        return None
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

# ---------------------------------------------------------------- official EU PDO boundaries
_CYR = dict(zip("абвгдежзийклмнопрстуфхцчшщъьюя", ["a","b","v","g","d","e","zh","z","i","y","k","l","m","n","o","p","r","s","t","u","f","h","ts","ch","sh","sht","a","","yu","ya"]))
_GRK = dict(zip("αβγδεζηθικλμνξοπρσςτυφχψωάέήίόύώϊϋΐΰ", ["a","v","g","d","e","z","i","th","i","k","l","m","n","x","o","p","r","s","s","t","y","f","ch","ps","o","a","e","i","i","o","y","o","i","y","i","y"]))
def translit(t):
    out = []
    for ch in t:
        lo = ch.lower()
        r = _CYR.get(lo, _GRK.get(lo))
        if r is None: out.append(ch); continue
        out.append(r.capitalize() if ch != lo else r)
    s = "".join(out)
    if any(ch.lower() in _GRK for ch in t):   # Greek digraphs
        s = s.replace("Ou", "U").replace("ou", "u").replace("Mp", "B").replace(" mp", " b").replace("nt", "nd")
    return s

def pdo_list(cc):
    """[(pid, display name, geometry)] of one EU country (B._pdo_index, Candiago et al. 2022, CC BY 4.0)."""
    seen, by = set(), {}
    for lst in B._pdo_index().values():
        for pid, nm, g in lst:
            if pid in seen or not pid.startswith(f"PDO-{cc}-"): continue
            seen.add(pid)
            by.setdefault(nm.split(" / ")[0].strip(), []).append((pid, g))
    # one area per name (a denomination registered once per wine category)
    return [(v[0][0], nm, unary_union([g for _, g in v]).buffer(0)) for nm, v in by.items()]

def add_pdos(spec, built, regions):
    """Every official denomination of the country that the spec has not drawn already: nested under the smallest region
    or denomination that holds it (so regions sit at the back and the appellations inside them on top)."""
    pc = spec.get("pdo")
    if not pc: return []
    cc = pc["cc"]
    names = pc.get("names", {})
    skip = set(pc.get("skip", []))
    pdos = pdo_list(cc)
    taken = []   # pids already used as a region's own geometry
    byname = {}
    for pid, nm, g in pdos: byname.setdefault(nm, []).append((pid, g))
    for r in regions:   # regions that ARE an official PDO take its boundary
        want = r.get("pdo_name")
        if not want: continue
        gs = [(pid, g) for n in ([want] if isinstance(want, str) else want) for pid, g in byname.get(n, [])]
        if gs:
            built[r["id"]] = unary_union([g for _, g in gs]).buffer(0)
            taken += [pid for pid, _ in gs]
        else:
            print(f"   ! {spec['map']}/{r['id']}: no PDO named {want}")
    cand = [(pid, names.get(nm) or translit(nm), g) for pid, nm, g in pdos
            if pid not in taken and nm not in skip and g.area >= pc.get("min", 0.0005)]
    return nest_official(spec, built, cand, pc.get("prefix", ""), "-" + cc.lower())

def nest_official(spec, built, cand, prefix="", suffix="-x"):
    """Adds official areas [(key, name, geometry)], biggest first, each under the smallest area that holds it."""
    extra = []
    existing = [(rid, g) for rid, g in built.items()]
    used_geoms = [built[r] for r in built]
    for key, disp, g in sorted(cand, key=lambda x: -x[2].area):
        if any(g2.intersection(g).area / max(1e-12, g2.union(g).area) > 0.9 for g2 in used_geoms): continue   # same shape twice
        rid = prefix + B.slug(disp)
        if rid in built or any(e["id"] == rid for e in extra): rid += suffix
        holders = [(hid, hg) for hid, hg in existing if hg.area > g.area * 1.05 and hg.intersection(g).area > 0.75 * g.area]
        parent = min(holders, key=lambda x: x[1].area)[0] if holders else None
        extra.append({"id": rid, "name": disp, "parent": parent, "_geom": g})
        built[rid] = g; existing.append((rid, g)); used_geoms.append(g)
        print(f"   + {spec['map']}: {disp} ({'in ' + parent if parent else 'top'})")
    return extra

def add_avas(spec, built, avas):
    """Every AVA of the map's states (UC Davis AVA project) not drawn yet, nested inside the AVAs that hold it."""
    ac = spec.get("ava_auto")
    if not ac: return []
    states = set(ac["states"])
    la0, lo0, la1, lo1 = spec["bbox"]
    from shapely.geometry import box as _box
    frame = _box(lo0, la0, lo1, la1)
    used = {n for r in spec["regions"] for n in r.get("ava", [])}
    cand = []
    for n, f in avas.items():
        st = set((f["properties"].get("state") or "").split("|"))
        if n in used or not (st & states) or n in ac.get("skip", []): continue
        g = shape(f["geometry"]).buffer(0)
        if g.intersection(frame).area < 0.6 * g.area: continue
        cand.append((n, n, g))
    return nest_official(spec, built, cand, ac.get("prefix", ""), "-ava")

def build_map(spec, avas):
    mid = spec["map"]
    print(f"{mid}…")
    bbox = tuple(spec["bbox"])
    pr = B.Proj(bbox, spec.get("W", 2800))
    tol = 0.55
    land, focus, lk, rv = B.base_layers(pr, bbox, spec["focus"], tol=tol)
    built = {}
    regions = spec["regions"]
    byid = {r["id"]: r for r in regions}
    def depth(r):
        d = 0
        while r.get("parent") and r["parent"] in byid:
            r = byid[r["parent"]]; d += 1
        return d
    # parents first so children can be clipped to them
    for r in sorted(regions, key=depth):
        g = geom_of(r["id"], r, spec, built, avas)
        if g is not None: built[r["id"]] = g
    # places drawn as circles share the ground between them (Voronoi cells), so neighbours never overlap
    circ = [r for r in regions if "circle" in r and r["id"] in built]
    if len(circ) > 1:
        from shapely.ops import voronoi_diagram
        from shapely.geometry import MultiPoint, box as _box
        la0, lo0, la1, lo1 = spec["bbox"]
        cells = list(voronoi_diagram(MultiPoint([(r["circle"]["c"][1], r["circle"]["c"][0]) for r in circ]),
                                     envelope=_box(lo0 - 5, la0 - 5, lo1 + 5, la1 + 5)).geoms)
        for r in circ:
            c = Point(r["circle"]["c"][1], r["circle"]["c"][0])
            cell = next((x for x in cells if x.contains(c)), None)
            if cell is not None: built[r["id"]] = built[r["id"]].intersection(cell)
    for r in add_pdos(spec, built, regions) + add_avas(spec, built, avas):
        regions.append(r); byid[r["id"]] = r
    if spec.get("auto_nest"):
        # official areas inside other official areas (an AVA within an AVA): the smaller one sits on top, one level down
        for r in regions:
            if r.get("parent") or r["id"] not in built: continue
            g = built[r["id"]]
            holders = [(o["id"], built[o["id"]]) for o in regions if o is not r and o["id"] in built
                       and built[o["id"]].area > g.area * 1.05 and built[o["id"]].intersection(g).area > 0.75 * g.area]
            if holders:
                r["parent"] = min(holders, key=lambda x: x[1].area)[0]
                print(f"   ~ {spec['map']}: {r['id']} inside {r['parent']}")
    areas, col = [], {}
    def top(r):
        while r.get("parent") and r["parent"] in byid: r = byid[r["parent"]]
        return r["id"]
    col = B.atlas_colors([(r["id"], depth(r), r.get("parent")) for r in regions if r["id"] in built], built,
                         {r["id"]: r["color"] for r in regions if r.get("color")})
    for r in sorted(regions, key=depth):
        if r["id"] not in built: continue
        d = depth(r)
        areas.append(B.area_record(pr, r["id"], r["name"], min(d, 2), col.get(r["id"], 0), built[r["id"]], tol, parent=r.get("parent"),
                                   min_area=1, soft=r.get("soft", "units" in r or "circle" in r), grapes=r.get("grape_line"), pdo=False))
    areas = [a for a in areas if a]
    areas.sort(key=lambda a: (a["lv"], -sum(len(x) for x in a["shapes"])))
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
