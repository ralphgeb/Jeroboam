#!/usr/bin/env python3
"""Builds the home-screen widgets' data: fun facts and 100 wines to try (with small bottle pictures), straight from the app's
library, so the widget extension needs no shared storage. Run after content changes: python3 tools/build_widget_data.py"""
import json, os
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, "Jeroboam")
lib = json.load(open(os.path.join(APP, "Resources/Content/library.json")))
OUT = os.path.join(APP, "JeroWidget/Resources")
BOT = os.path.join(OUT, "Bottles")
os.makedirs(BOT, exist_ok=True)
for f in os.listdir(BOT): os.remove(os.path.join(BOT, f))

great = [g for g in lib["great"] if g.get("bottle") and os.path.exists(os.path.join(APP, "Resources/Photos", g["bottle"] + ".jpg"))]
great.sort(key=lambda g: (-(g.get("criticScore") or 0), g["name"]))
top = great[:100]
wines = []
for g in top:
    src = Image.open(os.path.join(APP, "Resources/Photos", g["bottle"] + ".jpg")).convert("RGB")
    h = 420
    im = src.resize((round(src.width * h / src.height), h), Image.LANCZOS)
    im.save(os.path.join(BOT, g["id"] + ".jpg"), quality=72, optimize=True)
    why = g.get("why") or g.get("what") or ""
    wines.append({"id": g["id"], "name": g["name"], "zone": g.get("zone") or g.get("area") or "", "color": g.get("color", "red"),
                  "price": g.get("avgPrice"), "score": g.get("criticScore"), "why": why})
data = {"facts": lib["facts"], "wines": wines}
json.dump(data, open(os.path.join(OUT, "widget.json"), "w"), ensure_ascii=False, separators=(",", ":"))
print(len(data["facts"]), "facts,", len(wines), "wines")
