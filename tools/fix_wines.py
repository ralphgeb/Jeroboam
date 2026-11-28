"""Fix wrongly identified wines in the online wine list (the worker's `wines` table).

  python3 tools/fix_wines.py list            every saved wine, one per line (key, scans, label words, details)
  python3 tools/fix_wines.py apply           applies tools/wine_fixes.json: for each {"from": <wrong key>, "wine": {...}} the right wine
                                             is saved with the wrong one's label signature (not counted as a scan), then
                                             POST /wine/correct drops the wrong row and moves its label signature and
                                             fingerprints to the right one (same as a correction made in the app)
Env URL, KEY (the worker's address and app key; GitHub secrets PRICE_DB_URL / PRICE_DB_KEY)."""
import json, os, sys, unicodedata, urllib.request

URL, KEY = os.environ["URL"].rstrip("/"), os.environ["KEY"]

def call(path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(URL + path, data=data, method="POST" if body is not None else "GET",
                                 headers={"x-jero-key": KEY, "content-type": "application/json", "user-agent": "jero-fix"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read() or b"{}")

def fold(s):
    s = unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode().lower()
    return "".join(c for c in s if c.isalnum() or c == " ")

def key(w):
    """The app's WineDB.key: producer|name|vintage, folded."""
    return "|".join(x.strip() for x in [fold(w.get("producer")), " ".join(fold(w.get("name")).split()), fold(w.get("vintage"))])

def rows():
    return call("/wines/export?limit=5000")["rows"]

def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "list"
    if mode == "list":
        rs = rows()
        print(f"{len(rs)} wines with a label signature")
        for r in rs:
            w = json.loads(r.get("json") or "{}")
            print(f"- {key(w)} || label: {r.get('sig')} || {w.get('region')}, {w.get('country')} | {w.get('style')} | "
                  f"grapes {w.get('grapes')} | list {w.get('from_database')} | checked {w.get('checked')}")
        return
    fixes = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "wine_fixes.json")))
    by_key = {}
    for r in rows():
        w = json.loads(r.get("json") or "{}")
        by_key.setdefault(key(w), (r, w))
    for f in fixes:
        old = by_key.get(f["from"])
        if not old:
            print("not found (already fixed?):", f["from"]); continue
        r, w = old
        right = dict(w); right.update(f["wine"])
        for k in ("from_database", "list_pick"): right.pop(k, None)
        right["found"] = True; right["checked"] = bool(right.get("grapes"))
        body = {"key": key(right), "json": json.dumps(right), "name": right.get("name", ""), "producer": right.get("producer", ""),
                "vintage": right.get("vintage", ""), "region": right.get("region", ""), "country": right.get("country", ""),
                "style": right.get("style", ""), "count": False}
        if r.get("sig"): body["sig"] = r["sig"]
        call("/wine", body)
        if key(right) != f["from"]:
            call("/wine/correct", {"from": f["from"], "to": key(right)})
        print("fixed:", f["from"], "->", key(right))

if __name__ == "__main__":
    main()
