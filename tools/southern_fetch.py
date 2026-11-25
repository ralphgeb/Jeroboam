"""Runs on a GitHub runner (open network; this container cannot reach these hosts): source data for the Chile, Argentina,
New Zealand and South Africa maps. Writes everything into out/ (published to the `southern-data` branch).

  nz_gi/<slug>.geojson    official New Zealand wine GI boundaries (IPONZ register "Geodata ZIP", NZ Crown copyright, CC BY 4.0)
  osm_vineyards_<cc>.json landuse=vineyard polygons from OpenStreetMap (ODbL): [{"n": name, "r": [[lon,lat]...], "h": [holes]}]
  osm_wineries_<cc>.json  craft=winery / tourism=wine_cellar points (ODbL): [{"n": name, "ll": [lat, lon]}]
  osm_admin_ar.json       Argentine admin boundaries (levels 5-10) and place names in Mendoza/San Juan (districts)
  docs/*                  reference texts: Chile Decree 464, Argentina's IG/DOC list, SA Wine of Origin booklet, Wikipedia lists
Every step is independent: a failure is logged and the rest still runs."""
import json, os, re, sys, time, glob, zipfile, io, urllib.request, urllib.parse, traceback
OUT = "out"
os.makedirs(f"{OUT}/nz_gi", exist_ok=True); os.makedirs(f"{OUT}/docs", exist_ok=True)
LOG = open(f"{OUT}/log.txt", "w")
def log(*a):
    s = " ".join(str(x) for x in a); print(s); LOG.write(s + "\n"); LOG.flush()
UA = {"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) jero-map-build/1.0"}
def get(url, data=None, timeout=300, tries=3):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, data=data, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read()
        except Exception as e:
            log("  retry", url[:120], e); time.sleep(5 + 10 * i)
    return None
def step(fn):
    try: fn()
    except Exception: log("FAILED", fn.__name__, traceback.format_exc())

# ------------------------------------------------------------------ New Zealand GIs (IPONZ)
NZ_SLUGS = ["northland", "matakana", "kumeu", "auckland", "waiheke-island", "gisborne", "hawkes-bay", "central-hawkes-bay",
            "wairarapa", "gladstone", "martinborough", "nelson", "marlborough", "north-canterbury", "waipara-valley", "canterbury",
            "waitaki-valley-north-otago", "central-otago", "eastern-bays", "ruapehu", "wellington", "te-muna", "bannockburn",
            "gimblett-gravels", "new-zealand", "north-island", "south-island"]
