"""Prologue, scene 1: the storm arrives (480x270). Draft outside the project.
    python make_scene1.py
Writes scene1_storm.gif (animated), scene1_still_*.png and the separate depth layers."""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.environ.get("PROLOGUE_OUT", os.path.join(ROOT, "builds", "prologue"))
os.makedirs(OUT, exist_ok=True)
SOURCES = os.path.join(ROOT, "assets", "sprites", "nico_prologue", "source")
W, H = 480, 270
FPS = 20
SECONDS = 9.0
FRAMES = int(FPS * SECONDS)
HORIZON = 150

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16.0
YY, XX = np.mgrid[0:H, 0:W]
DITHER = BAYER[YY % 4, XX % 4]


def c(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


# palette: navy night, petrol and violet water, blue-white foam
SKY_TOP, SKY_LOW = c("#050722"), c("#141a55")
CLOUD_DARK, CLOUD_MID, CLOUD_LIT = c("#0a0d36"), c("#171e66"), c("#2a3690")
SEA_FAR = [c("#0e1650"), c("#141e66")]
SEA_MID = [c("#101a5c"), c("#18278a"), c("#1f3a9c")]
SEA_NEAR = [c("#0a1248"), c("#122070"), c("#1c3490"), c("#244aa8")]
FOAM = [c("#7f93e0"), c("#c4d2ff"), c("#f2f6ff")]
FOG = c("#3a4590")
FLASH = c("#8fa6ff")


def ramp(colors, t):
    """Pick from `colors` using t in [0,1) with ordered dithering between neighbours."""
    n = len(colors) - 1
    t = np.clip(t, 0, 0.9999) * n
    i = t.astype(int)
    frac = t - i
    pick = i + (frac > DITHER)
    out = np.zeros((H, W, 3), np.float32)
    for k, col in enumerate(colors):
        out[pick == k] = col
    return out


def periodic_noise(width, height, cell, seed, cell_y=None):
    """Noise that wraps horizontally so it can scroll forever."""
    r = np.random.RandomState(seed)
    cell_y = cell_y or cell
    gw, gh = width // cell, height // cell_y + 2
    grid = r.rand(gh, gw)
    xs = np.arange(width) / cell
    ys = np.arange(height) / cell_y
    x0 = xs.astype(int) % gw
    x1 = (x0 + 1) % gw
    fx = xs - np.floor(xs)
    fy = ys - np.floor(ys)
    y0 = ys.astype(int)
    y1 = y0 + 1
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    a = grid[np.ix_(y0, x0)] * (1 - fx) + grid[np.ix_(y0, x1)] * fx
    b = grid[np.ix_(y1, x0)] * (1 - fx) + grid[np.ix_(y1, x1)] * fx
    return a * (1 - fy[:, None]) + b * fy[:, None]


def fbm(width, height, seed):
    # stretched sideways: storm clouds are long layered banks, not blobs
    return 0.5 * periodic_noise(width, height, 96, seed, 28) + 0.3 * periodic_noise(width, height, 48, seed + 1, 16)         + 0.2 * periodic_noise(width, height, 20, seed + 2, 8)


CLOUD_W = 960
CLOUDS_BACK = fbm(CLOUD_W, 170, 3)
CLOUDS_FRONT = fbm(CLOUD_W, 170, 9)
FOG_TEX = fbm(CLOUD_W, 40, 21)


def sky_layer(t, flash):
    """Dense overlapping clouds drifting sideways; no stars."""
    grad = np.clip(YY / (HORIZON + 10.0), 0, 1)
    img = ramp([SKY_TOP, SKY_LOW], grad ** 0.9)
    for tex, speed, y0, thr in ((CLOUDS_BACK, 3.0, 0, 0.47), (CLOUDS_FRONT, 7.0, -14, 0.5)):
        off = int(t * speed) % CLOUD_W
        cols = (np.arange(W) + off) % CLOUD_W
        rows = np.clip(np.arange(H) - y0, 0, tex.shape[0] - 1)
        n = tex[np.ix_(rows, cols)]
        fade = np.clip(1 - (YY - 100) / 70.0, 0, 1)         # clouds thin out near the horizon
        v = n * (0.55 + 0.6 * fade)
        mask = v > thr
        lit = v > thr + 0.09
        top = v > thr + 0.17
        img[mask] = CLOUD_DARK
        img[lit] = CLOUD_MID
        img[top & (DITHER > 0.35)] = CLOUD_LIT
    # lightning lights the undersides of the clouds
    if flash > 0:
        img = img + (FLASH - img) * (0.5 * flash) * np.clip(1.2 - YY / 190.0, 0.15, 1)[..., None]
    return img


def island_silhouettes(img, flash):
    """Far dark hills on the horizon."""
    r = random.Random(5)
    col = (c("#0c1348") + (c("#33408c") - c("#0c1348")) * 0.5 * flash)
    for cx, wid, hh in ((60, 70, 26), (130, 90, 34), (300, 60, 20), (388, 110, 40), (450, 70, 24)):
        for x in range(cx - wid, cx + wid):
            if 0 <= x < W:
                k = 1 - abs(x - cx) / wid
                top = int(HORIZON - hh * (k ** 0.8) - r.random() * 2)
                img[top:HORIZON + 4, x] = col
    return img


def wave_layer(img, t, base, amp, parts, colors, speed, seed, foam=True, crest_bias=0.0, depth=60, phase_mul=1.0):
    """One sea layer: a travelling crest line with dithered body and flickering foam on the crests.
    `parts` is a list of (wavelength, amplitude share, speed share)."""
    xs = np.arange(W, dtype=np.float32)
    h = np.full(W, float(base), np.float32)
    steep = np.zeros(W, np.float32)
    for k, (wl, share, sp) in enumerate(parts):
        ph = t * speed * sp * phase_mul / wl * math.tau + seed * 1.7 + k
        wave = np.sin(xs / wl * math.tau + ph)
        h -= amp * share * (0.5 + 0.5 * wave) ** 1.4          # sharp crests, wide troughs
        steep += np.cos(xs / wl * math.tau + ph) * share
    top = h.astype(int)
    depth_map = YY - top[None, :]
    body = depth_map >= 0
    shade = np.clip(depth_map / float(depth), 0, 1)
    layer = ramp(colors, shade)
    # lighter band along the crest, foam where the crest is high and steep
    img[body] = layer[body]
    face = body & (depth_map < 7) & (DITHER < 0.55 - depth_map / 16.0)
    img[face] = colors[-1] + (c("#5a78e0") - colors[-1]) * 0.45
    if foam:
        r = np.random.RandomState(seed * 100 + int(t * 6))
        rnd = r.rand(W)
        crest = (np.abs(steep) < 0.75) & (h < base - amp * 0.28)
        for dx in range(W):
            if crest[dx] and rnd[dx] > 0.15:
                y = top[dx]
                n = 2 + int(rnd[dx] * 4)
                for k in range(n):
                    if 0 <= y + k < H:
                        img[y + k, dx] = FOAM[min(2, k + (1 if rnd[dx] > 0.7 else 0))] if k < 2 else FOAM[0]
        # streaks of foam trailing down the face of the wave
        for dx in range(0, W, 3):
            if crest[dx] and rnd[dx] > 0.5:
                y = top[dx] + 3
                for k in range(int(3 + rnd[dx] * 6)):
                    if y + k < H and (dx + k) % 2 == 0:
                        img[y + k, dx] = FOAM[0]
    return img, top


def wreck(img, t, flash):
    """A broken ship with a torn sail, tilting on the swell, at mid distance on the left."""
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    wood, wood_d, wood_l = (30, 22, 34), (16, 12, 24), (60, 46, 66)
    sail = (92, 96, 150)
    tilt = math.sin(t * 0.9) * 0.05
    cx, cy = 100, 160 + math.sin(t * 1.3) * 2.5

    def P(x, y):
        x, y = x * 1.7, y * 1.7
        c_, s_ = math.cos(tilt), math.sin(tilt)
        return (cx + x * c_ - y * s_, cy + x * s_ + y * c_)
    hull = [P(-46, -10), P(-30, 6), P(30, 10), P(52, -6), P(56, -22), P(40, -12), P(-30, -16)]
    d.polygon(hull, fill=wood)
    d.line([P(-44, -10), P(-28, 5), P(30, 9), P(50, -6)], fill=wood_d, width=2)
    d.line([P(-30, -16), P(40, -12), P(56, -22)], fill=wood_l, width=1)
    for k in range(-30, 40, 12):                          # deck planks / gun ports
        d.rectangle([P(k, -8), P(k + 3, -5)], fill=wood_d)
    d.line([P(-6, -14), P(-2, -64)], fill=wood_d, width=3)   # main mast
    d.line([P(-30, -14), P(-34, -46)], fill=wood_d, width=2)  # broken fore mast
    d.line([P(-12, -52), P(10, -52)], fill=wood_d, width=2)
    d.polygon([P(-11, -52), P(8, -52), P(6, -30), P(-2, -26), P(-10, -34)], fill=sail)
    d.polygon([P(-11, -52), P(-6, -52), P(-9, -34)], fill=(70, 74, 124))
    for a, b in ((P(-2, -64), P(-34, -46)), (P(-2, -64), P(48, -8)), (P(-2, -60), P(-44, -10))):
        d.line([a, b], fill=(18, 14, 30), width=1)           # rigging
    arr = np.array(layer, dtype=np.float32)
    a = arr[..., 3:4] / 255.0
    rgb = arr[..., :3]
    rgb = rgb + (FLASH - rgb) * (0.45 * flash)
    return img * (1 - a) + rgb * a


def rock(img, flash):
    d_img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(d_img)
    d.polygon([(-4, 275), (-4, 232), (18, 218), (46, 224), (70, 244), (84, 275)], fill=(14, 14, 36, 255))
    d.polygon([(18, 218), (46, 224), (60, 236), (30, 232)], fill=(30, 34, 74, 255))
    arr = np.array(d_img, dtype=np.float32)
    a = arr[..., 3:4] / 255.0
    rgb = arr[..., :3] + (FLASH - arr[..., :3]) * (0.12 * flash)
    return img * (1 - a) + rgb * a


def fog_band(img, t):
    off = int(t * 5) % CLOUD_W
    cols = (np.arange(W) + off) % CLOUD_W
    n = FOG_TEX[:, cols]
    for y in range(HORIZON - 20, HORIZON + 14):
        k = y - (HORIZON - 20)
        strength = math.sin(k / 34 * math.pi) * 0.5
        if strength <= 0:
            continue
        a = np.clip((n[min(k, 39)] - 0.35) * 2.2, 0, 1) * strength
        sel = a > DITHER[y]
        img[y][sel] = img[y][sel] * 0.45 + FOG * 0.55
    return img


def bolt(r, x0, y0, x1, y1, branches=True, depth=0):
    pts = [(x0, y0)]
    x, y = x0, y0
    n = max(6, int(abs(y1 - y0) / 9))
    for i in range(1, n + 1):
        ty = y0 + (y1 - y0) * i / n
        tx = x0 + (x1 - x0) * i / n
        x = tx + r.uniform(-9, 9) * (1 if i < n else 0)
        y = ty + r.uniform(-3, 3)
        pts.append((x, y))
    segs = [pts]
    if branches and depth < 2:
        for i in range(2, len(pts) - 1):
            if r.random() < 0.28:
                bx, by = pts[i]
                ex = bx + r.choice((-1, 1)) * r.uniform(20, 50)
                ey = by + r.uniform(18, 45)
                segs += bolt(r, bx, by, ex, min(ey, HORIZON - 6), False, depth + 1)
    return segs


# thunder timeline (seconds): (time, x top, x bottom, strength)
STRIKES = [(1.1, 330, 300, 0.8), (1.25, 330, 300, 0.45), (3.3, 150, 175, 1.0), (3.45, 150, 175, 0.55),
           (3.6, 150, 175, 0.3), (5.4, 400, 385, 0.7), (7.0, 250, 240, 1.0)]


def flash_at(t):
    f = 0.0
    for ts, _, _, s in STRIKES:
        dt = t - ts
        if 0 <= dt < 0.55:
            f = max(f, s * math.exp(-dt * 7.0))
    return min(1.0, f)


def active_bolts(t):
    out = []
    for i, (ts, xt, xb, s) in enumerate(STRIKES):
        if 0 <= t - ts < 0.16:
            out.append((i, xt, xb, s))
    return out


def draw_bolts(img, t, flash_amount):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i, xt, xb, s in active_bolts(t):
        r = random.Random(100 + (i if i not in (1, 2, 4) else i - 1))   # re-strikes reuse the path
        for seg in bolt(r, xt, -4, xb, HORIZON + 4):
            line = [(int(x), int(y)) for x, y in seg]
            d.line(line, fill=(90, 110, 255, int(110 * s)), width=5)
            d.line(line, fill=(150, 170, 255, int(200 * s)), width=3)
            d.line(line, fill=(235, 242, 255, 255), width=1)
    arr = np.array(layer, dtype=np.float32)
    a = arr[..., 3:4] / 255.0
    return img * (1 - a) + arr[..., :3] * a


def rain(img, t, store={}):
    """Two depths of diagonal rain: thin and dim behind, longer and brighter in front."""
    if "far" not in store:
        r = random.Random(77)
        store["far"] = [(r.uniform(0, W + 80), r.uniform(0, H), r.uniform(0.7, 1.0)) for _ in range(170)]
        store["near"] = [(r.uniform(0, W + 80), r.uniform(0, H), r.uniform(0.7, 1.0)) for _ in range(70)]
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for name, speed, length, color, width in (("far", 150, 7, (120, 140, 230, 90), 1), ("near", 330, 14, (190, 205, 255, 150), 1)):
        for x0, y0, k in store[name]:
            y = (y0 + t * speed * k) % (H + 20) - 10
            x = (x0 - t * speed * k * 0.28) % (W + 80) - 40
            d.line([(x, y), (x - length * 0.28, y - length)], fill=color, width=width)
    arr = np.array(layer, dtype=np.float32)
    a = arr[..., 3:4] / 255.0
    return img * (1 - a) + arr[..., :3] * a


def spray(img, t, top_near):
    """Drops thrown off the crests of the front waves."""
    r = random.Random(int(t * 12) + 5)
    d = np.zeros((H, W), bool)
    for _ in range(26):
        x = r.randrange(W)
        y0 = int(top_near[x]) - r.randint(1, 9)
        if 0 <= y0 < H:
            d[y0, x] = True
            if r.random() < 0.4 and y0 - 1 >= 0:
                d[y0 - 1, x] = True
    img[d] = FOAM[2]
    return img


def camera(img, t):
    """Slow drift, a gentle vertical sway and a short shake after each thunder."""
    sway = math.sin(t * 1.1) * 1.4
    shake_x = shake_y = 0.0
    for ts, _, _, s in STRIKES:
        dt = t - (ts + 0.22)
        if 0 <= dt < 0.5:
            amp = 3.0 * s * math.exp(-dt * 6)
            shake_x += math.sin(dt * 70) * amp
            shake_y += math.cos(dt * 83) * amp * 0.7
    ox, oy = int(round(shake_x + t * 0.8)) % W, int(round(sway + shake_y))
    out = np.roll(img, -oy, axis=0)
    # sideways drift is almost imperceptible; wrap with the nearest column instead of black
    return np.roll(out, -int(round(shake_x)), axis=1)


def render(t, layers=False):
    f = flash_at(t)
    img = sky_layer(t, f)
    img = island_silhouettes(img, f)
    # five depths of sea
    img, _ = wave_layer(img, t, HORIZON, 4, [(22, 0.6, 0.3), (9, 0.4, 0.5)], SEA_FAR, 16, 1, foam=False, depth=24, lit_face=False)
    img = wreck(img, t, f)
    img, _ = wave_layer(img, t, HORIZON + 22, 9, [(46, 0.6, 1.0), (20, 0.4, -0.6)], SEA_MID, 22, 2, depth=40)
    img, _ = wave_layer(img, t, HORIZON + 46, 17, [(70, 0.6, -1.0), (31, 0.4, 0.8)], SEA_MID, 28, 3, depth=50, phase_mul=1.0)
    img, near_top = wave_layer(img, t, HORIZON + 86, 36, [(130, 0.65, 1.0), (52, 0.35, -0.7)], SEA_NEAR, 36, 4, depth=70)
    img = fog_band(img, t)
    img = rock(img, f)
    img = spray(img, t, near_top)
    # sea gets lit by the flash too
    if f > 0:
        sea = YY > HORIZON
        img[sea] = img[sea] + (FLASH - img[sea]) * (0.2 * f)
    img = rain(img, t)
    img = draw_bolts(img, t, f)
    # darkening between strikes, and the finale: a huge flash that burns the screen, then black
    ambient = 0.78 + 0.22 * math.sin(t * 0.7) ** 2
    img = img * ambient
    if t >= 7.0:
        k = t - 7.0
        white = max(0.0, 1.0 - k / 0.25) * 0.85
        fade = min(1.0, max(0.0, (k - 0.25) / 1.6))
        img = img + (c("#f4f8ff") - img) * white
        img = img * (1 - fade)
    return np.clip(img, 0, 255).astype(np.uint8)



# ================================================================ v2 refinements
from PIL import ImageFilter

CLOUD_RIM = c("#4a5cc8")
CLOUD_RIM_LOW = c("#2c3a9a")


def sky_layer(t, flash):
    """Dense, layered cloud banks drifting sideways (two speeds), each with a lit rim; no stars."""
    grad = np.clip(YY / (HORIZON + 10.0), 0, 1)
    img = ramp([SKY_TOP, SKY_LOW], grad ** 0.9)
    for tex, speed, y0, thr in ((CLOUDS_BACK, 3.0, 0, 0.46), (CLOUDS_FRONT, 7.0, -14, 0.5)):
        off = int(t * speed) % CLOUD_W
        cols = (np.arange(W) + off) % CLOUD_W
        rows = np.clip(np.arange(H) - y0, 0, tex.shape[0] - 1)
        n = tex[np.ix_(rows, cols)]
        fade = np.clip(1 - (YY - 100) / 70.0, 0, 1)
        v = n * (0.55 + 0.6 * fade)
        mask = v > thr
        body = v > thr + 0.07
        core = v > thr + 0.16
        img[mask] = CLOUD_DARK
        img[body] = CLOUD_MID
        img[core & (DITHER > 0.45)] = CLOUD_LIT
        # rim light on the upper edge of every bank, a dimmer one on the underside
        above = np.roll(mask, 1, axis=0)
        below = np.roll(mask, -1, axis=0)
        top_edge = mask & ~above
        top_edge2 = np.roll(top_edge, 1, axis=0) & mask
        img[top_edge] = CLOUD_RIM
        img[top_edge2 & (DITHER > 0.4)] = CLOUD_RIM_LOW
        img[mask & ~below & (DITHER < 0.5)] = CLOUD_RIM_LOW
    if flash > 0:
        img = img + (FLASH - img) * (0.5 * flash) * np.clip(1.2 - YY / 190.0, 0.15, 1)[..., None]
    return img


def wreck(img, t, flash):
    """A broken ship with a torn sail, heeling over on the swell, at mid distance on the left."""
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    wood, wood_d, wood_l = (34, 24, 38), (16, 12, 24), (72, 54, 76)
    sail, sail_d = (118, 122, 176), (80, 84, 136)
    tilt = -0.09 + math.sin(t * 0.9) * 0.04          # listing to starboard, rolling a little
    cx, cy = 104, 160 + math.sin(t * 1.3) * 2.5
    k = 1.8

    def P(x, y):
        x, y = x * k, y * k
        c_, s_ = math.cos(tilt), math.sin(tilt)
        return (cx + x * c_ - y * s_, cy + x * s_ + y * c_)

    def poly(pts, fill):
        d.polygon([P(*p) for p in pts], fill=fill)

    def line(pts, fill, w=1):
        d.line([P(*p) for p in pts], fill=fill, width=w)
    # hull: high stern castle on the right, bow low and broken on the left
    poly([(-44, -4), (-34, 8), (-6, 12), (26, 10), (46, 2), (52, -20), (46, -26), (34, -14), (-20, -12), (-40, -8)], wood)
    poly([(30, -14), (46, -26), (52, -20), (46, -6)], wood_d)          # stern castle
    line([(-44, -4), (-34, 8), (-6, 12), (26, 10), (46, 2)], wood_d, 2)
    line([(-40, -9), (-20, -12), (34, -14), (46, -26)], wood_l, 1)      # moonlit rail
    for x in range(-28, 28, 9):                                           # gun ports
        poly([(x, -5), (x + 4, -5), (x + 4, -1), (x, -1)], wood_d)
    for x in range(-34, 30, 7):                                           # plank seams
        line([(x, -10), (x + 2, 9)], wood_d, 1)
    # splintered bow
    poly([(-44, -4), (-52, -12), (-46, -9), (-48, -16), (-40, -8)], wood)
    # masts: main one standing, fore one snapped
    line([(2, -12), (4, -74)], wood_d, 3)
    line([(-26, -12), (-30, -46), (-24, -50)], wood_d, 2)
    line([(-14, -62), (22, -62)], wood_d, 2)
    line([(-12, -42), (20, -42)], wood_d, 2)
    # torn sails
    poly([(-13, -62), (21, -62), (19, -48), (13, -44), (9, -52), (3, -43), (-4, -48), (-9, -41), (-12, -52)], sail)
    poly([(-13, -62), (-5, -62), (-8, -50), (-12, -52)], sail_d)
    poly([(-11, -41), (18, -41), (15, -26), (9, -22), (4, -29), (-3, -23), (-9, -30)], sail_d)
    # rigging
    for a, b in (((4, -74), (-30, -46)), ((4, -74), (50, -22)), ((4, -68), (-44, -4)), ((4, -68), (44, -26))):
        line([a, b], (22, 18, 40), 1)
    arr = np.array(layer, dtype=np.float32)
    a = arr[..., 3:4] / 255.0
    rgb = arr[..., :3] + (FLASH - arr[..., :3]) * (0.45 * flash)
    # a thin rim light on the top edges so it separates from the sky
    alpha = arr[..., 3] > 0
    top = alpha & ~np.roll(alpha, 1, axis=0)
    rgb[top] = np.array([90, 100, 170], np.float32) * (0.6 + 0.4 * flash)
    return img * (1 - a) + rgb * a


def draw_bolts(img, t, flash_amount):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for i, xt, xb, s in active_bolts(t):
        r = random.Random(100 + (i if i not in (1, 2, 4) else i - 1))
        for seg in bolt(r, xt, -4, xb, HORIZON + 4):
            line = [(int(x), int(y)) for x, y in seg]
            d.line(line, fill=(235, 242, 255, 255), width=1)
    core = np.array(layer, dtype=np.float32)
    # soft blue glow around the strike lights up the clouds and the water near it
    alpha = Image.fromarray((core[..., 3]).astype(np.uint8))
    glow1 = np.array(alpha.filter(ImageFilter.GaussianBlur(2.2)), dtype=np.float32) / 255.0
    glow2 = np.array(alpha.filter(ImageFilter.GaussianBlur(14)), dtype=np.float32) / 255.0
    strength = max([s for _, _, _, s in active_bolts(t)] or [0])
    img = img + (c("#6a86ff") - img) * np.clip(glow2 * 2.2 * strength, 0, 0.6)[..., None]
    img = img + (c("#a8bcff") - img) * np.clip(glow1 * 2.4, 0, 0.85)[..., None]
    a = core[..., 3:4] / 255.0
    return img * (1 - a) + core[..., :3] * a



# ================================================================ v3 refinements: bigger irregular waves, hull, rocks
def wave_layer(img, t, base, amp, parts, colors, speed, seed, foam=True, crest_bias=0.0, depth=60, phase_mul=1.0, lit_face=True):
    """One sea layer: irregular swells (a slow envelope makes some crests taller), a dithered body with a
    moonlit face on the rising side of every wave, and foam caps with drips."""
    xs = np.arange(W, dtype=np.float32)
    h = np.full(W, float(base), np.float32)
    slope = np.zeros(W, np.float32)
    env = 0.62 + 0.38 * np.sin(xs / 170.0 * math.tau + t * 0.35 + seed * 2.1) * np.sin(xs / 97.0 * math.tau - t * 0.22 + seed)
    for k, (wl, share, sp) in enumerate(parts):
        ph = t * speed * sp * phase_mul / wl * math.tau + seed * 1.7 + k
        wave = np.sin(xs / wl * math.tau + ph)
        h -= amp * share * (0.5 + 0.5 * wave) ** 1.5 * env
        slope += np.cos(xs / wl * math.tau + ph) * share * sp
    top = h.astype(int)
    depth_map = YY - top[None, :]
    body = depth_map >= 0
    shade = np.clip(depth_map / float(depth), 0, 1)
    layer = ramp(colors, shade)
    img[body] = layer[body]
    # moonlit face: the side of the wave that rises toward the crest catches the light
    rising = (slope > 0)[None, :]
    face = lit_face & body & (depth_map < 10) & (DITHER < (0.75 - depth_map / 14.0)) & rising
    img[face] = colors[-1] + (c("#6a86e8") - colors[-1]) * 0.5
    dim = lit_face & body & (depth_map < 5) & (DITHER < 0.4) & ~rising
    img[dim] = colors[-1] + (c("#34508f") - colors[-1]) * 0.5
    if foam:
        r = np.random.RandomState(seed * 100 + int(t * 6))
        rnd = r.rand(W)
        tall = (base - h) / max(amp, 1.0)                    # 0 in the trough, up to 1 on a big crest
        for dx in range(W):
            if tall[dx] < 0.3:
                continue
            y = top[dx]
            n = 1 + int(tall[dx] * 4 + rnd[dx] * 2)
            for k in range(n):
                if 0 <= y + k < H:
                    shade_i = 2 if k == 0 else (1 if k < n - 1 else 0)
                    if rnd[dx] < 0.12 and k > 0:
                        continue
                    img[y + k, dx] = FOAM[shade_i]
            if tall[dx] > 0.55 and rnd[dx] > 0.55:           # drips running down the face
                for k in range(n, n + int(2 + rnd[dx] * 7)):
                    if y + k < H and (dx + k) % 2 == 0:
                        img[y + k, dx] = FOAM[0]
        # foam patches left on the water between crests
        for _ in range(int(W / 28)):
            px = int(r.rand() * W)
            py = int(top[px] + 6 + r.rand() * depth * 0.5)
            wd = 3 + int(r.rand() * 7)
            for dx in range(wd):
                if px + dx < W and py < H and dith_ok(px + dx, py, 0.5):
                    img[py, px + dx] = FOAM[0]
    return img, top


def dith_ok(x, y, level):
    return DITHER[y % H, x % W] < level


def wreck(img, t, flash):
    """The ship, now with shaded planks, a wet waterline and a ragged bow."""
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    wood, wood_d, wood_l = (34, 24, 38), (16, 12, 24), (78, 58, 82)
    sail, sail_d = (118, 122, 176), (80, 84, 136)
    tilt = -0.09 + math.sin(t * 0.9) * 0.04
    cx, cy = 104, 160 + math.sin(t * 1.3) * 2.5
    k = 1.8

    def P(x, y):
        x, y = x * k, y * k
        c_, s_ = math.cos(tilt), math.sin(tilt)
        return (cx + x * c_ - y * s_, cy + x * s_ + y * c_)

    def poly(pts, fill):
        d.polygon([P(*p) for p in pts], fill=fill)

    def line(pts, fill, w=1):
        d.line([P(*p) for p in pts], fill=fill, width=w)
    poly([(-44, -4), (-34, 8), (-6, 12), (26, 10), (46, 2), (52, -20), (46, -26), (34, -14), (-20, -12), (-40, -8)], wood)
    poly([(-44, -4), (-34, 8), (-6, 12), (26, 10), (46, 2), (47, 4), (26, 14), (-6, 15), (-36, 11)], wood_d)   # keel shadow
    poly([(30, -14), (46, -26), (52, -20), (46, -6)], wood_d)
    line([(-40, -9), (-20, -12), (34, -14), (46, -26)], wood_l, 1)
    line([(-42, -4), (-30, -6), (-4, -7), (28, -8), (48, -10)], wood_l, 1)      # a lit strake along the hull
    for x in range(-34, 30, 6):
        line([(x, -10), (x + 2, 10)], wood_d, 1)
    for x in range(-28, 28, 9):
        poly([(x, -5), (x + 4, -5), (x + 4, -1), (x, -1)], wood_d)
        line([(x, -5), (x + 4, -5)], wood_l, 1)
    poly([(-44, -4), (-54, -14), (-47, -9), (-50, -19), (-41, -8)], wood)       # splintered bow
    line([(-44, -4), (-51, -13)], wood_l, 1)
    line([(2, -12), (4, -74)], wood_d, 3)
    line([(-26, -12), (-30, -46), (-24, -50)], wood_d, 2)
    line([(-14, -62), (22, -62)], wood_d, 2)
    line([(-12, -42), (20, -42)], wood_d, 2)
    poly([(-13, -62), (21, -62), (19, -48), (13, -44), (9, -52), (3, -43), (-4, -48), (-9, -41), (-12, -52)], sail)
    poly([(-13, -62), (-5, -62), (-8, -50), (-12, -52)], sail_d)
    poly([(-11, -41), (18, -41), (15, -26), (9, -22), (4, -29), (-3, -23), (-9, -30)], sail_d)
    for a, b in (((4, -74), (-30, -46)), ((4, -74), (50, -22)), ((4, -68), (-44, -4)), ((4, -68), (44, -26))):
        line([a, b], (22, 18, 40), 1)
    arr = np.array(layer, dtype=np.float32)
    a = arr[..., 3:4] / 255.0
    rgb = arr[..., :3] + (FLASH - arr[..., :3]) * (0.22 * flash)
    alpha = arr[..., 3] > 0
    top = alpha & ~np.roll(alpha, 1, axis=0)
    rgb[top] = np.array([100, 110, 180], np.float32) * (0.6 + 0.4 * flash)
    return img * (1 - a) + rgb * a


def rock(img, flash):
    """A big wet rock in the lower-left corner with facets and a rim of light."""
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.polygon([(-4, 275), (-4, 226), (10, 214), (30, 206), (52, 212), (66, 228), (78, 250), (92, 275)], fill=(12, 14, 36, 255))
    d.polygon([(10, 214), (30, 206), (52, 212), (44, 222), (24, 224)], fill=(36, 42, 88, 255))      # lit top
    d.polygon([(52, 212), (66, 228), (58, 232), (44, 222)], fill=(24, 28, 66, 255))
    d.polygon([(-4, 240), (20, 232), (34, 250), (20, 275), (-4, 275)], fill=(8, 10, 28, 255))        # shadow side
    d.line([(10, 214), (30, 206), (52, 212)], fill=(92, 108, 190, 255), width=1)                      # moon rim
    d.line([(52, 212), (66, 228)], fill=(64, 78, 150, 255), width=1)
    for x, y in ((24, 232), (38, 240), (16, 246), (50, 236)):                                         # wet glints
        d.point((x, y), fill=(120, 140, 220, 255))
    arr = np.array(layer, dtype=np.float32)
    a = arr[..., 3:4] / 255.0
    rgb = arr[..., :3] + (FLASH - arr[..., :3]) * (0.12 * flash)
    return img * (1 - a) + rgb * a


def main():
    frames = []
    for i in range(FRAMES):
        t = i / FPS
        frame = camera(render(t), t)
        frames.append(Image.fromarray(frame))
        if i % 30 == 0:
            print("frame", i, "of", FRAMES)
    frames[0].save(os.path.join(OUT, "scene1_storm.gif"), save_all=True, append_images=frames[1:], duration=1000 // FPS, loop=0, optimize=False)
    for name, tt in (("calm", 0.5), ("strike", 3.34), ("rain", 4.6), ("finale", 7.08)):
        Image.fromarray(camera(render(tt), tt)).resize((W * 3, H * 3), Image.NEAREST).save(os.path.join(OUT, "scene1_still_%s.png" % name))
    sheet = Image.new("RGB", (W * 2, H * 3))
    for k, tt in enumerate((0.3, 1.1, 2.0, 3.34, 5.4, 7.1)):
        sheet.paste(Image.fromarray(camera(render(tt), tt)), ((k % 2) * W, (k // 2) * H))
    sheet.resize((W * 3, H * 4 + 270), Image.NEAREST).save(os.path.join(OUT, "scene1_sheet.png"))
    print("ok")


if __name__ == "__main__":
    main()
