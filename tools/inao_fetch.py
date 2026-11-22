"""INAO parcel-level AOC delimitation (data.gouv.fr, Licence Ouverte): extract the Burgundy Grand Cru / village appellations."""
import os, re, subprocess, sys, glob, json
URL = "https://static.data.gouv.fr/resources/delimitation-parcellaire-des-aoc-viticoles-de-linao/20261109-223939/2026-11-09-delim-parcellaire-aoc-shp.zip"
os.makedirs("raw", exist_ok=True); os.makedirs("out", exist_ok=True)
if not glob.glob("raw/**/*.shp", recursive=True):
    subprocess.check_call(["curl", "-sSL", "--retry", "3", "-o", "raw/inao.zip", URL])
    subprocess.check_call(["unzip", "-q", "-o", "raw/inao.zip", "-d", "raw"])
shps = glob.glob("raw/**/*.shp", recursive=True)
print(shps)
import geopandas as gpd
frames = []
for sp in shps:
    g = gpd.read_file(sp, engine="pyogrio")
    print(sp, len(g), g.crs); print(list(g.columns)); print(g.head(3).drop(columns="geometry").to_string())
    frames.append(g)
g = frames[0]
for f in frames:
    if len(f) > len(g): g = f
g = g.to_crs(4326)
b = g.cx[4.6:5.2, 46.85:47.35]
b = b[b["app"].notna()]
print("in Côte d'Or box:", len(b))
names = sorted(set(zip(b["app"], b["denom"].fillna(""))))
print(len(names)); print(names)
b = b.assign(key=b["app"].astype(str) + "|" + b["denom"].fillna("").astype(str))
d = b.dissolve(by="key", as_index=False)[["app", "denom", "geometry"]]
d["geometry"] = d.geometry.simplify(0.000015)
d.to_file("out/inao_cotedor.geojson", driver="GeoJSON")
print(os.path.getsize("out/inao_cotedor.geojson"))
