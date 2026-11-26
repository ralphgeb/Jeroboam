"""Claude + web search vs Gemini + Google Search, on the app's own "check this wine online" question.

Takes N wines from content/prices/wine_details.csv whose grapes are KNOWN from the shop's own description (blend_source is a
shop text, not a rule), skipping wines whose grapes the app already settles for free (content/grape_rules.yaml, or the grape
on the label). Asks both through Jero's worker (backend/cloudflare: /claude with one web search, /gemini with Google Search)
with the same prompt the app uses, then scores the main grape against the known one.

Run on GitHub (Actions > Compare wine checks), which has the worker's address and key:  python3 tools/compare_wine_check.py 50
Env: URL (worker address), KEY (x-jero-key). Writes compare_report.md. Costs about $0.012 per wine on the Claude side.
"""
import csv, json, os, random, re, sys, time, unicodedata, urllib.request, uuid
import yaml

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
URL, KEY = os.environ["URL"].rstrip("/"), os.environ["KEY"]
N = int(sys.argv[1]) if len(sys.argv) > 1 else 50

FORMAT = """Reply with only one JSON object and nothing else:
{"confirmed": true or false, "region": "", "country": "", "grapes": ["..."], "grape_percent": [100], "style": "red|white|rose|sparkling|fortified|sweet|orange", "tasting_notes": ["..."], "palate": "one sentence"}
Set confirmed to false and grapes to [] if it does not clearly state the grapes of this wine. Use "" or [] for anything not stated."""

def fold(s):
    return "".join(c for c in unicodedata.normalize("NFD", (s or "").lower()) if unicodedata.category(c) != "Mn").replace("’", "'")

def has(w, t):
    return re.search(r"(?<![a-z])" + re.escape(fold(w)) + r"(?![a-z])", t) is not None

lib = json.load(open(os.path.join(ROOT, "Jeroboam/Resources/Content/library.json"), encoding="utf-8"))
ALIAS = {fold(n): g["name"] for g in lib["grapes"] for n in [g["name"]] + (g.get("aka") or [])}
RULES = yaml.safe_load(open(os.path.join(ROOT, "content/grape_rules.yaml"), encoding="utf-8"))

def settled_for_free(region, name, color):
    t = fold(region + " " + name)
    for r in RULES:
        if r.get("color") and r["color"] != color: continue
        if any(has(x, t) for x in r.get("not") or []): continue
        if any(has(m, t) for m in r["match"]): return True
    return any(len(a) >= 4 and has(a, fold(name)) for a in ALIAS)

def canon(g):
    return ALIAS.get(fold(g).strip(), g.strip())

def post(path, body):
    req = urllib.request.Request(URL + path, data=json.dumps(body).encode(), method="POST",
                                 headers={"content-type": "application/json", "x-jero-key": KEY,
                                          "x-jero-device": str(uuid.uuid4()), "anthropic-version": "2026-10-21",
                                          "user-agent": "jero-compare"})
    t0 = time.time()
    try:
        with urllib.request.urlopen(req, timeout=90) as r:
            return json.loads(r.read()), time.time() - t0, None
    except urllib.error.HTTPError as e:
        return None, time.time() - t0, f"HTTP {e.code}: {e.read()[:600].decode(errors='replace')}"
    except Exception as e:
        return None, time.time() - t0, str(e)[:200]

def last_json(text):
    o, c = text.rfind("{"), text.rfind("}")
    if o < 0 or c <= o: return None
    # the JSON object can contain braces only at its ends; walk back to the matching opening brace
    depth = 0
    for i in range(c, -1, -1):
        depth += text[i] == "}"
        depth -= text[i] == "{"
        if depth == 0:
            try: return json.loads(text[i:c + 1])
            except Exception: return None
    return None

def ask_claude(prompt):
    body = {"max_tokens": 2000, "messages": [{"role": "user", "content": prompt}],
            "thinking": {"type": "disabled"}, "output_config": {"effort": "low"},
            "tools": [{"type": "web_search_20250305", "name": "web_search", "max_uses": 1}]}
    d, secs, err = post("/claude", body)
    if err: return None, secs, 0.0, err
    text = "".join(c.get("text", "") for c in d.get("content", []) if c.get("type") == "text")
    if os.environ.get("DEBUG"):
        print("  claude stop:", d.get("stop_reason"), "| blocks:", [c.get("type") for c in d.get("content", [])], "| text end:", repr(text[-400:]), flush=True)
    u = d.get("usage", {})
    cost = u.get("input_tokens", 0) * 0.10 / 1e6 + u.get("output_tokens", 0) * 0.50 / 1e6 + \
        (u.get("server_tool_use", {}) or {}).get("web_search_requests", 0) * 0.01
    return last_json(text), secs, cost, None

