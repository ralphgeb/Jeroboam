#!/usr/bin/env python3
"""Builds the illustrated wine maps used by the app.

Base geography: Natural Earth (public domain), 10m countries, lakes and rivers.
Download the GeoJSON files into a folder and pass it with --ne (default ~/ne):
  ne_10m_admin_0_countries, ne_50m_admin_0_countries, ne_10m_lakes,
  ne_10m_rivers_lake_centerlines, ne_10m_rivers_europe
Output: Jeroboam/Resources/Maps/<id>.json (projected, simplified, integer coordinates).
"""
import argparse, json, math, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from map_specs import MAPS

W = 1000  # output width in map units

ap = argparse.ArgumentParser()
ap.add_argument("--ne", default=os.path.expanduser("~/ne"))
ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "Jeroboam", "Resources", "Maps"))
args = ap.parse_args()

def load(name):
    with open(os.path.join(args.ne, name + ".geojson")) as f:
        return json.load(f)["features"]

countries10 = load("ne_10m_admin_0_countries")
countries50 = load("ne_50m_admin_0_countries")
lakes = load("ne_10m_lakes")
rivers = load("ne_10m_rivers_lake_centerlines") + load("ne_10m_rivers_europe")

def polys(geom):
    if geom is None: return []
    if geom["type"] == "Polygon": return [geom["coordinates"]]
    if geom["type"] == "MultiPolygon": return geom["coordinates"]
    return []

def lines(geom):
    if geom is None: return []
    if geom["type"] == "LineString": return [geom["coordinates"]]
    if geom["type"] == "MultiLineString": return geom["coordinates"]
    return []

def ring_bbox(r):
    xs = [p[0] for p in r]; ys = [p[1] for p in r]
    return min(xs), min(ys), max(xs), max(ys)

class Proj:
    def __init__(self, bbox):
        self.la0, self.lo0, self.la1, self.lo1 = bbox
        self.k = math.cos(math.radians((self.la0 + self.la1) / 2))
        if (self.lo1 - self.lo0) > 200: self.k = 1.0
        self.s = W / ((self.lo1 - self.lo0) * self.k)
        self.H = round((self.la1 - self.la0) * self.s)
    def __call__(self, lon, lat):
        return ((lon - self.lo0) * self.k * self.s, (self.la1 - lat) * self.s)

def clip_poly(pts, xmin, ymin, xmax, ymax):
    def clip(pts, inside, inter):
        out = []
        if not pts: return out
        prev = pts[-1]
        for cur in pts:
            if inside(cur):
                if not inside(prev): out.append(inter(prev, cur))
                out.append(cur)
            elif inside(prev):
                out.append(inter(prev, cur))
            prev = cur
        return out
    def ix(x):
        return lambda a, b: (x, a[1] + (b[1] - a[1]) * (x - a[0]) / (b[0] - a[0]))
    def iy(y):
        return lambda a, b: (a[0] + (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]), y)
    pts = clip(pts, lambda p: p[0] >= xmin, ix(xmin))
    pts = clip(pts, lambda p: p[0] <= xmax, ix(xmax))
    pts = clip(pts, lambda p: p[1] >= ymin, iy(ymin))
    pts = clip(pts, lambda p: p[1] <= ymax, iy(ymax))
    return pts

def clip_line(pts, xmin, ymin, xmax, ymax):
    """Split a polyline into the pieces inside the rectangle (Liang-Barsky per segment)."""
    out, cur = [], []
    for a, b in zip(pts, pts[1:]):
        dx, dy = b[0] - a[0], b[1] - a[1]
        t0, t1, ok = 0.0, 1.0, True
        for p, q in ((-dx, a[0] - xmin), (dx, xmax - a[0]), (-dy, a[1] - ymin), (dy, ymax - a[1])):
            if p == 0:
                if q < 0: ok = False; break
            else:
                t = q / p
                if p < 0: t0 = max(t0, t)
                else: t1 = min(t1, t)
        if not ok or t0 > t1:
            if len(cur) > 1: out.append(cur)
            cur = []; continue
        pa = (a[0] + t0 * dx, a[1] + t0 * dy); pb = (a[0] + t1 * dx, a[1] + t1 * dy)
        if not cur: cur = [pa]
        cur.append(pb)
        if t1 < 1.0:
            out.append(cur); cur = []
    if len(cur) > 1: out.append(cur)
    return out

