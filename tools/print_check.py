"""Fingerprint check (TestFlight, while testing): every new label print a phone sends (worker /prints/export) is compared with the
182k shop-photo prints on the `fingerprints` branch, and the 3 nearest wines go back to the worker (/prints/checks), where the
app's TestFlight page "Fingerprint check" lists them next to what the label reading said.

  python3 tools/print_check.py <dir with the fingerprints branch>      (env URL, KEY: the worker)
Uses tools/prices/fingerprint_test.py for loading and the same-wine rules. Only numbers and wine names move; no photos.
"""
import base64, json, os, sys, time, urllib.request
import numpy as np
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "prices"))
import fingerprint_test as ft

URL, KEY = os.environ["URL"].rstrip("/"), os.environ["KEY"]
HEAD = {"x-jero-key": KEY, "user-agent": "jero-print-check", "content-type": "application/json"}

def get(path):
    return json.load(urllib.request.urlopen(urllib.request.Request(URL + path, headers=HEAD), timeout=60))

def post(path, body):
    req = urllib.request.Request(URL + path, data=json.dumps(body).encode(), headers=HEAD, method="POST")
    return json.load(urllib.request.urlopen(req, timeout=120))

def phone_row(key):
    p, n = (key.split("|") + ["", ""])[:2]
    r = {"label_id": f"{p}|{n}", "producer": p, "producer_name": p, "wine": n}
    r["words"] = ft.words(r)
    return r

def top(q, X, rows, k=3):
    """the k nearest DIFFERENT wines (a wine's other photos are skipped)"""
    d = np.sqrt(np.maximum((X * X).sum(1) - 2 * X @ q + (q * q).sum(), 0))
    out, seen = [], set()
    for i in np.argsort(d)[:60]:
        r = rows[i]
        if r["label_id"] in seen: continue
        seen.add(r["label_id"])
        out.append((r, float(d[i])))
        if len(out) == k: break
    return out

def main():
    since = int(time.time()) - 3 * 86400
    scans = get(f"/prints/export?limit=2000&since={since}").get("rows", [])
    done = {r["id"] for r in get("/prints/checks?limit=200").get("rows", [])}
    todo = [s for s in scans if s.get("id") not in done]
    print(f"{len(scans)} phone prints in the last 3 days, {len(todo)} not checked yet", flush=True)
    if not todo: return
    F, L, rows = ft.load(sys.argv[1])
    rev = max(set(r["rev"] for r in rows), key=[r["rev"] for r in rows].count)
    checks = []
    for s in todo:
        v = np.frombuffer(base64.b64decode(s["vec"]), dtype="<f4").astype("float32")
        if int(s.get("rev") or 0) != rev or len(v) != F.shape[1]:
            checks.append({"id": s["id"], "key": s["key"], "created": s["created"], "results": {"note": f"revision {s.get('rev')} vs shops' {rev}"}})
            continue
        me = phone_row(s["key"])
        res = {}
        for name, X in (("label", L), ("whole", F)):
            res[name] = [{"wine": r["wine"], "producer": r["producer_name"], "dist": round(d, 3),
                          "same": bool(ft.same_wine(me, r)), "sameProducer": bool(ft.same_producer(me, r))} for r, d in top(v, X, rows)]
        best = min((res["label"][0], res["whole"][0]), key=lambda x: x["dist"]) if res["label"] and res["whole"] else None
        res["verdict"] = "same wine" if best and best["same"] else ("same producer" if best and best["sameProducer"] else "different")
        checks.append({"id": s["id"], "key": s["key"], "created": s["created"], "results": res})
        print(s["key"], "->", res["verdict"], best and (best["wine"], best["dist"]), flush=True)
    print(post("/prints/checks", {"checks": checks}))

if __name__ == "__main__":
    main()
