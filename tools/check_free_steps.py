"""The app's own free wine check (WineRecognizer.verifyOnline steps before the paid search), on the same 50 wines as
compare_wine_check.py, to see how many it settles and what it costs.

  step 1  our wine list / cloud list      the test wines come FROM our list, so the app would settle all of them here;
                                          the test pretends they are new wines
  step 2  appellation rule / grape on label   the sample already leaves these out (so 0 by design)
  step 3  free pages: DuckDuckGo html results (+ the shop page when we know one), cut to grape/taste sentences
          exactly as WebFacts.swift does, read by Claude Haiku with no tools (the app's prompt, max_tokens 1500)

Two runs of step 3: "new wine" (search results only: what a wine nobody has scanned gets) and "with shop page"
(when the price list knows the wine's shop page). Run on GitHub (free-steps.yml): needs URL and KEY of Jero's worker.
"""
import concurrent.futures as cf, csv, html as H, json, os, random, re, sys, time, unicodedata, urllib.parse, urllib.request, uuid
import yaml

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
URL, KEY = os.environ["URL"].rstrip("/"), os.environ["KEY"]
N = int(sys.argv[1]) if len(sys.argv) > 1 else 50
UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)"
SKIP = ["facebook.", "instagram.", "youtube.", "pinterest.", "amazon.", "tripadvisor.", "twitter.", "x.com", "tiktok.", "reddit."]
KEYWORDS = ["grape", "variet", "cépage", "cepage", "uva ", "uvas", "blend", "made from", "made with", "tasting", "aroma", "nose", "palate", "flavo"]
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
def canon(g): return ALIAS.get(fold(g).strip(), g.strip())
# names the scoring should treat as the same grape (the 50-wine test marked these wrong although they are right)
SAME = {"pelaverga piccolo": "Pelaverga", "malvasia di candia aromatica": "Malvasia", "monastrell": "Mourvèdre", "mourvedre": "Mourvèdre"}
def canon2(g): return SAME.get(fold(g).strip(), canon(g))

def fetch(url, timeout=6):
    try:
        req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "text/html"})
        with urllib.request.urlopen(req, timeout=timeout) as r:
            if r.status != 200: return None, r.status
            data = r.read(3_000_001)
            if len(data) > 3_000_000: return None, "big"
            return data.decode("utf-8", errors="replace"), 200
    except urllib.error.HTTPError as e: return None, e.code
    except Exception as e: return None, type(e).__name__

def search(q):
    page, status = fetch("https://html.duckduckgo.com/html/?" + urllib.parse.urlencode({"q": q}))
    if not page: return [], status
    out = []
    for raw in re.findall(r"uddg=([^&\"']+)", page):
        u = urllib.parse.unquote(raw)
        host = urllib.parse.urlparse(u).netloc.lower()
        if not u.startswith("http") or any(s in host for s in SKIP) or u.lower().endswith(".pdf"): continue
        if u not in out: out.append(u)
        if len(out) >= 4: break
    return out, (200 if out else "no results")

def plain(h):
    for p in [r"<script[\s\S]*?</script>", r"<style[\s\S]*?</style>", r"<[^>]+>"]:
        h = re.sub(p, " ", h, flags=re.I)
    return re.sub(r"[ \t\r]+", " ", H.unescape(h))

def excerpt(url):
    page, _ = fetch(url)
    if not page: return ""
    out, size = [], 0
    for s in re.split(r"[.!?\n]", plain(page)):
        s = s.strip()
        if not (12 < len(s) < 400) or not any(k in s.lower() for k in KEYWORDS): continue
        out.append(s); size += len(s)
        if size > 1400: break
    return ". ".join(out)

def pages(query, shop):
    urls = ([shop] if shop else [])
    found, status = search(query + " grape variety")
    for u in found:
        if u not in urls: urls.append(u)
    urls = urls[:4]
    with cf.ThreadPoolExecutor(4) as ex: texts = list(ex.map(excerpt, urls))
    out = ""
    for u, t in zip(urls, texts):
        if not t: continue
        if len(out) > 3500: break
        out += f"Source: {urllib.parse.urlparse(u).netloc}\n{t}\n\n"
    return out[:4500], status, len(found)

