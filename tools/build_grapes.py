#!/usr/bin/env python3
"""Renders a realistic grape-bunch image for every variety (transparent PNG, original artwork).

Shaded spherical berries with highlights and bloom, a brown stem and a serrated vine leaf. Each grape gets its own
berry color and bunch shape (compact / loose, long / short, with or without a shoulder), seeded by its id.
Output: Jeroboam/Resources/Grapes/<id>.png  (run after adding grapes to content/grapes.yaml)
"""
import json, math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.join(os.path.dirname(__file__), "..")
OUT = os.path.join(ROOT, "Jeroboam", "Resources", "Grapes")
SIZE = 360          # output px
SS = 3              # supersampling

# berry colors (base RGB) — darker blue-black for thick-skinned grapes, purple for lighter reds
BLACK = {
    "default": (52, 44, 78), "cabernet-sauvignon": (40, 38, 70), "merlot": (58, 66, 112), "pinot-noir": (44, 30, 54),
    "syrah": (48, 46, 86), "grenache": (70, 40, 74), "tempranillo": (46, 48, 84), "sangiovese": (72, 40, 70),
    "nebbiolo": (64, 52, 92), "malbec": (46, 30, 58), "zinfandel": (54, 50, 92), "gamay": (78, 44, 80),
    "barbera": (62, 42, 76), "cinsault": (92, 46, 76), "meunier": (58, 40, 70), "tannat": (34, 26, 46),
    "petit-verdot": (36, 30, 56), "touriga-nacional": (40, 32, 62), "pinotage": (56, 38, 70),
}
PINK = {"default": (178, 104, 124), "pinot-grigio": (176, 128, 136), "gewurztraminer": (196, 108, 118)}
WHITE = {
    "default": (190, 206, 104), "riesling": (196, 204, 92), "muscat": (226, 186, 78), "viognier": (222, 196, 96),
    "semillon": (214, 200, 110), "chenin-blanc": (200, 206, 108), "furmint": (206, 198, 96), "palomino": (204, 210, 128),
    "pedro-ximenez": (222, 196, 102), "marsanne": (220, 190, 104), "torrontes": (212, 200, 110),
}
LEAF = (118, 176, 58)
STEM = (122, 96, 62)


def rgb(c, k=1.0):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def berry_sprite(r, color, bloom, rng):
    """One shaded berry as an RGBA array of size (2r+2)."""
    n = int(2 * r + 2)
    y, x = np.mgrid[0:n, 0:n].astype(np.float32)
    cx = cy = n / 2
    dx, dy = (x - cx) / r, (y - cy) / r
    d2 = dx * dx + dy * dy
    inside = d2 <= 1
    z = np.sqrt(np.clip(1 - d2, 0, 1))
    # light from the upper left, slightly in front
    L = np.array([-0.45, -0.55, 0.70]); L /= np.linalg.norm(L)
    lam = np.clip(dx * L[0] + dy * L[1] + z * L[2], 0, 1)
    shade = 0.5 + 0.62 * lam
    base = np.array(color, np.float32)
    col = base[None, None, :] * shade[..., None]
    # bloom: a soft dusty sheen on dark grapes
    if bloom > 0:
        haze = np.array([150, 160, 190], np.float32)
        t = bloom * (0.3 + 0.7 * (1 - z))[..., None] * 0.6
        col = col * (1 - t) + haze * t
    # specular highlight
    H = np.array([-0.35, -0.45, 0.82]); H /= np.linalg.norm(H)
    spec = np.clip(dx * H[0] + dy * H[1] + z * H[2], 0, 1) ** 70
    col = col + 255 * spec[..., None] * (0.38 if bloom < 0.3 else 0.22)
    # translucent glow for pale berries
    if bloom < 0.3:
        col = col + np.array([18, 16, 4], np.float32) * (z ** 2)[..., None]
    # rim darkening
    col = col * (0.82 + 0.18 * z[..., None])
    a = np.clip((1 - np.sqrt(d2)) * r * 1.4, 0, 1) * inside
    out = np.zeros((n, n, 4), np.float32)
    out[..., :3] = np.clip(col, 0, 255)
    out[..., 3] = a * 255
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def leaf_polygon(cx, cy, s, angle):
    """Five-lobed serrated vine leaf around (cx, cy)."""
    pts = []
    lobes = [(-90, 1.0), (-30, 0.9), (25, 0.72), (155, 0.72), (210, 0.9)]
    for i in range(200):
        t = i / 200 * 360 - 90
        # radius: sum of lobe bumps
        r = 0.55
        for la, lr in lobes:
            dd = ((t - la + 180) % 360) - 180
            r = max(r, lr * math.exp(-(dd / 34) ** 2))
        # sinus near the petiole (bottom)
        dd = ((t - 90 + 180) % 360) - 180
        r *= 1 - 0.55 * math.exp(-(dd / 16) ** 2)
        r *= 1 + 0.035 * (1 if (i % 4) < 2 else -1)      # serration
        a = math.radians(t + angle)
        pts.append((cx + math.cos(a) * r * s, cy + math.sin(a) * r * s))
    return pts


