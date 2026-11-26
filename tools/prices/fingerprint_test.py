#!/usr/bin/env python3
"""Is a label fingerprint good enough to name a wine? Measured before anything is switched on in the app.

Test 1 (shop photo vs shop photo): wines that several shops sell, each with its own photo. Every such photo is looked up among the
prints of all OTHER shops; right = the nearest print is the same wine (any vintage: vintages share a label). Pictures that are the
same file in two shops (the producer's packshot, distance < SAME) are counted apart, since a phone photo never is that close.
Wrong answers are split into look-alikes (same producer, another wine) and others.
Test 2 (real phone scans): if the worker's address/key are set (env URL, KEY), the app's own scan prints (GET /prints/export) are
looked up among the shop prints, and the 3 nearest wines are listed next to the wine the scan turned out to be.

  python3 tools/prices/fingerprint_test.py <dir with the shops' .status.tsv / .meta.tsv / .full.f16 / .label.f16> [report.md]
"""
import base64, glob, json, os, sys, unicodedata, urllib.request
from collections import Counter, defaultdict
import numpy as np

SAME = 0.05            # closer than this = the same picture file


def fold(s):
    s = "".join(c for c in unicodedata.normalize("NFD", s or "") if unicodedata.category(c) != "Mn").lower()
    return " ".join("".join(c for c in s if c.isalnum() or c == " ").split())


def load(d):
    """every ok print of every shop: whole-photo and label prints (float32) + one row of facts per photo"""
    import csv
    csv.field_size_limit(10 ** 9)
    full, label, rows = [], [], []
    for st in sorted(glob.glob(os.path.join(d, "*.status.tsv"))):
        pre = st[:-len(".status.tsv")]; host = os.path.basename(pre)
        status = list(csv.DictReader(open(st), delimiter="\t"))
        if not status or not int(status[0]["dims"]): continue
        dims = int(status[0]["dims"])
        F = np.fromfile(pre + ".full.f16", dtype="<f2").reshape(-1, dims)
        Lb = np.fromfile(pre + ".label.f16", dtype="<f2").reshape(-1, dims)
        meta = {}
        for m in csv.DictReader(open(pre + ".meta.tsv", encoding="utf-8"), delimiter="\t"):
            meta.setdefault(int(m["row"]), m)          # a photo's first list row names it
        ok = [int(x["row"]) for x in status if x["status"] == "ok" and int(x["row"]) in meta]
        full.append(F[ok].astype("float32")); label.append(Lb[ok].astype("float32"))
        for r in ok:
            m = meta[r]; k = m["key"]
            rows.append({"host": host, "rev": int(status[r]["revision"]), "key": k, "label_id": "|".join(k.split("|")[:2]),
                         "producer": k.split("|")[0], "wine": m["wine"], "link": m["link"]})
    if not rows: sys.exit("no prints")
    return np.concatenate(full), np.concatenate(label), rows


def nearest(Q, X, k, exclude):
    """k nearest (euclidean) rows of X for every row of Q; exclude[i] = boolean mask of X rows not allowed for query i"""
    xn = (X * X).sum(1)
    out_i, out_d = [], []
    for s in range(0, len(Q), 512):
        q = Q[s:s + 512]
        d2 = (q * q).sum(1)[:, None] + xn[None, :] - 2 * q @ X.T
        for j in range(len(q)):
            d2[j, exclude(s + j)] = np.inf
        idx = np.argpartition(d2, k, axis=1)[:, :k]
        dd = np.take_along_axis(d2, idx, 1)
        o = np.argsort(dd, 1)
        out_i.append(np.take_along_axis(idx, o, 1)); out_d.append(np.sqrt(np.maximum(np.take_along_axis(dd, o, 1), 0)))
    return np.concatenate(out_i), np.concatenate(out_d)


