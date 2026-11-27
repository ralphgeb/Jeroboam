"""Which scanned wines needed the paid online check? Reads every scanned wine from the worker (/wines/export, with its JSON) and
sorts them by how their grapes were settled, the way the app decides (WineRecognizer.verifyOnline):
  free  - from our wine list (from_database), or grapes fixed by the appellation rule / printed on the label (certainGrapes)
  paid  - checked online (checked) and none of the above: the free pages (shop page + DuckDuckGo) or, mostly, the ~1.2 c search
  none  - not checked (older scans, before the online check existed, or the daily allowance was reached)
Env URL, KEY. Writes paid_scans.md."""
import json, os, sys, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
URL, KEY = os.environ["URL"].rstrip("/"), os.environ["KEY"]
req = urllib.request.Request(URL + "/wines/export?limit=5000", headers={"x-jero-key": KEY, "user-agent": "jero-paid-scans"})
rows = json.load(urllib.request.urlopen(req, timeout=60))["rows"]
import yaml, unicodedata, re
def fold(s): return "".join(c for c in unicodedata.normalize("NFD", (s or "").lower()) if unicodedata.category(c) != "Mn").replace("’", "'")
def has(w, t): return re.search(r"(?<![a-z])" + re.escape(fold(w)) + r"(?![a-z])", t) is not None
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
lib = json.load(open(os.path.join(ROOT, "Jeroboam/Resources/Content/library.json"), encoding="utf-8"))
ALIAS = {fold(n) for g in lib["grapes"] for n in [g["name"]] + (g.get("aka") or []) if len(n) >= 4} - {"breton", "bouchet", "rolle", "jaen"}
RULES = yaml.safe_load(open(os.path.join(ROOT, "content/grape_rules.yaml"), encoding="utf-8"))
def rule(w):
    t = fold(w.get("region", "") + " " + w.get("name", ""))
    st = (w.get("style") or "").lower(); col = "red" if "red" in st else ("white" if "white" in st else "")
    for r in RULES:
        if r.get("color") and r["color"] != col: continue
        if any(has(x, t) for x in r.get("not") or []): continue
        if any(has(m, t) for m in r["match"]): return "appellation rule"
    n = fold(w.get("name", ""))
    if any(has(a, n) for a in ALIAS): return "grape on the label"
    return None
out = {"paid": [], "free": [], "none": []}
for r in rows:
    try: w = json.loads(r.get("json") or "{}")
    except Exception: w = {}
    line = f"{r.get('producer','')} — {r.get('name','')} {r.get('vintage','') or ''}".strip()
    if w.get("from_database"): out["free"].append(line + " (our wine list)")
    elif rule(w): out["free"].append(line + f" ({rule(w)})")
    elif w.get("checked"): out["paid"].append(line)
    else: out["none"].append(line)
rep = [f"# Scanned wines by cost ({len(rows)} in the online list)", "",
       f"## Online check, probably paid (~1.2 c each): {len(out['paid'])}", ""] + [f"- {x}" for x in out["paid"]] + \
      ["", f"## Free: {len(out['free'])}", ""] + [f"- {x}" for x in out["free"]] + \
      ["", f"## Not checked online: {len(out['none'])}", ""] + [f"- {x}" for x in out["none"]]
open("paid_scans.md", "w").write("\n".join(rep)); print("\n".join(rep))
