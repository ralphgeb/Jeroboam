"""Find real, openly licensed bottle photos on Wikimedia Commons for the 'Great wines to try' list.

usage: fetch_bottles.py wine_list.txt outdir shard nshards
Only keeps a file when its title names the producer AND something marks it as a bottle photo
(title, categories or description). No match -> no photo (the app then shows a plain tile, never a drawing)."""
import json, os, re, sys, time, unicodedata, subprocess, urllib.parse, urllib.request
UA = {"User-Agent": "JeroWineApp/1.0 (educational wine app; contact via github)"}
OK = ("CC BY", "CC BY-SA", "CC0", "Public domain", "PD")
BOTTLE = re.compile(r"bottle|bouteille|botella|flasche|botiglia|garrafa|magnum|jeroboam|label|etiquet|étiquet|etichetta|wine\b", re.I)
BAD = re.compile(r"vineyard|winery|chateau view|château view|building|castle|cellar|barrel|map\b|logo|landscape|panorama|village|museum|facade|vines|harvest|tasting room|church", re.I)
STOP = {"chateau", "domaine", "maison", "bodegas", "bodega", "weingut", "estate", "wines", "wine", "cellars", "vineyards", "familia", "casa", "tenuta",
        "azienda", "agricola", "cantina", "castello", "de", "du", "la", "le", "les", "des", "et", "and", "the", "di", "del", "della", "von", "van", "dos", "da", "famille", "clos", "cave", "caves"}
def norm(s): return re.sub(r"[^a-z0-9 ]+", " ", unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode().lower())
def get(url):
    for i in range(8):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=40) as r: return json.loads(r.read())
        except urllib.error.HTTPError as e:
            if e.code == 429: time.sleep(10 + 8 * i); continue
            raise
    raise RuntimeError("rate limited")
def search(q, n=10):
    u = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode({
        "action": "query", "format": "json", "generator": "search", "gsrsearch": "filetype:bitmap " + q, "gsrnamespace": 6, "gsrlimit": n,
        "prop": "imageinfo", "iiprop": "url|extmetadata|size", "iiurlwidth": 700})
    return sorted(get(u).get("query", {}).get("pages", {}).values(), key=lambda p: p.get("index", 99))
def accept(p, ptoks, ntoks):
    ii = p["imageinfo"][0]; m = ii.get("extmetadata", {})
    if not m.get("LicenseShortName", {}).get("value", "").startswith(OK): return None
    if ii["height"] < 600 or ii["height"] < ii["width"]: return None
    title = norm(p["title"])
    if not all(t in title for t in ptoks): return None
    hay = p["title"] + " " + m.get("Categories", {}).get("value", "") + " " + re.sub("<[^>]+>", " ", m.get("ImageDescription", {}).get("value", ""))
    if not BOTTLE.search(hay) or BAD.search(p["title"]): return None
    score = sum(1 for t in ntoks if t in title)
    artist = re.sub("<[^>]+>", "", m.get("Artist", {}).get("value", "")).strip()
    return score, {"title": p["title"], "url": ii["thumburl"], "license": m["LicenseShortName"]["value"], "artist": artist[:80], "page": ii["descriptionurl"]}
if __name__ == "__main__":
    lst, outdir, shard, nsh = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    os.makedirs(outdir, exist_ok=True)
    cpath = os.path.join(outdir, "credits.json")
    credits = json.load(open(cpath)) if os.path.exists(cpath) else {}
    for line in open(lst, encoding="utf-8"):
        idx, wid, producer, name = line.rstrip("\n").split("|")
        if int(idx) % nsh != shard or "bw-" + wid in credits: continue
        ptoks = [t for t in norm(producer).split() if t not in STOP and len(t) >= 3][:2] or norm(producer).split()[:1]
        ntoks = [t for t in norm(name).split() if t not in STOP and len(t) >= 4 and t not in ptoks]
        best = None
        for q in (f'{producer} {name} bottle', f'{producer} bottle'):
            try: res = search(q)
            except Exception as e: print("FAIL", wid, e); continue
            for p in res:
                a = accept(p, ptoks, ntoks)
                if a and (best is None or a[0] > best[0]): best = a
            if best: break
            time.sleep(1.5)
        if not best: print("NONE", wid); continue
        dest = os.path.join(outdir, f"bw-{wid}.jpg")
        for i in range(4):
            if subprocess.run(["curl", "-sS", "-f", "-m", "60", "-A", UA["User-Agent"], "-o", dest, best[1]["url"]]).returncode == 0: break
            time.sleep(8 + 5 * i)
        else: print("DLFAIL", wid); continue
        credits["bw-" + wid] = best[1]; json.dump(credits, open(cpath, "w"), indent=1, ensure_ascii=False)
        print("OK", wid, best[1]["title"], best[1]["license"]); time.sleep(2)
