# Wine prices (checked 2026-11-22)

- `wine_prices.csv` — the merged list: one row per wine + vintage + bottle size (about 164k wines). Duplicates are merged and,
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
- `sources/more_wine_shops_2.csv` — Wine Chateau (NJ), Chambers Street Wines, Crush (NY),
  Last Bottle (US), Great Wines Direct (UK), Black Market (New Zealand). Hedonism is now its full catalogue (fetched per collection).
  Niche specialists: BGWM (London; Greek, Lebanese, Georgian…), Sotheby's Wine (NY), Field & Fawcett (York). English wine: Chapel Down, Grape Britannia, Lyme Bay, Ridgeview.
  Ireland: The Corkscrew, Wine Online. Switzerland: Schenk (CHF at ECB rate 1 EUR = 0.9223 CHF). AUD/CAD/NZD at ECB rates (1 EUR = 1.6487 AUD = 1.5723 CAD = 1.9968 NZD).

Matching across shops is by name words + vintage + size, so a few matches may be wrong. Supermarket wines
mostly have no vintage. Rebuild: `python3 tools/prices/merge_prices.py content/prices/wine_prices.csv`.
Personal use only.

## Wine details (`wine_details.csv`)
Same rows as `wine_prices.csv` (wine + vintage + size) with: colour, country, region, appellation, grapes, aromas,
notes, avg_score, scores, score_links, details_link.
- Places come from the shops' own tags first, then from `content/regions.yaml` (+ a list of common appellations in the
  script) matched in the wine's name, then in the shop description.
- Facts that don't change with the vintage (place, grapes, colour, aromas) are shared between vintages and sizes of the same wine;
  single-grape appellations give the grape (Barolo -> Nebbiolo, Sancerre -> Sauvignon Blanc …).
- `grape_blend` (e.g. `Merlot 60%, Cabernet Franc 35%, Cabernet Sauvignon 5%`) is read from shop descriptions; `blend_source` says
  `shop description`, `shop description (other size)` or `appellation rule` (100% for single-grape appellations such as Barolo or Chablis).
- `aromas_source`: `shop description`, `shop description (other vintage)` or `typical for <grape>` (from content/grapes.yaml when no description names any).
- Aromas use the app's aroma wheel words (`content/aromas.yaml`) found in the shop descriptions.
- `notes` is a short summary generated from these facts (shop and critic texts are copyrighted, so they are not copied);
  `details_link` opens a shop page with the full description.
- Scores are critics' scores quoted on the shop pages (Wine Advocate, Wine Spectator, James Suckling, Vinous, Jeb Dunnuck,
  Burghound, Decanter, Wine Enthusiast, Jancis Robinson /20 …). `avg_score` averages the 100-point scores;
  `score_links` are the shop pages that quote them (the critics' own sites need a subscription).
Rebuild: `python3 tools/prices/enrich_details.py <folder of shop catalogue JSONL>`.

CaskCartel was removed (Nov 2026): it resells other shops' wines (Hedonism, Wine Online Delivery, Best of Wines …) at large markups.
Wines it shared with other shops keep those shops' prices; wines only it sold were dropped. Manual fixes live in `sources/manual_overrides.csv`.
Exception: 634 producers that no other shop sells (about 1,180 wines) are kept from CaskCartel in `sources/reseller_only.csv`;
their rows say `price_note = high reseller price` in wine_prices.csv and the shop is shown as "CaskCartel (high reseller price)".
