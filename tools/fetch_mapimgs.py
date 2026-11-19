"""Runner script: search Wikimedia Commons for wine-region map images (CC/PD) and download several candidates
per region (out/<id>__<n>.<ext> + out/candidates.json) so the best can be picked by hand."""
import json, os, re, sys, time, subprocess, urllib.parse, urllib.request
UA = "JeroWineApp/1.0 (educational wine app)"
OK = ("CC BY", "CC BY-SA", "CC0", "Public domain", "PD", "Attribution")
def api(params):
    u = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(params)
    for i in range(8):
        try:
            with urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": UA}), timeout=40) as r:
                return json.loads(r.read())
        except urllib.error.HTTPError as e:
            if e.code == 429: time.sleep(5 + 5 * i); continue
            raise
    return {}
spec = json.load(open(sys.argv[1])); out = sys.argv[2]; os.makedirs(out, exist_ok=True)
cands = {}
for rid, queries in spec.items():
    seen, got = set(), []
    for q in queries:
        d = api({"action": "query", "format": "json", "generator": "search", "gsrsearch": q, "gsrnamespace": 6,
                 "gsrlimit": 12, "prop": "imageinfo", "iiprop": "url|extmetadata|size|mime", "iiurlwidth": 1200})
        for p in sorted(d.get("query", {}).get("pages", {}).values(), key=lambda p: p.get("index", 99)):
            if p["title"] in seen or "imageinfo" not in p: continue
            seen.add(p["title"])
            ii = p["imageinfo"][0]; m = ii.get("extmetadata", {})
            lic = re.sub("<[^>]+>", "", m.get("LicenseShortName", {}).get("value", ""))
            if not lic.startswith(OK): continue
            if ii.get("mime") not in ("image/svg+xml", "image/png", "image/jpeg"): continue
            if ii["width"] < 600 and ii.get("mime") != "image/svg+xml": continue
            artist = re.sub("<[^>]+>", "", m.get("Artist", {}).get("value", "")).strip()[:80]
            got.append({"title": p["title"], "url": ii["thumburl"], "license": lic, "artist": artist, "page": ii["descriptionurl"]})
            if len(got) >= 6: break
        if len(got) >= 6: break
        time.sleep(1)
    cands[rid] = []
    for n, g in enumerate(got):
        ext = ".png" if g["url"].lower().endswith(".png") else ".jpg"
        dest = os.path.join(out, f"{rid}__{n}{ext}")
        if subprocess.run(["curl", "-sS", "-f", "-m", "60", "-A", UA, "-o", dest, g["url"]]).returncode == 0:
            g["file"] = os.path.basename(dest); cands[rid].append(g)
        time.sleep(0.5)
    print(rid, len(cands[rid]), [c["title"][5:60] for c in cands[rid]])
json.dump(cands, open(os.path.join(out, "candidates.json"), "w"), indent=1, ensure_ascii=False)
