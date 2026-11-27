"""Scanning with a shortlist: does giving Claude the 10 wines of our list that best fit a label help, without making it pick wrong?

For every scanned label (worker /wines/export: the label's signature words + the wine it was saved as), builds the shortlist the
way the app does (LabelMatcher.shortlist, ported in label_match_test.py terms), asks Claude (through the worker, the app's own
instructions) with and without it, and counts: picked the right wine / said none / picked a wrong one / own answer right.
The signature is only up to 8 words of the label, so this is harder than a real scan. Env URL, KEY. ~2 c of Haiku in all.
"""
import json, os, re, sys, urllib.request, uuid
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import label_match_test as lm

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
URL, KEY = os.environ["URL"].rstrip("/"), os.environ["KEY"]
swift = open(os.path.join(ROOT, "Jeroboam/Sources/WineRecognizer.swift"), encoding="utf-8").read()
SYSTEM = re.search(r'private static let system = """\n(.*?)\n    """', swift, re.S).group(1)
SYSTEM = " ".join(l.strip().rstrip("\\").strip() for l in SYSTEM.split("\n"))
FORMAT = ('\nReply with only one JSON object: {"found": true, "producer": "", "name": "", "vintage": "", "region": "", '
          '"confidence": "high|medium|low", "list_pick": 0}')

def ask(text):
    body = {"max_tokens": 600, "system": SYSTEM + FORMAT, "messages": [{"role": "user", "content": text}],
            "thinking": {"type": "disabled"}, "output_config": {"effort": "low"}}
    req = urllib.request.Request(URL + "/claude", data=json.dumps(body).encode(), method="POST",
        headers={"content-type": "application/json", "x-jero-key": KEY, "x-jero-device": str(uuid.uuid4()),
                 "anthropic-version": "2026-10-21", "user-agent": "jero-shortlist-test"})
    try:
        d = json.loads(urllib.request.urlopen(req, timeout=60).read())
    except Exception as e:
        return None, 0.0
    t = "".join(c.get("text", "") for c in d.get("content", []) if c.get("type") == "text")
    u = d.get("usage", {}); cost = u.get("input_tokens", 0) * 0.10 / 1e6 + u.get("output_tokens", 0) * 0.50 / 1e6
    o, c = t.find("{"), t.rfind("}")
    try: return json.loads(t[o:c + 1]), cost
    except Exception: return None, cost

def shortlist(L, wines, index, limit=10):
    score = {}
    for w in L:
        if w in lm.WEAK: continue
        for k in index.get(w, ()):
            if k in score: continue
            P, N, Pl = k
            own, prod, place = len(N & L), len(P & L), len(Pl & L)
            s = own / max(1, len(N)) * 2 + prod + place * 0.5 - len(N - L) * 0.5
            if own >= 1 and (prod >= 1 or own >= 2 or place >= 1) and s >= 2: score[k] = s
    out, seen = [], set()
    for k, _ in sorted(score.items(), key=lambda x: -x[1]):
        name, maker = wines[k][0], wines[k][1]
        tag = maker.lower() + "|" + " ".join(sorted(k[1]))
        if tag in seen: continue
        seen.add(tag); out.append((k, maker, name))
        if len(out) == limit: break
    return out

def same(a_prod, a_name, b_prod, b_name):
    A = {t for t in lm.tokens(a_prod + " " + a_name) if len(t) >= 4} - lm.GENERIC
    B = {t for t in lm.tokens(b_prod + " " + b_name) if len(t) >= 4} - lm.GENERIC
    return bool(A and B) and len(A & B) >= max(1, min(len(A), len(B)) * 0.6)

def main():
    req = urllib.request.Request(URL + "/wines/export?limit=5000", headers={"x-jero-key": KEY, "user-agent": "jero-shortlist-test"})
    rows = json.loads(urllib.request.urlopen(req, timeout=60).read())["rows"]
    wines, index = lm.load_list()
    # every word of a list wine's own name indexes it (load_list indexes own-name words already)
    tally = {}; cost = 0.0; lines = []
    for r in rows:
        sig = (r.get("sig") or "").split()
        L = {t for t in sig if len(t) >= 4}
        truth_p, truth_n = r.get("producer") or "", r.get("name") or ""
        sl = shortlist(L, wines, index)
        listed = any(same(m, n, truth_p, truth_n) for _, m, n in sl)
        text = "Text read from the wine label (OCR, may contain errors):\n\n" + " ".join(sig)
        if sl:
            text += "\n\nWines from Jero's list that might be this wine (pick one only if the label really is it, else 0):\n" + \
                    "\n".join(f"{i + 1}. {m} — {n}" for i, (_, m, n) in enumerate(sl))
        a, c = ask(text); cost += c
        if not a: verdict = "no answer"
        else:
            pick = int(a.get("list_pick") or 0)
            if sl and 1 <= pick <= len(sl):
                m, n = sl[pick - 1][1], sl[pick - 1][2]
                verdict = "picked RIGHT" if same(m, n, truth_p, truth_n) else "picked WRONG"
                got = f"{m} — {n}"
            else:
                verdict = ("none; own answer right" if same(a.get("producer", ""), a.get("name", ""), truth_p, truth_n) else "none; own answer differs")
                got = f"{a.get('producer','')} — {a.get('name','')}"
            verdict = ("[on list] " if listed else "[not on list] ") + verdict
        tally[verdict] = tally.get(verdict, 0) + 1
        lines.append(f"| {verdict} | {' '.join(sig)[:50]} | {truth_p[:22]} — {truth_n[:28]} | {len(sl)} | {got[:50] if a else ''} |")
        print(lines[-1], flush=True)
    rep = [f"# Shortlist test ({len(rows)} scanned labels, Haiku ${cost:.3f})", ""] + [f"- {k}: **{v}**" for k, v in sorted(tally.items())] + \
          ["", "| Result | Label words | Saved as | Shortlist | Claude chose |", "|---|---|---|---|---|"] + sorted(lines)
    open("shortlist_report.md", "w").write("\n".join(rep)); print("\n".join(rep[:14]))

if __name__ == "__main__":
    main()
