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
ladders = load("ladders.yaml") or []
grape_rules = load("grape_rules.yaml") or []

# ---- five levels. The grapes, regions and terms were written for three; they are spread over five here.
def _relevel():
    seen = {}
    def nth(key, i): seen[key] = seen.get(key, -1) + 1; return seen[key]
    for g in grapes:
        o = g["level"]; g["old_level"] = o
        g["level"] = 1 if o == 1 else (3 if o == 2 else (4 if nth("g3", 0) < 20 else 5))
    for r in regions:
        o = r["level"]; r["old_level"] = o
        r["level"] = 2 if o == 1 else (3 if o == 2 else (4 if r["country"] == "France" else 5))
    for t in glossary:
        o = t.get("level", 1)
        k = nth("w%d" % o, 0)
        t["level"] = (1 if k < 14 else 2) if o == 1 else ((3 if k < 34 else 4) if o == 2 else (4 if k < 20 else 5))
_relevel()
UNIT_IDS = load("unit_ids.yaml")
soils = load("soils.yaml") or {}
lids = {l["id"] for l in labels}

maps = {}
for p in glob.glob(os.path.join(MAPS, "*.json")):
    m = json.load(open(p))
    if "id" not in m:          # not a map (e.g. world-countries.json, the Journal's country outlines)
        continue
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
photo_ids = {os.path.splitext(f)[0] for f in os.listdir(PHOTOS) if f.endswith((".jpg", ".heic"))} if os.path.isdir(PHOTOS) else set()

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
    elif kind == "ladder":
        if arg not in {l["id"] for l in ladders}: err(f"{where}: unknown ladder {arg}")
    else:
        err(f"{where}: unknown visual kind {kind}")

for s in styles: check_visual(s.get("visual"), f"style {s['id']}")
# grapes stated as fact from the appellation: every grape must have a page (the app shows it as a link)
_gnames = {g["name"] for g in grapes} | {a for g in grapes for a in (g.get("aka") or [])}
for _r in grape_rules:
    if _r["grape"] not in _gnames: err(f"grape_rules: unknown grape {_r['grape']}")

# ---------------- course
UNIT_COVERS = {
    "l1-what-is-wine": "harvest", "l1-tasting": "sommelier", "l1-white-grapes": "loire-sancerre", "l1-black-grapes": "grape-bunch-red",
    "l1-world": "napa-valley", "l1-food": "corks", "l1-serving": "barrel-cellar",
    "l2-vineyard": "vineyard-rows", "l2-winery": "fermentation-tank", "l2-more-whites": "santorini-kouloura", "l2-more-reds": "barolo-langhe",
    "l2-sparkling": "riddling", "l2-sweet-fortified": "port-lodge", "l2-labels": "bottle-shapes", "l2-label-decoder": "bordeaux-chateau",
    "l3-viticulture": "pruning", "l3-winemaking": "barrel-making", "l3-bordeaux": "saint-emilion", "l3-burgundy": "burgundy-cote",
    "l3-france-more": "rhone-hermitage", "l3-italy": "tuscany-chianti", "l3-iberia": "douro-terraces", "l3-central-europe": "wachau",
    "l3-new-world": "mendoza-andes", "l3-tasting": "veraison", "l1-history": "qvevri",
}
# ---------------- study guides (generated): everything the practice and mock exams can ask is taught here
import random as _rnd
rbyid = {r["id"]: r for r in regions}
gbyid = {g["id"]: g for g in grapes}
def _plain(s): return re.sub(r"\*+", "", s or "").strip()
def _lvl(v): return ["low", "low", "medium-low", "medium", "medium-high", "high"][max(0, min(5, v))]
EUROPE = {"France", "Italy", "Spain", "Portugal", "Germany", "Austria", "Hungary", "Greece", "Lebanon"}

