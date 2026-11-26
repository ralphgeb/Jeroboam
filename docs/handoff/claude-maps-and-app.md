# Claude: maps, app, course and journal

Branch: **`claude/vibrant-ramanujan-g4uz35`** (pushed). `main` is at `4b82399`; everything after that is on the branch only.
Last TestFlight build: **1.0 (65)** = GitHub run 80. Run 82 also uploaded (freeze fix + iCloud status line), probably build 66.
Nothing below the line "Not yet on TestFlight" has been built for TestFlight yet; the branch compiles and passes the 10
logic tests (snapshots.yml, `only: LogicTests`, last run 45826698233).

The project's own rules and the technical detail of each feature are in `CLAUDE.md` (sections "Maps, round 3",
"App round", "Welcome back", "Cellar & journal round", "Faster scans"). This file is the story and the decisions.

---

## 26 Nov 2026 (evening): merged the price session's work

- Merged `claude/optimistic-carson-85ujkl` (critic scores per critic with the shop page quoting each, Wine Enthusiast dataset
  scores, 20-column `app_wines.tsv.z`) into `claude/vibrant-ramanujan-g4uz35`. No conflicts; the combined branch builds and the
  content check passes. Their code is additive (new optional fields `dbCritics`/`dbCriticLinks`, columns 19–20).
- Checked the new list: 196,714 rows, all 20 columns, numeric prices, 28,870 with critic scores; all 134 aroma words are on the
  wheel (families + `also`). "Gooseberry" (2,879 wines) had no icon keyword: now mapped to the small green-berry icon.
- Unpacked, the list is 50.8 MB on the phone (was 45.1 MB); the app indexes it in the background at launch (`PriceBook.warm`).
- **For the price session:** these still look like non-wine in the list (the `Vin de Liqueur`, Liqueur Muscat/Topaque and
  Hardys "Whiskers Blake" tawny entries ARE wine and should stay): Hamilton Rum "87 White Stache", Brannland IsCider, Brutes
  Cider Rosa Himmel, Domaine des Grottes Scideration (cider), Eve's Cidery Dry Sparkling Perry, Ross-on-Wye Green Horse Pet Nat
  Perry, Koloa Hawaiian Mai Tai Cocktail, and the 0.0% wines (Henri Badoux Aigle Murailles 0.0%, Leitz Eins Zwei Zero Riesling
  and Sparkling 0.0%, Sangre de Toro White 0.0%). Rules to add in `wine_clean.py`: cider, perry, cocktail, rum producers, "0.0%".
- Phones download the list from `main`: the new scores reach them once this branch is merged to `main`.

## 26 Nov 2026

### For the other sessions
- **The price list is no longer shipped inside the app.** `Jeroboam/Resources/Prices/prices.tsv` moved to
  `content/prices/prices.tsv` (reference only) and `tools/prices/build_app_prices.py` now writes there. Phones download
  `content/prices/app_wines.tsv.z` (7 MB) right after install and every 6 h when it changes (`PriceUpdater`). If you rebuild the
  price list: `build_app_wines.py` is what phones use; push it to `main`. Don't put a price file back into `Jeroboam/Resources`.
- **Photos are HEIC now.** New photos still arrive as `.jpg` from `tools/fetch_photos.py`; run `python3 tools/compress_photos.py`
  (needs `pip install pillow-heif`) to convert them; originals go to `media/photos-original/`. The app loads `.heic` then `.jpg`.
- `tools/build_widget_data.py` reads bottle photos from `media/photos-original/`.
- Found but not fixed (price data, your area): about 30 alcohol-free items slipped through the cleaning rules (seen when checking
  the CSVs on 25 Nov).
- The wine-identification flow changed shape (see "Faster scans"): `identifyFast` + `finish`. `WineRecognizer.known()` looks a
  wine up by producer/name/vintage in the phone DB and the cloud `/wine?key=` before any paid web check.

### Done today (all on the branch, compile-checked)
1. **Faster scans**: the bottle (name, producer, vintage, photo) appears as soon as it is known; the price search and the
   online check of grapes/notes run side by side afterwards, under "Checking grapes and tasting notes…". Unconfirmed grapes and
   notes stay hidden until checked (a guess is never shown as a fact). The cloud wine list gets a 0.8 s head start, then Claude
   races it. The wine-list index is built in the background at launch. Expected: new wine 1–3 s instead of 5–15 s.
   *Option 3 (match the label text against the 197k list before calling Claude) is waiting for Ralph's go-ahead after he
   tries this on TestFlight.*
2. **Smaller download**: photos 69 → 40 MB (HEIC q50, max 1,200 px; checked by eye at 2x zoom and SSIM ≥ 0.98); price list no
   longer bundled (−29 MB in the app, −7 MB of download). App resources 145 → 82 MB. Further ideas given to Ralph, not done:
   On-Demand Resources for Plus-only content (levels 2–5 photos, maps beyond France, Great Wines bottles): first download could
   reach ~25–35 MB; compact binary maps.
