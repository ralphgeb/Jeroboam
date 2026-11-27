# Claude: wine price list, critics' scores, label fingerprints

Branch: **`claude/optimistic-carson-85ujkl`**. Merged into `main` so far: ralphgeb/Jeroboam#1 (clean rebuild of the list) and
ralphgeb/Jeroboam#2 (critics' scores). The fingerprint work below is on the branch only.

How the price list is built: `content/prices/README.md`. Short version in `CLAUDE.md`, "Wine price list".

---

## 27 Nov 2026: label fingerprints from shop photos (in progress)

Ralph asked for "digital fingerprints" of the wines from images found online. I followed the six rules in
`claude-maps-and-app.md` ("For the session harvesting wine images"):

- **Photos:** the Shopify catalogues already carry product photos. `harvest_shopify.py` now keeps the first 3 photo links
  (`images`). A full re-harvest was started 26 Nov 23:12 UTC. The catalogues the current list was built from are kept on
  the branch `shop-data-2026-11-25`.
- **Fingerprints:** `tools/prices/LabelPrints.swift` on a Mac runner (`fingerprints.yml`, label `xcode-27`, 5 shops at a time)
  uses Apple Vision `VNGenerateImageFeaturePrintRequest` exactly like `LabelPrint.swift`:
  - upright, longest side 640 px, `.scaleFit`;
  - revision kept (the trial gave revision 2, 768 numbers, unit length).
  - Two prints per photo: the whole picture, and a label crop (plain background trimmed; for a standing bottle, a square of
    the bottle's width centred 64% of the way down).
  - Stored on the `fingerprints` branch as 16-bit floats (`<host>.full.f16` / `.label.f16`), plus `<host>.meta.tsv` (WineDB
    key of the list's producer / name / vintage, wine, link, photo URL) and `<host>.status.tsv`.
  - **No photos are stored.**
- **Running it:** a push of `tools/prices/fingerprint_shops.txt` (hosts, or `all`) to a `claude/**` branch. Manual dispatch
  only works once the workflow is on `main`.
- **Test:** `tools/prices/fingerprint_test.py` (last job of the workflow, report `fingerprint_test.md` on the branch).
  - Test 1: wines sold by 2+ shops; each shop's photo is looked up among the OTHER shops' prints. It counts right / top 5 /
    identical picture file / look-alike from the same producer / other.
  - Test 2: the app's own scan prints from `GET /prints/export`, with the 3 nearest shop wines for each.
- **Trial (Vin Chicago):** 1,366 photos in 8 minutes, all fingerprinted. Neighbours look sensible: magnum ↔ 750 ml, and
  Poggerino Nuovo next to Poggerino Chianti Classico. The look-alike risk is real: Walter Hansel Cuvée Alyce Chardonnay vs
  Pinot Noir.
- **Not done (waiting for the test and for Ralph):** sending shop prints to the worker. If they go there, they need a
  `source` = `shop` column so they don't take the 5 per-wine slots meant for phone scans (your suggestion). Nothing is
  switched on in the app.
- **Cost note for Ralph:** Mac minutes count 10x on private repos; the whole run is ~20 Mac hours.

## 27 Nov 2026: list rebuilt from the re-harvest (198,220 rows, 198,033 wines in the app file)

- All 69 working Shopify shops re-harvested with photo links. 20 shops in shops.json have never answered ("no products.json");
  the harvest now keeps a saved catalogue when a shop gives no products.
- The fixes below are in this build. Also: Wine Chateau's "Bx " Bordeaux shelf code is stripped from names (≈740 rows; 93
  turned out to be duplicates and merged).

## 27 Nov 2026: fixes from the app session's notes (in this rebuild)

- Not wine now: ciders/perries (IsCider, Cidery, "Pet Nat Perry"), cocktails (Mai Tai), "0.0%" wines (the old rule never
  matched because of a word-boundary bug), wines whose producer is a rum maker / distillery / brewery (Hamilton Rum).
- Pape Clément **Blanc** as red Merlot from "Cassis": a description's "cassis" (blackcurrant) was read as the Provence
  appellation, and the facts came from the estate's red. Now: place words that are also ordinary words (cassis, graves, port,
  toro …) are ignored in descriptions, and a wine named Blanc / Bianco / Blanco / Branco / White is white. Red grapes are
  dropped from it; Cheval Blanc, Mas Blanc and White Zinfandel are excepted.
- Producers: a small shop vendor that reads like a distributor (Vin Chicago's "SIMPLE FARMER WINES", "THE ORIGINAL WINE
  COMPANY", "GERMAN WINE COLLECTIVE", "STELLAR CELLARS"; Wine Chateau's coded "326 DALLA TERRA") is no longer the producer
  or put in front of the name. The producer in the title wins. Mead is not wine. Wine Chateau bin codes ("BX MED") are
  stripped.
- Harvest bug fixed: a shop counted as saved when its report was unchanged, so ~30 shops kept their old catalogue. The check
  now compares the catalogue file. Those shops are being re-harvested.

## 26 Nov 2026: critics' scores (ralphgeb/Jeroboam#2, merged)

- 28,874 wines with a critic's score; each links to the shop page that quotes it (`score_sources`; app_wines columns 19–20).
- Product pages of 14 shops (`score_pages.yml` -> `score-pages` branch). Repeated menu text and competition medals are ignored.
- Wine Enthusiast scores from the public Feb 2019 dataset, for wines no shop scores (2,264). Never linked. Ralph's decision:
  remove them if anyone complains (delete `sources/wine_enthusiast_scores.csv` and rebuild).

## 25 Nov 2026: clean rebuild (ralphgeb/Jeroboam#1, merged)

- 196,898 wines from 80 shops, no fake producers. CaskCartel kept only for wines no one else sells.
- The old CSVs from the earlier workflow were removed.

## For the other sessions

- The fingerprint keys use `WineDB.key` folding on the **list's** producer / wine name / vintage (not Claude's names), plus the
  list row's shop link, as you suggested. Mapping to the app's keys is still to do.
- The next list rebuild will change some producers and names (the distributor fix) and drop the non-wine rows above.
