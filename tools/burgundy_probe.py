import json, urllib.request, urllib.parse, sys
def get(u, t=60):
    req = urllib.request.Request(u, headers={"User-Agent": "jero-map-build/1.0"})
    return urllib.request.urlopen(req, timeout=t).read()
for q in ["aires parcellaires AOC viticoles", "délimitation parcellaire AOC Bourgogne", "climats de Bourgogne", "appellations viticoles Bourgogne grands crus", "INAO aire géographique AOC vin"]:
    try:
        d = json.loads(get("https://www.data.gouv.fr/api/1/datasets/?page_size=6&q=" + urllib.parse.quote(q)))
        print("==", q)
        for x in d["data"]:
            print(" *", x["title"], "|", x["slug"], "|", x["organization"]["name"] if x.get("organization") else "")
            for r in x["resources"][:8]:
                print("     -", r["title"][:70], r.get("format"), r.get("filesize"), r["url"][:140])
    except Exception as e:
        print("ERR", q, e)
# Overpass: named vineyards in the Côte d'Or
ql = '[out:json][timeout:90];(way["landuse"="vineyard"]["name"](46.9,4.6,47.3,5.1););out tags center 400;'
for host in ["https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter"]:
    try:
        d = json.loads(get(host + "?data=" + urllib.parse.quote(ql), 100))
        names = sorted({e["tags"].get("name") for e in d["elements"]})
        print(host, len(d["elements"]), names[:120]); break
    except Exception as e:
        print("ERR overpass", host, e)
