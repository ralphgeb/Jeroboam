#!/usr/bin/env python3
"""Shrinks content/prices/wine_prices.csv to the compact list the app searches when a bottle is looked up
(name, producer, vintage, size, average/low/high price in US dollars, shops). Run after the CSV changes:
python3 tools/prices/build_app_prices.py"""
import csv, os
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "content/prices/wine_prices.csv")
OUT = os.path.join(ROOT, "Jeroboam/Resources/Prices/prices.tsv")
GBP_TO_USD = 1.0990 / 0.83735
import re
SKIP = re.compile(r"\b(keg|kegs|cans?|can pack|gift card|voucher|subscription|club membership)\b", re.I)
NAMED = [(re.compile(r"\bdouble magnum\b", re.I), 3000), (re.compile(r"\bmagnum\b", re.I), 1500), (re.compile(r"\bjeroboam\b", re.I), 3000),
         (re.compile(r"\brehoboam\b", re.I), 4500), (re.compile(r"\bmethuselah\b", re.I), 6000), (re.compile(r"\bimperial\b", re.I), 6000),
         (re.compile(r"\bhalf[- ]bottle\b|\bdemi\b", re.I), 375)]
def size_from_name(name):
    """Bottle size written in the wine's name (1.5 Litre, 300cl, 750ml, Magnum…), in ml, or None."""
    m = re.search(r"(\d+(?:[.,]\d+)?)\s*(litres?|liters?|ltrs?|l)\b", name, re.I)
    if m: return round(float(m.group(1).replace(",", ".")) * 1000)
    m = re.search(r"(\d+(?:[.,]\d+)?)\s*cl\b", name, re.I)
    if m: return round(float(m.group(1).replace(",", ".")) * 10)
    m = re.search(r"(\d{3,5})\s*ml\b", name, re.I)
    if m: return int(m.group(1))
    for rx, ml in NAMED:
        if rx.search(name): return ml
    return None
n = skipped = fixed = 0
with open(SRC, newline="") as f, open(OUT, "w") as out:
    for r in csv.DictReader(f):
        try:
            usd = float(r["avg_price_usd"] or 0)
        except ValueError:
            continue
        if usd <= 0: continue
        if SKIP.search(r["wine"]): skipped += 1; continue
        named = size_from_name(r["wine"])
        if named and named != int(float(r["size_ml"] or 750)):
            r["size_ml"] = str(named); fixed += 1
        if int(float(r["size_ml"] or 750)) > 18000: skipped += 1; continue
        lo = float(r["min_price_gbp"] or 0) * GBP_TO_USD
        hi = float(r["max_price_gbp"] or 0) * GBP_TO_USD
        clean = lambda s: (s or "").replace("\t", " ").replace("\n", " ").strip()
        out.write("\t".join([clean(r["wine"]), clean(r["producer"]), clean(r["vintage"]), clean(r["size_ml"]),
                             f"{usd:.0f}", f"{lo:.0f}", f"{hi:.0f}", clean(r["shops_count"]),
                             clean(r.get("cheapest_link")).replace("https://", "", 1)]) + "\n")
        n += 1
print(n, "wines;", fixed, "sizes read from the name,", skipped, "kegs/cans/odd rows left out;", round(os.path.getsize(OUT) / 1e6, 1), "MB")