BASE = "https://www.iponz.govt.nz/get-ip/geographical-indications/register/"
def nz_gis():
    import geopandas as gpd
    slugs = list(NZ_SLUGS)
    # crawl the register for any other New Zealand wine GI
    for start in range(0, 2400, 10):
        html = get(f"{BASE}?start={start}", tries=2)
        if not html: break
        h = html.decode("utf8", "ignore")
        found = re.findall(r'/geographical-indications/register/([a-z0-9\-]+)/?["?]', h)
        new = [s for s in found if s not in slugs]
        if start and not found: break
        slugs += [s for s in dict.fromkeys(new)]
    log("register slugs:", len(slugs))
    meta = {}
    for slug in dict.fromkeys(slugs):
        html = get(BASE + slug + "/", tries=2)
        if not html: continue
        h = html.decode("utf8", "ignore")
        text = re.sub(r"<[^>]+>", " ", h); text = re.sub(r"\s+", " ", text)
        if "New Zealand" not in text or not re.search(r"\bwine\b", text, re.I): continue
        if re.search(r"Country of origin\s*:?\s*(?!New Zealand)[A-Z]", text) and "Country of origin New Zealand" not in text:
            pass
        title = re.search(r"<h1[^>]*>(.*?)</h1>", h, re.S)
        title = re.sub(r"<[^>]+>|\s+", " ", title.group(1)).strip() if title else slug
        links = re.findall(r'href="([^"]+\.(?:zip|kml|kmz|geojson|gpkg)[^"]*)"', h, re.I) + \
                re.findall(r'href="([^"]*(?:[Gg]eodata|download)[^"]*)"', h)
        links = [urllib.parse.urljoin(BASE + slug + "/", l.replace("&amp;", "&")) for l in links]
        log("GI", slug, "|", title, "|", links[:5])
        meta[slug] = {"title": title, "links": links, "text": text[:4000]}
        for li, url in enumerate(dict.fromkeys(links)):
            data = get(url, tries=2)
            if not data or data[:2] != b"PK": continue
            d = f"dl/nz/{slug}/{li}"; os.makedirs(d, exist_ok=True)
            zipfile.ZipFile(io.BytesIO(data)).extractall(d)
            files = [p for p in glob.glob(d + "/**/*", recursive=True) if p.lower().endswith((".shp", ".kml", ".geojson", ".gpkg", ".json", ".tab"))]
            log("   files", files)
            frames = []
            for p in files:
                try:
                    df = gpd.read_file(p)
                    if df.crs is None: df = df.set_crs(2193 if abs(df.total_bounds[0]) > 1000 else 4326)
                    frames.append(df.to_crs(4326))
                except Exception as e:
                    log("   cannot read", p, e)
            if frames:
                import pandas as pd
                df = gpd.GeoDataFrame(pd.concat(frames, ignore_index=True), crs=4326)
                df = df[df.geometry.notna()]
                g = df.geometry.buffer(0).union_all() if hasattr(df.geometry, "union_all") else df.geometry.buffer(0).unary_union
                g = g.simplify(0.0002, preserve_topology=True)
                gpd.GeoDataFrame({"name": [title], "slug": [slug]}, geometry=[g], crs=4326).to_file(f"{OUT}/nz_gi/{slug}.geojson", driver="GeoJSON")
                log("   saved", slug, g.geom_type, round(g.area, 4))
                break
    json.dump(meta, open(f"{OUT}/nz_gi/meta.json", "w"), ensure_ascii=False, indent=1)

# ------------------------------------------------------------------ OpenStreetMap (Overpass)
HOSTS = ["https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter",
         "https://maps.mail.ru/osm/tools/overpass/api/interpreter"]
def overpass(q):
    for _ in range(3):
        for host in HOSTS:
            data = get(host, data=urllib.parse.urlencode({"data": q}).encode(), timeout=900, tries=1)
            if data:
                try: return json.loads(data)
                except Exception as e: log("  bad json", host, e)
        time.sleep(30)
    raise RuntimeError("overpass failed")

def tiles(s, w, n, e, step=2.0):
    la = s
    while la < n:
        lo = w
        while lo < e:
            yield (la, lo, min(n, la + step), min(e, lo + step)); lo += step
        la += step