def simplify(pts, tol):
    if len(pts) < 3: return pts
    keep = [False] * len(pts); keep[0] = keep[-1] = True
    stack = [(0, len(pts) - 1)]
    while stack:
        i, j = stack.pop()
        ax, ay = pts[i]; bx, by = pts[j]
        dx, dy = bx - ax, by - ay; L = math.hypot(dx, dy)
        best, bi = -1, -1
        for k in range(i + 1, j):
            px, py = pts[k]
            d = abs(dy * (px - ax) - dx * (py - ay)) / L if L > 0 else math.hypot(px - ax, py - ay)
            if d > best: best, bi = d, k
        if best > tol:
            keep[bi] = True; stack += [(i, bi), (bi, j)]
    return [p for p, k in zip(pts, keep) if k]

def flat(pts):
    out = []
    last = None
    for x, y in pts:
        q = (round(x), round(y))
        if q != last: out += q; last = q
    return out

def area(pts):
    return 0.5 * sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(pts, pts[1:] + pts[:1]))

def centroid(pts):
    A = area(pts)
    if abs(A) < 1e-9:
        return sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts)
    cx = sum((a[0] + b[0]) * (a[0] * b[1] - b[0] * a[1]) for a, b in zip(pts, pts[1:] + pts[:1])) / (6 * A)
    cy = sum((a[1] + b[1]) * (a[0] * b[1] - b[0] * a[1]) for a, b in zip(pts, pts[1:] + pts[:1])) / (6 * A)
    return cx, cy

# ---- region shapes (in lat/lon), built in a local km plane
def km_frame(lat0):
    kx = 111.32 * math.cos(math.radians(lat0)); ky = 110.57
    return kx, ky

def shape_latlon(s):
    if s["t"] == "poly":
        return [(lon, lat) for lat, lon in s["p"]]
    if s["t"] == "blob":
        lat0, lon0 = s["c"]; rx, ry = s["r"]; a = math.radians(s["a"])
        kx, ky = km_frame(lat0)
        out = []
        for i in range(48):
            t = 2 * math.pi * i / 48
            x, y = rx * math.cos(t), ry * math.sin(t)
            xr, yr = x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a)
            out.append((lon0 + xr / kx, lat0 + yr / ky))
        return out
    if s["t"] == "strip":
        pts = s["p"]; w = s["w"] / 2
        lat0 = sum(p[0] for p in pts) / len(pts); lon0 = sum(p[1] for p in pts) / len(pts)
        kx, ky = km_frame(lat0)
        P = [((lon - lon0) * kx, (lat - lat0) * ky) for lat, lon in pts]
        # densify
        D = [P[0]]
        for a, b in zip(P, P[1:]):
            n = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) / 2))
            for k in range(1, n + 1):
                D.append((a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n))
        def normal(i):
            a = D[max(0, i - 2)]; b = D[min(len(D) - 1, i + 2)]
            dx, dy = b[0] - a[0], b[1] - a[1]; L = math.hypot(dx, dy) or 1
            return -dy / L, dx / L
        left = [(p[0] + normal(i)[0] * w, p[1] + normal(i)[1] * w) for i, p in enumerate(D)]
        right = [(p[0] - normal(i)[0] * w, p[1] - normal(i)[1] * w) for i, p in enumerate(D)]
        ring = left + cap_arc(D[-1], left[-1], right[-1], w) + right[::-1] + cap_arc(D[0], right[0], left[0], w)
        return [(lon0 + x / kx, lat0 + y / ky) for x, y in ring]
    raise ValueError(s)

def cap_arc(c, frm, to, w):
    a0 = math.atan2(frm[1] - c[1], frm[0] - c[0])
    a1 = math.atan2(to[1] - c[1], to[0] - c[0])
    # go the outer way: the arc that does not pass through the path direction (half circle, clockwise)
    d = -math.pi  # half circle around the outside of the end point
    return [(c[0] + w * math.cos(a0 + d * k / 10), c[1] + w * math.sin(a0 + d * k / 10)) for k in range(1, 10)]

