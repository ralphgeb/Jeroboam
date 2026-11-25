#!/usr/bin/env python3
"""Keeps the facts of the previous build (country, region, grapes, blend, shop aromas, scores) for offers whose shop is not
re-harvested from Shopify (UK supermarkets, English wineries, shops the last harvest could not reach), keyed by product URL:
content/prices/sources/legacy_details.csv. enrich_details.py uses it when it has no shop description for a URL.
Run BEFORE merge_prices.py / enrich_details.py overwrite the old files:
    python3 tools/prices/legacy_details.py content/prices/sources/shopify_shops.csv"""
import csv, os, sys
from urllib.parse import urlparse
csv.field_size_limit(10**9)
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
P = os.path.join(ROOT, 'content/prices/')
harvested = {urlparse(r['url']).netloc for r in csv.DictReader(open(sys.argv[1], encoding='utf-8'))}
dets = {(r['wine'], r['producer'], r['vintage'], r['size_ml']): r for r in csv.DictReader(open(P + 'wine_details.csv', encoding='utf-8'))}
cols = ['url', 'color', 'country', 'region', 'appellation', 'grapes', 'grape_blend', 'blend_source', 'aromas', 'aromas_source', 'scores']
out = {}
for r in csv.DictReader(open(P + 'wine_prices.csv', encoding='utf-8')):
    d = dets.get((r['wine'], r['producer'], r['vintage'], r['size_ml']))
    if not d:
        continue
    for part in r['links'].split(' ; '):
        if ': ' not in part:
            continue
        u = part.split(': ', 1)[1].strip()
        if urlparse(u).netloc in harvested:
            continue
        out.setdefault(u, {c: d.get(c, '') for c in cols if c != 'url'} | {'url': u})
with open(P + 'sources/legacy_details.csv', 'w', newline='', encoding='utf-8') as f:
    w = csv.DictWriter(f, fieldnames=cols); w.writeheader(); w.writerows(out.values())
print('legacy facts for', len(out), 'product pages')