def main():
    d = sys.argv[1]; report = sys.argv[2] if len(sys.argv) > 2 else os.path.join(d, "fingerprint_test.md")
    F, L, rows = load(d)
    revs = Counter(r["rev"] for r in rows)
    lines = [f"# Label fingerprint test", "", f"{len(rows):,} shop photos fingerprinted from {len({r['host'] for r in rows})} shops; "
             f"Vision revisions {dict(revs)}; {F.shape[1]} numbers per print.", ""]
    host = np.array([r["host"] for r in rows]); lab = np.array([r["label_id"] for r in rows])
    shops_of = defaultdict(set)
    for r in rows: shops_of[r["label_id"]].add(r["host"])
    q = np.array([i for i, r in enumerate(rows) if r["label_id"] and len(shops_of[r["label_id"]]) >= 2])
    rng = np.random.default_rng(7)
    if len(q) > 20000: q = np.sort(rng.choice(q, 20000, replace=False))
    lines += [f"## Test 1: shop photo vs other shops' photos", "",
              f"{len(q):,} photos of wines sold by 2+ shops, each looked up among {len(rows):,} prints of the other shops.", ""]
    C = np.concatenate([F, L], 1) / np.sqrt(2)          # both prints together
    lines += ["| print | right (nearest is the same wine) | right in top 5 | same picture file | wrong: look-alike (same producer) | wrong: other |",
              "|---|---|---|---|---|---|"]
    best = {}
    for name, X in (("whole photo", F), ("label crop", L), ("both", C)):
        idx, dist = nearest(X[q], X, 5, lambda j: host == host[q[j]])
        right1 = lab[idx[:, 0]] == lab[q]
        right5 = (lab[idx] == lab[q][:, None]).any(1)
        same = right1 & (dist[:, 0] < SAME)
        wrong = ~right1
        look = wrong & (np.array([rows[i]["producer"] for i in idx[:, 0]]) == np.array([rows[i]["producer"] for i in q]))
        n = len(q)
        pc = lambda m: f"{m.sum():,} ({100 * m.mean():.0f}%)"
        lines.append(f"| {name} | {pc(right1)} | {pc(right5)} | {pc(same)} | {pc(look)} | {pc(wrong & ~look)} |")
        best[name] = (idx, dist, right1, same)
    lines += ["", "Without identical picture files (what a phone photo would face), and how sure a match can be by distance:", "",
              "| print | right | accept if nearest closer than | accepted | of those right |", "|---|---|---|---|---|"]
    for name, (idx, dist, right1, same) in best.items():
        m = ~same
        if not m.any(): continue
        d0, r0 = dist[m, 0], right1[m]
        for t in np.quantile(d0, [0.1, 0.25, 0.5]):
            acc = d0 < t
            lines.append(f"| {name} | {100 * r0.mean():.0f}% | {t:.3f} | {100 * acc.mean():.0f}% | {100 * r0[acc].mean():.0f}% |")
    # examples of wrong answers (for reading by hand)
    idx, dist, right1, same = best["both"]
    lines += ["", "Some wrong answers (both prints):", ""]
    for j in np.where(~right1)[0][:25]:
        a, b = rows[q[j]], rows[idx[j, 0]]
        lines.append(f"- {a['wine']} ({a['host']}) -> {b['wine']} ({b['host']}), distance {dist[j, 0]:.3f}")

    url, key = os.environ.get("URL"), os.environ.get("KEY")
    if url and key:
        try:
            req = urllib.request.Request(url.rstrip("/") + "/prints/export?limit=20000", headers={"x-jero-key": key})
            scans = json.load(urllib.request.urlopen(req, timeout=60)).get("rows", [])
        except Exception as e:
            scans = []; lines += ["", f"Phone scans could not be read: {e}"]
        main_rev = revs.most_common(1)[0][0]
        S, sk = [], []
        for s in scans:
            v = np.frombuffer(base64.b64decode(s["vec"]), dtype="<f4")
            if int(s.get("rev") or 0) == main_rev and len(v) == F.shape[1]:
                S.append(v); sk.append(s["key"])
        lines += ["", "## Test 2: phone scans vs shop photos", "",
                  f"{len(scans)} phone prints in the worker, {len(S)} of the same revision ({main_rev})."]
        if S:
            S = np.stack(S)
            for name, X in (("whole photo", F), ("label crop", L)):
                idx, dist = nearest(S, X, 3, lambda j: np.zeros(len(X), bool))
                lines += ["", f"### nearest shop photos ({name})", "", "| scan was | 1st | 2nd | 3rd |", "|---|---|---|---|"]
                for j in range(len(S)):
                    cells = [f"{rows[i]['wine']} ({dist[j, n]:.3f})" for n, i in enumerate(idx[j])]
                    lines.append(f"| {sk[j]} | " + " | ".join(cells) + " |")
    open(report, "w").write("\n".join(lines) + "\n")
    print("\n".join(lines[:40]))


if __name__ == "__main__":
    main()