def haiku(prompt):
    body = {"max_tokens": 1500, "messages": [{"role": "user", "content": prompt}], "thinking": {"type": "disabled"}, "output_config": {"effort": "low"}}
    req = urllib.request.Request(URL + "/claude", data=json.dumps(body).encode(), method="POST",
        headers={"content-type": "application/json", "x-jero-key": KEY, "x-jero-device": str(uuid.uuid4()), "anthropic-version": "2026-10-21", "user-agent": "jero-free-steps"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r: d = json.loads(r.read())
    except Exception as e: return None, 0.0
    text = "".join(c.get("text", "") for c in d.get("content", []) if c.get("type") == "text")
    u = d.get("usage", {})
    cost = u.get("input_tokens", 0) * 0.10 / 1e6 + u.get("output_tokens", 0) * 0.50 / 1e6
    o, c = text.find("{"), text.rfind("}")
    try: return json.loads(text[o:c + 1]), cost
    except Exception: return None, cost

def verdict(ans, truth):
    if not ans: return "no answer"
    gr = [canon2(g) for g in ans.get("grapes") or [] if g]
    if not ans.get("confirmed") or not gr: return "not found"
    return "right" if canon2(truth) in gr[:2] else "WRONG"

rows = []
for r in csv.DictReader(open(os.path.join(ROOT, "content/prices/wine_details.csv"), encoding="utf-8")):
    if r["blend_source"] in ("", "appellation rule") or not r["grape_blend"] or not r["producer"]: continue
    col = {"Red": "red", "White": "white"}.get(r["color"], "")
    if settled_for_free(r["appellation"] or r["region"], r["wine"], col): continue
    rows.append(r)
random.Random(7).shuffle(rows)
sample = rows[:N]
print(f"testing the same {len(sample)} wines as compare_wine_check.py", flush=True)

res = {"new": {}, "shop": {}}
cost = {"new": 0.0, "shop": 0.0}; secs = {"new": [], "shop": []}; search_ok = 0; empty = {"new": 0, "shop": 0}
out = []
for i, r in enumerate(sample, 1):
    truth = r["grape_blend"].split(",")[0].rsplit(" ", 1)[0].strip()
    wine = " ".join(x for x in [r["producer"], r["wine"], r["vintage"]] if x)
    place = f" ({r['region']})" if r["region"] else ""
    shop = r["details_link"]
    if shop and not shop.startswith("http"): shop = "https://" + shop
    cells = []
    for mode, link in [("new", None), ("shop", shop or None)]:
        t0 = time.time()
        text, status, nres = pages(wine + " " + r["region"], link)
        if mode == "new" and nres: search_ok += 1
        if not text:
            v, c, ans = "no pages", 0.0, None; empty[mode] += 1
        else:
            prompt = f"Wine: {wine}{place}.\nBelow is text from web pages. Report only what these pages say about this exact wine; never fill gaps from memory.\n\n{text}\n\n" + FORMAT
            ans, c = haiku(prompt); v = verdict(ans, truth)
        s = time.time() - t0
        res[mode][v] = res[mode].get(v, 0) + 1; cost[mode] += c; secs[mode].append(s)
        g = ", ".join((ans or {}).get("grapes") or [])[:35]
        cells.append(f"{v}{' (' + g + ')' if g else ''} {s:.1f}s" + ("" if mode == "shop" or nres else f" [search: {status}]"))
        time.sleep(1.5)   # be gentle with DuckDuckGo
    out.append(f"| {i} | {wine[:48]} | {truth} | " + " | ".join(cells) + " |")
    print(out[-1], flush=True)

med = lambda t: sorted(t)[len(t) // 2] if t else 0
def line(name, m):
    s = res[m]
    return (f"- **{name}**: right {s.get('right', 0)}/{len(sample)}, wrong {s.get('WRONG', 0)}, not found {s.get('not found', 0)}, "
            f"no useful pages {s.get('no pages', 0)}, no answer {s.get('no answer', 0)}; median {med(secs[m]):.1f} s; Haiku cost ${cost[m]:.3f} in all")
report = "\n".join([f"# The app's free steps on the same {len(sample)} wines", "",
    f"DuckDuckGo returned results for {search_ok}/{len(sample)} searches (from a GitHub server; a phone may do better).", "",
    line("Step 3, new wine (search results only)", "new"), line("Step 3, with the shop page we know", "shop"), "",
    "| # | Wine | Known main grape | New wine | With shop page |", "|---|---|---|---|---|"] + out)
open("free_steps_report.md", "w").write(report)
print("\n" + report.split("| # |")[0])