def _grape_card(g):
    rs = [rbyid[r]["name"] for r in g.get("regions", []) if r in rbyid][:6]
    struct = [f"{_lvl(g['body'])} body", f"{_lvl(g['acidity'])} acidity"]
    if g["berry"] != "white" and g.get("tannin"): struct.append(f"{_lvl(g['tannin'])} tannin")
    lines = [_plain(g["summary"]), "",
             f"- **Aromas:** {', '.join(a.lower() for a in g['aromas'][:6])}.",
             f"- **Structure:** {', '.join(struct)}.",
             f"- **Origin:** {g['origin']}."]
    if g.get("aka"): lines.append(f"- **Also called:** {', '.join(g['aka'])}.")
    if rs: lines.append(f"- **Where it grows:** {', '.join(rs)}.")
    if g.get("food"): lines.append(f"- **Food:** {', '.join(f.lower() for f in g['food'][:4])}.")
    card = {"learn": g["name"], "visual": f"grape:{g['id']}", "body": "\n".join(lines)}
    for pid in (f"grape-{g['id']}", f"grape-{g['id'].split('-')[0]}"):
        if pid in photo_ids:
            card["visual"] = f"photo:{pid}"; card["alt"] = f"grape:{g['id']}"; break
    return card

def _grape_questions(gs, pool, rnd):
    qs = []
    for g in gs[:3]:
        same = [x["name"] for x in pool if x["berry"] == g["berry"] and x["id"] != g["id"]]
        if len(same) < 3: same = [x["name"] for x in pool if x["id"] != g["id"]]
        wrong = rnd.sample(same, 3)
        opts = wrong + [g["name"]]; rnd.shuffle(opts)
        qs.append({"choice": f"Which grape shows **{', '.join(a.lower() for a in g['aromas'][:3])}**?",
                   "options": opts, "a": g["name"], "explain": _plain(g["summary"])})
    if len(gs) >= 3:
        pairs, used = [], set()
        for g in gs:
            r = next((rbyid[r]["name"] for r in g.get("regions", []) if r in rbyid and rbyid[r]["name"] not in used), None)
            if r and len(pairs) < 4 and g["name"] not in used:
                used |= {r, g["name"]}; pairs.append([g["name"], r])
        if len(pairs) >= 3:
            qs.append({"match": "Match each grape to a place where it grows", "pairs": pairs,
                       "explain": "Each grape is matched with one of its key regions from the cards above."})
    return qs

def _region_card(r):
    gs = [gbyid[x]["name"] for x in r.get("grapes", []) if x in gbyid]
    lines = [_plain(r["summary"]), ""]
    parent = next((p for p in regions if r["id"] in (p.get("sub") or []) and p["kind"] != "country"), None)
    if r["kind"] != "country": lines.append(f"- **Where:** {parent['name'] + ', ' if parent else ''}{r['country']}.")
    if gs: lines.append(f"- **Grapes:** {', '.join(gs[:5])}.")
    if r.get("climate"): lines.append(f"- **Climate:** {_plain(r['climate'])}")
    if r.get("classification"): lines.append(f"- **Quality system:** {_plain(r['classification'])}")
    for f in (r.get("facts") or [])[:2]: lines.append(f"- {_plain(f)}")
    c = {"learn": r["name"], "body": "\n".join(lines)}
    if r.get("map"):
        hl = ",".join(a for a in (r.get("highlight") or ([] if r["kind"] == "country" else [r["id"]])) if a in maps.get(r["map"], ()))
        c["visual"] = f"map:{r['map']}" + (f":{hl}" if hl else "")
    return c

