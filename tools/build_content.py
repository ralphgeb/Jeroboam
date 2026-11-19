#!/usr/bin/env python3
"""Compiles content/*.yaml into Jeroboam/Resources/Content/{course,library}.json and validates it.

Course units live in content/course/*.yaml (one unit per file); levels.yaml lists them in order.
Card shorthand in YAML:
  - learn: Title          body: |...   visual: spec
  - choice: Question?     options: [...]  a: correct option text   explain: ...
  - blank: Text with ___  answers: [word]  options: [distractors]  explain: ...
  - tf: Statement.        truth: true/false   explain: ...
  - match: Prompt         pairs: [[left, right], ...]   explain: ...
"""
import json, os, re, sys, glob
import yaml

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "content")
OUT = os.path.join(ROOT, "Jeroboam", "Resources", "Content")
MAPS = os.path.join(ROOT, "Jeroboam", "Resources", "Maps")

errors, warnings = [], []
def err(m): errors.append(m)
def warn(m): warnings.append(m)

def load(name):
    with open(os.path.join(SRC, name)) as f:
        return yaml.safe_load(f)

# ---------------- library
grapes = load("grapes.yaml")
regions = load("regions.yaml")
aromas = load("aromas.yaml")
colors = load("colors.yaml")
glossary = load("glossary.yaml")
styles = load("styles.yaml")
flows = load("flows.yaml")
sat = load("sat.yaml")
pairings = load("pairings.yaml")
labels = load("labels.yaml")
lids = {l["id"] for l in labels}

maps = {}
for p in glob.glob(os.path.join(MAPS, "*.json")):
    m = json.load(open(p))
    maps[m["id"]] = {r["id"] for r in m.get("areas", m.get("regions", []))}

gids = [g["id"] for g in grapes]
rids = [r["id"] for r in regions]
cids = [c["id"] for c in colors]
fids = [f["id"] for f in flows]
for name, ids in (("grape", gids), ("region", rids), ("color", cids), ("flow", fids)):
    dup = {i for i in ids if ids.count(i) > 1}
    if dup: err(f"duplicate {name} ids: {dup}")
gset, rset, cset, fset = set(gids), set(rids), set(cids), set(fids)

aroma_items = {}
for grp in aromas:
    for cat in grp["categories"]:
        for it in cat["items"]:
            k = it.lower()
            if k in aroma_items: err(f"aroma '{it}' in both {aroma_items[k]} and {cat['id']}")
            aroma_items[k] = cat["id"]

for g in grapes:
    for k in ("name", "berry", "origin", "summary", "body", "acidity", "tannin", "alcohol", "sweetness", "aromas", "regions", "food", "glass", "level"):
        if k not in g: err(f"grape {g['id']} missing {k}")
    if g.get("berry") not in ("black", "white", "pink"): err(f"grape {g['id']} bad berry")
    for r in g.get("regions", []):
        if r not in rset: err(f"grape {g['id']} -> unknown region {r}")
    if g.get("glass") not in cset: err(f"grape {g['id']} -> unknown glass color {g.get('glass')}")
    unknown = [a for a in g.get("aromas", []) if a.lower() not in aroma_items]
    if unknown: warn(f"grape {g['id']} aromas not in lexicon: {unknown}")

for r in regions:
    for k in ("name", "country", "kind", "grapes", "summary", "level"):
        if k not in r: err(f"region {r['id']} missing {k}")
    for gid in r.get("grapes", []):
        if gid not in gset: err(f"region {r['id']} -> unknown grape {gid}")
    for s in r.get("sub", []) or []:
        if s not in rset: err(f"region {r['id']} -> unknown sub {s}")
    m = r.get("map")
    if m:
        if m not in maps: err(f"region {r['id']} -> unknown map {m}")
        else:
            for h in r.get("highlight", []) or []:
                if h not in maps[m]: err(f"region {r['id']} highlight {h} not on map {m}")
    r.setdefault("grapes", [])

# every region area on a map should ideally have an entry
missing_entries = sum(1 for mid, areas in maps.items() for a in areas if a not in rset)
if missing_entries: print(f"note: {missing_entries} map areas have no region guide (shown with name only)")

PHOTOS = os.path.join(os.path.dirname(OUT), "Photos")
photo_ids = {f[:-4] for f in os.listdir(PHOTOS) if f.endswith(".jpg")} if os.path.isdir(PHOTOS) else set()

