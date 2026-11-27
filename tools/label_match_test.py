"""Scanning option 3, tested before it is built: can the phone name a wine from its label text alone, by finding it in our wine
list (content/prices/app_wines.tsv.z), without asking Claude?

Test set: every wine scanned so far (the worker's /wines/export: the label "signature" the phone kept, and the wine Claude
decided it was). The signature is only part of the label (words of 4+ letters from its first 4 lines, at most 8), so the
phone, which has the whole label text, should do at least as well as this.

For each label: the list's wines whose words are ALL printed on the label (at least two real words, generic ones like
"chateau" not counted) are candidates; the most specific one wins, and only when no other different wine is as specific
(else: ambiguous -> Claude). The winner is compared with Claude's answer.

Run on GitHub (label-match.yml), which has the worker's address and key. Env URL, KEY. Writes label_match_report.md.
"""
import json, os, re, sys, unicodedata, urllib.request, zlib
from collections import defaultdict

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SKIP = {"wine", "wines", "the", "and", "des", "les", "del", "della", "domaine", "cuvee", "vintage"}   # PriceBook.skip
GENERIC = {"chateau", "bodega", "bodegas", "weingut", "tenuta", "cantina", "estate", "winery", "vineyard", "vineyards", "cellars",
           "family", "maison", "casa", "vina", "vino", "vins", "wines", "red", "white", "rose", "rosso", "bianco", "rouge", "blanc",
           "tinto", "blanco", "reserve", "reserva", "riserva", "grand", "vin", "france", "italy", "spain", "doc", "docg", "aoc",
           "igt", "appellation", "controlee", "origine", "protegee", "denominazione", "product", "produit", "bottled", "estate"}

def fold(s):
    return "".join(c for c in unicodedata.normalize("NFD", (s or "").lower()) if unicodedata.category(c) != "Mn")

def tokens(s):
    """PriceBook.tokens: letters/digits runs of 3+, minus skip words and 4-digit years."""
    out = set()
    for t in re.findall(r"[^\W_]+", fold(s)):
        if len(t) >= 3 and t not in SKIP and not (len(t) == 4 and t.isdigit()): out.add(t)
    return out

# words shops add that a label may not print: packaging, sizes, countries, quality tiers in the abstract
NOISE = {"magnum", "jeroboam", "half", "bottle", "bottles", "case", "gift", "box", "astuccio", "cassetta", "legno", "coffret", "etui",
         "italy", "france", "spain", "portugal", "germany", "austria", "usa", "california", "australia", "zealand", "chile",
         "argentina", "africa", "south", "lebanon", "greece", "hungary", "limited", "edition", "doc", "docg", "aoc", "aop", "igt",
         "igp", "dop", "dоса", "freres", "fils", "pere", "sons", "brothers", "nv", "750ml", "375ml", "1500ml", "150cl", "75cl"}
MIN = 4   # the signature keeps only words of 4+ letters; the phone would use every word of 3+

# a wine's own name keeps colour and tier words (Maximum Rosé is not Maximum Blanc de Blancs, Réserve du Couvent is not the plain one)
NAME_GENERIC = {"chateau", "bodega", "bodegas", "weingut", "tenuta", "cantina", "estate", "winery", "vineyard", "vineyards",
                "cellars", "family", "maison", "casa", "vina", "vino", "vins", "wines", "vin", "appellation", "controlee",
                "origine", "protegee", "denominazione", "product", "produit", "bottled"}

def core(s, drop=(), generic=GENERIC):
    return frozenset(t for t in tokens(s) if len(t) >= MIN and t not in generic and t not in NOISE and t not in drop)

def load_list():
    """Every wine in the list as (producer words, own-name words): the name minus the producer, packaging, country and the
    wine's own region/appellation (printed on some labels, not on others, so they are not required)."""
    raw = zlib.decompress(open(os.path.join(ROOT, "content/prices/app_wines.tsv.z"), "rb").read(), -15).decode()
    wines = {}
    for line in raw.split("\n"):
        f = line.split("\t")
        if len(f) < 8: continue
        place = tokens((f[11] if len(f) > 11 else "") + " " + (f[12] if len(f) > 12 else ""))
        P = core(f[1], drop=place)   # "Domaine X: Gevrey-Chambertin": the place is not the producer
        N = core(f[0], drop=set(tokens(f[1])) | place, generic=NAME_GENERIC)
        if not P or not N: continue
        k = (P, N, frozenset(t for t in place if len(t) >= MIN and t not in GENERIC))
        if k not in wines: wines[k] = (f[0], f[1], f[13] if len(f) > 13 else "", f[11] if len(f) > 11 else "")
    index = defaultdict(list)
    for k in wines:
        for w in k[1]: index[w].append(k)
    return wines, index

# words that appear on many labels: a wine whose own name is only these needs its appellation on the label too
WEAK = {"grand", "reserve", "reserva", "riserva", "vieilles", "vignes", "rouge", "blanc", "blancs", "rose", "rosso", "bianco",
        "tinto", "blanco", "brut", "classico", "superiore", "selection", "special", "cuvee", "premier", "villages", "crianza",
        "estate", "old", "vines", "red", "white", "dry", "sec"}

