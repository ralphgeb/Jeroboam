import math

# ---- region shapes (in lat/lon), built in a local km plane
def km_frame(lat0):
    kx = 111.32 * math.cos(math.radians(lat0)); ky = 110.57
    return kx, ky

def shape_latlon(s):
    if s["t"] == "poly":
        return [(lon, lat) for lat, lon in s["p"]]
    if s["t"] == "blob":
        lat0, lon0 = s["c"]; rx, ry = s["r"]; a = math.radians(s["a"])
        kx, ky = km_frame(lat0)
        out = []
        for i in range(48):
            t = 2 * math.pi * i / 48
            x, y = rx * math.cos(t), ry * math.sin(t)
            xr, yr = x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a)
            out.append((lon0 + xr / kx, lat0 + yr / ky))
        return out
    if s["t"] == "strip":
        pts = s["p"]; w = s["w"] / 2
        lat0 = sum(p[0] for p in pts) / len(pts); lon0 = sum(p[1] for p in pts) / len(pts)
        kx, ky = km_frame(lat0)
        P = [((lon - lon0) * kx, (lat - lat0) * ky) for lat, lon in pts]
        # densify
        D = [P[0]]
        for a, b in zip(P, P[1:]):
            n = max(1, int(math.hypot(b[0] - a[0], b[1] - a[1]) / 2))
            for k in range(1, n + 1):
                D.append((a[0] + (b[0] - a[0]) * k / n, a[1] + (b[1] - a[1]) * k / n))
        def normal(i):
            a = D[max(0, i - 2)]; b = D[min(len(D) - 1, i + 2)]
            dx, dy = b[0] - a[0], b[1] - a[1]; L = math.hypot(dx, dy) or 1
            return -dy / L, dx / L
        left = [(p[0] + normal(i)[0] * w, p[1] + normal(i)[1] * w) for i, p in enumerate(D)]
        right = [(p[0] - normal(i)[0] * w, p[1] - normal(i)[1] * w) for i, p in enumerate(D)]
        ring = left + cap_arc(D[-1], left[-1], right[-1], w) + right[::-1] + cap_arc(D[0], right[0], left[0], w)
        return [(lon0 + x / kx, lat0 + y / ky) for x, y in ring]
    raise ValueError(s)

def cap_arc(c, frm, to, w):
    a0 = math.atan2(frm[1] - c[1], frm[0] - c[0])
    a1 = math.atan2(to[1] - c[1], to[0] - c[0])
    # go the outer way: the arc that does not pass through the path direction (half circle, clockwise)
    d = -math.pi  # half circle around the outside of the end point
    return [(c[0] + w * math.cos(a0 + d * k / 10), c[1] + w * math.sin(a0 + d * k / 10)) for k in range(1, 10)]

