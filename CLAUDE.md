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
Same as Ahead: push to `main`, run build-ios.yml, TestFlight build number = run number; never claim an upload without evidence.

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
