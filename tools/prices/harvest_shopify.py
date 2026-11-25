#!/usr/bin/env python3
"""Downloads the public catalogues (/products.json) of the Shopify wine shops in tools/prices/shops.json.

Runs on a GitHub runner (.github/workflows/harvest_shops.yml): this project's dev container cannot reach the shops.
Writes, per shop, <out>/<host>.jsonl.gz with one product per line:
  {url, id, handle, title, vendor, type, tags[], text, published_at, variants: [{title, price, compare_at, available, grams, sku}]}
and <out>/report.json (per shop: products, pages, capped, currency seen on the storefront, errors).
Nothing is filtered here; tools/prices/shopify_to_sources.py decides what is wine and what each bottle costs.

Run: python3 tools/prices/harvest_shopify.py --out shop-data [--only host,host] [--workers 8]
"""
import argparse, gzip, html, json, os, re, sys, threading, time
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import urlparse
import requests

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
UA = "Mozilla/5.0 (compatible; JeroCatalogBot/1.0; wine price research)"
LOCK = threading.Lock()


def log(*a):
    with LOCK:
        print(*a, flush=True)


def text_of(raw):
    if not raw:
        return ""
    t = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", raw, flags=re.S | re.I)
    t = re.sub(r"<br\s*/?>|</p>|</li>|</h\d>|</div>", " \n ", t, flags=re.I)
    t = html.unescape(re.sub(r"<[^>]+>", " ", t))
    t = re.sub(r"[ \t\r\f\v]+", " ", t)
    t = re.sub(r"\s*\n\s*", "\n", t).strip()
    return t[:6000]


def get(session, url, tries=5):
    """GET with backoff on 429/5xx. Returns a Response or None."""
    for i in range(tries):
        try:
            r = session.get(url, timeout=30)
        except requests.RequestException as e:
            if i == tries - 1:
                log("   !", url, e.__class__.__name__)
                return None
            time.sleep(2 + 3 * i)
            continue
        if r.status_code == 429 or r.status_code >= 500:
            wait = float(r.headers.get("Retry-After") or 0) or (5 + 10 * i)
            time.sleep(min(wait, 60))
            continue
        return r
    return None


def slim(p, base):
    vs = []
    for v in p.get("variants") or []:
        vs.append({"title": v.get("title") or "", "price": v.get("price"), "compare_at": v.get("compare_at_price"),
                   "available": bool(v.get("available")), "grams": v.get("grams"), "sku": v.get("sku") or ""})
    tags = p.get("tags") or []
    if isinstance(tags, str):
        tags = [t.strip() for t in tags.split(",") if t.strip()]
    return {"url": f"{base}/products/{p.get('handle', '')}", "id": p.get("id"), "handle": p.get("handle"),
            "title": (p.get("title") or "").strip(), "vendor": (p.get("vendor") or "").strip(),
            "type": (p.get("product_type") or "").strip(), "tags": tags, "text": text_of(p.get("body_html")),
            "published_at": p.get("published_at"), "variants": vs}


def paged(session, url_fmt, delay, max_pages):
    """Yields product lists page by page; stops on empty page, error or repeated page (Shopify's paging cap)."""
    seen_first = set()
    for page in range(1, max_pages + 1):
        r = get(session, url_fmt.format(page=page))
        if r is None or r.status_code != 200:
            return
        try:
            prods = r.json().get("products") or []
        except ValueError:
            return
        if not prods:
            return
        first = prods[0].get("id")
        if first in seen_first:   # the shop keeps returning the same page: capped
            return
        seen_first.add(first)
        yield prods
        time.sleep(delay)


def storefront_currency(session, base):
    """The currency the storefront shows (Shopify.currency.active on the home page, else cart.js)."""
    r = get(session, base + "/", tries=2)
    if r is not None and r.status_code == 200:
        m = re.search(r'Shopify\.currency\s*=\s*\{[^}]*"active"\s*:\s*"([A-Z]{3})"[^}]*"rate"\s*:\s*"([\d.]+)"', r.text)
        if m:
            return m.group(1), m.group(2)
    r = get(session, base + "/cart.js", tries=2)
    if r is not None and r.status_code == 200:
        try:
            return r.json().get("currency"), None
        except ValueError:
            pass
    return None, None


def harvest(shop, out, delay, max_pages):
    base = shop["base"].rstrip("/")
    host = urlparse(base).netloc
    s = requests.Session()
    s.headers.update({"User-Agent": UA, "Accept": "application/json,text/html;q=0.8"})
    rep = {"name": shop["name"], "base": base, "status": shop.get("status"), "declared_currency": shop["currency"],
           "products": 0, "pages": 0, "via_collections": False, "error": None}
    t0 = time.time()
    try:
        rep["storefront_currency"], rep["storefront_rate"] = storefront_currency(s, base)
        prods = {}
        for page in paged(s, base + "/products.json?limit=250&page={page}", delay, max_pages):
            rep["pages"] += 1
            for p in page:
                prods[p["id"]] = p
        if rep["pages"] == 0:
            rep["error"] = "no products.json"
        # a full last page means Shopify stopped paging before the end: walk every collection too
        if rep["pages"] >= 99 or (rep["pages"] and len(prods) % 250 == 0 and len(prods) >= 5000):
            rep["via_collections"] = True
            handles = []
            for pg in range(1, 200):
                r = get(s, f"{base}/collections.json?limit=250&page={pg}")
                if r is None or r.status_code != 200:
                    break
                cs = r.json().get("collections") or []
                if not cs:
                    break
                handles += [c["handle"] for c in cs if c.get("products_count", 1)]
                time.sleep(delay)
            log(f"   {host}: capped at {len(prods)}, walking {len(handles)} collections")
            for h in handles:
                for page in paged(s, f"{base}/collections/{h}/products.json?limit=250&page={{page}}", delay, max_pages):
                    for p in page:
                        prods.setdefault(p["id"], p)
        with gzip.open(os.path.join(out, host + ".jsonl.gz"), "wt", encoding="utf-8") as f:
            for p in prods.values():
                f.write(json.dumps(slim(p, base), ensure_ascii=False) + "\n")
        rep["products"] = len(prods)
    except Exception as e:  # keep going with the other shops
        rep["error"] = f"{e.__class__.__name__}: {e}"
    rep["seconds"] = round(time.time() - t0)
    log(f"{shop['name']:30} {host:38} {rep['products']:7} products  {rep['seconds']}s  {rep.get('storefront_currency')} {rep['error'] or ''}")
    return host, rep


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="shop-data")
    ap.add_argument("--only", default="")
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--delay", type=float, default=0.6)
    ap.add_argument("--max-pages", type=int, default=400)
    a = ap.parse_args()
    cfg = json.load(open(os.path.join(ROOT, "tools/prices/shops.json")))
    blocked = cfg["blocked"]
    shops = [s for s in cfg["shops"] if not any(b in s["base"] for b in blocked)]
    if a.only:
        want = a.only.split(",")
        shops = [s for s in shops if any(w in s["base"] for w in want)]
    os.makedirs(a.out, exist_ok=True)
    with ThreadPoolExecutor(a.workers) as ex:
        reps = dict(ex.map(lambda s: harvest(s, a.out, a.delay, a.max_pages), shops))
    old = {}
    rp = os.path.join(a.out, "report.json")
    if a.only and os.path.exists(rp):
        old = json.load(open(rp))
    old.update(reps)
    json.dump(old, open(rp, "w"), indent=1, ensure_ascii=False)
    print("total products", sum(r["products"] for r in reps.values()), "from", sum(1 for r in reps.values() if r["products"]), "shops")


if __name__ == "__main__":
    main()
