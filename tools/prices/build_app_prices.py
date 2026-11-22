#!/usr/bin/env python3
"""Shrinks content/prices/wine_prices.csv to the compact list the app searches when a bottle is looked up
(name, producer, vintage, size, average/low/high price in US dollars, shops). Run after the CSV changes:
python3 tools/prices/build_app_prices.py"""
import csv, os
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "content/prices/wine_prices.csv")
OUT = os.path.join(ROOT, "Jeroboam/Resources/Prices/prices.tsv")
GBP_TO_USD = 1.0990 / 0.83735
n = 0
with open(SRC, newline="") as f, open(OUT, "w") as out:
    for r in csv.DictReader(f):
        try:
            usd = float(r["avg_price_usd"] or 0)
        except ValueError:
            continue
        if usd <= 0: continue
        lo = float(r["min_price_gbp"] or 0) * GBP_TO_USD
        hi = float(r["max_price_gbp"] or 0) * GBP_TO_USD
        clean = lambda s: (s or "").replace("\t", " ").replace("\n", " ").strip()
        out.write("\t".join([clean(r["wine"]), clean(r["producer"]), clean(r["vintage"]), clean(r["size_ml"]),
                             f"{usd:.0f}", f"{lo:.0f}", f"{hi:.0f}", clean(r["shops_count"])]) + "\n")
        n += 1
print(n, "wines,", round(os.path.getsize(OUT) / 1e6, 1), "MB")