BOXES = {  # s, w, n, e
    "cl": [(-39.5, -74.0, -26.5, -69.5)],
    "ar": [(-37.6, -70.3, -30.3, -66.3), (-29.8, -69.0, -22.5, -64.8), (-42.5, -72.5, -37.5, -62.5), (-46.5, -72.5, -42.5, -66.0)],
    "nz": [(-46.8, 166.0, -34.3, 179.0)],
    "za": [(-34.9, 17.6, -28.3, 24.0)],
}
def r5(c): return [round(c["lon"], 5), round(c["lat"], 5)]
def osm_vineyards():
    for cc, boxes in BOXES.items():
        polys, wineries, seen = [], [], set()
        for b in boxes:
            for (a, bb, c, d) in tiles(*b):
                q = (f'[out:json][timeout:800];(way["landuse"="vineyard"]({a},{bb},{c},{d});'
                     f'relation["landuse"="vineyard"]({a},{bb},{c},{d}););out tags geom;')
                try: r = overpass(q)
                except Exception as e: log("  vineyard tile failed", cc, (a, bb, c, d), e); continue
                n0 = len(polys)
                for el in r["elements"]:
                    k = (el["type"], el["id"])
                    if k in seen: continue
                    seen.add(k)
                    nm = el.get("tags", {}).get("name", "")
                    if el["type"] == "way" and el.get("geometry"):
                        polys.append({"n": nm, "r": [r5(p) for p in el["geometry"]]})
                    elif el["type"] == "relation":
                        outer = [[r5(p) for p in m["geometry"]] for m in el.get("members", []) if m.get("role") == "outer" and m.get("geometry")]
                        inner = [[r5(p) for p in m["geometry"]] for m in el.get("members", []) if m.get("role") == "inner" and m.get("geometry")]
                        if outer: polys.append({"n": nm, "rel": outer, "h": inner})
                q = (f'[out:json][timeout:800];(nwr["craft"="winery"]({a},{bb},{c},{d});nwr["tourism"="wine_cellar"]({a},{bb},{c},{d});'
                     f'nwr["shop"="wine"]["winery"]({a},{bb},{c},{d}););out tags center;')
                try:
                    r = overpass(q)
                    for el in r["elements"]:
                        t = el.get("tags", {}); c0 = el.get("center") or el
                        if "lat" not in c0 or not t.get("name"): continue
                        wineries.append({"n": t["name"], "ll": [round(c0["lat"], 5), round(c0["lon"], 5)],
                                         "w": t.get("website", ""), "k": t.get("craft") or t.get("tourism")})
                except Exception as e:
                    log("  winery tile failed", cc, e)
                log("tile", cc, (a, bb, c, d), "vineyards", len(polys) - n0)
                time.sleep(2)
        json.dump(polys, open(f"{OUT}/osm_vineyards_{cc}.json", "w"), separators=(",", ":"), ensure_ascii=False)
        json.dump(wineries, open(f"{OUT}/osm_wineries_{cc}.json", "w"), separators=(",", ":"), ensure_ascii=False)
        log(cc, "vineyards", len(polys), "wineries", len(wineries))

def osm_admin_ar():
    """Districts of the Argentine wine provinces (admin_level 5..10) and place names, for the IGs that are districts."""
    out = {"rel": [], "places": []}
    for name in ["Mendoza", "San Juan", "Salta", "Catamarca", "La Rioja", "Neuquén", "Río Negro", "Tucumán"]:
        q = (f'[out:json][timeout:800];area["boundary"="administrative"]["admin_level"="4"]["name"="{name}"]->.p;'
             f'(relation["boundary"="administrative"]["admin_level"~"^(5|6|7|8|9|10)$"](area.p););out tags geom;')
        try:
            r = overpass(q)
            for el in r["elements"]:
                if el["type"] != "relation": continue
                ways = [[r5(p) for p in m["geometry"]] for m in el.get("members", []) if m.get("type") == "way" and m.get("geometry") and m.get("role") in ("outer", "")]
                t = el.get("tags", {})
                out["rel"].append({"prov": name, "n": t.get("name", ""), "lv": t.get("admin_level"), "ways": ways})
            log("admin", name, len(r["elements"]))
        except Exception as e:
            log("admin failed", name, e)
        q = (f'[out:json][timeout:600];area["boundary"="administrative"]["admin_level"="4"]["name"="{name}"]->.p;'
             f'node["place"~"^(town|village|hamlet|locality|suburb|neighbourhood|isolated_dwelling)$"](area.p);out tags;')
        try:
            r = overpass(q)
            for el in r["elements"]:
                t = el.get("tags", {})
                if t.get("name"): out["places"].append({"prov": name, "n": t["name"], "p": t["place"], "ll": [round(el["lat"], 5), round(el["lon"], 5)]})
        except Exception as e:
            log("places failed", name, e)
        time.sleep(2)
    json.dump(out, open(f"{OUT}/osm_admin_ar.json", "w"), separators=(",", ":"), ensure_ascii=False)
    log("admin ar relations", len(out["rel"]), "places", len(out["places"]))

