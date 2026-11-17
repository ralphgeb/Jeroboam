# CLAUDE.md — Jero (iOS wine-learning app; repo name Jeroboam)

Duolingo-style wine course (Levels 1–3, WSET-inspired) plus a wine atlas: grapes, regions with illustrated maps, aroma wheel, colors, styles, tasting guide, glossary. Owner: Ralph (no Mac; builds run in GitHub Actions, ship to TestFlight). Sister apps: Ahead (`ralphgeb/MyiOSApp`), Halo, Scout.

- App name **Jero** (short for Jeroboam). Bundle ID `com.ralphgeb.jero`, iOS 17+, iPhone only, Swift 5 mode, SwiftUI + Observation. No third-party packages.
- Project root `Jeroboam/` (XcodeGen `project.yml`; never commit a .xcodeproj).

## Layout
```
content/            SOURCE of all text: YAML (course/*.yaml units, grapes, regions, aromas, colors, glossary, styles, flows, sat, pairings, levels)
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
Jeroboam/Sources/        Swift app
.github/workflows/build-ios.yml   TestFlight (workflow_dispatch; needs ASC_* + APPLE_TEAM_ID secrets)
.github/workflows/preview.yml     Simulator build + screenshots (no secrets; runs on push to main), artifact "screenshots"
```

## Content rules
- Card YAML: `learn` (title/body/visual), `choice` (options + `a` = correct text), `blank` (`___` per answer, `answers`, distractor `options`), `tf` (`truth`), `match` (`pairs`, all items unique). Every question needs `explain`.
- Visual specs: `map:<mapId>[:<area,area>]`, `grape:<id>`, `glass:<colorId>`, `glassonly:<colorId>`, `colors:white|rose|red`, `profile:<grape>`, `aromas:<grape>`, `wheel`, `flow:<flowId>`, `diagram:<vine-cycle|climate|grape-anatomy|bottle-sizes|serving-temps|sweetness|solera|wine-belt|glass-shapes|tannin-acid>`.
- Region ids == map area ids, so tapping a map area opens its guide. The builder warns about map areas without a region entry.
- Never quote WSET materials verbatim; the app says "inspired by", not affiliated.

## Journal & AI
- Journal tab: photo -> Apple Vision OCR (free) -> label text to Claude Haiku 5.5 (`claude-haiku-5-5`, structured JSON) -> image fallback only if text is thin or confidence low.
- Key: GitHub secret `ANTHROPIC_API_KEY` -> build setting JERO_API_KEY -> Info.plist `JeroAPIKey` (testing only; ships inside the binary — use a proxy before public release).
- Cost ≈ $0.0003–0.0005 per text lookup, ≈ $0.0005–0.0008 with the image fallback (Haiku 5.5: $0.10/MTok in, $0.50/MTok out). Prices are model estimates, not live quotes.

## Design rules (owner feedback: elegant and refined, "not too bold, not too big", coherent; Wine Folly as reference)
- Light: porcelain #F5F4F2 + Bordeaux #8B1538 (+ pink #D8285A accents). Dark: deep Bordeaux #1A0910 with beige #F0D9C4 actions.
- Type: SF Pro only, one scale (`TypeScale`): screen title 30 bold, section 19 semibold, card title 17 semibold, body 16, secondary 14, caption 12.
  Every screen starts with `ScreenHeader(eyebrow:title:subtitle:)`; sections use `SectionTitle`. No uppercase poster titles, no heavy/black weights.
  `Font.display` is kept only for numbers and is scaled down.
- Lists: `GroupCard` + `IconRow` (Settings-like). Cards open with a zoom transition: `.zoomSource(ZoomID…)` on the card,
  `.zoomDestination` on the navigationDestination (iOS 18+, plain push before).
- Logo: grape cluster of 8 berries in rows 2·3·3 with a short stem (`GrapeMark`, `GrapeMark.brandGradient`); icon = beige grapes on Bordeaux.
  Not the Vivino-like 1-at-the-bottom cluster. Grapes on cards use `GrapeBadge` (cluster in berry colors on a tinted disc).
- Flavor icons: `FlavorIcons.swift`, one line icon per descriptor on a 24-pt grid (`FlavorGlyph.kind(for:)`); new aroma names need a mapping.
- Maps: white focus country with a soft lift shadow, grey neighbours, blue sea, 13-color palette; areas are inset and rounded (`soften`).
  Areas show small numbered badges only; tapping shows the name in a callout box (tap again to open). Legends list number + name.
- Color chart: square swatches, no corner radius, four per row.

## Debug screenshots
DEBUG builds accept `-screen <name>` (onboarding, learn, lesson, feedback, blank, match, complete, practice, library, grapes, grape, regions, region, map, explorer, tuscany, lebanon, portugal, icons, aromas, colors, styles, tasting, cards, boldness, labels, guide, journal, profile) — see `DebugScreens.swift`. Not compiled into Release.

## Release procedure
Same as Ahead: push to `main`, run build-ios.yml, TestFlight build number = run number; never claim an upload without evidence.
