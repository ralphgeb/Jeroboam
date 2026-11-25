# CLAUDE.md — Jero (iOS wine-learning app; repo name Jeroboam)

Duolingo-style wine course (Levels 1–3, WSET-inspired) plus a wine atlas: grapes, regions with illustrated maps, aroma wheel, colors, styles, tasting guide, glossary. Owner: Ralph (no Mac; builds run in GitHub Actions, ship to TestFlight). Sister apps: Ahead (`ralphgeb/MyiOSApp`), Halo, Scout.

- App name **Jero** (short for Jeroboam). Bundle ID `com.ralphgeb.jero`, iOS 17+, iPhone only, Swift 5 mode, SwiftUI + Observation. No third-party packages.
- Project root `Jeroboam/` (XcodeGen `project.yml`; never commit a .xcodeproj).

## Layout
```
content/            SOURCE of all text: YAML (course/*.yaml units, grapes, regions, aromas, colors, glossary, styles, flows, sat, pairings, levels,
                    wines.yaml = "Wines of the world" catalog; deep/<unit>.yaml = deep-dive lessons merged before "Going further";
                    photos.json = Wikimedia Commons queries)
tools/fetch_photos.py + .github/workflows/photos.yml   fetch CC/PD photos from Commons on a runner (this container's IP is
                    rate-limited) -> pushed to the `photos` branch; pick, resize to 900 px and copy into Resources/Photos
                    (+ credits.json). Lessons use `visual: "photo:<id>"`; missing ids are hidden with a warning.
tools/build_content.py   YAML -> Jeroboam/Resources/Content/{course,library}.json + validation (run after every content edit)
tools/build_maps2.py     map builder v2 (zoomable, levels 0/1/2). Sources in /home/user/ne (Natural Earth) and /home/user/geo:
                         fr/communes-<dept>.geojson (gregoiredavid/france-geojson), it_comuni.geojson (openpolis/geojson-italy),
                         ava/ (UCDavisLibrary/ava). Run: python3 tools/build_maps2.py [fr|it|us|legacy]
tools/inao_fetch.py + .github/workflows/inao.yml   INAO parcel-level AOC delimitation (data.gouv.fr, Licence Ouverte) -> `inao-data`
                         branch (Côte d'Or: Grand Crus, Premier Cru climats). NOT used by the build: the owner asked to remove the Grand cru
                         level; the data is there if climats are wanted later. tools/burgundy_fetch.py + burgundy.yml: OSM vineyard parcels (reference).
France map = ONE map (france.json). Bordeaux and Burgundy are drawn K=4 times finer inside it (`FineProj`, area records carry `k`,
                         doc has `insets` with fine coast/water/rivers and `lod` [1.9, 3.4]). The separate bordeaux/burgundy maps were removed;
                         region pages use `map: france` and the card/explorer frame the place via `MapGeometry.zoneRect`. Levels: 0 region,
                         1 sub-region, 2 appellation (village/commune). Explorer buttons Regions / Sub-regions / Appellations each show exactly
                         that level (parents hatched behind); area names are drawn inside the borders when they fit (white on solid, dark on
                         hatched or faded), else a number badge. Two-pane map layout only when the page is >= 760 pt wide (not on the upright inner screen).
Maps beyond the atlas (Settings > More maps > ExtraAtlasView): content/extra/<map>.yaml = geometry spec + guide text for one map
                         (24 maps: US states by AVA, UK, Canada, Georgia, Armenia, Switzerland, Croatia, Slovenia, Romania, Bulgaria, Moldova,
                         Turkey, Uruguay, Brazil, Mexico, China, Japan, Cyprus; no Israel). `python3 tools/build_extra_maps.py [map]` builds
                         Resources/Maps/<map>.json (geoBoundaries ADM units via `units`, AVAs via `ava`, sketches via `poly`/`within`,
                         `clip`/`minus`); build_content.py turns the same files into Resources/Content/extra.json (ContentStore.extraRegions,
                         `Region.local` = grape names without an atlas page). `tools/preview_map.py <map> out.png` draws a quick check picture.
                         Region ids must be unique across the atlas and all extras. `ContentStore.regionMatching` finds a place from a label's
                         region text (atlas and extras, else the country page); the Journal uses it.
tools/specs_fr.py        French appellations as real commune lists or commune-centroid polygons
tools/specs_world.py     Italy zones/DOCGs (comuni), US AVA lists
tools/specs_gb.py        Portugal, Spain, Germany, Austria, Hungary, Greece, Chile/Argentina, Australia, NZ, South Africa and Lebanon
                         as unions of real admin units (geoBoundaries gbOpen, ~/geo/gb/<ISO>-<ADM>.geojson; download from
                         media.githubusercontent.com/media/wmgeolab/geoBoundaries/main/releaseData/gbOpen/<ISO>/<ADM>/...simplified.geojson).
                         Modes: U(names[, clip=km around the sketch]) or S(snap units inside the sketch). Run: build_maps2.py gb lb
tools/map_specs.py       hand sketches (world map + the outlines the gb specs snap/clip to)
tools/geodata_pdo.py + .github/workflows/geodata.yml   on a runner: EU wine PDO boundaries (Candiago et al. 2022, figshare
                         5877659, CC BY 4.0) + OSM simplified land polygons -> `geo-data` branch -> extract into ~/geo/pdo.
                         ~/geo/ext/WineRegions (github.com/adynak/WineRegions, CC0): Australian GIs, Argentine regions.
                         build_maps2 replaces any area whose name (or PDO_ALIAS) matches an overlapping official
                         boundary (`pdo_geom`, list in tools/pdo_used.txt); coastlines come from OSM when a tile covers
                         the map. Maps are at least MIN_ASPECT 1.3 wide. Credits are shown under Regions & maps.
Jeroboam/Sources/        Swift app
.github/workflows/build-ios.yml   TestFlight (workflow_dispatch; needs ASC_* + APPLE_TEAM_ID secrets)
.github/workflows/preview.yml     Simulator build + screenshots (no secrets; runs on push to main), artifact "screenshots"
```