def check_visual(v, where):
    if not v: return
    parts = v.split(":", 2)
    kind = parts[0]; arg = parts[1] if len(parts) > 1 else ""
    if kind == "map":
        if arg not in maps: err(f"{where}: unknown map {arg}"); return
        if len(parts) > 2:
            for h in parts[2].split(","):
                if h and h not in maps[arg]: err(f"{where}: highlight {h} not on map {arg}")
    elif kind in ("grape", "profile", "aromas"):
        if arg not in gset: err(f"{where}: unknown grape {arg}")
    elif kind in ("glass", "glassonly"):
        if arg not in cset: err(f"{where}: unknown color {arg}")
    elif kind == "colors":
        if arg not in ("white", "rose", "red"): err(f"{where}: bad color family {arg}")
    elif kind == "flow":
        if arg not in fset: err(f"{where}: unknown flow {arg}")
    elif kind == "diagram":
        if arg not in ("vine-cycle", "climate", "grape-anatomy", "bottle-sizes", "serving-temps", "sweetness", "solera",
                       "wine-belt", "glass-shapes", "three-colors", "tannin-acid"):
            err(f"{where}: unknown diagram {arg}")
    elif kind == "wheel":
        pass
    elif kind == "photo":
        if arg not in photo_ids: warn(f"{where}: photo {arg} not downloaded yet (hidden)"); return "drop"
    elif kind == "label":
        if arg not in lids: err(f"{where}: unknown label {arg}")
    else:
        err(f"{where}: unknown visual kind {kind}")

for s in styles: check_visual(s.get("visual"), f"style {s['id']}")

# ---------------- course
UNIT_COVERS = {
    "l1-what-is-wine": "harvest", "l1-tasting": "sommelier", "l1-white-grapes": "loire-sancerre", "l1-black-grapes": "grape-bunch-red",
    "l1-world": "napa-valley", "l1-food": "corks", "l1-serving": "barrel-cellar",
    "l2-vineyard": "vineyard-rows", "l2-winery": "fermentation-tank", "l2-more-whites": "santorini-kouloura", "l2-more-reds": "barolo-langhe",
    "l2-sparkling": "riddling", "l2-sweet-fortified": "port-lodge", "l2-labels": "bottle-shapes", "l2-label-decoder": "bordeaux-chateau",
    "l3-viticulture": "pruning", "l3-winemaking": "barrel-making", "l3-bordeaux": "saint-emilion", "l3-burgundy": "burgundy-cote",
    "l3-france-more": "rhone-hermitage", "l3-italy": "tuscany-chianti", "l3-iberia": "douro-terraces", "l3-central-europe": "wachau",
    "l3-new-world": "mendoza-andes", "l3-tasting": "veraison",
}
levels_meta = load("levels.yaml")
course = {"levels": []}
card_count = 0
lesson_ids = set()
for lv in levels_meta:
    level = {"id": f"l{lv['number']}", "number": lv["number"], "title": lv["title"], "subtitle": lv["subtitle"],
             "color": lv.get("color", "#7D1D3F"), "units": []}
    for ui, ufile in enumerate(lv["units"]):
        u = load(os.path.join("course", ufile + ".yaml"))
        deep = os.path.join(SRC, "deep", ufile + ".yaml")
        if os.path.exists(deep):
            # deep-dive lessons go before the closing "Going further" lesson
            extra = load(os.path.join("deep", ufile + ".yaml"))
            tail = [l for l in u["lessons"] if l["title"] == "Going further"]
            u["lessons"] = [l for l in u["lessons"] if l["title"] != "Going further"] + extra + tail
        uid = f"l{lv['number']}u{ui + 1}"
        unit = {"id": uid, "title": u["title"], "summary": u["summary"], "icon": u.get("icon", "book"), "lessons": []}
        cover = u.get("cover") or UNIT_COVERS.get(ufile)
        if cover:
            if cover in photo_ids: unit["cover"] = cover
            else: warn(f"{ufile}: cover photo {cover} missing")
        for li, ls in enumerate(u["lessons"]):
            lid = f"{uid}{chr(97 + li)}"
            if lid in lesson_ids: err(f"dup lesson {lid}")
            lesson_ids.add(lid)
            cards = []
            for ci, c in enumerate(ls["cards"]):
                cid = f"{lid}-{ci + 1}"
                where = f"{ufile}/{ls['title']}/#{ci + 1}"
                out = {"id": cid}
                if "learn" in c:
                    out.update(t="learn", title=c["learn"], body=c.get("body", "").strip())
                elif "choice" in c:
                    opts = [str(o) for o in c["options"]]
                    a = str(c["a"])
                    if a not in opts:
                        err(f"{where}: answer '{a}' not in options {opts}")
                        continue
                    if len(set(opts)) != len(opts): err(f"{where}: duplicate options")
                    out.update(t="choice", q=c["choice"], options=opts, a=opts.index(a))
                elif "blank" in c:
                    q = c["blank"]
                    answers = [str(x) for x in c["answers"]]
                    n = q.count("___")
                    if n != len(answers): err(f"{where}: {n} blanks but {len(answers)} answers")
                    opts = [str(o) for o in c.get("options", [])]
                    bank = opts + [x for x in answers if x not in opts]
                    if len(set(bank)) != len(bank): err(f"{where}: duplicate words in bank")
                    if len(bank) < len(answers) + 2: warn(f"{where}: small word bank")
                    out.update(t="blank", q=q, answers=answers, options=opts)
                elif "tf" in c:
                    if not isinstance(c.get("truth"), bool): err(f"{where}: tf needs truth: true/false")
                    out.update(t="tf", q=c["tf"], truth=c["truth"])
                elif "match" in c:
                    pairs = [[str(a), str(b)] for a, b in c["pairs"]]
                    lefts = [p[0] for p in pairs]; rights = [p[1] for p in pairs]
                    if len(set(lefts)) != len(lefts) or len(set(rights)) != len(rights): err(f"{where}: duplicate match items")
                    if set(lefts) & set(rights): err(f"{where}: match item on both sides")
                    out.update(t="match", q=c["match"], pairs=pairs)
                else:
                    err(f"{where}: unknown card type {list(c.keys())}")
                    continue
                if c.get("explain"): out["explain"] = c["explain"].strip()
                elif out["t"] != "learn": warn(f"{where}: question without explanation")
                if c.get("visual"):
                    if check_visual(c["visual"], where) != "drop":
                        out["visual"] = c["visual"]
                cards.append(out)
                card_count += 1
            unit["lessons"].append({"id": lid, "title": ls["title"], "icon": ls.get("icon"), "cards": cards})
        level["units"].append(unit)
    course["levels"].append(level)

