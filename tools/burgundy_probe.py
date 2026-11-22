import json, urllib.request, urllib.parse
def get(u, t=60):
    return urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "jero-map-build/1.0"}), timeout=t).read()
for q in ["INAO parcellaire", "aire parcellaire AOC", "AOC viticoles INAO", "aires géographiques AOC AOP vins", "délimitation parcellaire", "appellations d'origine contrôlée viticoles", "Climats de Bourgogne parcelles"]:
    try:
        d = json.loads(get("https://www.data.gouv.fr/api/2/datasets/search/?page_size=8&q=" + urllib.parse.quote(q)))
        print("==", q, d.get("total"))
        for x in d["data"]:
            print(" *", x["title"][:90], "|", x["slug"], "|", (x.get("organization") or {}).get("name", ""))
            for r in (x.get("resources") or [])[:6]:
                print("     -", (r.get("title") or "")[:60], r.get("format"), r.get("filesize"), (r.get("url") or "")[:150])
    except Exception as e:
        print("ERR", q, e)
