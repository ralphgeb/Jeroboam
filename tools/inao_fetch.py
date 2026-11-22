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
for sp, f in zip(shps, frames):
    if len(f) > len(g): g = f
g = g.to_crs(4326)
cols = [c for c in g.columns if c != "geometry"]
txt = g[cols].astype(str).agg(" | ".join, axis=1)
pat = r"montrachet|chambertin|musigny|vougeot|romanée|romanee|richebourg|tâche|tache|corton|bonnes.mares|clos de|echezeaux|échezeaux|lambrays|griotte|ruchottes|mazis|charmes|chapelle|saint-denis|chevalier|criots|bâtard|batard|bienvenues|chablis|rully|mercurey|givry|montagny|bouzeron|puligny|chassagne|meursault|pommard|volnay|beaune|santenay|savigny|gevrey|morey|chambolle|nuits|vosne|fixin|marsannay|ladoix|aloxe|pernand|auxey|monthelie|saint-romain|saint-aubin|maranges|côte de|cote de|pouilly|saint-véran|mâcon|macon"
sel = g[txt.str.contains(pat, case=False, regex=True)]
b = sel.cx[4.4:5.4, 46.7:47.5]
print("selected", len(sel), "in Côte d'Or box", len(b))
for c in cols:
    if b[c].dtype == object:
        vals = sorted(set(map(str, b[c])))
        print(c, len(vals), vals[:80])
b.to_file("out/inao_burgundy.geojson", driver="GeoJSON")
print(os.path.getsize("out/inao_burgundy.geojson"))
