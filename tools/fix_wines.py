"""Fix wrongly identified wines in the online wine list (the worker's `wines` table).

  python3 tools/fix_wines.py list            every saved wine, one per line (key, scans, label words, details)
  python3 tools/fix_wines.py apply           applies tools/wine_fixes.json through the worker (POST /wine/fix): the right wine
                                             keeps the wrong row's label signature, fingerprints and scans, and the fix is logged
                                             so every phone takes it in (WineFixes in the app)
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
    current = {}
    for r in rows():
        w = json.loads(r.get("json") or "{}")
        current.setdefault(key(w), w)
    for f in fixes:
        if f["from"] not in current:
            # applied before the feed existed: the right wine as it is stored now goes out once more, so phones take it in
            if mode != "log" or f.get("to") not in current:
                print("skipped (already fixed):", f["from"]); continue
            f = {"from": f["from"], "wine": {k: v for k, v in current[f["to"]].items() if k not in ("from_database", "list_pick")}}
        # the worker keeps the rest of the wrong row's details, moves its label signature and fingerprints, and logs the fix so
        # every phone takes it in (GET /wine/fixes). mode "log" also sends fixes whose wrong row is already gone (applied before
        # the feed existed): the right wine is then stored as given.
        try:
            r = call("/wine/fix", {"from": f["from"], "wine": f["wine"]})
            print("fixed:", f["from"], "->", r.get("to"))
        except Exception as e:
            print("failed:", f["from"], e)

if __name__ == "__main__":
    main()