3. **Sommelier review of the whole course** (5 levels, 41 units):
   - Level order kept (it is right). Fixed ~15 places where a question asked something not yet taught (added the fact to the
     lesson): Albariño, harvest months, oak-fermented Chardonnay, oak chips, Wachau/Danube, DOQ, riddling/disgorgement/dosage,
     Tokaji Aszú, Sanlúcar, Pessac-Léognan, "between two seas", DAC, snowmelt in Mendoza; new card "The south and the mountains"
     (Languedoc-Roussillon, Banyuls, Provence/Bandol, Cahors, Madiran, Jura vin jaune).
   - New visual kind `ladder:<id>` (content/ladders.yaml, `LadderView`): EU quality, Burgundy (with %), Italy, VDP, 1855 growths,
     100-point scale, three score scales, Rioja ageing, Prädikat, sparkling sweetness. 16 new flows in content/flows.yaml (body,
     BLIC, tasting note, food & wine, faults, opening sparkling, decanting, training, en primeur, deduction, Bordeaux blend,
     Port styles, lees ageing, families…).
   - Wrong/duplicate photos fixed: history photos were shifted one card; Cognac for Champagne base wine, NZ tasting room for
     Champagne houses, beach gravel, building-site granite, etc. 7 new Commons photos (Egyptian tomb painting, Pommery cellars,
     bâtonnage, Codorníu, cooling jackets, yeast, mildew).
   - ~200 questions got a picture (grape photo or map; never one that gives the answer away).
   - The builder's teaching audit and my stricter check: `content` answers are now taught before they are asked.
4. **Quiz fixes** (Ralph's screenshots): pictures in questions no longer show the answer (no area names on question maps, wine
   belt without latitudes/caption, colour ladder without names); the explanation after answering is always shown in full
   (no "Why?" button), scrolling inside the panel when long.
5. **Cellar & journal round**: drinking-window alerts (3 monthly, different wording each time); journal world map with small
   style-coloured dots, All / In my cellar / Tasted filter, tap a dot for a place card, TestFlight switch Dots/Glow/Countries
   (Ralph said "dots, be the judge"); wine profile bars on every bottle (with your tasting's marks beside them); new journal
   charts (insight sentence, taste fingerprint radar, month by month, blind progress, grape ring, cellar readiness);
   **Collection** stamp album + ticks + 8 milestone badges, in Journal and Profile, two-pane on the Duo sideways.
   **Ralph's rule: only TASTED wines count as tried, never just a bottle in the cellar.**
6. **Top bar**: streak flame + XP stay next to the avatar when the title collapses (Practice), and always in Atlas and Journal.
7. **Welcome back** for returning players after a reinstall (iCloud finds progress): first page → "Welcome back, <name>" with
   picture + change picture → "carry on / test my knowledge again" (placement quiz only ever opens more levels).
8. **Crash after reinstall** (Ralph saw it once): launch-time price tasks mutated the cellar off the main thread while iCloud
   restored it → now `@MainActor`; CloudKit pull applies changes to the journal as it is after the network wait.
9. **Repeat scans** never pay the web check twice (lookup by producer/name/vintage before the paid search).

### Done 25 Nov (on TestFlight in build 65 unless noted)
- **Build 65 froze on launch**: photos were saved at 4,800 px (renderer scale) and CloudKit re-encoded them on the main thread
  every sync. Fixed (1,600 real px, ImageIO off the main thread, reuse, 10-min back-off) in run 82. TestFlight Settings shows
  "iCloud photos: OK / N refused / failed" to diagnose CloudKit. Ralph created the record types Tasting and Bottle himself.
- iCloud: Sync now button animates; tap a bottle/tasting photo to see it full screen (pinch/double-tap, swipe down);
  iCloud photo uploads capped at 1 MB.
- `asc-status.yml` workflow lists the latest TestFlight builds and their state. **TestFlight build number ≠ run number.**
- App review round (build 78+): paywall test checkout only in TestFlight, no Sign in with Apple (iCloud KVS + CloudKit sync,
  "Erase all my data"), spaced review of mistakes, select-then-Check questions, capped Dynamic Type, accessibility labels,
  Reduce Motion, privacy manifests, logic tests.
- Cellar grid opened the wrong bottle when tapping the bottom of a tile → fixed. Journal tab paused on first open → insights
  computed off the main thread.

### Maps (24–25 Nov)
- Chile, Argentina, New Zealand, South Africa, Germany, Austria, South Australia, Hungary rebuilt from official data
  (Decree 464, IG lists, IPONZ GIs, EU PDO boundaries, WineRegions); Portugal, Spain, Greece in three levels; US AVAs nested;
  EU extras (Romania, Bulgaria, Croatia, Slovenia, Cyprus) on official PDOs; Georgia (21 appellations as named dots); Japan in
  the main Atlas. Regions always drawn behind their appellations.
- **Ralph's rule: don't draw shapes we aren't sure of.** All invented circles/cells were removed; places without a boundary are
  named dots. Canada West and Moldova were left as they are on purpose.

### Ralph's preferences learned (keep to them)
- Elegant, "not too bold, not too big"; Wine Folly as the reference. Keep the bold map palette.
- Don't upload to TestFlight unless he says so; compile checks on the branch are fine. He has no Mac.
- Explanations after answers are the most important teaching moment: always visible.
- Ask before big new directions; he likes options with a recommendation.

### Open / next
- Ralph to say "send to TestFlight" → merge the branch to `main`, run build-ios.yml, check with asc-status.yml.
- Scanning option 3 (local list before Claude): after he tests the speedups.
- Download size: On-Demand Resources (biggest remaining win), compact maps.
- Not started, ideas he liked: year-in-wine recap, "what should I open tonight?", restaurant wine-list scan, taste profile,
  shareable tasting card, the Jero puppy mascot.
- Still to do from earlier: Claude API behind the Cloudflare worker (key out of the binary), localisation, splitting Journal.swift.
- Missing history photos h-02 and h-18 (Egypt now has one; "Today and tomorrow" has none).