wines = load("wines.yaml")
sids = {s["id"] for s in styles}
wids = [w["id"] for w in wines]
if len(set(wids)) != len(wids): err("duplicate wine ids")
for w in wines:
    if w["region"] not in rset: err(f"wine {w['id']}: unknown region {w['region']}")
    if w["style"] not in sids: err(f"wine {w['id']}: unknown style {w['style']}")
    if w["glass"] not in cset: err(f"wine {w['id']}: unknown glass color {w['glass']}")
    for g in w["grapes"]:
        if g not in gset: err(f"wine {w['id']}: unknown grape {g}")
    w["summary"] = w["summary"].strip()

library = {"wines": wines, "grapes": grapes, "regions": regions, "aromas": aromas, "colors": colors, "glossary": glossary,
           "styles": styles, "flows": flows, "sat": sat, "pairings": pairings, "labels": labels}

for w in warnings: print("warning:", w)
for e in errors: print("ERROR:", e)
if errors:
    sys.exit(1)

os.makedirs(OUT, exist_ok=True)
json.dump(course, open(os.path.join(OUT, "course.json"), "w"), ensure_ascii=False, separators=(",", ":"))
json.dump(library, open(os.path.join(OUT, "library.json"), "w"), ensure_ascii=False, separators=(",", ":"))
n_lessons = sum(len(u["lessons"]) for l in course["levels"] for u in l["units"])
n_units = sum(len(l["units"]) for l in course["levels"])
print(f"OK: {len(course['levels'])} levels, {n_units} units, {n_lessons} lessons, {card_count} cards; "
      f"{len(grapes)} grapes, {len(regions)} regions, {len(aroma_items)} aromas, {len(glossary)} terms, {len(styles)} styles")
