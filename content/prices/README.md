# Wine prices (checked 2026-11-22)

- `wine_prices.csv` — the merged list: one row per wine + vintage + bottle size (about 189k wines). Duplicates are merged and,
  when a wine is sold by several shops, the price is the average of one price per shop (in-stock prices preferred,
  outliers more than 2.5x off the median dropped). Prices in GBP, EUR and USD (ECB rates of 2026-11-20:
  1 EUR = 0.83735 GBP = 1.0990 USD). `prices` lists every shop price used (cheapest first);
  `links` has the matching product page for each price, and `cheapest_link` the cheapest one.
- `sources/uk_supermarkets.csv` — Tesco, Sainsbury's, Waitrose, Morrisons, Asda, Aldi, Iceland (via trolley.co.uk).
- `sources/us_wine_shops.csv` — Zachys, Flatiron Wines (NY, SF), Verve, Vintage Berkeley, Leon & Son, Thatcher's.
- `sources/europe_wine_shops.csv` — Hedonism, The Good Wine Shop, Highbury Vintners, Secret Bottle Shop,
  Shrine to the Vine (UK), Le Petit Ballon (FR), Tannico (IT).
- `sources/more_wine_shops.csv` — Primal Wine, Mysa, Domestique, Wine Therapy, Helen's Wines, Keg n Bottle (US),
  Camperdown Cellars (AU), Zyn (Canada), Tanners (UK), Drops (Germany).
- `sources/more_wine_shops_2.csv` — CaskCartel (US, ~48k wines), Wine Chateau (NJ), Chambers Street Wines, Crush (NY),
  Last Bottle (US), Great Wines Direct (UK), Black Market (New Zealand). Hedonism is now its full catalogue (fetched per collection). AUD/CAD/NZD at ECB rates (1 EUR = 1.6487 AUD = 1.5723 CAD = 1.9968 NZD).

Matching across shops is by name words + vintage + size, so a few matches may be wrong. Supermarket wines
mostly have no vintage. Rebuild: `python3 tools/prices/merge_prices.py content/prices/wine_prices.csv`.
Personal use only.
