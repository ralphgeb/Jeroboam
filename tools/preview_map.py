#!/usr/bin/env python3
"""Quick picture of a built map (areas coloured, names at the centres) for checking geometry: preview_map.py <map> <out.png>"""
import json, sys
from PIL import Image, ImageDraw
d = json.load(open(f"Jeroboam/Resources/Maps/{sys.argv[1]}.json"))
S = 1100 / max(d["w"], d["h"])
im = Image.new("RGB", (int(d["w"] * S), int(d["h"] * S)), (190, 215, 235))
dr = ImageDraw.Draw(im)
def poly(f, fill=None, outline=None, k=1):
    pts = [(f[i] / k * S, f[i + 1] / k * S) for i in range(0, len(f) - 1, 2)]
    if len(pts) > 2: dr.polygon(pts, fill=fill, outline=outline)
for f in d["land"]: poly(f, (225, 225, 222))
for f in d["focus"]: poly(f, (250, 248, 240), (150, 150, 150))
for f in d["lakes"]: poly(f, (190, 215, 235))
cols = [(168, 40, 70), (214, 120, 60), (90, 140, 90), (120, 90, 160), (60, 130, 150), (200, 170, 60), (180, 90, 120), (80, 110, 170)]
for a in sorted(d["areas"], key=lambda a: a["lv"]):
    c = cols[a["c"] % len(cols)]
    for sh in a["shapes"]:
        poly(sh, tuple(int(x * (0.55 if a["lv"] else 0.8) + 255 * (0.45 if a["lv"] else 0.2)) for x in c) if a["lv"] == 0 else c, (60, 60, 60), a.get("k", 1))
for a in d["areas"]:
    dr.text((a["cx"] * S - 20, a["cy"] * S - 5), a["name"][:16], fill=(0, 0, 0))
for c in d["cities"]:
    dr.ellipse((c["x"] * S - 3, c["y"] * S - 3, c["x"] * S + 3, c["y"] * S + 3), fill=(0, 0, 0)); dr.text((c["x"] * S + 5, c["y"] * S - 5), c["n"], fill=(0, 0, 0))
im.save(sys.argv[2])
