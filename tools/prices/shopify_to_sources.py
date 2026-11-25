#!/usr/bin/env python3
"""Raw Shopify catalogues (shop-data branch, made by harvest_shopify.py) -> content/prices/sources/shopify_shops.csv

One row per wine offer (product x bottle size) with a per-bottle price. Drops what is not wine, resolves the real producer
(shop 'vendor' fields often hold the importer, a consignor code or the shop's own name) and puts the producer in the wine
name when the shop leaves it out ('Chardonnay 2024' -> 'Carsten Saalwächter Chardonnay 2024').
Also writes content/prices/sources/shopify_report.md (per shop: products, kept, why the rest was dropped).

Run: python3 tools/prices/shopify_to_sources.py <shop-data dir>
"""
import collections as C, csv, glob, gzip, json, os, re, sys
from urllib.parse import urlparse

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
from wine_clean import (fold, toks, is_nonwine, wine_signal, size_ml, pack_count, vintage_of, NOT_PRODUCER, names_in_title,
                        lead_segment, key_tokens, tidy_title, SIZES, STYLE_WORDS)
import enrich_details as ED   # grape and place dictionaries (content/grapes.yaml, regions.yaml)

RATES = {'EUR': 1.0, 'GBP': 0.83735, 'USD': 1.0990, 'AUD': 1.6487, 'CAD': 1.5723, 'NZD': 1.9968, 'CHF': 0.9223}
REGION = [('US', 'US wine shop'), ('UK', 'UK wine shop'), ('Australia', 'Australia wine shop'), ('Canada', 'Canada wine shop'),
          ('New Zealand', 'New Zealand wine shop'), ('Ireland', 'Ireland wine shop'), ('Switzerland', 'Switzerland wine shop')]
SHOP_WORDS = set("wine wines shop store cellar cellars merchant merchants co company the and online direct boutique market emporium".split())


def region_label(loc):
    for k, v in REGION:
        if loc.endswith(k):
            return v
    return 'EU wine shop'


def place_or_grape(seg):
    f = fold(seg).strip()
    return bool(f) and (ED.GRAPE_RX.fullmatch(f) or ED.PLACE_RX.fullmatch(f) or ED.COUNTRIES.get(f)) is not None


STOPPER = re.compile(r"^(?:(?:19|20)\d\d\b|nv\b|\d|['\"\u2018\u201c(])")


def name_prefix(title):
    words = re.sub(r"^\s*(?:(?:19|20)\d\d|NV)\s+", "", title).split()
    for i, w in enumerate(words):
        rest = fold(' '.join(words[i:i + 4]))
        if STOPPER.match(rest) or ED.PLACE_RX.match(rest) or ED.GRAPE_RX.match(rest) or STYLE_WORDS.match(rest) or rest.startswith(('cabernet', 'pinot', 'sauvignon')):
            if 1 <= i <= 4:
                pre = ' '.join(words[:i]).strip(" ,-'")
                f = fold(pre).strip()
                if pre[:1].isupper() and len(f) >= 3 and not NOT_PRODUCER.match(f) and not ED.PLACE_RX.fullmatch(f) and f not in ED.COUNTRIES:
                    return pre
            return ''
    return ''


