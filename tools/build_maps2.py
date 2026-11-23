#!/usr/bin/env python3
"""Detailed, zoomable wine maps (format v2).

Sources (download first, see CLAUDE.md):
  ~/ne/*.geojson                         Natural Earth 10m (land, countries, admin-1, lakes, rivers)
  ~/geo/fr/communes-<dept>.geojson       French communes (github.com/gregoiredavid/france-geojson)
  ~/geo/fr/departements-full.geojson     French départements
  ~/geo/it_comuni.geojson                Italian comuni (github.com/openpolis/geojson-italy)
  ~/geo/ava/avas_aggregated_files/avas.geojson   US AVAs (github.com/UCDavisLibrary/ava)

Areas carry a level: 0 = region, 1 = appellation/district, 2 = cru/village. The app shows deeper levels as you zoom.
"""
import json, math, os, re, sys, unicodedata
from shapely.geometry import shape, Polygon, MultiPolygon, Point, box, LineString, MultiLineString
from shapely.ops import unary_union, transform
from shapely.prepared import prep
from shapely.geometry.polygon import orient

sys.path.insert(0, os.path.dirname(__file__))
import specs_fr as FR
import specs_world as WD
from map_specs import MAPS as LEGACY
from geo_shapes import shape_latlon

HOME = os.environ.get("GEO_HOME", "/home/user")
NE = os.path.join(HOME, "ne")
GEO = os.path.join(HOME, "geo")
OUT = os.path.join(os.path.dirname(__file__), "..", "Jeroboam", "Resources", "Maps")
os.makedirs(OUT, exist_ok=True)

RES = 2  # coordinate precision multiplier (smooth edges when zoomed)
MIN_ASPECT = 1.3  # width / height
MAP_PAD = 0.5  # extra context around every map (fraction of the bbox on each side) so neighbours and sea show

def chaikin(pts, it=2):
    """Corner-cutting smoothing for a closed ring (list of (x,y), first==last)."""
    ring = list(pts[:-1]) if len(pts) > 1 and pts[0] == pts[-1] else list(pts)
    for _ in range(it):
        if len(ring) < 3: break
        out = []
        n = len(ring)
        for i in range(n):
            (x0, y0), (x1, y1) = ring[i], ring[(i + 1) % n]
            out.append((0.75 * x0 + 0.25 * x1, 0.75 * y0 + 0.25 * y1))
            out.append((0.25 * x0 + 0.75 * x1, 0.25 * y0 + 0.75 * y1))
        ring = out
    return ring + ring[:1]

PALETTE = ["claret", "magenta", "rose", "coral", "orange", "ochre", "gold", "olive", "green", "teal", "blue", "violet", "plum"]

def cidx(name, i=0):
    if name in PALETTE: return PALETTE.index(name)
    return [0, 9, 4, 11, 6, 1, 8, 3, 12, 2, 7, 5, 10][i % 13]

def load(path):
    with open(path) as f: return json.load(f)["features"]

print("loading sources…")
countries = load(f"{NE}/ne_10m_admin_0_countries.geojson")
countries50 = load(f"{NE}/ne_50m_admin_0_countries.geojson")
admin1 = load(f"{NE}/ne_10m_admin_1_states_provinces.geojson")
lakes = load(f"{NE}/ne_10m_lakes.geojson")
land10 = load(f"{NE}/ne_10m_land.geojson")
rivers = load(f"{NE}/ne_10m_rivers_lake_centerlines.geojson") + load(f"{NE}/ne_10m_rivers_europe.geojson")

def norm(s):
    s = s.replace("œ", "oe").replace("Œ", "Oe")
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower()
    s = s.replace("-", " ").replace("'", " ").replace("’", " ")
    s = " ".join(s.split())
    for art in ("le ", "la ", "les ", "l "):
        if s.startswith(art): s = s[len(art):]
    return s

# ---------------------------------------------------------------- projection
class Proj:
    def __init__(self, bbox, W, pad=None):
        la0, lo0, la1, lo1 = bbox
        if pad is None: pad = 0.0 if lo1 - lo0 > 200 else MAP_PAD
        # more context, same detail per degree: the full map can fill a tall phone screen centered on the region
        W = W * (1 + 2 * pad) / 1.32 if lo1 - lo0 < 200 else W
        dla, dlo = (la1 - la0) * pad, (lo1 - lo0) * pad
        bbox = (la0 - dla, lo0 - dlo, la1 + dla, lo1 + dlo)
        if lo1 - lo0 < 200:
            # tall countries (Portugal, Chile, Italy…) get extra width so a wide card can show them whole
            k = math.cos(math.radians((bbox[0] + bbox[2]) / 2))
            asp = (bbox[3] - bbox[1]) * k / (bbox[2] - bbox[0])
            if asp < MIN_ASPECT:
                extra = ((bbox[2] - bbox[0]) * MIN_ASPECT / k - (bbox[3] - bbox[1])) / 2
                W = min(W * 3, W * ((bbox[3] - bbox[1]) + 2 * extra) / (bbox[3] - bbox[1]))  # keep detail per degree
                bbox = (bbox[0], bbox[1] - extra, bbox[2], bbox[3] + extra)
            # phone rule: with the whole region fitted between the explorer's header and list card
            # (about 361 x 385 pt), the map must still cover a 400 x 870 pt screen, so it never runs out at the edges
            k0 = math.cos(math.radians((la0 + la1) / 2))
            dpp = max((lo1 - lo0) * k0 / 361, (la1 - la0) / 385)  # degrees per point at that fit
            need_w, need_h = 400 * dpp / k, 870 * dpp
            if bbox[3] - bbox[1] < need_w:
                e = (need_w - (bbox[3] - bbox[1])) / 2
                W = min(W * 3, W * need_w / (bbox[3] - bbox[1]))
                bbox = (bbox[0], bbox[1] - e, bbox[2], bbox[3] + e)
            if bbox[2] - bbox[0] < need_h:
                e = (need_h - (bbox[2] - bbox[0])) / 2
                bbox = (bbox[0] - e, bbox[1], bbox[2] + e, bbox[3])
        self.bbox = bbox
        self.la0, self.lo0, self.la1, self.lo1 = bbox
        self.k = math.cos(math.radians((self.la0 + self.la1) / 2))
        if self.lo1 - self.lo0 > 200: self.k = 1.0
        W = round(min(W, 16000) * RES) if lo1 - lo0 < 200 else W * RES
        self.W = W
        self.s = W / ((self.lo1 - self.lo0) * self.k)
        self.H = round((self.la1 - self.la0) * self.s)
    def xy(self, lon, lat):
        return ((lon - self.lo0) * self.k * self.s, (self.la1 - lat) * self.s)
    def geom(self, g):
        return transform(lambda x, y, z=None: ((x - self.lo0) * self.k * self.s, (self.la1 - y) * self.s), g)

class FineProj(Proj):
    """The France projection magnified K times: coordinates stay in France units x K, so detailed insets sit exactly on the country map."""
    def __init__(self, base, K, bbox):
        self.__dict__.update(base.__dict__)
        self.K = K
        self.s = base.s * K
        self.W = base.W * K
        self.H = base.H * K
        self.bbox = bbox

def polys_of(g):
    if g.is_empty: return []
    if isinstance(g, Polygon): return [g]
    if isinstance(g, MultiPolygon): return list(g.geoms)
    if hasattr(g, "geoms"): return [p for x in g.geoms for p in polys_of(x)]
    return []

def lines_of(g):
    if g.is_empty: return []
    if isinstance(g, LineString): return [g]
    if isinstance(g, MultiLineString): return list(g.geoms)
    if hasattr(g, "geoms"): return [l for x in g.geoms for l in lines_of(x)]
    return []

def flat(coords):
    out, last = [], None
    for x, y in coords:
        q = (round(x), round(y))
        if q != last: out += q; last = q
    return out

def enc_polys(g, tol, min_area, smooth=False):
    res = []
    for p in polys_of(g.simplify(tol * RES, preserve_topology=True)):
        if p.area < min_area * RES * RES: continue
        coords = list(orient(p, 1.0).exterior.coords)
        f = flat(chaikin(coords) if smooth else coords)
        if len(f) >= 6: res.append(f)
    return res

# ---------------------------------------------------------------- sources by key
_fr_cache = {}
def fr_communes(dept):
    if dept not in _fr_cache:
        _fr_cache[dept] = [(f["properties"]["nom"], shape(f["geometry"])) for f in load(f"{GEO}/fr/communes-{dept}.geojson")]
    return _fr_cache[dept]

