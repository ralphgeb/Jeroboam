#!/usr/bin/env python3
"""Builds the home-screen widgets' data: fun facts and 100 wines to try (with small bottle pictures), straight from the app's
library, so the widget extension needs no shared storage. Run after content changes: python3 tools/build_widget_data.py"""
import json, os
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP = os.path.join(ROOT, "Jeroboam")
lib = json.load(open(os.path.join(APP, "Resources/Content/library.json")))
OUT = os.path.join(APP, "JeroWidget/Resources")
BOT = os.path.join(OUT, "Bottles")
os.makedirs(BOT, exist_ok=True)
for f in os.listdir(BOT): os.remove(os.path.join(BOT, f))

# the full-size originals (tools/compress_photos.py keeps them in media/photos-original)
ORIG = os.path.join(APP, "..", "media", "photos-original")
great = [g for g in lib["great"] if g.get("bottle") and os.path.exists(os.path.join(ORIG, g["bottle"] + ".jpg"))]
great.sort(key=lambda g: (-(g.get("criticScore") or 0), g["name"]))
top = great[:100]
wines = []
for g in top:
    src = Image.open(os.path.join(ORIG, g["bottle"] + ".jpg")).convert("RGB")
    h = 420
    im = src.resize((round(src.width * h / src.height), h), Image.LANCZOS)
    # cut the bottle out of its white studio background: light pixels connected to the picture's edge become transparent
    a = np.asarray(im).astype(np.int16)
    light = (a.min(axis=2) >= 232) | ((a.max(axis=2) - a.min(axis=2) <= 10) & (a.min(axis=2) >= 214))
    lab, n = ndimage.label(light)
    edge = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.isin(lab, list(edge))
    bg = ndimage.binary_opening(bg, iterations=1) | bg & ~ndimage.binary_dilation(~bg, iterations=2)
    alpha = Image.fromarray(((~bg) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.9))
    out = im.convert("RGBA"); out.putalpha(alpha)
    out.save(os.path.join(BOT, g["id"] + ".png"), optimize=True)
    why = g.get("why") or g.get("what") or ""
    wines.append({"id": g["id"], "name": g["name"], "zone": g.get("zone") or g.get("area") or "", "color": g.get("color", "red"),
                  "price": g.get("avgPrice"), "score": g.get("criticScore"), "why": why})
data = {"facts": lib["facts"], "wines": wines}
json.dump(data, open(os.path.join(OUT, "widget.json"), "w"), ensure_ascii=False, separators=(",", ":"))
print(len(data["facts"]), "facts,", len(wines), "wines")