def main():
    src = sys.argv[1]
    cfg = json.load(open(os.path.join(HERE, 'shops.json')))
    shops = {urlparse(s['base']).netloc: s for s in cfg['shops'] if not any(b in s['base'] for b in cfg['blocked'])}
    report = {os.path.basename(f)[:-12]: json.load(open(f)) for f in glob.glob(os.path.join(src, '*.report.json'))}
    checked = (open(os.path.join(src, 'HARVESTED_AT')).read().strip()[:10] if os.path.exists(os.path.join(src, 'HARVESTED_AT')) else '')

    # ---- 1. read everything, decide what is wine
    prods, why = [], C.defaultdict(C.Counter)
    for f in sorted(glob.glob(os.path.join(src, '*.jsonl.gz'))):
        host = os.path.basename(f)[:-9]
        if host not in shops:
            continue
        for line in gzip.open(f, 'rt', encoding='utf-8'):
            p = json.loads(line)
            p['host'] = host
            p['title'] = tidy_title(p['title'])
            why[host]['products'] += 1
            if not p['title'] or not p['variants']:
                why[host]['empty'] += 1; continue
            if is_nonwine(p['title'], p['type'], p['tags']):
                why[host]['not wine'] += 1; continue
            if not wine_signal(p['title'], p['type'], p['tags'], ED.GRAPE_RX, ED.PLACE_RX):
                why[host]['no wine signal'] += 1; continue
            prods.append(p)

    # ---- 2. which shops are real wine shops (candidates and new shops must be mostly wine)
    keep_host = {}
    for h, w in why.items():
        share = (w['products'] - w['not wine'] - w['no wine signal'] - w['empty']) / max(1, w['products'])
        st = shops[h].get('status')
        keep_host[h] = share >= (0.25 if st == 'existing' else 0.4) and w['products'] >= 10   # mixed shops keep their wines; non-wine businesses go
    prods = [p for p in prods if keep_host[p['host']]]

    # ---- 3. producers: is the shop's vendor field the producer?
    vstat = C.defaultdict(lambda: [0, 0])          # (host, vendor) -> [products, titles naming the vendor]
    lead_rate = C.Counter()
    for p in prods:
        v = vstat[(p['host'], p['vendor'])]; v[0] += 1
        if p['vendor'] and names_in_title(p['vendor'], p['title']): v[1] += 1
        if lead_segment(p['title']): lead_rate[p['host']] += 1
    per_host = C.Counter(p['host'] for p in prods)
    shop_toks = {h: set(toks(s['name'])) - SHOP_WORDS for h, s in shops.items()}
    all_shop_names = {fold(s['name']).strip() for s in shops.values()}

    def vendor_ok(host, vendor):
        if not vendor or NOT_PRODUCER.match(fold(vendor).strip()):
            return False
        vt = set(toks(vendor)) - SHOP_WORDS
        if fold(vendor).strip() in all_shop_names or (vt and vt <= shop_toks[host]):
            return False
        n, m = vstat[(host, vendor)]
        if m / n >= 0.3:
            return True
        # shop titles that leave the producer out (Newcomer: 'Chardonnay 2024'): a small vendor is the producer
        titles_lead = lead_rate[host] / max(1, per_host[host])
        return n <= 25 and titles_lead < 0.35

    good_vendor = {k: vendor_ok(*k) for k in vstat}
    canon = {}                                      # folded -> spelling as written (vendors first, then titles, then the old list)
    spell = C.defaultdict(C.Counter)
    dictionary = C.Counter()
    for (h, v), ok in good_vendor.items():
        if ok:
            dictionary[fold(v).strip()] += vstat[(h, v)][0]
    def seg_ok(seg):
        f = fold(seg).strip()
        return bool(f) and not place_or_grape(seg) and not NOT_PRODUCER.match(f) and not STYLE_WORDS.search(f) \
            and not ED.GRAPE_RX.search(f) and not ED.PLACE_RX.match(f) and len(f.split()) <= 5 and not re.search(r"\d", f)
    for p in prods:
        seg = lead_segment(p['title'])
        if seg and seg_ok(seg):
            dictionary[fold(seg).strip()] += 1
            spell[fold(seg).strip()][seg] += 1
    # genuine producers of the previous list (their name is in their own wine names)
    import csv as _csv
    _csv.field_size_limit(10**9)
    oldp = os.path.join(ROOT, 'content/prices/wine_prices.csv')
    if os.path.exists(oldp):
        seen = C.Counter()
        for r in _csv.DictReader(open(oldp, encoding='utf-8')):
            pr = r['producer'].strip()
            if pr and not NOT_PRODUCER.match(fold(pr).strip()) and names_in_title(pr, r['wine']) and seg_ok(pr) or (pr and not STYLE_WORDS.search(fold(pr)) and fold(pr).strip() in fold(r['wine']) and not NOT_PRODUCER.match(fold(pr).strip())):
                seen[fold(pr).strip()] += 1
                spell[fold(pr).strip()][pr] += 1
        for k, n in seen.items():
            if n >= 2: dictionary[k] += n
    for (h, v), ok in good_vendor.items():
        if ok: canon.setdefault(fold(v).strip(), v)
    COMMON = set(ED.GRAPES) | set(ED.PLACES) | set(ED.COUNTRIES)
    DICT, DICT_NAME = {}, {}
    for k, n in dictionary.items():
        kt = ' '.join(toks(k))
        if n >= 2 and len(kt) >= 4 and kt not in COMMON and not STYLE_WORDS.fullmatch(kt):
            if n > DICT.get(kt, 0): DICT[kt] = n; DICT_NAME[kt] = k
    # nicest spelling for dictionary names: the most common original casing seen in titles/vendors
    for (h, v), ok in good_vendor.items():
        if ok: canon.setdefault(fold(v).strip(), v)
    for k, c in spell.items():
        # prefer a mixed-case spelling (not ALL CAPS) with accents
        best = sorted(c.items(), key=lambda kv: (kv[0].isupper(), kv[0].islower(), -sum(ord(ch) > 127 for ch in kv[0]), -kv[1]))[0][0]
        canon.setdefault(k, best)
    def producer_of(p):
        v = p['vendor']
        if good_vendor.get((p['host'], v)):
            return v, 'vendor'
        seg = lead_segment(p['title'])
        if seg and seg_ok(seg) and (dictionary[fold(seg).strip()] >= 2 or lead_rate[p['host']] / max(1, per_host[p['host']]) >= 0.5):
            return canon.get(fold(seg).strip(), seg), 'title'
        # a known producer anywhere in the name (Zachys: 'Barolo Vignarionda Luigi Pira 2018'): longest match wins
        tt = toks(p['title'])
        for n in range(min(6, len(tt)), 0, -1):
            for i in range(len(tt) - n + 1):
                k = ' '.join(tt[i:i + n])
                if k in DICT and (n > 1 or DICT[k] >= 4 and len(k) >= 5) and not (i + n < len(tt) and tt[i + n] == 's'):
                    return canon.get(DICT_NAME[k], DICT_NAME[k].title() if DICT_NAME[k].islower() else DICT_NAME[k]), 'dictionary'
        # the words before the first place, grape, style word or vintage ('Sandalford Margaret River Shiraz 2020')
        pre = name_prefix(p['title'])
        if pre:
            return pre, 'name'
        return '', 'unknown'

    # ---- 4. offers: one per bottle size, per-bottle price
    out, stats = [], C.defaultdict(C.Counter)
    for p in prods:
        h = p['host']; s = shops[h]; rep = report.get(h, {})
        cur = s['currency']
        if rep.get('storefront_currency') and rep['storefront_currency'] != cur and rep.get('storefront_rate') in ('1.0', '1'):
            cur = rep['storefront_currency']
        if cur not in RATES:
            stats[h]['currency?'] += 1; continue
        prod, how = producer_of(p)
        stats[h]['producer ' + how] += 1
        name = p['title']
        if prod and not names_in_title(prod, name):
            name = f'{prod} {name}'
        single = len(p['variants']) == 1
        best = {}
        for v in p['variants']:
            vt = '' if v['title'] in ('Default Title', 'Default') else v['title']
            if vt and is_nonwine(vt):
                continue
            try:
                price = float(v['price'] or 0)
            except ValueError:
                continue
            if price <= 0:
                continue
            ml = size_ml(vt, p['title']) or 750
            pk = pack_count(vt) if vt else 1
            if pk == 1 and not (vt and re.search(r'(?i)\b(single|bottle|btl|each|1\s*x)\b', vt)):
                pk = pack_count(p['title'])   # 'Case of 6', 'Three Bottle OWC' in the product name
            if pk == -1:
                stats[h]['case of unknown size'] += 1; continue
            per = price / pk
            vint = vintage_of(p['title']) or (vt if re.fullmatch(r'(19|20)\d\d', vt.strip()) else '') or vintage_of('', vt)
            eur750 = per / RATES[cur] * 750 / ml
            if eur750 < 4 or eur750 > 60000:
                stats[h]['implausible price'] += 1; continue
            k = (vint, ml)
            cand = (pk != 1, per, v['available'])
            if k not in best or cand < best[k][0]:
                best[k] = (cand, per, v['available'], ml, vint)
        if not best:
            stats[h]['no usable price'] += 1; continue
        for (vint, ml), (_, per, avail, _, _) in best.items():
            out.append({'shop': s['name'], 'location': s['location'], 'sold_in': region_label(s['location']), 'wine_name': name,
                        'producer': prod, 'producer_source': how, 'vintage': vint, 'size': f'{ml}ml', 'price': f'{per:.2f}', 'currency': cur,
                        'in_stock': 'yes' if avail else 'no', 'url': p['url'], 'checked': checked})
            stats[h]['offers'] += 1

    out.sort(key=lambda r: (r['shop'], fold(r['wine_name']), r['vintage'], r['size']))
    cols = list(out[0].keys())
    with open(os.path.join(ROOT, 'content/prices/sources/shopify_shops.csv'), 'w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=cols); w.writeheader(); w.writerows(out)

    # ---- 5. report
    L = [f'# Shopify harvest ({checked})', '', 'Per shop: products in the catalogue, what was dropped and why, wine offers kept, how the producer was found.', '',
         '| shop | status | currency | products | not wine | no wine signal | kept offers | producer from vendor / title / dictionary / unknown | note |',
         '|---|---|---|---|---|---|---|---|---|']
    for h, s in sorted(shops.items(), key=lambda kv: kv[1]['name']):
        w = why.get(h, C.Counter()); st = stats.get(h, C.Counter()); rep = report.get(h, {})
        note = rep.get('error') or ('' if keep_host.get(h, False) else 'dropped: not a wine catalogue') if w['products'] else (rep.get('error') or 'no data')
        if rep.get('storefront_currency') and rep['storefront_currency'] != s['currency']:
            note += f" storefront shows {rep['storefront_currency']} (rate {rep.get('storefront_rate')})"
        L.append(f"| {s['name']} ({h}) | {s.get('status')} | {s['currency']} | {w['products']} | {w['not wine']} | {w['no wine signal']} | {st['offers']} | "
                 f"{st['producer vendor']} / {st['producer title']} / {st['producer dictionary']} / {st['producer unknown']} | {note.strip()} |")
    L += ['', f'Total offers: {len(out)} from {len({r["shop"] + r["location"] for r in out})} shops.']
    open(os.path.join(ROOT, 'content/prices/sources/shopify_report.md'), 'w').write('\n'.join(L) + '\n')
    print('\n'.join(L[-1:]))
    print('kept hosts', sum(keep_host.values()), 'of', len(keep_host))


if __name__ == '__main__':
    main()