## Content rules
- Card YAML: `learn` (title/body/visual), `choice` (options + `a` = correct text), `blank` (`___` per answer, `answers`, distractor `options`), `tf` (`truth`), `match` (`pairs`, all items unique). Every question needs `explain`.
- Visual specs: `photo:<id>`, `map:<mapId>[:<area,area>]`, `grape:<id>`, `glass:<colorId>`, `glassonly:<colorId>`, `colors:white|rose|red`, `profile:<grape>`, `aromas:<grape>`, `wheel`, `flow:<flowId>`, `diagram:<vine-cycle|climate|grape-anatomy|bottle-sizes|serving-temps|sweetness|solera|wine-belt|glass-shapes|tannin-acid>`.
- Region ids == map area ids, so tapping a map area opens its guide. The builder warns about map areas without a region entry.
- Never quote WSET materials verbatim; the app says "inspired by", not affiliated.

## Journal & AI
- Journal tab has two modes: **Scan a wine** (details + average price + add to Cellar with quantity; cellar totals its value) and
  **Blind tasting** (label read but hidden; only the price shown; look/smell/taste, guess grape + country, reveal + score /100:
  grape 30, country 20, aromas 30, structure 20 — `TastingScore`). Old journal JSON stays decodable (new fields optional).
- Identification: photo -> Apple Vision OCR (free) -> label text to Claude Haiku 5.5 (`claude-haiku-5-5`, structured JSON) -> image fallback only if text is thin or confidence low.
- Average price: `WineRecognizer.averagePrice` uses Claude's web search tool (`web_search_20250305`, max 2 uses, allowed_domains
  wine-searcher.com + cellartracker.com), parses a JSON line; falls back to the model's estimate (source "Estimate").
  ≈ $0.01 per search + ~$0.002 tokens. Not verifiable from CI (no key in Debug builds) — check on TestFlight.
- Key: GitHub secret `ANTHROPIC_API_KEY` -> build setting JERO_API_KEY -> Info.plist `JeroAPIKey` (testing only; ships inside the binary — use a proxy before public release).
- Cost ≈ $0.0003–0.0005 per text lookup, ≈ $0.0005–0.0008 with the image fallback (Haiku 5.5: $0.10/MTok in, $0.50/MTok out). Prices are model estimates, not live quotes.