def deletes(w):
    return {w[:i] + w[i + 1:] for i in range(len(w))}

def fuzzy_index(index):
    """For each list word of 5+ letters, the forms one letter shorter: a label word one letter off finds it (SymSpell-style)."""
    near = defaultdict(set)
    for w in index:
        if len(w) >= 5:
            near[w].add(w)
            for d in deletes(w): near[d].add(w)
    return near

def corrected(label_words, index, near):
    """The label's words, plus the list word each 6+ letter label word is one typo away from (only when that is unique)."""
    out = set(label_words)
    for w in label_words:
        if w in index or len(w) < 6: continue
        cands = set(near.get(w, ())) | {x for d in deletes(w) for x in near.get(d, ())}
        cands = {c for c in cands if abs(len(c) - len(w)) <= 1}
        if len(cands) == 1: out |= cands
    return out

def match(label_words, wines, index):
    """The list's wine whose producer is on the label and whose own name is entirely on it: the one with the longest name
    wins; another producer's or another cuvée's name just as long -> ambiguous (ask Claude)."""
    L = {t for t in label_words if len(t) >= MIN}
    if NEAR is not None: L = corrected(L, index, NEAR)
    seen, cands = set(), []
    for w in L:
        for k in index.get(w, ()):
            if k in seen: continue
            seen.add(k)
            P, N, Pl = k
            # the producer on the label (more than half of its words), and the wine's own name entirely on it
            if not (N <= L and 2 * len(P & L) > len(P)): continue
            # "Charmes-Chambertin Grand Cru" has only "grand" of its own: its appellation must be on the label as well
            if N <= WEAK and not (Pl and Pl <= L): continue
            cands.append(k)
    if not cands: return None, "no match"
    # the most words in common wins: the wine's own name, plus its place when the label prints it (Gevrey, not Fixin)
    def score(k): return len(k[1]) + len(k[2] & L)
    cands.sort(key=lambda k: (score(k), len(k[0] & L), -len(k[0] - L)), reverse=True)
    best = cands[0]
    # same score but a different wine (another name, or another place of the same name) -> can't tell
    rivals = [k for k in cands[1:] if score(k) == score(best) and (k[1], k[2] & L) != (best[1], best[2] & L)]
    if rivals:
        if os.environ.get("WHY"): print("   rivals:", [[sorted(x) for x in k] for k in [best] + rivals[:3]])
        return None, "ambiguous"
    return best, "match"

NEAR = None

def main():
    global NEAR
    url, key = os.environ["URL"].rstrip("/"), os.environ["KEY"]
    req = urllib.request.Request(url + "/wines/export?limit=5000", headers={"x-jero-key": key, "user-agent": "jero-label-test"})
    rows = json.loads(urllib.request.urlopen(req, timeout=60).read())["rows"]
    wines, index = load_list()
    if os.environ.get("FUZZY", "1") == "1": NEAR = fuzzy_index(index)
    print(f"{len(rows)} scanned labels; {len(wines)} distinct wines in the list", flush=True)
    tally = defaultdict(int)
    lines = []
    for r in rows:
        sig = (r.get("sig") or "").split()
        claude = tokens((r.get("producer") or "") + " " + (r.get("name") or ""))
        claude4 = {t for t in claude if len(t) >= 4}
        t, why = match(sig, wines, index)
        if t is None:
            tally[why] += 1
            verdict = why
        else:
            # same wine as Claude's when most of the list wine's words are in Claude's producer + name
            same = bool(t[0] & claude4) and t[1] <= claude4
            verdict = "agrees with Claude" if same else "DIFFERENT from Claude"
            tally[verdict] += 1
        n, p = (wines[t][0], wines[t][1]) if t else ("", "")
        lines.append(f"| {verdict} | {' '.join(sig)[:60]} | {(r.get('producer') or '')[:28]} — {(r.get('name') or '')[:34]} | {p[:24]} — {n[:40]} |")
    total = len(rows) or 1
    found = tally["agrees with Claude"] + tally["DIFFERENT from Claude"]
    summary = [f"# Label match test ({len(rows)} scanned labels)", "",
               f"- Found in the list from the label alone: **{found}** ({100 * found / total:.0f}%)",
               f"  - same wine as Claude: **{tally['agrees with Claude']}**",
               f"  - a different wine from Claude's: **{tally['DIFFERENT from Claude']}** (read these: wrong pick, or Claude wrong)",
               f"- Ambiguous (two list wines fit; would ask Claude): {tally['ambiguous']}",
               f"- Not in the list or not enough words: {tally['no match']}", "",
               "The label text used here is only the phone's short signature (8 words at most); the phone has the whole label.", ""]
    order = {"DIFFERENT from Claude": 0, "agrees with Claude": 1, "ambiguous": 2, "no match": 3}
    lines.sort(key=lambda l: order[l.split(" | ")[0][2:]])
    report = "\n".join(summary + ["| Result | Label words | Claude said | List wine |", "|---|---|---|---|"] + lines)
    open("label_match_report.md", "w").write(report)
    print("\n".join(summary))
    print("\n".join(lines[:80]))

if __name__ == "__main__":
    main()