def build(spec):
    pr = Proj(spec["bbox"])
    H = pr.H; m = 4
    box = (-m, -m, W + m, H + m)
    la0, lo0, la1, lo1 = spec["bbox"]
    pad = 2.0
    gb = (lo0 - pad, la0 - pad, lo1 + pad, la1 + pad)
    world = spec["world"]
    tol = 0.45 if not world else 0.6
    src = countries50 if world else countries10

    def in_geo(r):
        x0, y0, x1, y1 = ring_bbox(r)
        return not (x1 < gb[0] or x0 > gb[2] or y1 < gb[1] or y0 > gb[3])

    def proj_poly(ring):
        pts = [pr(lon, lat) for lon, lat in ring]
        pts = clip_poly(pts, *box)
        if len(pts) < 3: return None
        pts = simplify(pts + [pts[0]], tol)[:-1]
        if len(pts) < 3 or abs(area(pts)) < (2 if not world else 1.5): return None
        return flat(pts)

    land, focus = [], []
    for f in src:
        p = f["properties"]
        code = p.get("ADM0_A3") or p.get("adm0_a3")
        is_focus = code in spec["focus"]
        for poly in polys(f["geometry"]):
            outer = poly[0]
            if not in_geo(outer): continue
            fp = proj_poly(outer)
            if fp: (focus if is_focus else land).append(fp)

    lk = []
    if not world:
        for f in lakes:
            for poly in polys(f["geometry"]):
                if not in_geo(poly[0]): continue
                fp = proj_poly(poly[0])
                if fp and abs(area(list(zip(fp[::2], fp[1::2])))) > 6: lk.append(fp)

    rv = []
    if not world:
        for f in rivers:
            rank = f["properties"].get("scalerank") or 0
            if rank > spec["river_rank"]: continue
            for ln in lines(f["geometry"]):
                xs = [p[0] for p in ln]; ys = [p[1] for p in ln]
                if max(xs) < gb[0] or min(xs) > gb[2] or max(ys) < gb[1] or min(ys) > gb[3]: continue
                pts = [pr(lon, lat) for lon, lat in ln]
                for piece in clip_line(pts, *box):
                    piece = simplify(piece, tol)
                    if len(piece) >= 2:
                        L = sum(math.hypot(b[0] - a[0], b[1] - a[1]) for a, b in zip(piece, piece[1:]))
                        if L > 8: rv.append({"w": 1 if rank >= 6 else 2, "p": flat(piece)})

    regions = []
    for r in spec["regions"]:
        shapes, best, bestA = [], None, -1
        for s in r["shapes"]:
            pts = [pr(lon, lat) for lon, lat in shape_latlon(s)]
            A = abs(area(pts))
            if A > bestA: best, bestA = pts, A
            shapes.append(flat(simplify(pts + [pts[0]], 0.4)[:-1]))
        if r["label"]:
            lx, ly = pr(r["label"][1], r["label"][0])
        else:
            lx, ly = centroid(best)
        regions.append({"id": r["id"], "name": r["name"], "small": r["small"], "shapes": shapes,
                        "lx": round(lx), "ly": round(ly)})

    cities = []
    for name, lat, lon in spec["cities"]:
        x, y = pr(lon, lat)
        cities.append({"n": name, "x": round(x), "y": round(y)})
    labels = []
    for t, lat, lon, kind in spec["labels"]:
        x, y = pr(lon, lat)
        labels.append({"t": t, "x": round(x), "y": round(y), "k": kind})

    out = {"id": spec["id"], "title": spec["title"], "w": W, "h": H, "land": land, "focus": focus,
           "lakes": lk, "rivers": rv, "regions": regions, "cities": cities, "labels": labels}
    if world:
        bands = []
        for a, b in ((30, 50), (-50, -30)):
            y0 = pr(0, b)[1]; y1 = pr(0, a)[1]
            bands += [round(y0), round(y1)]
        out["belts"] = bands
    return out

os.makedirs(args.out, exist_ok=True)
for spec in MAPS:
    data = build(spec)
    path = os.path.join(args.out, spec["id"] + ".json")
    with open(path, "w") as f:
        json.dump(data, f, separators=(",", ":"), ensure_ascii=False)
    print(f"{spec['id']:18s} {data['w']}x{data['h']}  land {len(data['land'])} focus {len(data['focus'])} "
          f"rivers {len(data['rivers'])} lakes {len(data['lakes'])} regions {len(data['regions'])}  {os.path.getsize(path)//1024} KB")
