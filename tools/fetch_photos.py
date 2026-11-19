"""Search Wikimedia Commons for openly licensed photos and download 900px thumbnails with credits."""
import json, sys, time, urllib.request, urllib.parse, re, os
UA = {"User-Agent": "JeroWineApp/1.0 (educational wine app; contact via github)"}
OK = ("CC BY", "CC BY-SA", "CC0", "Public domain", "PD")
def get(url, binary=False):
    for i in range(8):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=40) as r:
                b = r.read(); return b if binary else json.loads(b)
        except urllib.error.HTTPError as e:
            if e.code == 429: time.sleep(10 + 8 * i); continue
            raise
    raise RuntimeError("rate limited: " + url)
def search(q, n=6, portrait=False):
    u = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode({
        "action": "query", "format": "json", "generator": "search", "gsrsearch": "filetype:bitmap " + q,
        "gsrnamespace": 6, "gsrlimit": n, "prop": "imageinfo", "iiprop": "url|extmetadata|size", "iiurlwidth": 900})
    pages = get(u).get("query", {}).get("pages", {})
    out = []
    for p in sorted(pages.values(), key=lambda p: p.get("index", 99)):
        ii = p["imageinfo"][0]; m = ii.get("extmetadata", {})
        lic = m.get("LicenseShortName", {}).get("value", "")
        if not lic.startswith(OK): continue
        if portrait:
            if ii["height"] < 500: continue  # bottles: any orientation, tall is fine
        elif ii["width"] < 700 or ii["width"] < ii["height"] * 0.9: continue  # landscape-ish only
        artist = re.sub("<[^>]+>", "", m.get("Artist", {}).get("value", "")).strip()
        out.append({"title": p["title"], "url": ii["thumburl"], "license": lic, "artist": artist[:80], "page": ii["descriptionurl"]})
    return out
if __name__ == "__main__":
    spec = json.load(open(sys.argv[1])); outdir = sys.argv[2]
    credits_path = os.path.join(outdir, "credits.json")
    credits = json.load(open(credits_path)) if os.path.exists(credits_path) else {}
    # "id": "query"                -> best match saved as id.jpg
    # "id*": "query"               -> up to 3 candidates saved as id-1.jpg … id-3.jpg (to pick from)
    # query starting "portrait:"   -> tall images allowed (bottles)
    import subprocess
    for key, q in spec.items():
        multi = key.endswith("*"); base = key.rstrip("*")
        portrait = q.startswith("portrait:"); q = q.split(":", 1)[1] if portrait else q
        try:
            res = search(q, n=10 if multi else 6, portrait=portrait)
        except Exception as e:
            print("FAIL", base, e); continue
        if not res: print("NONE", base, q); continue
        for k, r in enumerate(res[:3] if multi else res[:1]):
            pid = f"{base}-{k + 1}" if multi else base
            if pid in credits: continue
            dest = os.path.join(outdir, pid + ".jpg")
            for i in range(5):
                rc = subprocess.run(["curl", "-sS", "-f", "-m", "60", "-A", UA["User-Agent"], "-o", dest, r["url"]]).returncode
                if rc == 0: break
                time.sleep(10 + 5 * i)
            if rc != 0: print("DLFAIL", pid); continue
            credits[pid] = r; json.dump(credits, open(credits_path, "w"), indent=1, ensure_ascii=False)
            print("OK", pid, r["title"], r["license"]); time.sleep(3)
