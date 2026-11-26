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

CANDIDATES = ["GroNLP/ik-nlp-22_winemag", "leowang707/wine_review", "ChiJuiChen/wine_review", "spawn99/WineReviews",
              "alfredodeza/wine-ratings", "psiyum/winemag-feb-2019"]
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
    out = sys.argv[1] if len(sys.argv) > 1 else "we-data"
    os.makedirs(out, exist_ok=True)
    rows, seen = [], set()
    for name in CANDIDATES:
        for df in frames(name):
            cols = {c.lower(): c for c in df.columns}
            if "points" not in cols or "title" not in cols:
                continue
            for rec in df[[cols[c] for c in KEEP if c in cols]].to_dict("records"):
                r = {c: rec.get(cols[c], "") if c in cols else "" for c in KEEP}
                r = {k: ("" if str(v) == "nan" else str(v).strip()) for k, v in r.items()}
                key = (r["title"].lower(), r["points"])
                if not r["title"] or not r["points"] or key in seen:
                    continue
                seen.add(key); rows.append(r)
        if len(rows) > 100000:
            break
    with open(os.path.join(out, "wine_enthusiast_scores.csv"), "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=KEEP); w.writeheader(); w.writerows(rows)
    print("kept", len(rows), "reviews (scores only, no review text)")


if __name__ == "__main__":
    main()
