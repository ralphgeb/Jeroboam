import json, urllib.request
def get(u, t=60):
    return urllib.request.urlopen(urllib.request.Request(u, headers={"User-Agent": "jero-map-build/1.0"}), timeout=t).read()
d = json.loads(get("https://www.data.gouv.fr/api/1/datasets/delimitation-parcellaire-des-aoc-viticoles-de-linao/"))
print(d["title"], d.get("license"), d.get("last_update"))
print((d.get("description") or "")[:1500])
for r in d["resources"]:
    print("-", r["title"][:80], "|", r.get("format"), "|", r.get("filesize"), "|", r["url"][:170])
