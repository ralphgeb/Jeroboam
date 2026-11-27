# Jero — launch checklist (27 Nov 2026)

What is left before Jero goes to the App Store, and what to change before it has many paying customers.
To be discussed with Ralph; nothing here is done unless it is ticked.

## A. Before submitting to App Review

- [ ] **Build for review with the switch on.** GitHub > Actions > "build-ios" > Run workflow > tick **"For App Store review"**.
      That build never shows the TestFlight section or the test checkout (reviewers get a sandbox receipt, like TestFlight,
      so a normal build would show them the free test checkout: likely rejection). TestFlight builds: leave it unticked.
- [ ] **Jero Plus subscription metadata.** App Store Connect > Subscriptions > Jero Plus: add the review screenshot (state is
      "Missing metadata" until then). A first review fails without it.
- [ ] **Attach Jero Plus to the version** (version page > In-App Purchases and Subscriptions).
- [ ] **Age rating questionnaire:** answer the alcohol questions truthfully (expect 17+ / 18+).
- [ ] **App Privacy answers** must match APP_STORE_LISTING.md §5: Photos (label photo when the text is unclear, and a numeric
      fingerprint of the label), Other User Content (label text), Product Interaction (anonymous wine count), Device ID (random
      install number). All "not linked to you", "not used for tracking", purpose App Functionality.
- [ ] **Privacy policy page loads** (GitHub Pages on for /docs) and its link is in App Store Connect.
- [ ] **One-time notice before the first scan** (suggested, not built): "Label photos are sent to Anthropic's Claude to identify
      the wine" + OK. Apple asks for clear disclosure before personal data goes to a third-party AI; a photo can catch faces or rooms.
- [ ] **Turn off the fingerprint test:** delete `.github/workflows/print-check.yml`, remove the worker secret `GITHUB_TOKEN`,
      hide Settings > TestFlight > Fingerprint check (TestFlight-only anyway).
- [ ] **Delete the old Anthropic API key** in the Anthropic console (the app uses the Cloudflare worker's key since build 67).
- [x] In-app privacy text updated (it said "Jero keeps no servers of its own").
- [x] Paywall has Restore Purchases, Terms of Use, Privacy Policy. No account needed; "Erase all my data" exists.

## B. Before ~1,000 paying customers (settings, not redesign)

| What | Why | Change |
|---|---|---|
| Worker global AI cap (`GLOBAL_DAILY_USD`, default $5/day) | A busy evening of new wines would stop scans for everyone ("daily limit reached") | Raise to $20–30 in Cloudflare (keep the per-phone cap) |
| Cloudflare free plan | 100k requests/day and tight CPU limits; fine now, no margin | Workers Paid, $5/month |
| Anthropic rate limits | A new account has low per-minute limits; a few dozen scans at once could hit them | Add ~$40 credit to move up a tier |
| Wine list download from GitHub (7 MB per install) | GitHub is not meant to serve app downloads and can throttle | Move `app_wines.tsv.z` to Cloudflare R2 (free downloads) |
| Free web pages (DuckDuckGo) | Blocked from servers; more wines fall to the 1.2 c paid search | Brave Search API (~0.3–0.5 c), or accept the cost |
| Shared worker key inside the app | Can be pulled out of the app; only the global cap protects | Later: Apple App Attest |
| Fingerprint test on GitHub | Would start a run per scan for every user | Delete before launch (see A) |
| [x] Worker re-read the whole wines table on each cold start | Would use up free database reads | Fixed (runs once; needs the worker pasted) |

Expected running cost at 1,000 users: AI about $20–40/month (falling as the shared wine list grows), Cloudflare $5,
iCloud free (each user's own). Revenue about $700–840/month after Apple's share.

## C. Open decisions (discuss later)

- Brave Search for the online grape check (test first on the same 50 wines).
- Picture matching: only as a cross-check on the label reading, after the Fingerprint check test (shop-vs-shop was 39% right).
- Merge the most-scanned "new" wines from the online table into the big wine list from time to time.
- Smaller download (On-Demand Resources for Plus-only content), localization, Dynamic Type in Journal/Cellar.