def _region_questions(rs, rnd):
    qs = []
    named = [r for r in rs if r["kind"] != "country"]
    for r in named[:2]:
        gs = [gbyid[x] for x in r.get("grapes", []) if x in gbyid]
        if not gs: continue
        g = gs[0]
        wrong = [x["name"] for x in grapes if x["berry"] == g["berry"] and x["id"] not in r.get("grapes", [])]
        if len(wrong) < 3: wrong = [x["name"] for x in grapes if x["id"] not in r.get("grapes", [])]
        opts = rnd.sample(wrong, 3) + [g["name"]]; rnd.shuffle(opts)
        qs.append({"choice": f"Which grape is most associated with **{r['name']}**?", "options": opts, "a": g["name"],
                   "explain": f"{r['name']}: {_plain(r['summary'])}"})
    if len(named) >= 3:
        pairs, used = [], set()
        for r in named:
            g = next((gbyid[x]["name"] for x in r.get("grapes", []) if x in gbyid and gbyid[x]["name"] not in used), None)
            if g and r["name"] not in used and len(pairs) < 4:
                used |= {g, r["name"]}; pairs.append([r["name"], g])
        if len(pairs) >= 3:
            qs.append({"match": "Match each region to its signature grape", "pairs": pairs,
                       "explain": "Each region is matched with a grape it is known for, as in the cards above."})
    return qs

