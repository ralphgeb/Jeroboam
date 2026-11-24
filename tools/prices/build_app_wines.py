#!/usr/bin/env python3
"""The full wine list the app downloads (prices + details), as one compressed file: content/prices/app_wines.tsv.z
(raw deflate of a tab-separated text). Columns:
 name, producer, vintage, size_ml, usd, low_usd, high_usd, shops, cheapest_link,
 colour (r/w/p/s/o or empty), country, region, appellation, grapes (; separated), aromas (; separated), score (0-100 or empty), score_link,
 grape percents (; separated, same order as the grapes, empty when unknown)
Joins content/prices/wine_prices.csv with content/prices/wine_details.csv row by row (same wine/producer/vintage/size).
Run: python3 tools/prices/build_app_wines.py"""
import csv, os, re, sys, zlib
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
csv.field_size_limit(10**9)
PRICES = os.path.join(ROOT, "content/prices/wine_prices.csv")
DETAILS = os.path.join(ROOT, "content/prices/wine_details.csv")
OUT = os.path.join(ROOT, "content/prices/app_wines.tsv.z")
GBP_TO_USD = 1.0990 / 0.83735
SKIP = re.compile(r"\b(keg|kegs|cans?|can pack|gift card|voucher|subscription|club membership)\b", re.I)
NAMED = [(re.compile(r"\bdouble magnum\b", re.I), 3000), (re.compile(r"\bmagnum\b", re.I), 1500), (re.compile(r"\bjeroboam\b", re.I), 3000),
         (re.compile(r"\brehoboam\b", re.I), 4500), (re.compile(r"\bmethuselah\b", re.I), 6000), (re.compile(r"\bimperial\b", re.I), 6000),
         (re.compile(r"\bhalf[- ]bottle\b|\bdemi\b", re.I), 375)]
def size_from_name(name):
    m = re.search(r"(\d+(?:[.,]\d+)?)\s*(litres?|liters?|ltrs?|l)\b", name, re.I)
    if m: return round(float(m.group(1).replace(",", ".")) * 1000)
    m = re.search(r"(\d+(?:[.,]\d+)?)\s*cl\b", name, re.I)
    if m: return round(float(m.group(1).replace(",", ".")) * 10)
    m = re.search(r"(\d{3,5})\s*ml\b", name, re.I)
    if m: return int(m.group(1))
    for rx, ml in NAMED:
        if rx.search(name): return ml
    return None
COL = {"red": "r", "white": "w", "rose": "p", "rosé": "p", "sparkling": "s", "orange": "o", "fortified": "f", "sweet": "d", "dessert": "d"}
clean = lambda s: (s or "").replace("\t", " ").replace("\n", " ").replace("\r", " ").strip()
def semi(s): return ";".join(x.strip() for x in re.split(r"[;,|/]", s or "") if x.strip())

dets = {}
with open(DETAILS, newline="", encoding="utf-8") as f:
    for r in csv.DictReader(f):
        dets[(r["wine"], r["producer"], r["vintage"], r["size_ml"])] = r
out, n, withd = [], 0, 0
with open(PRICES, newline="", encoding="utf-8") as f:
    for r in csv.DictReader(f):
        try: usd = float(r["avg_price_usd"] or 0)
        except ValueError: continue
        if usd <= 0 or SKIP.search(r["wine"]): continue
        d = dets.get((r["wine"], r["producer"], r["vintage"], r["size_ml"]), {})
        named = size_from_name(r["wine"])
        size = int(float(r["size_ml"] or 750))
        if named and named != size: size = named
        if size > 18000: continue
        lo = float(r["min_price_gbp"] or 0) * GBP_TO_USD
        hi = float(r["max_price_gbp"] or 0) * GBP_TO_USD
        sc = ""
        try:
            v = float(d.get("avg_score") or 0)
            sc = str(round(v)) if v >= 50 else ""
        except ValueError: pass
        slink = clean((d.get("score_links") or "").split(";")[0].split(" ")[0]).replace("https://", "", 1) if sc else ""
        # blend percentages ("Merlot 60%, Cabernet Franc 40%") give the grapes in order, and the percent column
        pairs = re.findall(r"([^,%]+?)\s+(\d{1,3})%", d.get("grape_blend") or "")
        gr = semi(clean(d.get("grapes"))); pct = ""
        if pairs and 95 <= sum(int(p) for _, p in pairs) <= 105:
            gr = ";".join(g.strip() for g, _ in pairs); pct = ";".join(p for _, p in pairs)
        row = [clean(r["wine"]), clean(r["producer"]), clean(r["vintage"]), str(size), f"{usd:.0f}", f"{lo:.0f}", f"{hi:.0f}", clean(r["shops_count"]),
               clean(r.get("cheapest_link")).replace("https://", "", 1),
               COL.get((d.get("color") or "").strip().lower(), ""), clean(d.get("country")), clean(d.get("region")), clean(d.get("appellation")),
               gr, semi(clean(d.get("aromas"))), sc, slink, pct]
        if any(row[9:]): withd += 1
        out.append("\t".join(row))
        n += 1
text = "\n".join(out) + "\n"
c = zlib.compressobj(9, zlib.DEFLATED, -15)
blob = c.compress(text.encode("utf-8")) + c.flush()
open(OUT, "wb").write(blob)
print(n, "wines,", withd, "with details;", round(len(text) / 1e6, 1), "MB text ->", round(len(blob) / 1e6, 1), "MB file")
