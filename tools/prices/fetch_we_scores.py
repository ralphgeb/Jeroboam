#!/usr/bin/env python3
"""Wine Enthusiast scores from the public "Wine Reviews" dataset (~130k reviews scraped from winemag.com in 2017; copies on
Kaggle and Hugging Face, published there as CC BY-NC-SA 4.0). Runs on a GitHub runner (the dev container cannot reach Hugging Face).

Keeps ONLY the facts needed to match a wine and its score: title, winery, variety, country, province, region, points, price.
The review texts (`description`) and the taster's name are dropped here and never stored.
These scores are used only for wines that have no other critic's score, and are never linked in the app
(owner's decision, Nov 2026: remove them if anyone complains — delete sources/wine_enthusiast_scores.csv and rebuild).

Output: <out>/wine_enthusiast_scores.csv
"""
import csv, io, os, sys
import requests

# the only public copy with the wine's title (needed to match a bottle): ~250k reviews scraped in February 2019
CANDIDATES = ["psiyum/winemag-feb-2019"]
KEEP = ["title", "winery", "variety", "country", "province", "region_1", "points", "price"]


def frames(name):
    import pandas as pd
    info = requests.get(f"https://huggingface.co/api/datasets/{name}", timeout=60)
    if info.status_code != 200:
        print(name, "->", info.status_code); return
    files = [s["rfilename"] for s in info.json().get("siblings", [])]
    print(name, files[:20])
    for fn in files:
        if not fn.lower().endswith((".csv", ".parquet", ".json", ".jsonl")):
            continue
        url = f"https://huggingface.co/datasets/{name}/resolve/main/{fn}"
        r = requests.get(url, timeout=300)
        if r.status_code != 200:
            print("  ", fn, r.status_code); continue
        b = io.BytesIO(r.content)
        try:
            if fn.endswith(".parquet"): df = pd.read_parquet(b)
            elif fn.endswith(".csv"): df = pd.read_csv(b, low_memory=False)
            else: df = pd.read_json(b, lines=fn.endswith(".jsonl"))
        except Exception as e:
            print("  ", fn, "unreadable", e); continue
        print("  ", fn, len(df), list(df.columns)[:14])
        yield df


def main():
    import re
    out = sys.argv[1] if len(sys.argv) > 1 else "we-data"
    os.makedirs(out, exist_ok=True)
    rows, seen = [], set()
    for name in CANDIDATES:
        for df in frames(name):
            cols = {c.lower(): c for c in df.columns}
            score = cols.get("points") or cols.get("rating")
            if not score or "title" not in cols:
                continue          # copies without the wine's title cannot be matched to a bottle
            for rec in df.to_dict("records"):
                g = lambda c: "" if c not in cols or str(rec.get(cols[c])) == "nan" else str(rec.get(cols[c])).strip()
                if re.search(r"spirit|beer|cider|sake", g("category"), re.I):
                    continue      # Wine Enthusiast also rates spirits
                title = g("title")
                pts = str(rec.get(score, "")).strip()
                m = re.search(r"\b(\d{2,3})\b", pts)
                if not title or not m:
                    continue
                winery = g("winery") or re.split(r"\s+(?:19|20)\d\d\b|\s+NV\b", title)[0].strip()
                r = {"title": title, "winery": winery, "variety": g("variety") or g("varietal"), "country": g("country"),
                     "province": g("province") or g("region"), "region_1": g("region_1") or g("subregion"), "points": m.group(1),
                     "price": re.sub(r"[^\d.]", "", g("price"))}
                key = (title.lower(), r["points"])
                if key in seen:
                    continue
                seen.add(key); rows.append(r)
    with open(os.path.join(out, "wine_enthusiast_scores.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=KEEP); w.writeheader(); w.writerows(rows)
    print("kept", len(rows), "reviews (scores only, no review text)")


if __name__ == "__main__":
    main()
