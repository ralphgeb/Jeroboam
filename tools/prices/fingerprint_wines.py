#!/usr/bin/env python3
"""Label fingerprints of the wines in wine_prices.csv from the shops' own product photos, made the app's way
(Apple Vision feature prints, tools/prices/LabelPrints.swift on a macOS runner; see docs/handoff/claude-maps-and-app.md,
"For the session harvesting wine images"). Only the numbers and the shop link are kept, never the photos.

  jobs  <shop-data dir> <wine_prices.csv> <host> <out dir>
        -> <out>/<host>.jobs.tsv (photo URLs, one per line) + <out>/<host>.meta.tsv (key, producer, wine, vintage, link, photo)
        One photo per distinct picture: a picture shared by several vintages/sizes of a wine is printed once (all its rows listed).
  (macOS) swiftc -O tools/prices/LabelPrints.swift -o labelprints && ./labelprints <out>/<host>.jobs.tsv <out>/<host>
        -> <host>.full.f16, <host>.label.f16 (row i = line i of jobs.tsv), <host>.status.tsv
  pack  <out dir> <host>
        counts -> <out>/<host>.prints.json

`key` is WineDB.key of the list's own producer / wine name / vintage (folded: lower case, no accents, letters, digits and spaces),
so prints can be mapped to the app's wine keys later; `link` is the shop page of the list row.
"""
import csv, gzip, json, os, sys, unicodedata
from collections import defaultdict
from urllib.parse import urlparse

csv.field_size_limit(10 ** 9)


def fold(s):
    """WineDB.fold: diacritics and case folded, lower case, only letters, digits and spaces."""
    s = "".join(c for c in unicodedata.normalize("NFD", (s or "")) if unicodedata.category(c) != "Mn").lower()
    return "".join(c for c in s if c.isalpha() or c.isdigit() or c == " ")


def wine_key(producer, name, vintage):
    """WineDB.key"""
    return "|".join(x.strip() for x in (fold(producer), " ".join(fold(name).split()), fold(vintage)))


def wine_pages(prices_csv, host):
    """product URL of this host -> list rows [(producer, wine, vintage)]"""
    out = defaultdict(list)
    for r in csv.DictReader(open(prices_csv, encoding="utf-8")):
        for part in (r.get("links") or "").split(" ; "):
            url = part.split(": ", 1)[-1].strip()
            if url.startswith("http") and urlparse(url).netloc == host:
                out[url.split("?")[0]].append((r.get("producer") or "", r["wine"], r["vintage"]))
    return out


def page_photos(pages, workers=6):
    """Shops without a catalogue on shop-data (Tesco, trolley.co.uk for the UK supermarkets): the product page's own photo
    (og:image / twitter:image), read on the runner. Yields {"url": page, "images": [photo]} like a catalogue line."""
    import re, time, urllib.request
    from concurrent.futures import ThreadPoolExecutor
    pat = re.compile(r"""<meta[^>]+(?:property|name)=["'](?:og:image|twitter:image)["'][^>]*content=["']([^"']+)["']"""
                     r"""|<meta[^>]+content=["']([^"']+)["'][^>]*(?:property|name)=["'](?:og:image|twitter:image)["']""", re.I)
    def one(url):
        for attempt in range(3):
            try:
                req = urllib.request.Request(url, headers={"user-agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 "
                                                           "(KHTML, like Gecko) Version/17.0 Safari/605.1.15", "accept-language": "en-GB"})
                html = urllib.request.urlopen(req, timeout=30).read(600000).decode("utf-8", "ignore")
                m = pat.search(html)
                img = (m.group(1) or m.group(2)).replace("&amp;", "&") if m else None
                return {"url": url, "images": [img] if img else []}
            except Exception:
                time.sleep(2 + 3 * attempt)
        return {"url": url, "images": []}
    with ThreadPoolExecutor(workers) as ex:
        yield from ex.map(one, sorted(pages))


def jobs(data_dir, prices_csv, host, out):
    os.makedirs(out, exist_ok=True)
    pages = wine_pages(prices_csv, host)
    photo_rows, order, no_photo = defaultdict(list), [], 0
    cat = os.path.join(data_dir, f"{host}.jsonl.gz")
    lines = (json.loads(l) for l in gzip.open(cat, "rt", encoding="utf-8")) if os.path.exists(cat) else page_photos(pages)
    for p in lines:
        url = (p.get("url") or "").split("?")[0]
        if url not in pages:
            continue
        imgs = [i for i in (p.get("images") or []) if i]
        if not imgs:
            no_photo += 1; continue
        src = imgs[0] if not imgs[0].startswith("//") else "https:" + imgs[0]
        k = src.split("?")[0]
        if k not in photo_rows:
            order.append(src)
        for prod, wine, vint in pages[url]:
            photo_rows[k].append((wine_key(prod, wine, vint), prod, wine, vint, url))
    with open(os.path.join(out, f"{host}.jobs.tsv"), "w") as f:
        f.writelines(s + "\n" for s in order)
    with open(os.path.join(out, f"{host}.meta.tsv"), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, delimiter="\t"); w.writerow(["row", "key", "producer", "wine", "vintage", "link", "photo"])
        for i, src in enumerate(order):
            seen = set()
            for rec in photo_rows[src.split("?")[0]]:
                if rec[0] in seen: continue
                seen.add(rec[0]); w.writerow([i, *rec, src.split("?")[0]])
    rep = {"host": host, "wine_pages": len(pages), "pages_without_photo": no_photo, "distinct_photos": len(order)}
    json.dump(rep, open(os.path.join(out, f"{host}.prints.json"), "w"), indent=1)
    print(json.dumps(rep))


def pack(out, host):
    """the run's counts into <host>.prints.json (the prints stay as LabelPrints wrote them: <host>.full.f16 / .label.f16)"""
    pre = os.path.join(out, host)
    status = list(csv.DictReader(open(pre + ".status.tsv"), delimiter="\t"))
    rep = json.load(open(pre + ".prints.json"))
    counts = defaultdict(int)
    for s in status: counts[s["status"]] += 1
    rep["status"] = dict(counts)
    rep["dims"] = int(status[0]["dims"]) if status else 0
    rep["revisions"] = sorted({int(s["revision"]) for s in status if s["status"] == "ok"})
    rep["fingerprinted"] = counts.get("ok", 0)
    json.dump(rep, open(pre + ".prints.json", "w"), indent=1)
    print(json.dumps(rep))


if __name__ == "__main__":
    if sys.argv[1] == "jobs": jobs(*sys.argv[2:6])
    elif sys.argv[1] == "pack": pack(*sys.argv[2:4])
    else: sys.exit(__doc__)
