"""The last N scans, in full: the label words the phone read (signature), what the wine was saved as, how it was settled
(our list, Claude's pick from the shortlist, Claude alone), and what our wine list holds for those label words (match, shortlist).
Env URL, KEY. python3 tools/recent_scans.py [N]"""
import json, os, sys, urllib.request
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import label_match_test as lm
from shortlist_test import shortlist
URL, KEY = os.environ["URL"].rstrip("/"), os.environ["KEY"]
N = int(sys.argv[1]) if len(sys.argv) > 1 else 10
req = urllib.request.Request(URL + "/wines/export?limit=5000", headers={"x-jero-key": KEY, "user-agent": "jero-recent"})
rows = json.loads(urllib.request.urlopen(req, timeout=60).read())["rows"][:N]
wines, index = lm.load_list()
lm.NEAR = lm.fuzzy_index(index)
for r in rows:
    w = json.loads(r.get("json") or "{}")
    sig = (r.get("sig") or "").split()
    L = lm.corrected({t for t in sig if len(t) >= 4}, index, lm.NEAR)
    t, why = lm.match(sig, wines, index)
    sl = shortlist(L, wines, index, limit=5)
    print("=" * 100)
    print("LABEL WORDS:", " ".join(sig))
    print("SAVED AS   :", w.get("producer"), "|", w.get("name"), "|", w.get("vintage"), "|", w.get("region"), "|", w.get("country"))
    print("           : grapes", w.get("grapes"), "| from list:", w.get("from_database"), "| list pick:", w.get("list_pick"),
          "| checked:", w.get("checked"), "| confidence:", w.get("confidence"))
    print("LIST MATCH :", why, (wines[t][1] + " — " + wines[t][0]) if t else "")
    for k, m, n in sl: print("  shortlist:", m, "—", n)
    # anything in the list sharing 2+ label words, to see if the wine is there under another name
    hits = {}
    for x in L:
        for k in index.get(x, ()):
            hits[k] = hits.get(k, 0) + 1
    best = sorted(hits.items(), key=lambda kv: -kv[1])[:4]
    for k, c in best:
        if c >= 2: print("  list has  :", wines[k][1], "—", wines[k][0], f"({c} label words)")