_it = None
def it_comuni(reg):
    global _it
    if _it is None:
        _it = [(f["properties"]["name"], f["properties"]["reg_name"], shape(f["geometry"])) for f in load(f"{GEO}/it_comuni.geojson")]
    return [(n, g) for n, r, g in _it if r == reg]

_ava = None
def avas():
    global _ava
    if _ava is None:
        _ava = {f["properties"]["name"].strip(): f for f in load(f"{GEO}/ava/avas_aggregated_files/avas.geojson")}
    return _ava

def slug(s):
    return norm(s).replace(" ", "-")

# ---------------------------------------------------------------- resolve area specs to geometry (lon/lat)
def resolve(specs, pool_fn, used_by_level=None):
    """specs with communes/within against a commune pool. Returns {id: (geom, [commune names])}."""
    used_by_level = used_by_level if used_by_level is not None else {}
    out = {}
    # explicit lists first, then polygons
    order = [s for s in specs if s.get("communes")] + [s for s in specs if not s.get("communes") and s.get("within")]
    for s in order:
        pool = pool_fn(s)
        used = used_by_level.setdefault(s["lv"], set())
        geoms, names = [], []
        if s.get("communes"):
            want = {norm(c) for c in s["communes"]}
            found = set()
            for n, g in pool:
                k = norm(n)
                if k in want:
                    geoms.append(g); names.append(n); found.add(k)
            for miss in sorted(want - found):
                print(f"   ! {s['id']}: commune not found: {miss}")
        else:
            poly = prep(Polygon([(lon, lat) for lat, lon in s["within"]]))
            for n, g in pool:
                if n in used: continue
                if poly.contains(g.representative_point()):
                    geoms.append(g); names.append(n)
        for n in names: used.add(n)
        if geoms:
            out[s["id"]] = (unary_union([g.buffer(0) for g in geoms]), names)
        else:
            print(f"   ! {s['id']}: empty")
    return out

def fr_pool(s):
    return [x for d in s["depts"] for x in fr_communes(d)]

def it_pool(s):
    return [x for r in s["depts"] for x in it_comuni(r)]

# ---------------------------------------------------------------- base map
_OSM = {}
def osm_land(clipbox):
    """OSM simplified land polygons (finer coastlines than Natural Earth), when a fetched tile covers the box."""
    d = os.path.join(GEO, "pdo")
    for k in ("europe", "lebanon", "usa-west", "southamerica", "australia", "nz", "safrica"):
        p = os.path.join(d, f"land_{k}.geojson")
        if not os.path.exists(p): continue
        if k not in _OSM:
            gs = [shape(f["geometry"]).buffer(0) for f in json.load(open(p))["features"]]
            _OSM[k] = (unary_union(gs), box(*unary_union(gs).bounds))
        u, b = _OSM[k]
        if b.buffer(0.05).contains(clipbox.buffer(-0.6)):
            return u.intersection(clipbox)
    return None

def base_layers(pr, bbox, focus_codes, world=False, tol=1.0, pad=1.5):
    bbox = pr.bbox
    la0, lo0, la1, lo1 = bbox
    clipbox = box(lo0 - pad, la0 - pad, lo1 + pad, la1 + pad)
    view = box(-20, -20, pr.W + 20, pr.H + 20)
    land, focus = [], []
    fine = None if world else osm_land(clipbox)
    if fine is not None:
        # coastlines from OSM; the focus country's inland borders from Natural Earth
        fg = unary_union([shape(f["geometry"]) for f in countries if f["properties"].get("ADM0_A3") in focus_codes
                          and shape(f["geometry"]).intersects(clipbox)]).buffer(0)
        nb = unary_union([shape(f["geometry"]) for f in countries if f["properties"].get("ADM0_A3") not in focus_codes
                          and shape(f["geometry"]).intersects(clipbox)]).buffer(0)
        fgf = fg.buffer(0.03).difference(nb).intersection(fine)
        others = fine.difference(fgf)
        focus.extend(enc_polys(pr.geom(fgf).buffer(0).intersection(view), tol, tol * tol * 4))
        land.extend(enc_polys(pr.geom(others).buffer(0).intersection(view), tol, tol * tol * 4))
    for f in ([] if fine is not None else (countries50 if world else countries)):
        g = shape(f["geometry"])
        if not g.intersects(clipbox): continue
        code = f["properties"].get("ADM0_A3")
        pg = pr.geom(g.intersection(clipbox)).intersection(view)
        enc = enc_polys(pg, tol, tol * tol * 4)
        (focus if code in focus_codes else land).extend(enc)
    lk = []
    if not world:
        for f in lakes:
            g = shape(f["geometry"])
            if not g.intersects(clipbox): continue
            lk += enc_polys(pr.geom(g.intersection(clipbox)).intersection(view), tol, tol * tol * 30)
    rv = []
    if not world:
        for f in rivers:
            rank = f["properties"].get("scalerank") or 0
            if rank > 9: continue
            g = shape(f["geometry"])
            if not g.intersects(clipbox): continue
            for ln in lines_of(pr.geom(g.intersection(clipbox)).intersection(view).simplify(tol * RES)):
                if ln.length > tol * 8:
                    rv.append({"w": 2 if rank < 6 else 1, "p": flat(ln.coords)})
    return land, focus, lk, rv

def admin_borders(pr, bbox, geoms, tol):
    """Internal boundary lines of a set of admin polygons (lon/lat shapes)."""
    la0, lo0, la1, lo1 = pr.bbox
    clipbox = box(lo0 - 1, la0 - 1, lo1 + 1, la1 + 1)
    view = box(-20, -20, pr.W + 20, pr.H + 20)
    out = []
    for g in geoms:
        if not g.intersects(clipbox): continue
        b = pr.geom(g.boundary.intersection(clipbox)).intersection(view).simplify(tol * RES)
        for ln in lines_of(b):
            if ln.length > tol * 6: out.append(flat(ln.coords))
    return out

def label_point(g):
    p = g.representative_point()
    return p.x, p.y

_GEOMS = {}   # (id(proj), area id) -> (lon/lat geometry, color, level), for province tints

def tints(pr, adm_geoms, tol, areas):
    """Light tint of every province that holds vineyards, in the color of its main wine area."""
    src = [(_GEOMS[(id(pr), a["id"])]) for a in areas if a and (id(pr), a["id"]) in _GEOMS and a["lv"] == 0]
    out = []
    for adm in adm_geoms:
        if adm.is_empty: continue
        best, best_a = None, 0.0
        for g, c, lv in src:
            if not g.intersects(adm): continue
            a = g.intersection(adm).area
            if a > best_a: best, best_a = c, a
        if best is None or best_a < adm.area * 0.004: continue
        shapes = enc_polys(soften(pr.geom(adm), tol), tol * 1.5, 8, smooth=True)
        if shapes: out.append({"c": best, "shapes": shapes})
    return out

def _bearing(a, b):
    return math.degrees(math.atan2(b[1] - a[1], (b[0] - a[0]) * math.cos(math.radians((a[1] + b[1]) / 2)))) % 180