def ask_gemini(prompt):
    d, secs, err = post("/gemini", {"prompt": prompt})
    if err and os.environ.get("DEBUG"): print("  gemini error:", err, flush=True)
    if err: return None, secs, None, err
    cand = (d.get("candidates") or [{}])[0]
    text = "".join(p.get("text", "") for p in (cand.get("content") or {}).get("parts", []))
    grounded = bool(cand.get("groundingMetadata", {}).get("groundingChunks"))
    return last_json(text), secs, grounded, None

def verdict(ans, truth_main):
    if not ans: return "no answer"
    grapes = [canon(g) for g in ans.get("grapes") or [] if g]
    if not ans.get("confirmed") or not grapes: return "not found"
    return "right" if canon(grapes[0]) == canon(truth_main) or canon(truth_main) in grapes[:2] else "WRONG"

rows = []
for r in csv.DictReader(open(os.path.join(ROOT, "content/prices/wine_details.csv"), encoding="utf-8")):
    if r["blend_source"] in ("", "appellation rule") or not r["grape_blend"] or not r["producer"]: continue
    col = {"Red": "red", "White": "white"}.get(r["color"], "")
    if settled_for_free(r["appellation"] or r["region"], r["wine"], col): continue
    rows.append(r)
random.Random(7).shuffle(rows)
sample = rows[:N]
print(f"{len(rows)} wines with known grapes the app cannot settle for free; testing {len(sample)}", flush=True)

out, score = [], {"claude": {}, "gemini": {}}
spend, secs_c, secs_g = 0.0, [], []
for i, r in enumerate(sample, 1):
    truth = r["grape_blend"].split(",")[0].rsplit(" ", 1)[0].strip()
    wine = " ".join(x for x in [r["producer"], r["wine"], r["vintage"]] if x)
    place = f" ({r['region']})" if r["region"] else ""
    prompt = (f"Use web search to check this wine: {wine}{place}. Use the producer's own page, a wine shop page or a critic's page "
              f"for this exact wine. Report only what those pages say; never fill gaps from memory.\n" + FORMAT)
    ca, cs, cost, cerr = ask_claude(prompt)
    ga, gs, grounded, gerr = ask_gemini(prompt)
    vc, vg = (cerr or verdict(ca, truth)), (gerr or verdict(ga, truth))
    score["claude"][vc if not cerr else "error"] = score["claude"].get(vc if not cerr else "error", 0) + 1
    score["gemini"][vg if not gerr else "error"] = score["gemini"].get(vg if not gerr else "error", 0) + 1
    spend += cost or 0; secs_c.append(cs); secs_g.append(gs)
    cg = ", ".join((ca or {}).get("grapes") or []) if ca else "-"
    gg = ", ".join((ga or {}).get("grapes") or []) if ga else "-"
    out.append(f"| {i} | {wine[:60]} | {truth} | {cg[:40]} ({vc[:20]}) | {gg[:40]} ({vg[:20]}{'' if gerr or grounded else ', no search'}) |")
    print(out[-1], flush=True)
    time.sleep(1)

def line(name, s, t):
    n = sum(s.values())
    return (f"- **{name}**: right {s.get('right', 0)}/{n}, wrong {s.get('WRONG', 0)}, not found {s.get('not found', 0)}, "
            f"no answer {s.get('no answer', 0)}, errors {s.get('error', 0)}; median {(sorted(t)[len(t) // 2] if t else 0):.1f} s")

report = "\n".join([
    f"# Wine check: Claude + web search vs Gemini + Google Search ({len(sample)} wines)", "",
    "Wines whose grapes are known from the shop's own description, excluding those the app settles for free.", "",
    line("Claude Haiku + 1 web search", score["claude"], secs_c) + f"; cost ${spend:.2f} in all",
    line("Gemini + Google Search", score["gemini"], secs_g) + " (free daily allowance)", "",
    "WRONG is the one that matters: a grape stated as fact that isn't. 'not found' is safe (the app keeps it hidden).", "",
    "| # | Wine | Known main grape | Claude | Gemini |", "|---|---|---|---|---|"] + out)
open("compare_report.md", "w").write(report)
print("\n" + report.split("| # |")[0])
