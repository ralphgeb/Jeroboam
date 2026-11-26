#!/usr/bin/env python3
"""Critics' scores from shop product pages (the catalogue feed often leaves out the page's "reviews" / "ratings" section).

Runs on a GitHub runner (.github/workflows/score_pages.yml); reads the harvested catalogues in <shop-data dir>.
  --sample N   : N wine pages per shop, saves only what is around critic names (to find which shops show scores and how)
  --full HOSTS : every wine page of those shops (comma separated), same output
Output: <out>/<host>.pages.jsonl.gz, one line per page: {url, status, jsonld: [...], snippets: ["…Wine Advocate 96…", …]}
Only short snippets are kept (critics' texts are copyrighted; enrich_details.py reads the score numbers only).
"""
import argparse, gzip, json, os, random, re, sys, time
from concurrent.futures import ThreadPoolExecutor
import requests

CRIT = re.compile(r"wine advocate|robert ?parker|\bparker\b|wine spectator|suckling|vinous|galloni|dunnuck|decanter|wine enthusiast|burghound|"
                  r"jancis|robinson|tim atkin|halliday|falstaff|neal martin|jane anson|perrotti|wine independent|kerin o.keefe|jasper morris|"
                  r"gambero rosso|bibenda|guia pe[nñ][ií]n|pe[nñ][ií]n|gault|bettane|rvf|revue du vin|james halliday|\b(?:WA|RP|WS|JS|VM|JD|WE|JR|BH|AG|NM|JA)\b", re.I)
NUM = re.compile(r"(?<![\d.])(?:1[0-9](?:\.5)?/20|[89]\d(?:\+|-[89]\d)?|100)(?![\d.])")
UA = "Mozilla/5.0 (compatible; JeroCatalogBot/1.0; wine price research)"


def clean(html):
    html = re.sub(r"<(script|style|noscript|svg)\b[^>]*>.*?</\1>", " ", html, flags=re.S | re.I)
    t = re.sub(r"<[^>]+>", " ", html)
    t = re.sub(r"&nbsp;|&#160;", " ", t)
    t = re.sub(r"&amp;", "&", t)
    return re.sub(r"\s+", " ", t)


def page(session, url, delay):
    out = {"url": url, "status": None, "jsonld": [], "snippets": []}
    for i in range(3):
        try:
            r = session.get(url, timeout=30)
        except requests.RequestException:
            time.sleep(3 + 5 * i); continue
        out["status"] = r.status_code
        if r.status_code == 429 or r.status_code >= 500:
            time.sleep(min(float(r.headers.get("Retry-After") or 0) or 10 * (i + 1), 60)); continue
        break
    else:
        return out
    if out["status"] != 200:
        return out
    html = r.text
    for m in re.finditer(r'<script[^>]+application/ld\+json[^>]*>(.*?)</script>', html, re.S | re.I):
        s = m.group(1)
        if re.search(r"rating|review", s, re.I):
            out["jsonld"].append(s.strip()[:3000])
    text = clean(html)
    seen = set()
    for m in CRIT.finditer(text):
        a, b = max(0, m.start() - 120), min(len(text), m.end() + 120)
        snip = text[a:b]
        if NUM.search(snip) and snip not in seen:
            seen.add(snip); out["snippets"].append(snip)
        if len(out["snippets"]) >= 12:
            break
    time.sleep(delay)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="shop-data")
    ap.add_argument("--out", default="score-pages")
    ap.add_argument("--sample", type=int, default=0)
    ap.add_argument("--full", default="")
    ap.add_argument("--delay", type=float, default=0.7)
    ap.add_argument("--workers", type=int, default=12)
    ap.add_argument("--budget", type=int, default=19000, help="seconds per shop")
    a = ap.parse_args()
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from wine_clean import is_nonwine
    os.makedirs(a.out, exist_ok=True)
    hosts = a.full.split(",") if a.full else [f[:-9] for f in os.listdir(a.data) if f.endswith(".jsonl.gz") and not f.endswith(".pages.jsonl.gz")]

    def one(host):
        prods = [json.loads(l) for l in gzip.open(os.path.join(a.data, host + ".jsonl.gz"), "rt")]
        urls = [p["url"] for p in prods if p.get("variants") and not is_nonwine(p["title"], p.get("type", ""), p.get("tags", []))]
        if a.sample:
            random.Random(7).shuffle(urls); urls = urls[:a.sample]
        s = requests.Session(); s.headers.update({"User-Agent": UA})
        t0 = time.time(); n = hit = 0
        with gzip.open(os.path.join(a.out, host + ".pages.jsonl.gz"), "wt", encoding="utf-8") as f:
            for u in urls:
                if time.time() - t0 > a.budget:
                    break
                r = page(s, u, a.delay); n += 1
                hit += bool(r["snippets"] or r["jsonld"])
                f.write(json.dumps(r, ensure_ascii=False) + "\n")
        print(f"{host:40} pages {n:6}  with critic text {hit:6}  {round(time.time() - t0)}s", flush=True)
        return host, {"pages": n, "with_scores": hit}

    with ThreadPoolExecutor(a.workers) as ex:
        rep = dict(ex.map(one, hosts))
    json.dump(rep, open(os.path.join(a.out, "score_pages_report.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
