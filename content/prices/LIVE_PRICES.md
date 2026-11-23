# Live Journal prices (no new build needed)

How it works: the app downloads `Jeroboam/Resources/Prices/prices.tsv` from this public repository (raw.githubusercontent.com,
`main` branch) at most every 6 hours, only when it changed (ETag), and uses it instead of the copy inside the app.
The copy inside the app is the offline fallback.

To change prices:
1. Update `content/prices/wine_prices.csv` (the database export).
2. Run `python3 tools/prices/build_app_prices.py` (writes `Jeroboam/Resources/Prices/prices.tsv`).
3. Commit and push to `main`. Phones pick it up on their next app start (within ~6 h; raw.githubusercontent caches ~5 min).

To use a real database instead: export the same TSV from it on a schedule (GitHub Action cron or a Cloudflare Worker cron writing to R2),
and set the build secret/setting `JeroPriceListURL` (Info.plist key) to that file's public address. Nothing else changes.
Shared per-wine prices (backend/cloudflare) remain optional and separate.
