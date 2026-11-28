"""Black Market (blackmarket.co.nz) sells wine in packs and its Shopify price is the price of the whole pack (6 bottles for most
wines, 3 for premium ones, 12 for some), although its page shows the per-bottle price ("$19.99 p/btl" = 119.94 for six).
The pack size is in no field: it shows in the price, which is the pack size times a per-bottle price ending .99/.49/.95/.50/.00/.90.

Run after merge_prices.py (it patches content/prices/wine_prices.csv in place), then build_app_wines.py and build_app_prices.py.
shopify_to_sources.py applies the same rule (shop flag "packs" in shops.json), so a full rebuild gives the same prices.
"""
import csv, os, re, statistics as S, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PATH = os.path.join(ROOT, "content/prices/wine_prices.csv")
RATES = {'EUR': 1.0, 'GBP': 0.83735, 'USD': 1.0990, 'AUD': 1.6487, 'CAD': 1.5723, 'NZD': 1.9968, 'CHF': 0.9223}
PACK_SHOPS = {"Black Market"}

def pack_of(price):
    """The pack size a pack price stands for (6, 3, 12, 2), else 6 (the shop's usual pack)."""
    c = round(price * 100)
    for k in (6, 3, 12, 2):
        if c % k == 0 and (c // k) % 100 in (99, 49, 95, 50, 0, 90):
            return k
    return 1 if c % 100 in (99, 49, 95) else 6

ENTRY = re.compile(r"^(?P<shop>.+?) \((?P<loc>[^)]*)\): (?P<price>[\d.]+) (?P<cur>[A-Z]{3})$")

def main():
    rows = list(csv.DictReader(open(PATH, newline="", encoding="utf-8")))
    cols = list(rows[0].keys())
    fixed = 0
    for r in rows:
        if not any(s + " (" in r["prices"] for s in PACK_SHOPS):
            continue
        links = {}
        for part in r["links"].split(" ; "):
            if ": " in part:
                s, u = part.split(": ", 1); links.setdefault(s.strip(), u.strip())
        offers = []
        for part in r["prices"].split(" ; "):
            m = ENTRY.match(part.strip())
            if not m:
                offers = None; break
            p = float(m["price"])
            if m["shop"] in PACK_SHOPS:
                p = p / pack_of(p)
            offers.append(dict(shop=m["shop"], loc=m["loc"], price=p, cur=m["cur"], eur=p / RATES[m["cur"]], url=links.get(m["shop"], "")))
        if not offers:
            continue
        med = S.median(o["eur"] for o in offers)
        use = [o for o in offers if med / 2.5 <= o["eur"] <= med * 2.5] or offers
        if (int(r["size_ml"] or 750) and min(o["eur"] for o in use) / RATES["EUR"] * 750 / int(r["size_ml"] or 750) < 1):
            continue
        pe = [o["eur"] for o in use]; avg = S.mean(pe)
        use.sort(key=lambda o: o["eur"])
        r.update({'avg_price_gbp': f"{avg*RATES['GBP']:.2f}", 'avg_price_eur': f'{avg:.2f}', 'avg_price_usd': f"{avg*RATES['USD']:.2f}",
                  'min_price_gbp': f"{min(pe)*RATES['GBP']:.2f}", 'max_price_gbp': f"{max(pe)*RATES['GBP']:.2f}",
                  'shops_count': len(use),
                  'prices': ' ; '.join(f"{o['shop']} ({o['loc']}): {o['price']:.2f} {o['cur']}" for o in use),
                  'cheapest_link': use[0]['url'] or r['cheapest_link'],
                  'links': ' ; '.join(f"{o['shop']}: {o['url']}" for o in use if o['url'])})
        fixed += 1
    w = csv.DictWriter(open(PATH, "w", newline="", encoding="utf-8"), fieldnames=cols)
    w.writeheader(); w.writerows(rows)
    print(f"{fixed} rows with pack prices fixed")

if __name__ == "__main__":
    main()