## Design rules (owner feedback: elegant and refined, "not too bold, not too big", coherent; Wine Folly as reference)
- Light: porcelain #F5F4F2 + Bordeaux #8B1538 (+ pink #D8285A accents). Dark: deep Bordeaux #1A0910 with beige #F0D9C4 actions.
- Type: SF Pro only, one scale (`TypeScale`): screen title 33 bold (eyebrow sits right on top), section 19 semibold, card title 17 semibold, body 16, secondary 14, caption 12.
  Every screen starts with `ScreenHeader(eyebrow:title:subtitle:)`; sections use `SectionTitle`. No uppercase poster titles, no heavy/black weights.
  `Font.display` is kept only for numbers and is scaled down.
- Lists: `GroupCard` + `IconRow` (Settings-like). Cards open with a zoom transition: `.zoomSource(ZoomID…)` on the card,
  `.zoomDestination` on the navigationDestination (iOS 18+, plain push before).
- Brand (owner's Illustrator file tools/brand/wine.ai -> wine.svg): wine splash logo + glass. `python3 tools/brand/build_brand.py`
  generates Sources/BrandShapes.swift (SplashBodyShape, SplashDropShape, GlassOutlineShape, GlassWineShape) and the app icon
  (Bordeaux ground, white splash, cork-beige droplet; rendered with cairosvg). In the app: `SplashMark` (Bordeaux on white),
  `HeroCardBackground`, `SilhouetteGlass` (every glass; wine color/level, narrower for whites and flutes). Old GrapeMark kept only as art.
- Grape pictures: Resources/Grapes/<id>.png are photo cutouts from the owner's supplied grid image (14 wine grapes have their
  own photo; other varieties reuse the closest-looking one by color). `tools/build_grapes.py` (rendered bunches) is the
  fallback generator — don't re-run it over the photos. `GrapeBadge` shows them (falls back to the drawn `GrapeCluster`).