def render(gid, berry, out_path):
    rng = random.Random(gid)
    W = SIZE * SS
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    color = (BLACK if berry == "black" else PINK if berry == "pink" else WHITE)
    color = color.get(gid, color["default"])
    if berry == "black":
        color = rgb(color, 1.3)
    bloom = 0.55 if berry == "black" else (0.25 if berry == "pink" else 0.08)

    # bunch shape
    long_ = rng.uniform(0.92, 1.12)
    compact = rng.uniform(0.3, 1.0)
    shoulder = rng.random() < 0.45
    lean = rng.uniform(-0.1, 0.1)
    r = W * rng.uniform(0.036, 0.042)
    top, bottom = W * 0.30, min(W * (0.30 + 0.56 * long_), W * 0.93)
    cx0 = W * 0.47
    berries = []
    for layer in (0, 1):                       # back layer (darker), then front
        sp_y = r * (1.42 if layer else 1.42)
        rows = int((bottom - top) / sp_y)
        for i in range(rows):
            f = i / max(1, rows - 1)
            half = W * 0.235 * min(1.0, (f + 0.12) / 0.25) * (1 - f ** 1.7) ** 0.75 + W * 0.02
            if shoulder and 0.08 < f < 0.42:
                half += W * 0.05 * math.sin((f - 0.08) / 0.34 * math.pi)
            half *= 0.92 if layer == 0 else 0.85
            y = top + i * sp_y + (sp_y / 2 if layer == 0 else 0)
            n = max(1, int(2 * half / (r * 1.7)) + (1 if layer == 0 else 0))
            for k in range(n):
                if layer == 1 and rng.random() < 0.12 * (1 - compact):
                    continue
                x = cx0 + lean * (y - top) + (k - (n - 1) / 2) * r * 1.7 + ((r * 0.85) if (i + layer) % 2 else 0) - r * 0.42
                berries.append((x + rng.uniform(-0.15, 0.15) * r, y + rng.uniform(-0.15, 0.15) * r,
                                r * rng.uniform(0.92, 1.06), rng.random(), layer))

    # stem
    sx, sy = cx0 + W * 0.02, top - r * 0.6
    d.line([(cx0, top + r), (sx, sy), (sx + W * 0.05, sy - W * 0.10)], fill=rgb(STEM), width=int(W * 0.018), joint="curve")
    d.line([(sx + W * 0.05, sy - W * 0.10), (sx + W * 0.03, sy - W * 0.15)], fill=rgb(STEM, 0.85), width=int(W * 0.014))

    # leaf behind the bunch, upper right or left
    side = 1 if rng.random() < 0.7 else -1
    lx, ly = cx0 + side * W * 0.22, top + W * 0.02
    ls = W * 0.23
    poly = leaf_polygon(lx, ly, ls, rng.uniform(-25, 25) + (20 if side > 0 else -20))
    leaf = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ld = ImageDraw.Draw(leaf)
    ld.polygon(poly, fill=rgb(LEAF) + (255,))
    # shading gradient across the leaf
    grad = Image.linear_gradient("L").resize((W, W)).rotate(-35)
    dark = Image.new("RGBA", (W, W), rgb(LEAF, 0.72) + (255,))
    mask = Image.composite(grad, Image.new("L", (W, W), 0), leaf.split()[3])
    leaf = Image.composite(dark, leaf, mask.point(lambda v: int(v * 0.6)))
    ld = ImageDraw.Draw(leaf)
    for la in (-90, -35, 20, 160, 215):
        a = math.radians(la + (20 if side > 0 else -20))
        ld.line([(lx, ly + ls * 0.05), (lx + math.cos(a) * ls * 0.75, ly + math.sin(a) * ls * 0.75)],
                fill=rgb(LEAF, 1.25) + (255,), width=max(2, int(W * 0.004)))
    img.alpha_composite(leaf)

    # berries back to front: top rows and the middle last so the bunch looks round
    shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    for x, y, rr, _, _l in berries:
        sd.ellipse((x - rr * 1.05, y - rr * 0.9, x + rr * 1.05, y + rr * 1.2), fill=(20, 10, 20, 70))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(r * 0.35)))
    order = sorted(berries, key=lambda b: (b[4], -abs(b[0] - cx0) * 0.5 + b[3] * r))
    for x, y, rr, v, layer in order:
        c = rgb(color, (0.9 + v * 0.18) * (0.72 if layer == 0 else 1.0))
        sp = berry_sprite(rr, c, bloom, rng)
        img.alpha_composite(sp, (int(x - sp.width / 2), int(y - sp.height / 2)))

    # crop to content with a little padding, square, downsample
    bbox = img.getbbox()
    if bbox:
        x0, y0, x1, y1 = bbox
        side_len = max(x1 - x0, y1 - y0) * 1.06
        cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
        img = img.crop((int(cx - side_len / 2), int(cy - side_len / 2), int(cx + side_len / 2), int(cy + side_len / 2)))
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    img.save(out_path, optimize=True)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    lib = json.load(open(os.path.join(ROOT, "Jeroboam", "Resources", "Content", "library.json")))
    only = set(sys.argv[1:])
    for g in lib["grapes"]:
        if only and g["id"] not in only:
            continue
        render(g["id"], g["berry"], os.path.join(OUT, g["id"] + ".png"))
    print("rendered", len(os.listdir(OUT)), "grapes")