def _chunks(xs, n):
    if not xs: return []
    k = max(1, -(-len(xs) // n)); size = -(-len(xs) // k)
    return [xs[i:i + size] for i in range(0, len(xs), size)]

def study_units(n):
    rnd = _rnd.Random(n * 7919)
    units = []
    gs = [g for g in grapes if g["level"] == n]
    lessons = []
    for part in _chunks(gs, 6):
        title = "Grape files: " + ", ".join(g["name"] for g in part[:2]) + ("…" if len(part) > 2 else "")
        lessons.append({"title": title, "cards": [_grape_card(g) for g in part] + _grape_questions(part, grapes, rnd)})
    if lessons:
        units.append((f"study-l{n}-grapes", {"title": "Grape files", "summary": f"Every Level {n} grape on one card: aromas, structure, origin and where it grows.",
                                            "icon": "leaf", "lessons": lessons}))
    rs = [r for r in regions if r["level"] == n]
    order = []
    for r in rs:
        if r["country"] not in order: order.append(r["country"])
    def app_lessons(countries):
        out = []
        for c in countries:
            items = sorted([r for r in rs if r["country"] == c], key=lambda r: (r["kind"] != "country", r["kind"] != "region"))
            parts = _chunks(items, 8)
            for i, part in enumerate(parts):
                names = [r["name"] for r in part if r["kind"] != "country"]
                t = c + (": " + ", ".join(names[:2]) + ("…" if len(names) > 2 else "") if names else "")
                out.append({"title": t, "cards": [_region_card(r) for r in part] + _region_questions(part, rnd)})
        return out
    groups = [("Appellations to know", "Every Level %d region on a card, with its map, grapes and climate." % n, order)] if n < 5 else [
        ("Appellations: France", "Every French appellation in Level 5, on its map.", [c for c in order if c == "France"]),
        ("Appellations: rest of Europe", "Italy, Iberia, central Europe, Greece and Lebanon, region by region.", [c for c in order if c in EUROPE and c != "France"]),
        ("Appellations: New World", "The Americas, South Africa, Australia and New Zealand, region by region.", [c for c in order if c not in EUROPE])]
    for i, (t, s, cs) in enumerate(groups):
        ls = app_lessons(cs)
        if ls: units.append((f"study-l{n}-regions{i}", {"title": t, "summary": s, "icon": "map", "lessons": ls}))
    terms = [t for t in glossary if t.get("level", 1) == n]
    lessons = []
    for i, part in enumerate(_chunks(terms, 8)):
        cards = []
        for t in part:
            sl = re.sub(r"[^a-z0-9]+", "-", t["term"].lower()).strip("-")
            c = {"learn": t["term"], "body": _plain(t["def"])}
            if "w-" + sl in photo_ids: c["visual"] = "photo:w-" + sl
            cards.append(c)
        for t in rnd.sample(part, min(3, len(part))):
            wrong = rnd.sample([x["def"] for x in terms if x["term"] != t["term"]], 3)
            opts = wrong + [t["def"]]; rnd.shuffle(opts)
            cards.append({"choice": f"What does **{t['term']}** mean?", "options": opts, "a": t["def"], "explain": f"{t['term']}: {_plain(t['def'])}"})
        lessons.append({"title": f"Vocabulary {i + 1}: {part[0]['term']} to {part[-1]['term']}", "cards": cards})
    if n == 3:
        for part in _chunks(styles, 6):
            cards = [{"learn": s["name"], "body": f"{_plain(s['summary'])}\n\n- **How:** {_plain(s['how'])}\n- **Examples:** {', '.join(s['examples'][:4])}.",
                      **({"visual": s["visual"]} if s.get("visual") else {})} for s in part]
            s = rnd.choice(part)
            opts = rnd.sample([x["name"] for x in styles if x["id"] != s["id"]], 3) + [s["name"]]; rnd.shuffle(opts)
            cards.append({"choice": f"**{s['examples'][0]}** is an example of which style?", "options": opts, "a": s["name"], "explain": _plain(s["summary"])})
            lessons.append({"title": "Styles: " + ", ".join(x["name"] for x in part[:2]) + "…", "cards": cards})
    if lessons:
        units.append((f"study-l{n}-words", {"title": "Words to know", "summary": "The vocabulary and styles the exams use, in short lists.",
                                           "icon": "text.book.closed", "lessons": lessons}))
    return units

levels_meta = load("levels.yaml")
# unique pictures: a new cover per unit and new photos for cards that used to repeat one (see photo_assign.yaml)
ASSIGN = load("photo_assign.yaml") if os.path.exists(os.path.join(SRC, "photo_assign.yaml")) else {}
UNIT_COVERS.update(ASSIGN.get("covers", {}))
CARD_PHOTOS = ASSIGN.get("cards", {})
course = {"levels": []}
card_count = 0
lesson_ids = set()
for lv in levels_meta:
    level = {"id": f"l{lv['number']}", "number": lv["number"], "title": lv["title"], "subtitle": lv["subtitle"],
             "color": lv.get("color", "#7D1D3F"), "units": []}
    sources = [(f, load(os.path.join("course", f + ".yaml"))) for f in lv["units"]] + study_units(lv["number"])
    for ui, (ufile, u) in enumerate(sources):
        deep = os.path.join(SRC, "deep", ufile + ".yaml")
        if os.path.exists(deep):
            # deep-dive lessons go before the closing "Going further" lesson
            extra = load(os.path.join("deep", ufile + ".yaml"))
            tail = [l for l in u["lessons"] if l["title"] == "Going further"]
            u["lessons"] = [l for l in u["lessons"] if l["title"] != "Going further"] + extra + tail
        uid = UNIT_IDS.get(ufile) or f"l{lv['number']}s{ui + 1}"
        unit = {"id": uid, "title": u["title"], "summary": u["summary"], "icon": u.get("icon", "book"), "lessons": []}
        if ufile.startswith("study-"): unit["study"] = True
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
                if c.get("alt"): out["alt"] = c["alt"]
                key = f"{ufile} | {ls['title']} | {c.get('learn', '')}"
                if key in CARD_PHOTOS and CARD_PHOTOS[key] in photo_ids:
                    c["visual"] = "photo:" + CARD_PHOTOS[key]
                if c.get("visual"):
                    if check_visual(c["visual"], where) != "drop":
                        out["visual"] = c["visual"]
                cards.append(out)
                card_count += 1
            unit["lessons"].append({"id": lid, "title": ls["title"], "icon": ls.get("icon"), "cards": cards})
        level["units"].append(unit)
    course["levels"].append(level)

# teaching audit: the right answer of every choice question should be taught somewhere in the learn cards
_taught = "\n".join(((c.get("title") or "") + " " + (c.get("body") or "")).lower()
                    for lvl in course["levels"] for u in lvl["units"] for ls in u["lessons"] for c in ls["cards"] if c["t"] == "learn")
_untaught = 0
for lvl in course["levels"]:
    for u in lvl["units"]:
        for ls in u["lessons"]:
            for c in ls["cards"]:
                if c["t"] == "choice":
                    a = str(c["options"][c["a"]]).lower().strip(". ")
                    if len(a) >= 4 and a not in _taught and a not in ("true", "false"):
                        _untaught += 1
                        if _untaught <= 12: warn(f"answer not taught in any learn card: {u['title']} / {ls['title']}: {c['q'][:60]} -> {a[:40]}")
if _untaught: warn(f"{_untaught} choice answers are not found verbatim in the learn cards")

# no picture twice: lesson cards keep their photo in course order; a later repeat (or a cover that
# repeats any card) is dropped.
seen_photos = set()
for lvl in course["levels"]:
    for u in lvl["units"]:
        for ls in u["lessons"]:
            for card in ls["cards"]:
                v = card.get("visual") or ""
                alt = card.pop("alt", None)
                if v.startswith("photo:"):
                    if v[6:] in seen_photos:
                        if alt: card["visual"] = alt
                        else: del card["visual"]
                    else: seen_photos.add(v[6:])
dropped_covers = 0
for lvl in course["levels"]:
    for u in lvl["units"]:
        cv = u.get("cover")
        if cv and cv in seen_photos: del u["cover"]; dropped_covers += 1
        elif cv: seen_photos.add(cv)
if dropped_covers: warn(f"{dropped_covers} unit covers repeat a lesson photo and were dropped")

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

facts = [str(f).strip() for f in load("facts.yaml")]
if len(set(facts)) != len(facts): err("duplicate fun facts")
if len(facts) < 100: warn(f"only {len(facts)} fun facts (want 100+ so mornings don't repeat)")
hist = load("region_history.yaml")
for rid, h in hist.items():
    r = next((x for x in regions if x["id"] == rid), None)
    if r is None: warn(f"history for unknown region {rid}"); continue
    r["history"] = str(h).strip()
great_base = {g["id"]: g for g in load("greatwines.yaml")}
great, area, area_vintages = [], None, []
rname = {r["id"]: r["name"] for r in regions}
great_lines = []
for fn in ["greatwines_more.txt"] + sorted(os.path.basename(p) for p in glob.glob(os.path.join(SRC, "great", "*.txt"))):
    path = os.path.join(SRC, fn) if fn == "greatwines_more.txt" else os.path.join(SRC, "great", fn)
    great_lines += [(fn, i, l) for i, l in enumerate(open(path, encoding="utf-8"), 1)]
for src_file, ln, line in great_lines:
    line = line.strip()
    if not line or line.startswith("# "): continue
    if line.startswith("## "):
        area, vs = [x.strip() for x in line[3:].split("|")]
        area_vintages = [v.strip() for v in vs.split(",")]
        continue
    if line.startswith("= "):
        gw = dict(great_base[line[2:].strip()])
        gw["snapshot"] = gw.get("photo")   # the real photo, shown on the detail page
    else:
        f = [x.strip() for x in line.split("|")]
        if len(f) != 10: err(f"{src_file}:{ln}: {len(f)} fields"); continue
        lo, hi = [int(x) for x in f[6].split("-")]
        gw = {"id": f[0], "name": f[1], "producer": f[2], "region": f[3], "grapes": [g.strip() for g in f[4].split(",")],
              "color": f[5], "price": [lo, hi], "scores": f[7], "what": f[8], "why": f[9], "vintages": area_vintages}
    gw["area"] = area
    gw["zone"] = f"{area} · {rname.get(gw['region'], gw['region'])}" if rname.get(gw["region"]) not in (None, area) else area
    gw.pop("photo", None)
    great.append(gw)
if len({g["id"] for g in great}) != len(great): err("duplicate great wine ids")
# real figures looked up on Wine-Searcher (content/great_prices.txt); the rest stay marked as estimates
real = {}
pp = os.path.join(SRC, "great_prices.txt")
if os.path.exists(pp):
    for line in open(pp, encoding="utf-8"):
        if not line.strip() or line.startswith("#"): continue
        f = [x.strip() for x in line.split("|")]
        real[f[0]] = f
gids_set = {g["id"] for g in great}
for k in real:
    if k not in gids_set: warn(f"great_prices.txt: unknown wine {k}")
for gw in great:
    f = real.get(gw["id"])
    if f:
        if f[1] not in ("-", ""): gw["avgPrice"] = int(f[1])
        if f[2] not in ("-", ""): gw["criticScore"] = int(f[2])
        gw["source"] = f[3]
_lp = os.path.join(SRC, "label_pos.json")
LABEL_POS = json.load(open(_lp)) if os.path.exists(_lp) else {}
# keep the strongest wines: 25 for the big areas, 10 for the rest (real figures first, then critic score, then list order)
BIG = {"Bordeaux": 25, "Burgundy": 25, "Champagne": 25, "Piedmont": 25, "Tuscany": 25, "Spain": 25}
def _score(g):
    if g.get("criticScore"): return g["criticScore"]
    import re as _re
    nums = [int(x) for x in _re.findall(r"\d+", g.get("scores", ""))]
    return max(nums) if nums else 0
_by = {}
for i, g in enumerate(great): _by.setdefault(g["area"], []).append((i, g))
_keep = set()
for area, items in _by.items():
    items.sort(key=lambda t: (0 if t[1].get("source") else 1, -_score(t[1]), t[0]))
    for i, g in items[:BIG.get(area, 10)]: _keep.add(g["id"])
great = [g for g in great if g["id"] in _keep]
print(f"great wines with real figures: {sum(1 for g in great if g.get('source'))}/{len(great)}")
for gw in great:
    if gw["region"] not in rset: err(f"great wine {gw['id']}: unknown region {gw['region']}")
    # grapes without a page in the app are kept as plain names
    known = [g for g in gw["grapes"] if g in gset]
    other = [g.replace("-", " ").title() if g == g.lower() else g for g in gw["grapes"] if g not in gset]
    gw["grapes"] = known
    if other: gw["also"] = other
    if gw.get("snapshot") and gw["snapshot"] not in photo_ids: gw["snapshot"] = None
    if "bw-" + gw["id"] in photo_ids: gw["bottle"] = "bw-" + gw["id"]
    if gw.get("bottle") and gw["id"] in LABEL_POS: gw["labelY"] = LABEL_POS[gw["id"]]
library = {"great": great, "facts": facts, "wines": wines, "grapes": grapes, "regions": regions, "aromas": aromas, "colors": colors, "glossary": glossary,
           "styles": styles, "flows": flows, "sat": sat, "pairings": pairings, "labels": labels, "ladders": ladders, "grapeRules": grape_rules}

_known = set(rids)
for _m in maps.values(): _known |= _m
for k in soils:
    if k not in _known: warn(f"soil for unknown place {k}")
library["soils"] = soils

# ---- maps beyond the atlas (content/extra/<map>.yaml): their own guide entries, shown from Settings and used by the Journal
extra_regions, extra_soils = [], {}
_taken = set(rids)
for fp in sorted(glob.glob(os.path.join(SRC, "extra", "*.yaml"))):
    spec = yaml.safe_load(open(fp, encoding="utf-8"))
    mid, c = spec["map"], spec["country"]
    if mid not in maps:
        err(f"extra map {mid}: map file not built"); continue
    if mid in _taken: err(f"extra map id {mid} collides with another place")
    _taken.add(mid)
    top = [r["id"] for r in spec["regions"] if not r.get("parent")]
    def entry(r, kind, sub=None):
        for gid in r.get("grapes", []) or []:
            if gid not in gset: err(f"extra {r['id']} -> unknown grape {gid}")
        # a place drawn as a dot (no official boundary) highlights the area it belongs to
        hl = [] if kind == "country" else ([r["parent"]] if "point" in r and r.get("parent") else ([] if "point" in r else [r["id"]]))
        e = {"id": r["id"], "name": r["name"], "country": c["name"], "kind": kind, "map": mid,
             "highlight": hl, "grapes": r.get("grapes") or [], "summary": r["summary"], "level": 3}
        for k in ("climate", "styles", "classification", "history", "facts", "local"):
            if r.get(k): e[k] = r[k]
        if sub: e["sub"] = sub
        if spec.get("atlas"): e["atlas"] = True      # shown in the main Atlas, not only under "Maps beyond the atlas"
        return e
    extra_regions.append(entry({"id": mid, "name": c["name"], **c}, "country", top))
    if c.get("soil"): extra_soils[mid] = c["soil"]
    for r in spec["regions"]:
        if r["id"] in _taken: err(f"extra region id {r['id']} is already used")
        _taken.add(r["id"])
        if r["id"] not in maps[mid] and "point" not in r: err(f"extra region {r['id']} is not on map {mid} (geometry missing?)")
        kids = [k["id"] for k in spec["regions"] if k.get("parent") == r["id"]]
        extra_regions.append(entry(r, "subregion" if r.get("parent") else "region", kids or None))
        if r.get("soil"): extra_soils[r["id"]] = r["soil"]

# ---- where places are on the earth (lat, lon): every map area, plus a centre for each country page. The Journal's world map uses it.
places, _lv0 = {}, {}
for _p in glob.glob(os.path.join(MAPS, "*.json")):
    _m = json.load(open(_p))
    if "id" not in _m:         # not a map
        continue
    for _a in _m.get("areas", []):
        if _a.get("ll"):
            places.setdefault(_a["id"], _a["ll"])
            if _a.get("lv", 0) == 0: _lv0.setdefault(_m["id"], []).append(_a["ll"])
    if _m["id"] not in _lv0:
        _lv0[_m["id"]] = [a["ll"] for a in _m.get("areas", []) if a.get("ll")]
for _r in regions + extra_regions:
    if _r["kind"] == "country" and _r.get("map") and _lv0.get(_r["map"]):
        _pts = _lv0[_r["map"]]
        places[_r["id"]] = [round(sum(p[0] for p in _pts) / len(_pts), 3), round(sum(p[1] for p in _pts) / len(_pts), 3)]

for w in warnings: print("warning:", w)
for e in errors: print("ERROR:", e)
if errors:
    sys.exit(1)

os.makedirs(OUT, exist_ok=True)
json.dump(course, open(os.path.join(OUT, "course.json"), "w"), ensure_ascii=False, separators=(",", ":"))
json.dump(library, open(os.path.join(OUT, "library.json"), "w"), ensure_ascii=False, separators=(",", ":"))
json.dump(places, open(os.path.join(OUT, "places.json"), "w"), separators=(",", ":"))
print(f"places: {len(places)} with coordinates")
json.dump({"regions": extra_regions, "soils": extra_soils}, open(os.path.join(OUT, "extra.json"), "w"), ensure_ascii=False, separators=(",", ":"))
print(f"extra atlas: {len([r for r in extra_regions if r['kind'] == 'country'])} maps, {len(extra_regions)} places")
n_lessons = sum(len(u["lessons"]) for l in course["levels"] for u in l["units"])
n_units = sum(len(l["units"]) for l in course["levels"])
print(f"OK: {len(course['levels'])} levels, {n_units} units, {n_lessons} lessons, {card_count} cards; "
      f"{len(grapes)} grapes, {len(regions)} regions, {len(aroma_items)} aromas, {len(glossary)} terms, {len(styles)} styles")
