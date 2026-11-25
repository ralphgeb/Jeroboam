# Wine prices (harvested 2026-11-25)

- `wine_prices.csv` — the merged list: one row per wine + vintage + bottle size (about 197k wines from 80 shops).
  Duplicates are merged and, when a wine is sold by several shops, the price is the average of one price per shop (in-stock prices preferred,
  outliers more than 2.5x off the median dropped). Prices in GBP, EUR and USD (ECB rates of 2026-11-20:
  1 EUR = 0.83735 GBP = 1.0990 USD = 1.6487 AUD = 1.5723 CAD = 1.9968 NZD = 0.9223 CHF). `prices` lists every shop price used (cheapest first);
  `links` has the matching product page for each price, and `cheapest_link` the cheapest one.
- `wine_details.csv` — the same rows with colour, country, region, appellation, grapes, blend, aromas, notes and critics' scores (below).

## How the list is built
1. **Harvest** (GitHub runner; this dev container cannot reach the shops): `.github/workflows/harvest_shops.yml` runs
   `tools/prices/harvest_shopify.py` once per shop in `tools/prices/shops.json` and pushes each shop's raw catalogue to the
   `shop-data` branch (`<host>.jsonl.gz` = every product with its price options, tags and description text; `<host>.report.json`).
   A push to a `claude/**` branch only fills in shops missing from `shop-data`; run the workflow by hand (empty input) to refresh every shop.
2. **Clean** (`tools/prices/shopify_to_sources.py <shop-data dir>` -> `sources/shopify_shops.csv.gz`, report in `sources/shopify_report.md`),
   rules in `tools/prices/wine_clean.py`:
   - *Not wine* is dropped: spirits, beer, cider, sake, alcohol-free drinks, food, glasses and accessories, gift cards, mixed cases and
     bundles, tastings and events, subscriptions, deposits. Wines in gift packaging ("in wooden gift box") stay.
     Shops whose catalogue is mostly not wine are dropped whole (In Vintage Tokyo, Nourished Communities, Good Earth Shop are blocked).
   - *Fake producers* are removed: shop "vendor" fields often hold the importer (Skurnik, Polaner, Zev Rovine …), a consignor code
     ("Private - DCMA26"), a Canadian agent number ("300146 - Mark Anthony …") or the shop's own name. The producer then comes from the
     shop's tags ("Wine Producer > Leonetti", "Brand: Contino"), the title ("Producer, Wine" / "Producer - Wine"), a dictionary of known
     producers found anywhere in the name ("Barolo Vignarionda **Luigi Pira** 2018"), or the words before the first place/grape/vintage.
     `producer_source` in shopify_shops.csv.gz says which. The dictionary also learns from the current `wine_prices.csv` (names that appear
     in their own wine names), so a rebuild can improve a few producers. When the shop leaves the producer out of the name it is added
     ("Chardonnay 2024" -> "Carsten Saalwächter Chardonnay 2024").
   - Prices are per bottle: every price option of a product is read (bottle, magnum, case of 6 …); case prices are divided by the
     number of bottles, cases of unknown size are skipped. Prices below 4 EUR per 75 cl, spreadsheet dates in the price field
     (Le Petit Ballon puts e.g. 45580 on sold-out wines) and prices 500x a shop's median are dropped.
   - Each shop's currency is the one in shops.json (the storefront currency seen from the runner is only reported).
3. **Keep old facts**: `tools/prices/legacy_details.py sources/shopify_shops.csv.gz <folder with the previous csv files>` writes
   `sources/legacy_details.csv`: full facts for sources that are not re-harvested, and the critics' scores of every old product page
   (the earlier build also read scores from product pages).
4. **Merge**: `python3 tools/prices/merge_prices.py content/prices/wine_prices.csv` (Shopify offers + the sources below).
5. **Details**: `python3 tools/prices/enrich_details.py <shop-data dir>`.
6. **App files**: `python3 tools/prices/build_app_wines.py` (content/prices/app_wines.tsv.z) and `python3 tools/prices/build_app_prices.py`
   (Jeroboam/Resources/Prices/prices.tsv). Phones download them from `main` (see LIVE_PRICES.md).