def osm_places():
    """Village and locality names inside the wine areas of Chile, New Zealand and South Africa (labels when zoomed in)."""
    for cc, boxes in (("cl", [(-39.5, -73.8, -27.0, -69.8)]), ("nz", [(-46.8, 166.0, -34.3, 179.0)]), ("za", [(-34.9, 17.6, -31.0, 23.0)])):
        out = []
        for b in boxes:
            for (a, bb, c, d) in tiles(*b, step=4.0):
                q = (f'[out:json][timeout:600];node["place"~"^(town|village|hamlet|locality|suburb)$"]({a},{bb},{c},{d});out tags;')
                try:
                    r = overpass(q)
                    for el in r["elements"]:
                        t = el.get("tags", {})
                        if t.get("name"): out.append({"n": t["name"], "p": t["place"], "ll": [round(el["lat"], 5), round(el["lon"], 5)]})
                except Exception as e:
                    log("places failed", cc, e)
        json.dump(out, open(f"{OUT}/osm_places_{cc}.json", "w"), separators=(",", ":"), ensure_ascii=False)
        log("places", cc, len(out))

# ------------------------------------------------------------------ reference texts
DOCS = {
    "cl_decreto464_leychile.json": "https://nuevo.leychile.cl/servicios/Navegar/get_norma_json?idNorma=12013",
    "cl_decreto464_obtxml.xml": "https://www.leychile.cl/Consulta/obtxml?opt=7&idNorma=12013",
    "cl_decreto464_sag.pdf": "https://sag.cl/sites/default/files/decreto_ndeg_464.pdf",
    "cl_decreto464_wipo_489584.html": "https://www.wipo.int/wipolex/es/text/489584",
    "cl_decreto464_wipo_489551.html": "https://www.wipo.int/wipolex/es/text/489551",
    "ar_ig_doc_2024.pdf": "https://www.argentina.gob.ar/sites/default/files/i.g._y_d.o.c._de_la_republica_argentina18_de_abril_2024.pdf",
    "ar_ig_doc.pdf": "https://www.argentina.gob.ar/sites/default/files/i.g._y_d.o.c._de_la_republica_argentina.pdf_.pdf.pdf_.pdf",
    "za_wo_booklet.pdf": "https://www.sawis.co.za/cert/download/wineoforiginbooklet201604.pdf",
    "za_new_demarcations.pdf": "https://www.sawis.co.za/winelaw/download/86_New_demarcations.pdf",
    "us_sa_wine_regions.pdf": "https://legacy.trade.gov/td/ocg/sawineregions.pdf",
}
WIKI = {"en": ["Wine_regions_of_South_Africa", "Chilean_wine", "Argentine_wine", "New_Zealand_wine", "Mendoza_wine",
               "List_of_wine-producing_regions", "Uco_Valley", "Luján_de_Cuyo_(wine)", "Marlborough_wine_region", "Hawke's_Bay_wine_region",
               "Central_Otago_wine_region", "Stellenbosch_(wine_region)", "Colchagua_Valley", "Maipo_Valley", "Casablanca_Valley"],
        "es": ["Vino_de_Chile", "Vino_de_Argentina", "Denominación_de_origen_(Chile)", "Valle_de_Uco", "Vitivinicultura_en_Argentina"]}
def docs():
    for name, url in DOCS.items():
        data = get(url, tries=2, timeout=120)
        log("doc", name, len(data) if data else None)
        if data: open(f"{OUT}/docs/{name}", "wb").write(data)
    for lang, pages in WIKI.items():
        for p in pages:
            data = get(f"https://{lang}.wikipedia.org/w/index.php?title={urllib.parse.quote(p)}&action=raw", tries=2, timeout=60)
            log("wiki", lang, p, len(data) if data else None)
            if data: open(f"{OUT}/docs/wiki_{lang}_{re.sub(r'[^A-Za-z0-9_]', '', p)}.txt", "wb").write(data)

if __name__ == "__main__":
    which = sys.argv[1:] or ["docs", "nz", "admin", "places", "osm"]
    if "docs" in which: step(docs)
    if "nz" in which: step(nz_gis)
    if "admin" in which: step(osm_admin_ar)
    if "places" in which: step(osm_places)
    if "osm" in which: step(osm_vineyards)
    os.system(f"du -ah {OUT} | sort -h | tail -60")