- Flavor icons: `FlavorIcons.swift`, one line icon per descriptor on a 24-pt grid (`FlavorGlyph.kind(for:)`); new aroma names need a mapping.
- Maps: white focus country with a soft lift shadow, grey neighbours, blue sea, 13-color palette; areas are inset and rounded (`soften`).
  Every map is built with 50% extra context (`MAP_PAD` 0.5, same detail per degree) so the full map can cover a phone screen centered on the region. Cards use `WineMapView(fill: true)` (centered on the areas, always covering);
  the full map opens centered, can't zoom out past "cover", detail levels are relative to the whole-map zoom (`lodBase`),
  and has a collapsible numbered list card (`MapListCard`). Lebanon cazas are trimmed to vineyard zones (`specs_gb.LEBANON.zones`).
  Atlas hierarchy (`specs_gb.HIERARCHY`, modelled on the owner's printed-atlas photos): level 0 = big wine regions from
  provinces/states (Spain's autonomous regions, Chile/Argentina regions, Australian states, Austrian Länder…), level 1 =
  appellations inside (existing regions find their parent by overlap; extra ones via B(lat, lon, km) snapped to municipalities).
  Province tints (`tints`) are drawn only on maps without a level-0 hierarchy. Keep the original bold palette (owner's choice).
- Quiz visuals in question cards use `hideAnswers` (no grape names, no map callouts, smaller maps).
- Practice: `QuizGenerator` has ~30 templates across grapes/regions/maps/colors/aromas/styles/pairings/labels/terms and a
  repeat memory (`QuizMemory`, last 400). Every unit ends with a "Going further" lesson (source in content/extras/*.yaml,
  merged into the unit files).
  Areas show small numbered badges only; tapping shows the name in a callout box (tap again to open). Legends list number + name.
- Learn tab: streak bar scrolls away; level tabs (+ compact level title once scrolled) stay pinned.
  Practice/Atlas/Journal use `CollapsingPage` (big title collapses into a top bar with the profile avatar).
- Thumbnails (`WineMapView(thumbnail: true)`): whole country, big regions only as solid shapes, soft halo on small ones.
- Maps, atlas style (owner's choice, "like the Rioja card"): big regions with appellations inside are pale washes,
  appellations strong; level-0 regions without children are a soft wash; highlighted areas full color.
  French and Italian detail maps draw rivers/estuaries as water (`water_polys`: buffered NE centerlines + smoothed estuary).
  The explorer frames the map between the header (120) and the list card (200).
- Quiz feedback: compact panel, answers scroll into view; wrong = #E5484D, right = teal.
- Atlas: "Wines of the world" (`Wines.swift`, 76 wines, tappable grapes/region/style); style pages list their wines.
- Journal: `JournalExtras` (how it works, palate passport, tonight's challenge, classics carousel).
- Brand board (round 1: identity, 20 logo directions, mascot "Jero" the puppy): claude.ai/artifact/LyWjNCyGSqKQ9jCXADvFJn
- Color chart: square swatches, no corner radius, four per row.

## Debug screenshots
DEBUG builds accept `-screen <name>` (onboarding, learn, lesson, photo, wines, wine, style, journalempty, feedback, blank, match, complete, practice, library, grapes, grape, regions, region, map, explorer, tuscany, lebanon, portugal, icons, aromas, colors, styles, tasting, cards, boldness, labels, guide, journal, tastings, scan, blind, profile); journal screens seed sample bottles — see `DebugScreens.swift`. Not compiled into Release.

## Release procedure
Same as Ahead: push to `main`, run build-ios.yml; never claim an upload without evidence. The TestFlight build number is NOT the run
number: Xcode's upload renumbers to the next free number (run 80 = build 65). `asc-status.yml` lists the latest builds and their state.

## Status
- **Jero Plus** ($0.99/month, `com.ralphgeb.jero.plus.monthly`, `Plus.swift`, gates in `Gates.swift`): Levels 2–3 + their guidebooks,
  countries other than France/Italy, 5 free cards per Atlas section (`AtlasQuota`, pill top-right), Journal (free users see
  `JournalStore.sample` greyed under a lock). StoreKit 2 when the product loads, else Halo-style test checkout. `.plusSheetHost()`
  on every presentation layer. TestFlight-only Settings section (`Distribution.isTestFlight`). The build workflow creates the
  subscription group/product/localization via the ASC API (state MISSING_METADATA until a review screenshot is added in ASC).
  Simulator = Plus unless the screen is a free one (`paywall`, `freelearn`, `journallocked`, `freeregions`) or `-free`.
- Notifications (`Notifications` in Progress.swift): morning fun fact (content/facts.yaml, 137) + evening practice, 28 days ahead.
- Study guide: build_content.py generates per-level units (Grape files, Appellations, Words to know; `unit.study`), open as soon as
  the level is, not counted for level progress. L1 "Scores & critics", L3 "The story of wine" + a history lesson per L3 region unit;
  region pages show `region_history.yaml`.
- Photos: every picture is used once (builder drops repeats; new ones assigned in content/photo_assign.yaml). Great wines to try:
  content/greatwines.yaml (25), bottle photos cropped to 0.78 portrait (`tw-*`).
- Maps: France and Italy have 3 levels (regions → zones → appellations/villages); explorer switch Regions/Zones/Appellations, opens on
  the deepest; Piedmont's Barolo village is `barolo-village` so the DOCG shows. Maps obey the phone rule in `Proj`.
- Journal ratings are on the 100-point scale (`points`; old 1–10 converted); `RatingGuideSheet` on the first blind tasting.
- TestFlight build 17 uploaded (run 17). Runs 13–14 failed on a stale provisioning profile (workflow now clears profiles).
- Lebanon map: 4 level-0 regions + 4 winery-cluster zones + 54 wineries. Logo: keep current mark for now.

## Screenshots (fast path)
- **Duo/foldable and layout pictures:** `snapshots.yml` (manual, ~12 min on runner label `xcode-27`) runs `JeroSnapshots` (XCTest in `Jeroboam/SnapshotTests`): real views hosted in an offscreen window at the iPhone Duo's point sizes (outside 466x678, inside 669x951 upright, 951x669 sideways) inside an ordinary iPhone simulator, written to the `snapshots` branch (jpg). Add a test per screen. No Duo simulator needed.
- **Do not use the Duo simulator for screenshots** (`duo.yml` is kept only for experiments): `simctl launch` hangs, the inside display stays black until unfolded by hand (no programmatic unfold), and runs take 50+ minutes. Duo simulator needs Xcode 27.1+.
- Wide layout: `Adaptive.swift` (`isWide` = window width >= 640 pt): picture left / text right in `LearnCard`, map left + list right in `MapExplorer`, adaptive grids. Landscape is allowed in project.yml.
- CI runner label `xcode-27` = macOS 27 + Xcode 27.x (used by build-ios.yml, preview.yml).

## Added in builds 53+ (search, prices, Oregon)
- Search: `Search.swift` (fold/matches/rank, `SearchBar`, `AtlasSearchResults`). RootView decides the rail layout from a keyboard-independent size (`stableSize`); the keyboard used to flip the layout and pop pages.
- Great wines: country chips start with **All**, which turns on by itself when you search (results from every country).
- Only France is free in the Atlas (`Plus.freeCountries`). All five mock exams are open.
- Prices: shop list (`PriceBook`, per-750 ml, vintage first, cheapest link) -> shared Cloudflare list (`PriceCloud`, secrets PRICE_DB_URL / PRICE_DB_KEY; backend/cloudflare) -> Great wines -> estimate. Whatever is found is shared; `PriceCloud.seedOnce()` sends a phone's known prices once. `PriceUpdater` downloads a newer `prices.tsv` from the repo (see content/prices/LIVE_PRICES.md).
- Map explorer "More details" button (France etc.) toggles commune lines + names.
- Journal wine page: `WineGlance` (4 compact tiles + 2:1 region map), then `WineInfoCard` holds grapes, drink window, fun fact. Heat map = blurred + alpha-threshold blobs in 3 bands.
- Atlas extras with `atlas: true`: georgia, moldova, great-lakes (Midwest), oregon (Oregon & Washington, ~38 AVAs).

## Added in builds 62+ (cellar, history, anonymous wine DB)
- Journal: first 6 cellar bottles + "Open your cellar" -> `CellarView.swift` (valuation, average bottle, filters/sort, `paidUSD` per bottle, gain/loss). `ScanHistory.swift` lists every scan from `WineDB` (`noteScan`, `history()`), kept even when a bottle/tasting is deleted. `Flags.swift` + countries card in `JournalInsights`; heat map = `HeatImage` density bitmap (sigma 6.5).
- Mock exams: 4 versions per level (`QuizGenerator.exam(level:version:)`, `ExamShuffleRNG`), 20 fixed lesson questions each + 10 generated. Practice shows a version picker.
- Anonymous wine DB: Cloudflare table `wines` (backend/cloudflare/schema.sql + worker.js `/wine`); app: `PriceCloud.shareWine/wine(sig:)`, called from `WineDB.noteScan` and `WineRecognizer.identify(image:)` (cloud hit = free scan). Privacy page updated; App Store "App Privacy" answers must say anonymous usage data.
- Widget look: App Group NOT registered (build 60 failed on it); widgets follow the phone's appearance. Needs `group.com.ralphgeb.jero` registered in the developer portal before an in-app picker can come back.
- Snapshot workflow now makes `build/` so test.log is published to the `snapshots` branch.

## Added in builds 69+ (web check, budget, cellar graphs, settings)
- New wines (not fully in the wine DB, `fromDatabase != true`, not `checked`): `WineRecognizer.verifyOnline` = free pages first (`WebFacts.swift`: known shop link + DuckDuckGo html results, cut to grape/taste sentences) read by Haiku with no tools; only if grapes stay unconfirmed, ONE paid web search (~1.2 c). Unconfirmed fields stay Claude's guess (`checked = true`). Result shared to the cloud wines table.
- `DailyBudget` ($0.10/day/phone, UserDefaults `jero.spend.<date>`): only new-wine work counts; DB/cloud/local hits are free. Reached -> `RecognizerError.limit`. TestFlight Settings switch `jero.testLimit` pretends it is reached.
- App Group `group.com.ralphgeb.jero` is registered and in both entitlements; Settings > Widgets picker (Automatic/Light/Dark) writes `widgetTheme` (`WidgetSettings`), widget reads `SharedTheme`.
- Settings is one card under "About you" (`settingsCard()` in ProfileView); More maps, Foldable preview and lookup cost line live in the TestFlight section (TestFlight-only); footer shows "Jero(TM)".
- Cellar: stat tiles open graphs (`CellarCharts.swift`, Swift Charts); list/tiles open a bottle via `navigationDestination(item:)`; `Thumb` crops with `Color.clear.overlay`.
- Wine DB: `tools/prices/build_app_wines.py` now writes 18 columns (col 17 = grape percents); `JournalStore.refreshFromShopList()` re-prices shop-priced bottles and re-applies DB details when the list is updated.

## Maps, round 3 (three levels everywhere, official boundaries)
- **Draw order:** `MapGeometry` sorts areas by level, then by size (largest first): regions always sit behind their appellations,
  whatever the JSON order. Sub-areas without their own page open their parent's guide (`regionForMapArea` also matches `highlight`).
- **`build_south` (build_maps2.py, specs in `tools/specs_south.py`)**: generic three-level builder used for Chile, Argentina,
  New Zealand, South Africa, Germany, Austria and South Australia (`python3 tools/build_maps2.py chile` etc.). Area units:
  name lists of the country's base admin level, `("ADM2", [...])`, `{"pdo": name, "cc": "DE"}` (EU PDO boundary),
  `{"file": "Australia/..."}` (WineRegions GI), `{"cell": (lat, lon)}` (the parent shared out by Voronoi cells: German Bereiche),
  `{"c", "r", "free": True, "vin": km}` (a circle shared with neighbouring circles, trimmed to the real vineyards), plus
  Argentina departments-within-province / OSM districts and NZ IPONZ GIs (`SOUTH_UNITS`). Containers with no units are the union
  of their children. `atlas_colors` gives touching areas of one level different colors (also used by the extras builder).
- New map layers: `vines` (OSM landuse=vineyard parcels, drawn darker from 1.3x zoom), `pois` (OSM wineries; dots from 2.6x when
  there are more than 60), `communes`/`villages` (the comunas/departments the areas are made of, and town names).
- **Source data for these maps**: `tools/southern_fetch.py` + `.github/workflows/southern.yml` (runs on push of either file to a
  claude/** branch, or by hand) -> `southern-data` branch: IPONZ GI geodata, OSM vineyards/wineries/places, Argentine districts,
  reference texts (Chile Decree 464, Argentina IG list, SA Wine of Origin booklet). Extract into ~/geo/south.
  Chile = Decree 464 comuna lists (regions > valleys > zones/areas). South Africa: Wine of Origin has no open GIS data;
  districts snap to municipal wards, wards are circles trimmed to vineyards.
- **Extras builder**: `pdo: {cc, names, skip}` adds every official EU PDO of the country, nested under the smallest area that
  holds it (Romania, Bulgaria, Croatia, Slovenia, Cyprus; Bulgarian/Greek names transliterated); `pdo_name` makes a region take
  its official boundary; `ava_auto: {states}` adds every AVA of the states; `auto_nest: true` nests AVAs inside AVAs; circles share
  ground by Voronoi. Japan is in the main Atlas (`atlas: true`).
- `build_gb` nested denominations (a pago inside a DO) are now one level deeper (Spain and Greece have level 2).
  `pdo_used.txt` is merged across runs (building one map keeps the others' credits).
- Sources: geoBoundaries (CC BY 4.0), EU PDO boundaries (Candiago et al. 2022, CC BY 4.0), UC Davis AVA project (CC0),
  adynak/WineRegions (CC0), IPONZ (NZ Crown copyright, CC BY 4.0), OpenStreetMap (ODbL) — credits page should list OSM and IPONZ.

## App round (release fixes, sync, accessibility) — not yet on TestFlight
- **Paywall:** the test checkout (`TestCheckoutSheet`) only opens in TestFlight/debug builds (`Distribution.isTestFlight`); an App
  Store copy that cannot load the product shows "The App Store can't be reached" and Plus turned on by the test checkout in a
  non-test copy is withdrawn by `Plus.refresh()`.
- **No Sign in with Apple** (entitlement removed; old stored ids are deleted). Settings > About you > "Sync with iCloud" switch
  (`Account.syncEnabled`, on by default) + "Erase all my data" (phone + iCloud; the subscription is left to the App Store).
  A new phone (not onboarded) looks for its progress first (`CloudSync.restore`, onboarding shows "Looking for your progress…").
- **Sync:** progress/profile/avatar in the iCloud key-value store, merged field by field (`ProgressData.merged`: never goes
  backwards). Tastings and bottles with full-size photos in CloudKit (`JournalCloud`, private DB, zone "Journal", record types
  Tasting/Bottle with `payload` Bytes + `photo` Asset; only changed records go up; remote edits/deletions come down).
  CloudKit is only in builds where the repo variable **CLOUDKIT_READY=true** (build-ios.yml adds the entitlements and Info.plist
  `JeroCloudKit=1`). One-time setup before turning it on: developer portal > Identifiers > iCloud Containers >
  `iCloud.com.ralphgeb.jero`; App ID com.ralphgeb.jero > iCloud > CloudKit + that container; run a debug build once on a device
  signed in to iCloud (creates the record types in Development), then CloudKit Console > Deploy Schema Changes to Production.
  Until CloudKit has synced once on a phone, the journal also keeps going through the key-value store (`JournalCloud.working`).
- **Progress saves** are coalesced (`GameProgress.save` -> next run-loop; `saveNow()` on going to the background).
- **Spaced review:** a corrected mistake comes back after 1, 3, 7, 21 days (`ProgressData.reviews`, optional; `GameProgress.dueReviews`
  feeds Practice > Review mistakes).
- **Lessons:** multiple choice and true/false are select-then-Check (same Check button as fill-in-the-blank).
- **Dynamic Type:** `Font.jero(size:weight:design:)` = `.system` scaled by `TypeScale.factor` (the reader's text size, 0.88–1.24).
  Used for reading text (252 sites); map canvases, diagrams, badges, label art, pinned bars, the Duo rail and Adaptive layouts
  keep fixed `.system(size:)`. Journal.swift and CellarView.swift are not converted yet (pricing work in progress there).
  New screens should use `.jero` for text, `.system` inside fixed-size frames.
- **Accessibility:** VoiceOver names on icon-only buttons (map zoom/close, close buttons, label steppers); Reduce Motion stops the
  lesson pulse, limit-card glow and loading shimmer. Navigation bar titles are SF Pro (no serif).
- **Maps:** Atlas thumbnails decode their map off the main thread (`MapGeometry.load`); full maps unchanged.
- **Privacy manifest** declares Photos, Other User Content and Product Interaction (not linked, app functionality) + App Group
  defaults reason 1C8F.1; the widget has its own manifest. Keep APP_STORE_LISTING.md §5 and docs/privacy.html in step.
- **Tests:** `SnapshotTests/LogicTests.swift` (merge, spaced review, streak freeze, blind score) runs with snapshots.yml.
- Still to do: the Claude API behind the Cloudflare worker (key out of the binary), pre-rendered map thumbnails (maps step 2),
  string catalog for localization, splitting Journal.swift.

## Wine price list (rebuilt Nov 2026, content/prices/README.md)
- ~197k wines from 80 shops. Shopify shops are listed in `tools/prices/shops.json` and harvested on a runner (`harvest_shops.yml`, one job per shop)
  into the `shop-data` branch; `shopify_to_sources.py` -> `legacy_details.py` -> `merge_prices.py` -> `enrich_details.py` -> `build_app_wines.py` / `build_app_prices.py`.
- Cleaning rules in `tools/prices/wine_clean.py`: no non-wine (spirits, beer, food, sets, tastings, alcohol-free), no fake producers (importers,
  consignor codes, agent numbers, shop names, "Chateau"), per-bottle prices from every price option. Blocked shops: In Vintage Tokyo, Nourished Communities, Good Earth Shop.
- CaskCartel only as a last resort: kept only for a wine + vintage + size no other shop sells (`price_note = high reseller price`).
- Removed: the `*_shopify_new.csv` companion files and their workflow (wrong shops, importer producers, copied descriptions) and the old per-source
  CSVs (`us_wine_shops`, `europe_wine_shops`, `more_wine_shops*`; all re-harvested). Non-Shopify English wineries live in `sources/other_shops.csv`.

## Aromas from the wine list
- `wine_details.csv` uses 134 aroma words. Wheel families in content/aromas.yaml carry `also: [...]` (Cherry, Citrus, Plum, Graphite,
  Iron, Olive, Tea, Anise, Sage, Rosemary, Pine, Bay leaf, Cinnamon, Ginger, Tar, Jasmine, Dried fruit, Beeswax, Blood orange):
  matched by `ContentStore.aromaCategory` (family colour, blind-tasting aroma score), never drawn on the wheel.
  FlavorIcons keywords: "iron" -> pebbles, "beeswax" -> honeycomb. Check new aroma words against both after a price-list rebuild.

## Builds 78–80 (Nov 2026)
- Build 78: app round + maps cleanup + price list (196,898 wines). Run 80 (TestFlight build 65): first build with CloudKit (CLOUDKIT_READY=true,
  container iCloud.com.ralphgeb.jero registered), Sync now animation, full-screen label photo (`PhotoViewer.swift`, `TappablePhoto`),
  iCloud photo uploads capped at 1 MB (`JournalCloud.uploadCopy`). Run 79 failed only on the CloudKit step's path (fixed).
