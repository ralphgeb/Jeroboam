"""Fetch named vineyard parcels (Grand Cru / Premier Cru / villages) of the Côte d'Or from OpenStreetMap (ODbL)."""
import json, urllib.request, urllib.parse, os, collections, time
def overpass(q):
    for host in ["https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter"]:
        for _ in range(3):
            try:
                req = urllib.request.Request(host, data=urllib.parse.urlencode({"data": q}).encode(), headers={"User-Agent": "jero-map-build/1.0"})
                return json.loads(urllib.request.urlopen(req, timeout=300).read())
            except Exception as e:
                print("retry", host, e); time.sleep(10)
    raise SystemExit("overpass failed")
tiles = [(46.85, 4.55, 47.05, 5.0), (47.05, 4.55, 47.25, 5.1), (47.25, 4.7, 47.45, 5.2)]
out, seen = [], set()
for (a, b, c, d) in tiles:
    q = f'[out:json][timeout:250];(way["landuse"="vineyard"]({a},{b},{c},{d});relation["landuse"="vineyard"]({a},{b},{c},{d}););out tags geom;'
    r = overpass(q)
    for e in r["elements"]:
        k = (e["type"], e["id"])
        if k in seen: continue
        seen.add(k); out.append(e)
    print("tile", (a, b, c, d), len(r["elements"]))
print("total", len(out))
keys = collections.Counter(k for e in out for k in e.get("tags", {}))
print(keys.most_common(40))
named = [e for e in out if e.get("tags", {}).get("name")]
print("named", len(named))
for e in named[:60]: print(e["tags"])
os.makedirs("out", exist_ok=True)
json.dump(out, open("out/burgundy_osm.json", "w"), separators=(",", ":"))
