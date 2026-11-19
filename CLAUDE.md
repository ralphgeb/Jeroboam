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
- Type: SF Pro only, one scale (`TypeScale`): screen title 30 bold, section 19 semibold, card title 17 semibold, body 16, secondary 14, caption 12.
  Every screen starts with `ScreenHeader(eyebrow:title:subtitle:)`; sections use `SectionTitle`. No uppercase poster titles, no heavy/black weights.
  `Font.display` is kept only for numbers and is scaled down.
- Lists: `GroupCard` + `IconRow` (Settings-like). Cards open with a zoom transition: `.zoomSource(ZoomID…)` on the card,
  `.zoomDestination` on the navigationDestination (iOS 18+, plain push before).
- Logo (owner's sketch): a cluster "resting on its side": rows 2·3·3 with the bottom row shifted right, stem + leaf top-left
  (`GrapeMark`, `GrapeMark.brandGradient`); icon = beige grapes, pale leaf on Bordeaux (rendered by a PIL script mirroring GrapeMarkLayout).
- Grape pictures: Resources/Grapes/<id>.png are photo cutouts from the owner's supplied grid image (14 wine grapes have their
  own photo; other varieties reuse the closest-looking one by color). `tools/build_grapes.py` (rendered bunches) is the
  fallback generator — don't re-run it over the photos. `GrapeBadge` shows them (falls back to the drawn `GrapeCluster`).
- Flavor icons: `FlavorIcons.swift`, one line icon per descriptor on a 24-pt grid (`FlavorGlyph.kind(for:)`); new aroma names need a mapping.
- Maps: white focus country with a soft lift shadow, grey neighbours, blue sea, 13-color palette; areas are inset and rounded (`soften`).
  Every map is built with 16% extra context (`MAP_PAD`). Cards use `WineMapView(fill: true)` (centered on the areas, always covering);
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
- TestFlight build 8 uploaded (run 8): hatched big regions + country lift, full map zooms out to fit width and floats between
  header and list card, interactive How to taste (`TastingStep` cards + sheet), more reference maps (29 regions).
  No free reference map found yet for Portugal (whole), Douro, Chile, Argentina, Lebanon (3 search rounds: content/mapimgs*.json).
- Lebanon map: 4 level-0 regions (governorates) + vineyard zones + 54 wineries (`pois`, dots; names when zoomed) georeferenced
  from the owner's winery map (`specs_gb.LEBANON.wineries`). Portugal: ~47 subregions from municipalities (owner's Wine Folly
  map used only as a reference). Areas are clipped to their map's bbox (an Azores "Lagoa" once stretched Portugal).
- Logo: owner said keep the current mark for now; revisit later (8 Jeroboam bottle options were shown).
