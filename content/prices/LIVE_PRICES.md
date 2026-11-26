# Live Journal prices (no new build needed)

How it works: the app downloads `content/prices/app_wines.tsv.z` (raw deflate, about 7 MB) from this public repository
(raw.githubusercontent.com, `main` branch): right after install, then at most every 6 hours and only when it changed (ETag).
No list is shipped inside the app (it would add 29 MB to the download); until the first download, lookups use the shared online
list and the estimate. If the first try is offline, the app tries again each time it comes back to the foreground.

To change prices:
1. Update `content/prices/wine_prices.csv` (the database export).
2. Run `python3 tools/prices/build_app_wines.py` (writes `content/prices/app_wines.tsv.z`, what phones download).
   `tools/prices/build_app_prices.py` still writes the plain `content/prices/prices.tsv` for reference; it is not in the app.
3. Commit and push to `main`. Phones pick it up on their next app start (within ~6 h; raw.githubusercontent caches ~5 min).

To use a real database instead: export the same TSV from it on a schedule (GitHub Action cron or a Cloudflare Worker cron writing to R2),
and set the build secret/setting `JeroPriceListURL` (Info.plist key) to that file's public address. Nothing else changes.
Shared per-wine prices (backend/cloudflare) remain optional and separate.