def snap_to_communes(ln, geoms, radius_km=1.4, max_turn=50):
    """The river's true course: the commune boundaries that run along it. Commune borders follow the river (the two
    banks meet in mid-stream), while the Natural Earth river line is coarse and can sit a kilometre off.
    Returns the (sub)segments of commune boundaries within radius_km of ln that run roughly parallel to it."""
    corridor = ln.buffer(km2deg(radius_km))
    L = ln.length
    kept = []
    for g in geoms:
        if not g.intersects(corridor): continue
        for piece in lines_of(g.boundary.intersection(corridor)):
            pts = list(piece.coords)
            for i in range(len(pts) - 1):
                p, q = pts[i], pts[i + 1]
                if p == q: continue
                mid = Point((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)
                t = ln.project(mid)
                t0, t1 = max(0, t - L * 0.01), min(L, t + L * 0.01)
                a0, a1 = ln.interpolate(t0).coords[0], ln.interpolate(t1).coords[0]
                d = abs(_bearing(p, q) - _bearing(a0, a1))
                d = min(d, 180 - d)
                if d <= max_turn and mid.distance(ln) <= km2deg(radius_km):
                    kept.append((LineString([p, q]), t / L if L else 0))
    return kept

def water_polys(pr, water, estuary, tol, geoms=None):
    """Wide rivers and estuaries as smooth water polygons (drawn over the wine areas, like a printed atlas).
    water = [(river name, half-width in km at the upstream end, half-width at the downstream end)];
    estuary = (lon0, lat0, lon1, lat1): sea inside this box (from the 10m land) is smoothed and drawn as water.
    geoms: the communes of the map (lon/lat); when given, the water is snapped onto the real commune borders so land and
    water meet exactly instead of leaving white gaps or cutting through appellations."""
    out = []
    view = box(-20, -20, pr.W + 20, pr.H + 20)
    la0, lo0, la1, lo1 = pr.bbox
    clip = box(lo0, la0, lo1, la1)
    for name, w0, w1 in water:
        for f in rivers:
            if f["properties"].get("name") != name: continue
            for ln in lines_of(shape(f["geometry"]).intersection(clip)):
                pts = list(ln.coords)
                n = len(pts)
                if n < 2: continue
                # orient upstream -> downstream (rivers here flow west/north-west toward the sea)
                if pts[0][0] < pts[-1][0]: pts = pts[::-1]
                ln = LineString(pts)
                segs = []
                for i in range(n - 1):
                    t = i / max(1, n - 2)
                    r = km2deg(w0 + (w1 - w0) * t)
                    segs.append(LineString(pts[i:i + 2]).buffer(r, cap_style=1))
                g = unary_union(segs).buffer(km2deg(0.15)).buffer(-km2deg(0.15))
                if geoms:
                    kept = snap_to_communes(ln, geoms)
                    if kept:
                        sn = [sg.buffer(km2deg(w0 + (w1 - w0) * t), cap_style=1) for sg, t in kept]
                        snapped = unary_union(sn)
                        support = unary_union([sg for sg, _ in kept]).buffer(km2deg(0.9))
                        far = g.difference(support)
                        # close the little gaps between boundary pieces, keep the banks sharp
                        rc = min(0.9, max(0.3, 3.5 * max(w0, w1)))     # closing: fill the gaps between boundary pieces
                        ro = 0.4 * min(w0, w1)                          # opening: drop thin spikes, never the river itself
                        g = unary_union([snapped, far]).buffer(km2deg(rc)).buffer(-km2deg(rc)).buffer(-km2deg(ro)).buffer(km2deg(ro))
                out += enc_polys(pr.geom(g).intersection(view), tol * 0.6, 1, smooth=True)
    if estuary:
        eb = box(*estuary)
        landg = unary_union([shape(f["geometry"]).intersection(eb.buffer(0.3)) for f in land10 if shape(f["geometry"]).intersects(eb)])
        sea = eb.difference(landg)
        r = km2deg(0.6)
        sea = sea.buffer(-r).buffer(2 * r).buffer(-r)  # smooth the coarse coastline both ways
        if geoms:
            # the coarse coast leaves white gaps between the water and the communes on the banks: widen the estuary
            # into whatever near it is not commune land
            cover = unary_union([g for g in geoms if g.intersects(eb.buffer(0.1))])
            ext = sea.buffer(km2deg(3.0)).intersection(eb).difference(cover)
            sea = unary_union([sea, ext]).buffer(km2deg(0.5)).buffer(-km2deg(0.5))
        out += enc_polys(pr.geom(sea.intersection(eb)).intersection(view), tol * 0.6, 4, smooth=True)
    return out

# ---------------------------------------------------------------- official EU wine PDO boundaries
# Candiago et al. 2022, "A geospatial inventory of regulatory information for wine protected designations of origin
# in Europe", Scientific Data (figshare collection 5877659, CC BY 4.0). Fetched by .github/workflows/geodata.yml.
PDO_DIR = os.path.join(GEO, "pdo")
_PDO = None
PDO_ALIAS = {  # our area id -> official PDO name(s) when the names differ
    "saint-emilion": ["Saint-Émilion", "Saint-Émilion grand cru"], "chateauneuf-du-pape": ["Châteauneuf-du-Pape"],
    "cotes-du-rhone": ["Côtes du Rhône"], "cote-rotie": ["Côte Rôtie"], "pouilly-fume": ["Pouilly-Fumé"],
    "chianti-classico": ["Chianti Classico"], "montalcino": ["Brunello di Montalcino"], "montepulciano": ["Vino Nobile di Montepulciano"],
    "douro": ["Douro"], "porto": ["Porto"], "jerez": ["Jerez-Xérès-Sherry"], "rias-baixas": ["Rías Baixas"],
    "mosel": ["Mosel"], "tokaj": ["Tokaj"],
    "santorini": ["Σαντορίνη"], "naoussa": ["Νάουσα"], "amyndeo": ["Αμύνταιο"], "nemea": ["Νεμέα"], "mantinia": ["Μαντινεία"],
    "patras": ["Πάτρα"], "crete": ["Αρχάνες", "Πεζά", "Δαφνές", "Σητεία"], "goumenissa": ["Γουμένισσα"], "rapsani": ["Ραψάνη"],
    "margaret-river": ["Margaret River"], "hunter-valley": ["Hunter"], "barossa": ["Barossa Valley"], "clare": ["Clare Valley"],
    "mclaren-vale": ["McLaren Vale"], "eden-valley": ["Eden Valley"], "yarra-valley": ["Yarra Valley"], "great-southern": ["Great Southern"],
    "tierra-de-leon": ["León"], "tejo": ["DoTejo"], "lisboa": ["Lisboa"], "samos": ["Σάμος"], "paros": ["Πάρος"], "rhodes": ["Ρόδος"], "limnos": ["Λήμνος"], "zitsa": ["Ζίτσα"], "barbera-dasti": ["Barbera d'Asti"], "moscato-dasti": ["Asti"],
}
def _pdo_index():
    global _PDO
    if _PDO is not None: return _PDO
    _PDO = {}
    gj = os.path.join(PDO_DIR, "pdo_all.geojson")
    if not os.path.exists(gj): return _PDO
    import csv
    names = {r["PDOid"]: r["PDOnam"] for r in csv.DictReader(open(os.path.join(PDO_DIR, "PDO_EU_id.csv"), encoding="utf-8-sig"))}
    for f in json.load(open(gj))["features"]:
        pid = f["properties"]["PDOid"]
        nm = names.get(pid)
        if not nm or not f["geometry"]: continue
        g = shape(f["geometry"]).buffer(0)
        if pid.startswith("PDO-HU-"):   # Hungary's districts are lists of scattered communes: close the gaps between them
            g = g.buffer(0.045, 6).buffer(-0.04, 6)
        for part in nm.split("/"):
            _PDO.setdefault(pkey(part.strip()), []).append((pid, nm, g))
    # Australian GIs (and other non-EU regions) from github.com/adynak/WineRegions (CC0)
    import glob as _glob
    for country in ("Australia", "Argentina"):
        for fp in _glob.glob(os.path.join(GEO, "ext", "WineRegions", country, "**", "*.geojson"), recursive=True):
            nm = os.path.basename(fp)[:-8].replace("_", " ")
            try:
                gs = [shape(f["geometry"]).buffer(0) for f in json.load(open(fp))["features"] if f.get("geometry")]
            except Exception:
                continue
            if gs:
                _PDO.setdefault(pkey(nm), []).append((f"{country}:{nm}", nm, unary_union(gs)))
    return _PDO
def pkey(t):
    return norm(t) or " ".join(t.lower().split())
USED_PDO = []
PDO_SKIP = {"es-la-rioja"}  # admin-region containers that share a name with an appellation
def pdo_geom(aid, name, geom_ll):
    """Official boundary for an area whose name matches a PDO that overlaps our approximate shape."""
    idx = _pdo_index()
    if not idx or geom_ll is None or geom_ll.is_empty or aid in PDO_SKIP: return None
    keys = [pkey(n) for n in PDO_ALIAS.get(aid, [])] + [pkey(name), pkey(aid.replace("-", " "))]
    best, score = None, 0.0
    for k in keys:
        for pid, nm, g in idx.get(k, []):
            if not g.intersects(geom_ll): continue
            inter = g.intersection(geom_ll).area
            sc = inter / max(1e-12, min(g.area, geom_ll.area))
            if sc > score: best, score = (pid, nm, g), sc
    if best and score > 0.2:
        USED_PDO.append((aid, best[0], best[1]))
        return best[2]
    return None

def area_record(pr, aid, name, lv, color, geom_ll, tol, label=None, parent=None, grapes=None, min_area=4, soft=False, pdo=True):
    off = pdo_geom(aid, name, geom_ll) if pdo else None
    if off is not None:
        geom_ll = off
    # keep areas on their map (e.g. a same-named municipality on an island far away)
    la0, lo0, la1, lo1 = pr.bbox
    geom_ll = geom_ll.intersection(box(lo0 - 0.5, la0 - 0.5, lo1 + 0.5, la1 + 0.5))
    _GEOMS[(id(pr), aid)] = (geom_ll, color, lv)
    g = pr.geom(geom_ll)
    if soft: g = soften(g, tol)
    shapes = enc_polys(g, tol, min_area, smooth=True)
    if not shapes: return None
    cx, cy = label_point(max(polys_of(g.simplify(tol * RES)), key=lambda p: p.area))
    rec = {"id": aid, "name": name, "lv": lv, "c": color, "shapes": shapes, "cx": round(cx), "cy": round(cy)}
    try:   # where it is on the earth (for the Journal's world map): a point inside its biggest piece, as lat/lon
        big = max(polys_of(geom_ll), key=lambda p: p.area).representative_point()
        rec["ll"] = [round(big.y, 3), round(big.x, 3)]
    except ValueError:
        pass
    if label:
        lx, ly = pr.xy(label[1], label[0])
        rec["lx"], rec["ly"] = round(lx), round(ly)
    if parent: rec["parent"] = parent
    if grapes: rec["g"] = grapes
    if getattr(pr, "K", 1) > 1: rec["k"] = pr.K
    return rec

def commune_layer(pr, named_geoms, tol, minz=3.0):
    """Hairline outlines and names of communes (shown when zoomed in)."""
    lines, names = [], []
    for n, g in named_geoms:
        pg = pr.geom(g)
        for p in polys_of(pg.simplify(tol * RES)):
            f = flat(chaikin(list(p.exterior.coords)))
            if len(f) >= 6: lines.append(f)
        x, y = label_point(pg)
        x0, y0, x1, y1 = pg.bounds
        # size of the commune, so the app only writes its name when the name fits inside it
        names.append({"n": n, "x": round(x), "y": round(y), "w": round(x1 - x0), "h": round(y1 - y0), "a": round(pg.area)})
    return lines, names

def write(mid, data):
    path = os.path.join(OUT, mid + ".json")
    with open(path, "w") as f:
        json.dump(data, f, separators=(",", ":"), ensure_ascii=False)
    n = len(data.get("areas", []))
    print(f"  {mid:18s} {data['w']}x{data['h']} areas {n:3d}  {os.path.getsize(path)//1024} KB")

def cities_of(pr, cities):
    out = []
    for c in cities:
        name, lat, lon = c[:3]
        rank = c[3] if len(c) > 3 else 1
        x, y = pr.xy(lon, lat)
        out.append({"n": name, "x": round(x), "y": round(y), "r": rank})
    return out

def labels_of(pr, labels):
    out = []
    for t, lat, lon, kind in labels:
        x, y = pr.xy(lon, lat)
        out.append({"t": t, "x": round(x), "y": round(y), "k": kind})
    return out

def doc(mid, title, pr, land, focus, lk, rv, areas, cities=(), labels=(), borders=(), communes=None, extra=None):
    d = {"v": 2, "id": mid, "title": title, "w": pr.W, "h": pr.H, "land": land, "focus": focus, "lakes": lk,
         "rivers": rv, "borders": list(borders), "areas": [a for a in areas if a], "cities": list(cities), "labels": list(labels)}
    if communes:
        d["communes"] = communes[0]
        d["villages"] = communes[1]
    if extra: d.update(extra)
    return d


def fine_inset(pr, pf, bbox, water, estuary, specs, res, tol, K):
    """Detailed coast, water, rivers and commune lines of one wine region, K times finer than the France map."""
    land, focus, lk, rv = base_layers(pf, bbox, ["FRA"], tol=tol, pad=0.02)
    _depts = sorted({d for s in specs for d in s["depts"]})
    lk = lk + water_polys(pf, water, estuary, tol, geoms=[gg for d in _depts for _, gg in fr_communes(d)])
    allnames = set()
    for s in specs:
        if s["id"] in res: allnames.update(res[s["id"]][1])
    named = [(n, gg) for d in _depts for n, gg in fr_communes(d) if n in allnames]
    lines, names = commune_layer(pf, named, tol)   # commune lines as fine line work, and the names (drawn only where they fit)
    la0, lo0, la1, lo1 = bbox
    x0, y0 = pr.xy(lo0, la1); x1, y1 = pr.xy(lo1, la0)
    return {"k": K, "box": [round(x0), round(y0), round(x1), round(y1)], "land": land, "focus": focus, "lakes": lk,
            "rivers": rv, "communes": lines, "villages": names}

# ================================================================= FRANCE
def build_france():
    print("France…")
    for grp in (FR.BORDEAUX, FR.BURGUNDY, FR.RHONE, FR.LOIRE, FR.CHAMPAGNE, FR.OTHER):
        for a in grp:
            seen = []
            for c in a["communes"]:
                if c not in seen: seen.append(c)
            a["communes"] = seen
    # fix renamed / merged communes
    renames = {"Blaignan-Prignac": "Blaignan", "Ingrandes-de-Touraine": "Coteaux-sur-Loire", "Saint-Patrice": "Coteaux-sur-Loire"}
    for grp in (FR.BORDEAUX, FR.BURGUNDY, FR.RHONE, FR.LOIRE):
        for a in grp:
            a["communes"] = [renames.get(c, c) for c in a["communes"] if c not in ("Fyé", "Milly")]
            a["communes"] = list(dict.fromkeys(a["communes"]))

    groups = {"bordeaux": FR.BORDEAUX, "burgundy": [a for a in FR.BURGUNDY], "rhone": FR.RHONE, "loire": FR.LOIRE,
              "champagne": FR.CHAMPAGNE}
    resolved = {}
    for gname, specs in groups.items():
        used = {}
        r = resolve(specs, fr_pool, used)
        # parents without their own selection = union of children
        for s in specs:
            if s["id"] not in r:
                kids = [r[k["id"]][0] for k in specs if k.get("parent") == s["id"] and k["id"] in r]
                if kids:
                    r[s["id"]] = (unary_union(kids), sum([r[k["id"]][1] for k in specs if k.get("parent") == s["id"] and k["id"] in r], []))
        resolved[gname] = r
    other = resolve([a for a in FR.OTHER if a["within"]], fr_pool, {})
    sw = []
    for patch in FR.SOUTHWEST_PATCHES:
        poly = prep(Polygon([(lon, lat) for lat, lon in patch]))
        for d in ["24", "46", "47", "81", "32", "64", "65", "82"]:
            for n, g in fr_communes(d):
                if poly.contains(g.representative_point()): sw.append(g)
    other["southwest"] = (unary_union([g.buffer(0) for g in sw]), [])

    deps = [shape(f["geometry"]) for f in load(f"{GEO}/fr/departements-full.geojson")]

    # ---- country map
    bbox = (41.3, -5.3, 51.2, 9.8)
    pr = Proj(bbox, 7000)   # fine enough for village appellations when zoomed in
    tol = 1.0
    land, focus, lk, rv = base_layers(pr, bbox, ["FRA"], tol=tol)
    areas = []
    top = {"bordeaux": ("Bordeaux", "plum", (44.2, -2.6), "Bordeaux blends · Sauvignon · Sémillon"),
           "burgundy": ("Burgundy", "magenta", (47.6, 6.1), "Pinot Noir · Chardonnay"),
           "rhone": ("Rhône Valley", "claret", (44.9, 5.95), "Syrah · Grenache · Viognier"),
           "loire": ("Loire Valley", "green", (48.05, -0.4), "Chenin · Sauvignon · Cab Franc"),
           "champagne": ("Champagne", "violet", (49.65, 4.9), "Chardonnay · Pinot Noir · Meunier")}
    # Bordeaux and Burgundy are drawn from the detailed maps: the same geometry, K times finer, sitting inside the France map.
    K = 4
    FINE = {"bordeaux": dict(bbox=(44.40, -1.35, 45.62, 0.35), water=[("Garonne", 0.14, 0.55), ("Dordogne", 0.14, 0.55)],
                             estuary=(-0.95, 44.98, -0.5, 45.62)),
            "burgundy": dict(bbox=(45.95, 3.45, 48.0, 5.45), water=[("Saône", 0.12, 0.16)], estuary=None),
            "rhone": dict(bbox=(43.75, 4.15, 45.65, 5.5), water=[("Rhône", 0.18, 0.22)], estuary=None),
            "loire": dict(bbox=(46.75, -2.2, 47.85, 3.2), water=[("Loire", 0.12, 0.3)], estuary=None),
            "champagne": dict(bbox=(47.85, 3.2, 49.45, 4.95), water=[("Marne", 0.08, 0.1)], estuary=None)}
    prs = {g: FineProj(pr, K, f["bbox"]) for g, f in FINE.items()}
    tolf = 0.9
    def P(g): return (prs[g], tolf) if g in prs else (pr, tol)
    def note(g, aid):
        if g in prs and (id(prs[g]), aid) in _GEOMS: _GEOMS[(id(pr), aid)] = _GEOMS[(id(prs[g]), aid)]
    insets = []
    for g, (name, col, lab, grapes) in top.items():
        specs = groups[g]
        pg, tg = P(g)
        geoms = [resolved[g][s["id"]][0] for s in specs if s["lv"] <= 1 and s["id"] in resolved[g] and s["id"] != "beaujolais"
                 and not s.get("parent")]
        areas.append(area_record(pg, g, name, 0, cidx(col), unary_union(geoms), tg, label=lab, grapes=grapes))
        note(g, g)
        for s in specs:
            if s["lv"] == 1 and s["id"] in resolved[g]:
                areas.append(area_record(pg, s["id"], s["name"], 1, cidx(col), resolved[g][s["id"]][0], tg, parent=g, grapes=s.get("grapes")))
        # the appellations inside each zone (Pauillac in the Haut-Médoc, Gevrey-Chambertin in the Côte de Nuits…)
        for s in specs:
            if s["lv"] == 2 and s["id"] in resolved[g] and s.get("parent") in resolved[g]:
                areas.append(area_record(pg, s["id"], s["name"], 2, cidx(s.get("color") or col), resolved[g][s["id"]][0], tg,
                                         parent=s["parent"], grapes=s.get("grapes"), min_area=1))
        if g in prs:
            f = FINE[g]
            insets.append(fine_inset(pr, pg, f["bbox"], f["water"], f["estuary"], specs, resolved[g], tg, K))
    bj = resolved["burgundy"].get("beaujolais")
    if bj: areas.append(area_record(pr, "beaujolais", "Beaujolais", 0, cidx("rose"), bj[0], tol, label=(45.85, 3.6), grapes="Gamay"))
    for s in FR.OTHER:
        if s["id"] in other:
            areas.append(area_record(pr, s["id"], s["name"], 0, cidx(s["color"]), other[s["id"]][0], tol, label=s["label"], grapes=s["grapes"]))
    borders = admin_borders(pr, bbox, deps, tol * 1.5)
    fr_tints = tints(pr, deps, tol, areas)
    cities = cities_of(pr, [("Paris", 48.857, 2.352, 0), ("Bordeaux", 44.84, -0.58, 0), ("Lyon", 45.76, 4.84, 0),
        ("Reims", 49.26, 4.03), ("Dijon", 47.32, 5.04), ("Strasbourg", 48.57, 7.75), ("Tours", 47.39, 0.69),
        ("Marseille", 43.30, 5.37, 0), ("Nantes", 47.22, -1.55), ("Montpellier", 43.61, 3.88), ("Toulouse", 43.60, 1.44, 0),
        ("Avignon", 43.95, 4.81), ("Nice", 43.70, 7.27)])
    labels = labels_of(pr, [("Atlantic Ocean", 46.2, -3.9, "sea"), ("Mediterranean Sea", 42.4, 5.6, "sea"),
                            ("English Channel", 50.2, -2.3, "sea"), ("Loire", 47.55, 0.15, "river"), ("Rhône", 44.55, 4.55, "river"),
                            ("Garonne", 44.2, 0.4, "river"), ("SPAIN", 42.2, -1.5, "area"), ("ITALY", 44.9, 8.6, "area"),
                            ("GERMANY", 50.3, 8.4, "area"), ("SWITZ.", 46.8, 7.7, "area")])
    write("france", doc("france", "France", pr, land, focus, lk, rv, areas, cities, labels, borders,
                        extra={"tints": fr_tints, "insets": insets, "lod": [1.9, 3.4]}))

    # ---- regional detail maps
    def detail(mid, title, g, bbox, W, sublv2_from_children=True, cities=(), labels=(), extra_specs=(), water=(), estuary=None):
        pr = Proj(bbox, W)
        tol = 0.9
        land, focus, lk, rv = base_layers(pr, bbox, ["FRA"], tol=tol)
        specs = list(groups[g]) + list(extra_specs)
        _depts = sorted({d for s in specs for d in s["depts"]})
        lk = lk + water_polys(pr, water, estuary, tol, geoms=[gg for d in _depts for _, gg in fr_communes(d)])
        r = dict(resolved[g])
        areas = []
        allnames = set()
        for s in specs:
            if s["id"] not in r: continue
            lv = 0 if s["lv"] <= 1 and not s.get("parent") else 1
            col = cidx(s["color"]) if s.get("color") else None
            if col is None:
                par = next((p for p in specs if p["id"] == s.get("parent")), None)
                col = cidx(par["color"]) if par and par.get("color") else 0
            areas.append(area_record(pr, s["id"], s["name"], lv, col, r[s["id"]][0], tol, label=s.get("label"),
                                     parent=s.get("parent"), grapes=s.get("grapes"), min_area=2))
            allnames.update(r[s["id"]][1])
        named = [(n, gg) for d in sorted({d for s in specs for d in s["depts"]}) for n, gg in fr_communes(d) if n in allnames]
        lay = commune_layer(pr, named, tol)
        areas.sort(key=lambda a: (a["lv"], -sum(len(s) for s in a["shapes"])) if a else (9, 0))
        write(mid, doc(mid, title, pr, land, focus, lk, rv, areas, cities_of(pr, cities), labels_of(pr, labels),
                       admin_borders(pr, bbox, deps, tol * 1.5), communes=lay))


# ================================================================= ITALY
def add_pdo_children(pr, areas, cc, tol, min_area=0.04, skip=(), max_n=60):
    """Official denominations of a country that the hand-built map lacks: added as level 1 under the big region they sit in."""
    idx = _pdo_index()
    skipn = {pkey(x) for x in skip}
    seen, cand = set(), []
    for lst in idx.values():
        for pid, nm, g in lst:
            if pid in seen or not pid.startswith(f"PDO-{cc}-"): continue
            seen.add(pid); cand.append((pid, nm, g))
    areas[:] = [a for a in areas if a]
    have = {pkey(a["name"]) for a in areas}
    existing = [(a["id"], _GEOMS[(id(pr), a["id"])][0], a["lv"], a["c"]) for a in areas if (id(pr), a["id"]) in _GEOMS]
    top = [e for e in existing if e[2] == 0]
    added = 0
    for pid, nm, pg in sorted(cand, key=lambda c: -c[2].area):
        if added >= max_n: break
        disp = nm.split(" / ")[0].strip()
        if pg.area < min_area or pkey(disp) in skipn or pkey(disp) in have: continue
        if any(pkey(part.strip()) in have for part in nm.split("/")): continue
        if any(g2.intersection(pg).area / max(1e-12, g2.union(pg).area) > 0.8 for _, g2, _, _ in existing if True): continue
        par = max(top, key=lambda e: e[1].intersection(pg).area, default=None)
        if not par or par[1].intersection(pg).area / pg.area < 0.5: continue
        rid = re.sub(r"[^a-z0-9]+", "-", norm(disp).replace(" ", "-")).strip("-")
        if any(a["id"] == rid for a in areas): rid += "-" + cc.lower()
        rec = area_record(pr, rid, disp, 1, par[3], pg, tol, parent=par[0], min_area=1, soft=True, pdo=False)
        if rec:
            areas.append(rec); existing.append((rid, pg, 1, par[3])); have.add(pkey(disp)); added += 1
            print(f"   + {cc}: {disp} (in {par[0]})")

def build_italy():
    print("Italy…")
    ita_regions = [shape(f["geometry"]) for f in admin1 if f["properties"]["adm0_a3"] == "ITA"]
    bbox = (36.5, 6.5, 47.2, 18.7)
    pr = Proj(bbox, 6000)   # fine enough for the Barolo and Chianti villages
    tol = 0.6
    land, focus, lk, rv = base_layers(pr, bbox, ["ITA"], tol=tol)
    areas = []
    for z in WD.ITALY:
        pool = it_comuni(z["reg"])
        geoms = []
        for poly in z["polys"]:
            pp = prep(Polygon([(lon, lat) for lat, lon in poly]))
            geoms += [g for n, g in pool if pp.contains(g.representative_point())]
        if not geoms:
            print("   ! empty", z["id"]); continue
        areas.append(area_record(pr, z["id"], z["name"], 0, cidx(z["color"]), unary_union([g.buffer(0) for g in geoms]), tol,
                                 label=z["label"], grapes=z["grapes"]))
    # zoom detail: DOCGs of Piedmont and Tuscany
    for specs, par in ((WD.PIEDMONT, "piedmont"), (WD.TUSCANY, "tuscany")):
        r = resolve(specs, it_pool, {})
        for s in specs:
            if s["id"] in r:
                areas.append(area_record(pr, s["id"], s["name"], 1, cidx(s["color"]), r[s["id"]][0], tol, parent=par, grapes=s.get("grapes")))
        # one step further: the villages of Barolo, Barbaresco and Chianti Classico
        reg = "Piemonte" if par == "piedmont" else "Toscana"
        for parent in ("barolo", "barbaresco", "chianti-classico"):
            ps = next((s for s in specs if s["id"] == parent), None)
            if not ps or parent not in r: continue
            want = {norm(c) for c in ps["communes"]}
            for n, g in it_comuni(reg):
                if norm(n) in want:
                    vid = slug(n) if slug(n) != parent else slug(n) + "-village"
                    areas.append(area_record(pr, vid, n + (" (village)" if vid != slug(n) else ""), 2, cidx(ps["color"]), g, tol,
                                             parent=parent, min_area=1))
    add_pdo_children(pr, areas, "IT", tol, min_area=0.05, max_n=70, skip=[
        "Vin Santo del Chianti Classico", "Primitivo di Manduria Dolce Naturale", "Verdicchio di Matelica Riserva", "Valtellina rosso", "Nebbiolo d'Alba",
        "Dolcetto d'Alba", "Dolcetto d'Acqui", "Grignolino del Monferrato Casalese", "Grignolino d'Asti", "Cortese dell'Alto Monferrato",
        "Oltrepò Pavese metodo classico", "Colli Orientali del Friuli Picolit", "Montepulciano d'Abruzzo Colline Teramane", "Colli Asolani - Prosecco",
        "Val d'Arno di Sopra", "Grance Senesi", "Monteregio di Massa Marittima", "Esino", "Gravina", "Squinzano", "Moscato di Trani", "Delia Nivolelli",
        "Erice", "Menfi", "Colli di Faenza", "Colli d'Imola", "Colli di Scandiano e di Canossa", "Colli Romagna centrale", "Modena", "Reggiano",
        "Collina Torinese", "Rosso Orvietano", "Spoleto", "Colli Martani", "Lessini Durello", "Casteller", "Valdadige", "Alba", "Val d'Arbia",
        "Lambrusco Salamino di Santa Croce", "Lambrusco Grasparossa di Castelvetro", "Cerasuolo di Vittoria"])
    cities = cities_of(pr, [("Rome", 41.9, 12.5, 0), ("Milan", 45.46, 9.19, 0), ("Turin", 45.07, 7.69), ("Florence", 43.77, 11.25, 0),
        ("Venice", 45.44, 12.33, 0), ("Naples", 40.85, 14.27, 0), ("Verona", 45.44, 10.99), ("Palermo", 38.12, 13.36),
        ("Bologna", 44.49, 11.34), ("Bari", 41.12, 16.87)])
    labels = labels_of(pr, [("Tyrrhenian Sea", 40.0, 11.8, "sea"), ("Adriatic Sea", 43.0, 15.4, "sea"), ("Ionian Sea", 38.0, 18.0, "sea"),
                            ("Po", 45.08, 10.5, "river")])
    ita_prov = [shape(f["geometry"]) for f in admin1 if f["properties"]["adm0_a3"] == "ITA"]
    write("italy", doc("italy", "Italy", pr, land, focus, lk, rv, areas, cities, labels, admin_borders(pr, bbox, ita_regions, tol * 1.5),
                       extra={"tints": tints(pr, ita_prov, tol, areas)}))

    def detail(mid, title, specs, bbox, cities, labels, reg, water=()):
        pr = Proj(bbox, 3000)
        tol = 0.55
        land, focus, lk, rv = base_layers(pr, bbox, ["ITA"], tol=tol)
        lk = lk + water_polys(pr, water, None, tol, geoms=[gg for _, gg in it_comuni(reg)])
        r = resolve(specs, it_pool, {})
        areas, names = [], set()
        for s in specs:
            if s["id"] in r:
                areas.append(area_record(pr, s["id"], s["name"], 0, cidx(s["color"]), r[s["id"]][0], tol, label=s.get("label"),
                                         grapes=s.get("grapes"), min_area=2))
                names.update(r[s["id"]][1])
        # Barolo / Chianti Classico villages as level 1
        for parent in ("barolo", "chianti-classico", "barbaresco"):
            ps = next((s for s in specs if s["id"] == parent), None)
            if not ps: continue
            for n, g in it_comuni(reg):
                if norm(n) in {norm(c) for c in ps["communes"]}:
                    # a village named like its zone (Barolo, Barbaresco) gets its own id, or it would hide the zone
                    vid = slug(n) if slug(n) != parent else slug(n) + "-village"
                    areas.append(area_record(pr, vid, n + (" (village)" if vid != slug(n) else ""), 1, cidx(ps["color"]), g, tol,
                                             parent=parent, min_area=2))
        areas.sort(key=lambda a: (a["lv"], -sum(len(s) for s in a["shapes"])))
        named = [(n, g) for n, g in it_comuni(reg) if n in names]
        lay = commune_layer(pr, named, tol)
        write(mid, doc(mid, title, pr, land, focus, lk, rv, areas, cities_of(pr, cities), labels_of(pr, labels),
                       communes=lay))
    detail("piedmont", "Piedmont", WD.PIEDMONT, (44.35, 7.55, 45.12, 9.05),
           [("Alba", 44.70, 8.035, 0), ("Asti", 44.90, 8.21, 0), ("Bra", 44.70, 7.85), ("Novi Ligure", 44.76, 8.79), ("Acqui Terme", 44.68, 8.47)],
           [("Tanaro", 44.83, 8.42, "river"), ("LANGHE", 44.55, 8.12, "area"), ("MONFERRATO", 45.0, 8.45, "area")], "Piemonte",
           water=[("Tanaro", 0.08, 0.12), ("Po", 0.12, 0.16)])
    detail("tuscany", "Tuscany", WD.TUSCANY, (42.3, 10.0, 44.1, 12.3),
           [("Florence", 43.77, 11.25, 0), ("Siena", 43.32, 11.33, 0), ("Pisa", 43.72, 10.40), ("Livorno", 43.55, 10.31), ("Grosseto", 42.76, 11.11),
            ("Arezzo", 43.46, 11.88)],
           [("Tyrrhenian Sea", 42.7, 10.35, "sea"), ("Arno", 43.72, 10.75, "river")], "Toscana",
           water=[("Arno", 0.08, 0.14)])

# ================================================================= USA (AVAs)
def build_usa():
    print("USA…")
    av = avas()
    states = [shape(f["geometry"]) for f in admin1 if f["properties"]["adm0_a3"] == "USA"]

    def ava_map(mid, title, tops, bbox, W, cities, labels, child_levels=1):
        pr = Proj(bbox, W)
        tol = 0.55
        land, focus, lk, rv = base_layers(pr, bbox, ["USA"], tol=tol)
        areas, ids = [], set()
        for i, (name, aid, col) in enumerate(tops):
            f = av.get(name)
            if not f: print("   ! AVA missing", name); continue
            areas.append(area_record(pr, aid, name, 0, cidx(col, i), shape(f["geometry"]).buffer(0), tol,
                                     grapes=None, min_area=2))
            ids.add(aid)
            if child_levels and f["properties"].get("contains"):
                for cn in f["properties"]["contains"].split("|"):
                    cf = av.get(cn.strip())
                    if not cf: continue
                    cid = WD.AVA_IDS.get(cn.strip(), slug(cn))
                    if cid in ids: continue
                    ids.add(cid)
                    areas.append(area_record(pr, cid, cn.strip(), 1, cidx(col, i), shape(cf["geometry"]).buffer(0), tol,
                                             parent=aid, min_area=1))
        areas = [a for a in areas if a]
        areas.sort(key=lambda a: (a["lv"], -sum(len(s) for s in a["shapes"])))
        write(mid, doc(mid, title, pr, land, focus, lk, rv, areas, cities_of(pr, cities), labels_of(pr, labels),
                       admin_borders(pr, bbox, states, tol * 2)))

    ava_map("california", "California", WD.CALIFORNIA, (32.4, -124.6, 42.1, -114.0), 3000,
            [("San Francisco", 37.77, -122.42, 0), ("Los Angeles", 34.05, -118.24, 0), ("Sacramento", 38.58, -121.49),
             ("San Diego", 32.72, -117.16), ("Fresno", 36.74, -119.79), ("Santa Barbara", 34.42, -119.70), ("Paso Robles", 35.63, -120.69)],
            [("Pacific Ocean", 35.0, -123.6, "sea"), ("NEVADA", 39.3, -116.8, "area")])
    ava_map("napa-sonoma", "Napa & Sonoma", WD.NAPA_SONOMA, (38.08, -123.3, 38.92, -122.1), 3000,
            [("Napa", 38.30, -122.29, 0), ("Sonoma", 38.29, -122.46), ("Healdsburg", 38.61, -122.87), ("Santa Rosa", 38.44, -122.71, 0),
             ("Calistoga", 38.58, -122.58), ("St. Helena", 38.505, -122.47), ("Yountville", 38.40, -122.36)],
            [("Pacific Ocean", 38.3, -123.2, "sea"), ("San Pablo Bay", 38.08, -122.38, "sea")])
    ava_map("pacific-northwest", "Oregon & Washington", WD.NORTHWEST, (41.9, -124.8, 49.1, -116.4), 3000,
            [("Seattle", 47.61, -122.33, 0), ("Portland", 45.52, -122.68, 0), ("Walla Walla", 46.06, -118.34), ("Yakima", 46.60, -120.51),
             ("Eugene", 44.05, -123.09), ("Medford", 42.33, -122.87)],
            [("Pacific Ocean", 45.5, -124.4, "sea"), ("Columbia", 45.7, -121.0, "river"), ("WASHINGTON", 47.8, -120.2, "area"),
             ("OREGON", 43.8, -120.3, "area")])

# ================================================================= admin-boundary countries (geoBoundaries)
import specs_gb as GB
_gb = {}
def gb_units(iso, adm):
    k = (iso, adm)
    if k not in _gb:
        def fx(n):
            try: return n.encode("latin1").decode("utf8")
            except Exception: return n
        _gb[k] = [(fx(f["properties"]["shapeName"]), shape(f["geometry"]).buffer(0)) for f in load(f"{GEO}/gb/{iso}-{adm}.geojson")]
    return _gb[k]

def km2deg(km): return km / 111.0

def soften(g, tol):
    """Pull a region slightly in from its admin edges and round it off, so it reads as a drawn area."""
    if g.is_empty: return g
    d = min(tol * RES * 2.2, math.sqrt(max(g.area, 1)) * 0.035)
    out = g.buffer(d * 0.6, join_style=1).buffer(-d * 1.6, join_style=1).buffer(d * 0.7, join_style=1)
    return out if not out.is_empty and out.area > g.area * 0.35 else g

# admin level used for the light province tints, per country
TINT_ADM = {"ESP": "ADM2", "PRT": "ADM1", "DEU": "ADM3", "AUT": "ADM2", "HUN": "ADM2", "GRC": "ADM2", "CHL": "ADM2",
            "ARG": "ADM2", "AUS": "ADM2", "NZL": "ADM2", "ZAF": "ADM3", "LBN": "ADM2"}

def build_gb(only=None):
    print("admin-boundary countries…")
    legacy = {m["id"]: m for m in LEGACY}
    for mid, cfg in GB.COUNTRIES.items():
        if only and mid not in only: continue
        spec = legacy[mid]
        isos = cfg["iso"] if isinstance(cfg["iso"], list) else [cfg["iso"]]
        W, tol = 3000, 0.5
        pr = Proj(spec["bbox"], W)
        land, focus, lk, rv = base_layers(pr, spec["bbox"], spec["focus"], tol=tol)
        if mid == "spain":   # the Canary Islands are not on this map: they stretched the country's frame in the Atlas thumbnails
            ycut = pr.xy(-9, 34.8)[1]
            focus = [f for f in focus if min(f[1::2]) < ycut]
            land = [f for f in land if min(f[1::2]) < ycut]
        sketches = {r["id"]: unary_union([Polygon(shape_latlon(s)).buffer(0) for s in r["shapes"]]) for r in spec["regions"]}
        geoms = {}
        for r in spec["regions"]:
            rid = r["id"]
            rs = cfg["regions"].get(rid)
            sk = sketches[rid]
            if rs is None:
                print(f"   ! {mid}/{rid}: no spec, keeping sketch"); geoms[rid] = sk; continue
            adm = rs["adm"]
            iso = isos[0]
            if "/" in adm: iso, adm = adm.split("/")
            units = gb_units(iso, adm)
            if rs["mode"] == "units":
                near = sk.buffer(km2deg(90))
                picked, missing = [], []
                for n in rs["names"]:
                    c = [g for nm, g in units if nm == n and g.intersects(near)]
                    if not c: missing.append(n)
                    picked += c
                if missing: print(f"   ! {mid}/{rid}: missing {missing}")
                g = unary_union(picked) if picked else sk
                if rs["clip"] is not None:
                    g = g.intersection(sk.buffer(km2deg(rs["clip"]))) if rs["clip"] > 0 else g.intersection(sk)
            else:
                zone = sk.buffer(km2deg(rs["km"])) if rs["km"] else sk
                zp = prep(zone)
                picked = [g for nm, g in units if zp.contains(g.representative_point())]
                if not picked:
                    picked = [g for nm, g in units if zp.intersects(g)]
                g = unary_union(picked) if picked else sk
            geoms[rid] = g
        for r in spec["regions"]:
            for m in cfg["regions"].get(r["id"], {}).get("minus", []):
                geoms[r["id"]] = geoms[r["id"]].difference(geoms[m].buffer(km2deg(0.5)))
        names = {r["id"]: r["name"] for r in spec["regions"]}
        small = {r["id"]: r["small"] for r in spec["regions"]}

        # ---- atlas hierarchy: big regions (level 0) with the appellations inside (level 1)
        H = GB.HIERARCHY.get(mid, {})
        def iso_adm(adm):
            return adm.split("/") if "/" in adm else (isos[0], adm)
        def units_union(gs):
            iso, adm = iso_adm(gs["adm"])
            pool = gb_units(iso, adm)
            got, miss = [], []
            for n in gs["names"]:
                c = [g for nm, g in pool if nm == n]
                if not c: miss.append(n)
                got += c
            if miss: print(f"   ! {mid}: missing {miss}")
            return unary_union(got) if got else None
        def blob_geom(b):
            iso, adm = iso_adm(b["adm"] or H.get("snap", "ADM3"))
            zone = Polygon(shape_latlon({"t": "blob", "c": b["c"], "r": (b["r"], b["r"]), "a": 0})).buffer(0)
            zp = prep(zone)
            picked = [g for _, g in gb_units(iso, adm) if zp.contains(g.representative_point())]
            g = unary_union(picked).intersection(zone.buffer(km2deg(b["r"] * 0.35))) if picked else zone
            for m in b.get("minus", []):
                if m in geoms: g = g.difference(geoms[m].buffer(km2deg(0.3)))
            return g
        def geom_of(x):
            return blob_geom(x) if "c" in x else units_union(x)

        groups = []   # (id, name, geom)
        for gid, (gname, gs) in H.get("groups", {}).items():
            g = geom_of(gs)
            if g is not None and not g.is_empty: groups.append((gid, gname, g))
        lv0_extra = []
        for gid, (gname, gs) in H.get("extra0", {}).items():
            g = geom_of(gs)
            if g is not None and not g.is_empty: lv0_extra.append((gid, gname, g))
        for d in H.get("drop", []):
            geoms.pop(d, None)
        children = []   # (id, name, geom, parent or None)
        for rid, g in geoms.items():
            children.append((rid, names.get(rid, rid), g, None))
        for rid, b in H.get("extra", {}).items():
            if rid in H.get("drop_extra", []): continue
            children.append((rid, b["name"], blob_geom(b), None))
        for rid, (n, gs) in H.get("units1", {}).items():
            g = units_union(gs)
            if g is not None: children.append((rid, n, g, None))
        subs = []
        for rid, (n, par, gs) in H.get("subs", {}).items():
            g = geom_of(gs)
            if g is not None: subs.append((rid, n, g, par))
        for rid, (n, par, b) in H.get("extra1", {}).items():
            subs.append((rid, n, blob_geom(b), par))

        # ---- every other official denomination of the country (PDO boundaries): level 1, or level 2 when inside one we have
        pa = H.get("pdo_auto")
        if pa:
            cc = pa["cc"]
            skipn = {pkey(x) for x in pa.get("skip", [])}
            minarea = pa.get("min", 0.004)
            idx = _pdo_index()
            seen_pid, cand = set(), []
            for lst in idx.values():
                for pid, nm, g in lst:
                    if pid in seen_pid or not pid.startswith(pa.get("prefix", f"PDO-{cc}-")): continue
                    seen_pid.add(pid); cand.append((pid, nm, g))
            used, usedgeom = set(), []
            pgeom = {pid: pg for pid, nm, pg in cand}
            for rid, n, g, _ in children + [(a, b, c, None) for a, b, c, d in subs] + [(a, b, c, None) for a, b, c in groups + lv0_extra]:
                n0 = len(USED_PDO)
                pdo_geom(rid, n, g)
                if len(USED_PDO) > n0:
                    pid = USED_PDO[-1][1]; used.add(pid); usedgeom.append(pgeom.get(pid))
            usedgeom = [u for u in usedgeom if u is not None]
            existing = {rid: g for rid, n, g, _ in children}
            ids_taken = {rid for rid, *_ in children} | {x[0] for x in subs} | {gid for gid, *_ in groups}
            for pid, nm, pg in sorted(cand, key=lambda c: -c[2].area):
                disp = nm.split(" / ")[0].strip()
                if pid in used or pkey(disp) in skipn or pkey(nm) in skipn or pg.area < minarea: continue
                # the source repeats some boundaries under a second name (Manzanilla = Jerez): never draw the same shape twice
                if any(g2.intersection(pg).area / max(1e-12, g2.union(pg).area) > 0.9 for g2 in list(existing.values()) + usedgeom): continue
                rid = pa.get("ids", {}).get(disp) or re.sub(r"[^a-z0-9]+", "-", norm(disp).replace(" ", "-")).strip("-")
                if rid in ids_taken: rid += "-" + cc.lower()
                ids_taken.add(rid)
                inside = [(e, g2) for e, g2 in existing.items() if g2.area > pg.area and g2.intersection(pg).area / max(1e-12, pg.area) > 0.8]
                if inside:
                    par = min(inside, key=lambda x: x[1].area)[0]
                    subs.append((rid, disp, pg, par))
                else:
                    children.append((rid, disp, pg, None)); existing[rid] = pg
                print(f"   + {mid}: {disp} ({'in ' + par if inside else 'new'})")

        areas = []
        col = {}
        if groups:
            for i, (gid, gname, g) in enumerate(groups):
                col[gid] = cidx(None, i)
                areas.append(area_record(pr, gid, gname, 0, col[gid], g, tol, min_area=1, soft=True))
            allg = unary_union([gr[2] for gr in groups]).buffer(km2deg(2))
            for rid, n, g, _ in children:
                g = g.intersection(allg)
                if g.is_empty: continue
                best = max(groups, key=lambda gr: gr[2].intersection(g).area if gr[2].intersects(g) else 0)
                areas.append(area_record(pr, rid, n, 1, col[best[0]], g, tol, parent=best[0], min_area=1, soft=True))
        else:
            for i, (rid, n, g, _) in enumerate(children + [(a, b, c, None) for a, b, c in lv0_extra]):
                col[rid] = cidx(None, i)
                areas.append(area_record(pr, rid, n, 1 if small.get(rid) else 0, col[rid], g, tol, min_area=1, soft=True))
        for rid, n, g, par in subs:
            areas.append(area_record(pr, rid, n, 1, col.get(par, 0), g, tol, parent=par, min_area=1, soft=True))
        areas = [a for a in areas if a]
        areas.sort(key=lambda a: a["lv"])
        fb = [g for iso in isos for _, g in gb_units(iso, "ADM1")]
        tadm = [g for iso in isos for _, g in gb_units(iso, TINT_ADM.get(iso, "ADM2"))]
        cities = cities_of(pr, [(n, la, lo, 0 if i < 3 else 1) for i, (n, la, lo) in enumerate(spec["cities"])])
        write(mid, doc(mid, spec["title"], pr, land, focus, lk, rv, areas, cities, labels_of(pr, spec["labels"]),
                       admin_borders(pr, spec["bbox"], fb, tol * 1.5), extra=None if groups else {"tints": tints(pr, tadm, tol, areas)}))

def build_lebanon():
    L = GB.LEBANON
    print("Lebanon…")
    pr = Proj(L["bbox"], 2400, pad=0.04)
    tol = 0.5
    land, focus, lk, rv = base_layers(pr, L["bbox"], L["focus"], tol=tol)
    units = gb_units("LBN", "ADM2")
    areas = []
    gov = gb_units("LBN", "ADM1")
    big = {}
    for i, (rid, name, govs) in enumerate(L.get("regions0", [])):
        g = unary_union([u for n, u in gov if n in govs])
        big[rid] = g
        areas.append(area_record(pr, rid, name, 0, cidx(None, i + 3), g, tol, min_area=1))
    for i, (rid, name, cazas) in enumerate(L["regions"]):
        g = unary_union([u for n, u in units if n in cazas])
        km = L.get("zones", {}).get(rid)
        if km and L.get("wineries"):
            # vineyards only: soft zones around the wineries inside this region, clipped to it
            pts = [Point(lo, la) for _, la, lo in L["wineries"] if g.buffer(0.01).contains(Point(lo, la))]
            if pts:
                r = km / 100
                z = unary_union([p.buffer(r, 24) for p in pts]).buffer(r * 0.6).buffer(-r * 0.6)
                g = g.intersection(z)
        parent = max(big, key=lambda k: big[k].intersection(g).area) if big else None
        areas.append(area_record(pr, rid, name, 1 if big else 0, cidx(None, i), g, tol, min_area=1, soft=True, parent=parent))
    fb = [g for _, g in gb_units("LBN", "ADM1")]
    pois = []
    for n, la, lo in L.get("wineries", []):
        x, y = pr.xy(lo, la); pois.append({"n": n, "x": round(x), "y": round(y)})
    cities = cities_of(pr, [(n, la, lo, 0 if i < 2 else 1) for i, (n, la, lo) in enumerate(L["cities"])])
    write("lebanon", doc("lebanon", L["title"], pr, land, focus, lk, rv, areas, cities, labels_of(pr, L["labels"]),
                         admin_borders(pr, L["bbox"], fb, tol * 1.5), extra={"pois": pois}))

# ================================================================= legacy maps → v2 (blob shapes, bold palette)
def build_legacy(keep):
    print("other countries…")
    for spec in LEGACY:
        if spec["id"] not in keep: continue
        W = 3000 if not spec["world"] else 2400
        pr = Proj(spec["bbox"], W)
        tol = 1.2 if not spec["world"] else 1.4
        land, focus, lk, rv = base_layers(pr, spec["bbox"], spec["focus"], world=spec["world"], tol=tol)
        areas = []
        for i, r in enumerate(spec["regions"]):
            geoms = [Polygon(shape_latlon(s)) for s in r["shapes"]]
            g = unary_union([x.buffer(0) for x in geoms])
            areas.append(area_record(pr, r["id"], r["name"], 1 if r["small"] else 0, cidx(None, i), g, tol, min_area=1))
        fb = [shape(f["geometry"]) for f in admin1 if f["properties"]["adm0_a3"] in spec["focus"]] if not spec["world"] else []
        extra = None
        if spec["world"]:
            bands = []
            for a, b in ((30, 50), (-50, -30)):
                bands += [round(pr.xy(0, b)[1]), round(pr.xy(0, a)[1])]
            extra = {"belts": bands}
        cities = cities_of(pr, [(n, la, lo, 0 if i < 3 else 1) for i, (n, la, lo) in enumerate(spec["cities"])])
        write(spec["id"], doc(spec["id"], spec["title"], pr, land, focus, lk, rv, areas, cities, labels_of(pr, spec["labels"]),
                              admin_borders(pr, spec["bbox"], fb, tol * 1.5), extra=extra))

if __name__ == "__main__":
    which = set(sys.argv[1:])
    if not which or "fr" in which: build_france()
    if not which or "it" in which: build_italy()
    if not which or "us" in which: build_usa()
    if not which or "legacy" in which: build_legacy({"world"})
    if not which or "gb" in which: build_gb()
    if not which or "lb" in which: build_lebanon()
    if USED_PDO:
        print(f"official PDO boundaries used for {len(USED_PDO)} areas")
        with open(os.path.join(os.path.dirname(__file__), "pdo_used.txt"), "w") as f:
            f.write("\n".join(f"{a}\t{p}\t{n}" for a, p, n in USED_PDO))