## Sources
- Shopify shops (`sources/shopify_shops.csv.gz`, 68 shops): UK — Hedonism, Highbury Vintners, Shrine to the Vine, The Good Wine Shop,
  Secret Bottle Shop, BGWM, Field & Fawcett, Great Wines Direct, Tanners, Chapel Down, Newcomer Wines, Parched, D Vine Cellars, Hard to Find Wines,
  Wayward, Uncharted, Modal, Montys, Wine Boutique, Top Cuvée, The Winemakers Club, Twelve Green Bottles, Pandemonium, Ake & Humphris, Exton Park;
  US — Zachys, Flatiron (NY, SF), Leon & Son, Thatcher's, Verve, Vintage Berkeley, Chambers Street, Crush, Wine Chateau, Wine Therapy, Primal,
  Mysa, Domestique, Helen's, Keg n Bottle, Last Bottle, Sotheby's Wine, Parcelle, Biondivino, Vin Chicago, Vino Fine Wine, ALLY, Flight, Merchant of Wine;
  Europe — Le Petit Ballon (FR), Tannico (IT), Drops (DE), Schenk (CH), The Corkscrew and Wine Online (IE), More Natural Wine, Natural Wine Dealers,
  NU Wines, OneDerWine, The Wine Buff; Canada — Zyn, The Living Vine; Australia — P&V, Camperdown, Aylesbury Estate; New Zealand — Black Market, Pask.
- `sources/uk_supermarkets.csv` — Tesco, Sainsbury's, Waitrose, Morrisons, Asda, Aldi, Iceland (via trolley.co.uk; not Shopify, kept as is;
  rows need a sign of wine — grape, wine place or wine word — so flutes, soups and cakes are left out).
- `sources/other_shops.csv` — shops that are not on Shopify: English wineries Grape Britannia, Lyme Bay, Ridgeview.
  (The older per-source lists `us_wine_shops.csv`, `europe_wine_shops.csv`, `more_wine_shops*.csv` were removed in Nov 2026: every shop in
  them is now re-harvested with full descriptions. They are in git history if ever needed.)
- `sources/reseller_only.csv` — CaskCartel, a reseller that relists other shops' wines at large markups. **Last resort only**: a CaskCartel
  offer is kept only when no other shop sells that wine + vintage + size (rows say `price_note = high reseller price`, shown as
  "CaskCartel (high reseller price)"); as soon as any shop sells it, the CaskCartel price is dropped. CaskCartel is never harvested.
- `sources/manual_overrides.csv` — the owner's fixes (price + cheapest link; adds the wine when no shop lists it).

Matching across shops is by name words + vintage + size, so a few matches may be wrong. Supermarket wines mostly have no vintage. Personal use only.

## Wine details (`wine_details.csv`)
Same rows as `wine_prices.csv` (wine + vintage + size) with: colour, country, region, appellation, grapes, aromas,
notes, avg_score, scores, score_links, details_link.
- Places come from the shops' own tags first ("Region > Red Mountain", "region_Itata Valley", "Origin_Gigondas", "Country: France"),
  then from `content/regions.yaml` (+ a list of common appellations in the script) matched in the wine's name, then in the shop description.
- Facts that don't change with the vintage (place, grapes, colour, aromas) are shared between vintages and sizes of the same wine;
  single-grape appellations give the grape (Barolo -> Nebbiolo, Sancerre -> Sauvignon Blanc …).
- `grape_blend` (e.g. `Merlot 60%, Cabernet Franc 35%, Cabernet Sauvignon 5%`) is read from shop descriptions; `blend_source` says
  `shop description`, `shop description (other size)` or `appellation rule` (100% for single-grape appellations such as Barolo or Chablis).
- `aromas_source`: `shop description`, `shop description (other vintage)` or `typical for <grape>` (from content/grapes.yaml when no description names any).
- Aromas use the app's aroma wheel words (`content/aromas.yaml`) found in the shop descriptions.
- `notes` is a short summary generated from these facts (shop and critic texts are copyrighted, so they are not copied);
  `details_link` opens a shop page with the full description.
- Scores are critics' scores quoted on the shop pages (Wine Advocate, Wine Spectator, James Suckling, Vinous, Jeb Dunnuck,
  Burghound, Decanter, Wine Enthusiast, Jancis Robinson /20 …), plus the ones kept from the previous build. `avg_score` averages the
  100-point scores; `score_links` are the shop pages that quote them (the critics' own sites need a subscription).
- Filled in (2026-11-25): colour 96%, country 93%, region 87%, appellation 49%, grapes 86%, blend 32%, aromas 88%, critics' score 8.5% (16.7k wines); producer known for 98.5%.
