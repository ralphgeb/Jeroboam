# CLAUDE.md — Jeroboam (iOS wine-learning app)

Duolingo-style wine course (Levels 1–3, WSET-inspired) plus a wine atlas: grapes, regions with illustrated maps, aroma wheel, colors, styles, tasting guide, glossary. Owner: Ralph (no Mac; builds run in GitHub Actions, ship to TestFlight). Sister apps: Ahead (`ralphgeb/MyiOSApp`), Halo, Scout.

- Bundle ID `com.ralphgeb.jeroboam`, iOS 17+, iPhone only, Swift 5 mode, SwiftUI + Observation. No third-party packages.
- Project root `Jeroboam/` (XcodeGen `project.yml`; never commit a .xcodeproj).

## Layout
```
content/            SOURCE of all text: YAML (course/*.yaml units, grapes, regions, aromas, colors, glossary, styles, flows, sat, pairings, levels)
tools/build_content.py   YAML -> Jeroboam/Resources/Content/{course,library}.json + validation (run after every content edit)
tools/map_specs.py       map definitions: bbox, region shapes (blob/strip/poly in lat/lon), cities, labels
tools/build_maps.py      Natural Earth GeoJSON (download to ~/ne, see header) -> Jeroboam/Resources/Maps/*.json
Jeroboam/Sources/        Swift app
.github/workflows/build-ios.yml   TestFlight (workflow_dispatch; needs ASC_* + APPLE_TEAM_ID secrets)
.github/workflows/preview.yml     Simulator build + screenshots (no secrets; runs on push to main), artifact "screenshots"
```

## Content rules
- Card YAML: `learn` (title/body/visual), `choice` (options + `a` = correct text), `blank` (`___` per answer, `answers`, distractor `options`), `tf` (`truth`), `match` (`pairs`, all items unique). Every question needs `explain`.
- Visual specs: `map:<mapId>[:<area,area>]`, `grape:<id>`, `glass:<colorId>`, `glassonly:<colorId>`, `colors:white|rose|red`, `profile:<grape>`, `aromas:<grape>`, `wheel`, `flow:<flowId>`, `diagram:<vine-cycle|climate|grape-anatomy|bottle-sizes|serving-temps|sweetness|solera|wine-belt|glass-shapes|tannin-acid>`.
- Region ids == map area ids, so tapping a map area opens its guide. The builder warns about map areas without a region entry.
- Never quote WSET materials verbatim; the app says "inspired by", not affiliated.

## Design rules (owner feedback: minimal, modern, graphic-designer quality, not childish)
- One main color (claret `#7D1D3F` / dark `#D4738F`) + muted complements (brass, sage, slate) on ivory paper. Maps use claret tints only.
- New York serif for display (`Font.serif`), SF for text, 24pt margins (`Metrics.margin`), hairlines, no heavy shadows, flat buttons.
- Logo: claret droplet (`DropletShape`/`BrandDroplet`); icon in Assets.

## Debug screenshots
DEBUG builds accept `-screen <name>` (onboarding, learn, lesson, feedback, blank, match, complete, practice, library, grapes, grape, regions, region, map, aromas, colors, styles, tasting, profile) — see `DebugScreens.swift`. Not compiled into Release.

## Release procedure
Same as Ahead: push to `main`, run build-ios.yml, TestFlight build number = run number; never claim an upload without evidence.
