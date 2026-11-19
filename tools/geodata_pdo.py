"""Runs on a GitHub runner: download the EU wine PDO dataset (Candiago et al. 2022, figshare collection 5877659,
CC BY 4.0) and OSM simplified land polygons, simplify, and write compact GeoJSON per country into out/."""
import json, os, sys, urllib.request, zipfile, glob
import geopandas as gpd
OUT = "out"; os.makedirs(OUT, exist_ok=True)
def get(url, dest=None):
    req = urllib.request.Request(url, headers={"User-Agent": "jero-geodata/1.0"})
    with urllib.request.urlopen(req, timeout=600) as r:
        data = r.read()
    if dest: open(dest, "wb").write(data)
    return data
os.makedirs("dl", exist_ok=True)
arts = json.loads(get("https://api.figshare.com/v2/collections/5877659/articles?page_size=100"))
log = []
for a in arts:
    files = json.loads(get(f"https://api.figshare.com/v2/articles/{a['id']}/files"))
    for f in files:
        log.append(f"{a['title']} | {f['name']} | {f['size']}")
        if f["size"] < 1_500_000_000:
            get(f["download_url"], os.path.join("dl", f["name"]))
open(f"{OUT}/figshare_files.txt", "w").write("\n".join(log))
print("\n".join(log))
for z in glob.glob("dl/*.zip"):
    zipfile.ZipFile(z).extractall("dl")
gpkgs = glob.glob("dl/**/*.gpkg", recursive=True) + glob.glob("dl/**/*.shp", recursive=True)
print("spatial files:", gpkgs)
for p in glob.glob("dl/**/*.csv", recursive=True):
    os.system(f"cp '{p}' {OUT}/")
for g in gpkgs:
    import pyogrio
    layers = pyogrio.list_layers(g) if g.endswith(".gpkg") else [[None]]
    for lay in layers:
        name = lay[0]
        df = gpd.read_file(g, layer=name) if name else gpd.read_file(g)
        print(g, name, len(df), list(df.columns)[:30], df.crs)
        df = df.to_crs(4326)
        df["geometry"] = df.geometry.buffer(0).simplify(0.0004, preserve_topology=True)
        cols = [c for c in df.columns if c != "geometry"]
        # keep text-ish columns only
        keep = [c for c in cols if df[c].dtype == object or "id" in c.lower() or "name" in c.lower()][:12]
        df = df[keep + ["geometry"]]
        ccol = next((c for c in df.columns if c.lower() in ("country", "cntr_code", "iso", "country_code", "member_state")), None)
        print("country column:", ccol)
        if ccol:
            for cc, sub in df.groupby(ccol):
                sub.to_file(f"{OUT}/pdo_{str(cc).replace('/', '_')}.geojson", driver="GeoJSON")
        else:
            df.to_file(f"{OUT}/pdo_all.geojson", driver="GeoJSON")
# OSM simplified land polygons (coastlines much finer than Natural Earth 10m)
get("https://osmdata.openstreetmap.de/download/simplified-land-polygons-complete-3857.zip", "dl/land.zip")
zipfile.ZipFile("dl/land.zip").extractall("dl/land")
shp = glob.glob("dl/land/**/*.shp", recursive=True)[0]
land = gpd.read_file(shp).to_crs(4326)
boxes = {"europe": (-26, 28, 38, 62), "lebanon": (32.5, 31.5, 38.5, 36),
         "usa-west": (-130, 28, -110, 52), "southamerica": (-82, -50, -56, -16), "australia": (108, -47, 160, -20),
         "nz": (162, -50, 182, -32), "safrica": (13, -37, 27, -28)}
from shapely.geometry import box
for k, b in boxes.items():
    sub = land[land.intersects(box(*b))].copy()
    sub["geometry"] = sub.geometry.intersection(box(*b)).simplify(0.0008, preserve_topology=True)
    sub = sub[~sub.geometry.is_empty]
    sub[["geometry"]].to_file(f"{OUT}/land_{k}.geojson", driver="GeoJSON")
    print("land", k, len(sub))
os.system(f"ls -la {OUT}")
