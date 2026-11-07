"""Prologue, scene 2: Nico wakes up on the beach (480x270). Draft outside the project.
    python make_scene2.py
Nico is the team's reference sprite (assets/ui/menu/source/nico_east.png) turned on its back, so his
jacket, scarf, hair and proportions are exactly the same as everywhere else."""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.environ.get("PROLOGUE_OUT", os.path.join(ROOT, "builds", "prologue"))
os.makedirs(OUT, exist_ok=True)
SOURCES = os.path.join(ROOT, "assets", "sprites", "nico_prologue", "source")
NICO_SRC = os.path.join(ROOT, "assets", "ui", "menu", "source", "nico_east.png")
W, H = 480, 270
FPS = 20
SECONDS = 10.0
FRAMES = int(FPS * SECONDS)
HORIZON = 112

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16.0
YY, XX = np.mgrid[0:H, 0:W]
DITHER = BAYER[YY % 4, XX % 4]


def c(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


def ramp(colors, t):
    n = len(colors) - 1
    t = np.clip(t, 0, 0.9999) * n
    i = t.astype(int)
    pick = i + ((t - i) > DITHER)
    out = np.zeros((H, W, 3), np.float32)
    for k, col in enumerate(colors):
        out[pick == k] = col
    return out


def periodic_noise(width, height, cell, seed, cell_y=None):
    r = np.random.RandomState(seed)
    cell_y = cell_y or cell
    gw, gh = width // cell, height // cell_y + 2
    grid = r.rand(gh, gw)
    xs, ys = np.arange(width) / cell, np.arange(height) / cell_y
    x0 = xs.astype(int) % gw
    x1 = (x0 + 1) % gw
    fx, fy = xs - np.floor(xs), ys - np.floor(ys)
    y0 = ys.astype(int)
    fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = grid[np.ix_(y0, x0)] * (1 - fx) + grid[np.ix_(y0, x1)] * fx
    b = grid[np.ix_(y0 + 1, x0)] * (1 - fx) + grid[np.ix_(y0 + 1, x1)] * fx
    return a * (1 - fy[:, None]) + b * fy[:, None]


CLOUD_W = 960
CLOUDS = 0.5 * periodic_noise(CLOUD_W, 140, 96, 31, 28) + 0.3 * periodic_noise(CLOUD_W, 140, 48, 32, 16) + 0.2 * periodic_noise(CLOUD_W, 140, 20, 33, 8)
FOG_TEX = 0.6 * periodic_noise(CLOUD_W, 40, 80, 41, 14) + 0.4 * periodic_noise(CLOUD_W, 40, 30, 42, 10)

SKY = [c("#060a2c"), c("#0e1850"), c("#1c2c78"), c("#2e4296")]
CLOUD_DARK, CLOUD_MID, CLOUD_RIM = c("#0a1040"), c("#16226a"), c("#4e68c0")
SEA = [c("#1c3290"), c("#142470"), c("#0d1a58"), c("#091244")]
SAND_WET = [c("#2c2838"), c("#3a3446"), c("#4a4256")]
SAND_DRY = [c("#4e4250"), c("#665664"), c("#7e6c70"), c("#9a8680")]
FOAM = [c("#6f88d8"), c("#b8caff"), c("#eef3ff")]


def draw_to(img, layer, tint=0.0, tint_color=None):
    arr = np.array(layer, dtype=np.float32)
    a = arr[..., 3:4] / 255.0
    rgb = arr[..., :3]
    return img * (1 - a) + rgb * a


# ---------------------------------------------------------------- static scenery
def make_backdrop():
    """Everything that does not move: sky gradient, moon, far forest, beach and its props."""
    img = ramp(SKY, np.clip(YY / 135.0, 0, 1))
    # moon, high on the right
    cx, cy, r = 392, 46, 15
    for rr, col, lvl in ((44, "#243282", 0.3), (32, "#2e3f96", 0.35), (24, "#3a4ca6", 0.4)):
        m = (np.hypot(XX - cx, YY - cy) <= rr) & (DITHER < lvl)
        img[m] = c(col)
    m = np.hypot(XX - cx, YY - cy) <= r
    shade = np.clip(((XX - cx) * 0.3 + (YY - cy) * 0.4 + 10) / 28.0, 0, 1)
    img[m] = (c("#f6f0d0")[None, None, :] * (1 - shade[..., None]) + c("#c8c0a0")[None, None, :] * shade[..., None])[m]
    for dx, dy, rr in ((-5, -4, 3), (5, 3, 4), (-2, 7, 2)):
        mm = np.hypot(XX - (cx + dx), YY - (cy + dy)) <= rr
        img[mm & (DITHER < 0.8) & m] = c("#d8cca0")
    return img


def forest_silhouette(img):
    """Dense dark vegetation behind the beach: tree crowns on both sides, with a moon-lit rim."""
    r = random.Random(4)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for x0, x1, base, hmax in ((-20, 120, 168, 70), (300, 500, 168, 90)):
        x = x0
        while x < x1:
            rad = r.randint(14, 26)
            top = base - r.randint(18, hmax)
            d.ellipse((x - rad, top, x + rad, top + rad * 2), fill=(6, 22, 28, 255))
            d.ellipse((x - rad + 3, top + 2, x + rad - 5, top + rad), fill=(10, 36, 40, 255))
            for k in range(5):                           # leaf-clump rim light
                ang = r.uniform(-1.2, -0.2)
                px, py = x + math.cos(ang) * rad * 0.8, top + rad + math.sin(ang) * rad * 0.9
                d.rectangle((px, py, px + 2, py), fill=(34, 74, 70, 255))
            x += r.randint(10, 20)
    d.rectangle((-20, 150, 130, 175), fill=(6, 22, 28, 255))
    d.rectangle((300, 150, 500, 175), fill=(6, 22, 28, 255))
    return draw_to(img, layer)


def far_ocean(img, t):
    """Calm sea with a long moon glitter, drifting wood and the wreck far away."""
    sea_top, sea_bot = HORIZON, 190
    k = np.clip((YY - sea_top) / float(sea_bot - sea_top), 0, 1)
    sea = ramp(SEA, k)
    mask = (YY >= sea_top) & (YY < sea_bot + 6)
    img[mask] = sea[mask]
    # slow ripples: thin lines that drift sideways
    for row in range(sea_top + 2, sea_bot, 3):
        depth = (row - sea_top) / (sea_bot - sea_top)
        spacing = 14 + depth * 26
        off = (t * (5 + depth * 6) + row * 7.3) % spacing
        x = np.arange(-int(spacing), W, int(spacing)) + off
        for xv in x:
            ln = int(4 + depth * 10)
            xi = int(xv)
            y = row
            for dx in range(ln):
                if 0 <= xi + dx < W and (dx + row) % 2 == 0:
                    img[y, xi + dx] = c("#2c48b0") if depth < 0.5 else c("#3a58c4")
    # moon glitter: broken bright dashes under the moon
    r = random.Random(int(t * 4))
    for row in range(sea_top + 1, sea_bot, 2):
        depth = (row - sea_top) / (sea_bot - sea_top)
        half = 4 + depth * 22
        for _ in range(3):
            x = int(392 + (r.random() - 0.5) * 2 * half * 0.8)
            w = r.randint(2, 4 + int(depth * 6))
            for dx in range(w):
                if 0 <= x + dx < W:
                    img[row, x + dx] = c("#b8c8ff") if r.random() < 0.6 else c("#e6edff")
    return img


def wreck_far(img, t):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    bob = math.sin(t * 0.8) * 1.0
    cx, cy = 96, HORIZON + 10 + bob
    col, col2 = (14, 12, 34, 255), (30, 34, 80, 255)
    d.polygon([(cx - 26, cy - 2), (cx - 18, cy + 5), (cx + 16, cy + 5), (cx + 28, cy - 4), (cx + 30, cy - 12), (cx + 22, cy - 6), (cx - 18, cy - 5)], fill=col)
    d.line([(cx - 2, cy - 5), (cx, cy - 38)], fill=col, width=2)                # standing mast
    d.line([(cx - 12, cy - 5), (cx - 16, cy - 22)], fill=col, width=1)           # broken fore mast
    d.polygon([(cx - 10, cy - 36), (cx + 10, cy - 36), (cx + 8, cy - 22), (cx + 3, cy - 18), (cx - 1, cy - 24), (cx - 8, cy - 20)], fill=(40, 48, 100, 255))
    d.line([(cx - 26, cy - 3), (cx - 18, cy - 5)], fill=col2, width=1)
    return draw_to(img, layer)


def shoreline(t, x):
    """y of the water's edge: a long slow swell washing in and out."""
    return 188 + 4 * math.sin(x / 60.0 + 0.4) + 3 * math.sin(x / 23.0 + 1.1) + 4.5 * math.sin(t * 0.9 - x / 160.0)


def beach(img, t):
    xs = np.arange(W)
    edge = np.array([shoreline(t, x) for x in xs], np.float32)
    ground = YY >= edge[None, :]
    # wet sand right behind the water: dark and shiny, drying out toward the bottom
    wet_depth = np.clip((YY - edge[None, :]) / 20.0, 0, 1)
    wet = ramp(SAND_WET, 1 - wet_depth)
    dry = ramp(SAND_DRY, np.clip((YY - 196) / 74.0, 0, 1) * 0.8 + 0.1 * np.sin(XX / 40.0) + 0.1)
    blend = np.clip((YY - edge[None, :] - 12) / 14.0, 0, 1)
    sand = np.where((blend > DITHER)[..., None], dry, wet)
    img[ground] = sand[ground]
    # foam line and a thin film of water that slides back over the sand
    for x in xs:
        y = int(edge[x])
        for k, col in enumerate((FOAM[2], FOAM[1], FOAM[0], FOAM[0])):
            if 0 <= y - 1 + k < H and (x + k) % (2 if k > 1 else 1) == 0:
                img[y - 1 + k, x] = col
        for k in range(4, 7):
            if y + k < H and DITHER[(y + k) % H, x] < 0.28 - (k - 4) * 0.1:
                img[y + k, x] = c("#5a76c8")
    return img, edge


def sand_details(img, t):
    r = random.Random(12)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    # puddles reflecting the sky, with a moving glint
    for cx, cy, rx, ry in ((310, 226, 24, 6), (140, 244, 20, 5), (410, 252, 18, 5), (80, 218, 12, 3)):
        d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=(36, 52, 128, 255))
        d.ellipse((cx - rx + 2, cy - ry + 1, cx + rx - 2, cy), fill=(50, 70, 160, 255))
        gx = cx + math.sin(t * 0.7 + cx) * (rx * 0.5)
        d.line((gx - 4, cy - 1, gx + 4, cy - 1), fill=(200, 215, 255, 255))
        d.arc((cx - rx - 1, cy - ry - 1, cx + rx + 1, cy + ry + 1), 20, 160, fill=(18, 20, 50, 255))
    # drag marks from the water to where Nico lies
    for off in (-6, 6):
        pts = [(156 + i * 4.4 + off * 0.5, 196 + i * 2.1 - off * 0.35 + math.sin(i / 3.0 + off) * 1.2) for i in range(0, 11)]
        for k, (x, y) in enumerate(pts):
            if k % 3 != 2:
                d.line((x, y, x + 3, y + 1), fill=(34, 30, 44, 255), width=1)
                d.point((x + 1, y + 2), fill=(96, 82, 92, 255))
    # scattered pebbles
    for _ in range(46):
        x, y = r.randint(0, W), r.randint(200, 266)
        s = r.randint(1, 3)
        d.ellipse((x, y, x + s + 1, y + s), fill=(28, 24, 40, 255))
        d.point((x, y), fill=(110, 98, 120, 255))
    return draw_to(img, layer)


def rock(d, x, y, w, h, lit=True):
    d.polygon([(x, y + h), (x + w * 0.1, y + h * 0.4), (x + w * 0.35, y), (x + w * 0.75, y + h * 0.1), (x + w, y + h * 0.55), (x + w * 0.95, y + h)], fill=(14, 14, 38, 255))
    d.polygon([(x + w * 0.1, y + h * 0.4), (x + w * 0.35, y), (x + w * 0.75, y + h * 0.1), (x + w * 0.55, y + h * 0.35)], fill=(40, 46, 96, 255))
    d.line([(x + w * 0.1, y + h * 0.4), (x + w * 0.35, y), (x + w * 0.75, y + h * 0.1)], fill=(100, 114, 190, 255), width=1)
    d.point((x + w * 0.6, y + h * 0.7), fill=(90, 100, 170, 255))


def wood_pieces(img, t):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    wd, wm, wl = (30, 20, 30, 255), (56, 40, 50, 255), (104, 80, 90, 255)
    # a driftwood log on the left of Nico
    d.polygon([(118, 232), (170, 224), (174, 232), (122, 240)], fill=wm)
    d.polygon([(118, 232), (170, 224), (172, 227), (120, 235)], fill=wl)
    d.line([(122, 240), (174, 232)], fill=wd, width=2)
    d.ellipse((115, 231, 124, 241), fill=wd)
    d.ellipse((117, 233, 122, 238), fill=(80, 60, 70, 255))
    # planks half buried in the sand
    for pts in (((300, 250), (356, 236), (358, 242), (302, 256)), ((60, 232), (92, 222), (94, 227), (62, 237))):
        d.polygon(pts, fill=wm)
        d.line([pts[0], pts[1]], fill=wl, width=1)
        d.line([pts[3], pts[2]], fill=wd, width=1)
    for x in (326, 340):
        d.line([(x, 244), (x + 1, 250)], fill=wd, width=1)
    # a broken mast planted in the sand on the right with a rag of sail
    d.polygon([(440, 252), (444, 252), (446, 120), (442, 120)], fill=wm)
    d.line([(446, 120), (446, 252)], fill=wl, width=1)
    d.polygon([(420, 150), (468, 144), (468, 148), (420, 154)], fill=wm)
    d.polygon([(424, 154), (446, 152), (442, 190), (436, 184), (432, 196), (426, 180)], fill=(90, 94, 150, 255))
    d.polygon([(424, 154), (432, 154), (430, 178), (426, 176)], fill=(66, 70, 120, 255))
    d.line([(442, 120), (418, 150)], fill=wd, width=1)
    # rocks
    rock(d, 18, 238, 46, 28)
    rock(d, 350, 232, 34, 22)
    rock(d, 318, 186, 26, 10)
    rock(d, 262, 256, 40, 18)
    return draw_to(img, layer)


def floating_wood(img, t):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for k, (x0, y0, ln, sp) in enumerate(((60, 150, 22, 3.0), (210, 138, 14, 2.0), (310, 160, 18, 4.0), (150, 170, 24, 2.5))):
        x = (x0 + t * sp) % (W + 40) - 20
        y = y0 + math.sin(t * 1.1 + k) * 1.6
        d.polygon([(x, y), (x + ln, y - 1), (x + ln + 2, y + 2), (x + 1, y + 3)], fill=(46, 32, 48, 255))
        d.line([(x, y), (x + ln, y - 1)], fill=(110, 86, 100, 255), width=1)
        for dx in range(-2, ln + 4, 3):                                  # foam ring around it
            d.point((x + dx, y + 4), fill=(150, 170, 240, 255))
    return draw_to(img, layer)


def shore_debris(img, t, edge):
    """Wreckage that the sea has pushed close to the shore: planks, a barrel, a snapped mast piece and
    rope, riding the swell and ringed with foam. Each piece follows the water's edge up and down."""
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    wd, wm, wl = (28, 18, 28, 255), (58, 40, 50, 255), (112, 86, 96, 255)
    foam = (170, 190, 250, 255)

    def ring(x, y, rx, k):
        for i in range(-rx, rx + 1, 3):
            if (i + k) % 2 == 0:
                d.point((x + i, y), fill=foam)

    # a long plank with nails, angled in the shallows
    x, y = 96 + math.sin(t * 0.3) * 4, edge[96] - 7 + math.sin(t * 1.2) * 1.4
    d.polygon([(x, y), (x + 40, y - 6), (x + 42, y - 2), (x + 2, y + 4)], fill=wm)
    d.line([(x, y), (x + 40, y - 6)], fill=wl, width=1)
    d.line([(x + 2, y + 4), (x + 42, y - 2)], fill=wd, width=1)
    for nx_ in (x + 10, x + 28):
        d.point((nx_, y - 2), fill=(150, 150, 170, 255))
    ring(int(x + 20), int(y + 6), 22, 0)
    # a snapped piece of mast with a tangle of rope, near the middle
    x, y = 330 + math.sin(t * 0.3 + 3) * 4, edge[330] - 5 + math.sin(t * 1.1 + 4) * 1.3
    d.polygon([(x, y), (x + 34, y - 3), (x + 36, y + 2), (x + 2, y + 5)], fill=wm)
    d.line([(x, y), (x + 34, y - 3)], fill=wl, width=1)
    d.polygon([(x - 4, y - 1), (x, y - 3), (x + 1, y + 6), (x - 3, y + 4)], fill=wd)       # splintered end
    d.line([(x + 22, y - 3), (x + 28, y - 12), (x + 40, y - 8), (x + 34, y + 1)], fill=(120, 98, 84, 255), width=1)   # rope
    ring(int(x + 18), int(y + 7), 20, 0)
    # two small boards already touching the wet sand, shoved by each wave
    for cx, off in ((160, 0.0), (292, 1.7)):
        push = 1.5 * math.sin(t * 0.9 + off)
        x, y = cx + push, edge[cx] + 1
        d.polygon([(x, y), (x + 18, y - 2), (x + 19, y + 1), (x + 1, y + 3)], fill=wm)
        d.line([(x, y), (x + 18, y - 2)], fill=wl, width=1)
        ring(int(x + 9), int(y + 4), 10, 1)
    # a few loose splinters and a coil of rope in the foam
    for cx in (60, 196, 262, 380, 420):
        x, y = cx + math.sin(t * 0.7 + cx) * 2, edge[cx] - 2 + math.sin(t * 1.5 + cx) * 1.0
        d.line([(x, y), (x + 5, y - 1)], fill=wm, width=2)
    return draw_to(img, layer)


# ---------------------------------------------------------------- vegetation that sways
def palm(layer, x, y, h, lean, t, phase, scale=1.0, shade=0):
    d = ImageDraw.Draw(layer)
    trunk, trunk_l = (12, 22, 26, 255), (38, 64, 64, 255)
    pts = []
    for i in range(0, 13):
        k = i / 12
        pts.append((x + lean * k * k + math.sin(t * 0.6 + phase) * 1.5 * k, y - h * k))
    d.line(pts, fill=trunk, width=int(6 * scale))
    d.line([(px + 2, py) for px, py in pts], fill=trunk_l, width=1)
    for i in range(1, 12, 2):                                            # trunk rings
        px, py = pts[i]
        d.line((px - 3 * scale, py, px + 3 * scale, py + 1), fill=(24, 40, 44, 255))
    tx, ty = pts[-1]
    frond_dark, frond_mid, frond_lit = (6, 26, 28, 255), (12, 48, 48, 255), (40, 96, 84, 255)
    for k in range(8):
        base = -math.pi + k * (math.pi / 7.0)
        sway = math.sin(t * 1.1 + phase + k * 0.7) * 0.08
        ang = base + sway
        ln = 46 * scale * (0.8 + 0.2 * math.sin(k * 1.9))
        # each frond is a leaf-shaped polygon that droops at the tip
        spine = []
        for j in range(0, 9):
            u = j / 8
            fx = tx + math.cos(ang) * ln * u
            fy = ty + math.sin(ang) * ln * u + (u ** 2) * 22 * scale
            spine.append((fx, fy))
        left = [(px_, py_ - (6 * scale) * math.sin(math.pi * (i_ / 8)) ) for i_, (px_, py_) in enumerate(spine)]
        right = [(px_, py_ + (4 * scale) * math.sin(math.pi * (i_ / 8)) ) for i_, (px_, py_) in enumerate(spine)]
        d.polygon(left + right[::-1], fill=frond_mid if k % 2 else frond_dark)
        d.line(spine, fill=frond_lit if (k % 3 == 0) else frond_dark, width=1)
        for j in range(1, 8):                                            # leaflets
            px_, py_ = spine[j]
            d.line((px_, py_, px_ + 2, py_ + 5 * scale), fill=frond_dark)
    d.ellipse((tx - 3, ty - 2, tx + 3, ty + 4), fill=(30, 22, 20, 255))  # coconuts


def bushes(layer, t):
    d = ImageDraw.Draw(layer)
    r = random.Random(8)
    for x0, x1, y in ((0, 90, 262), (370, 480, 262), (190, 330, 270)):
        x = x0
        while x < x1:
            rad = r.randint(8, 16)
            sway = math.sin(t * 1.3 + x * 0.1) * 1.2
            d.ellipse((x - rad + sway, y - rad * 1.6, x + rad + sway, y + 6), fill=(6, 24, 28, 255))
            d.ellipse((x - rad + 3 + sway, y - rad * 1.6 + 1, x + rad - 4 + sway, y - rad * 0.6), fill=(12, 46, 46, 255))
            for _ in range(3):
                d.point((x + r.randint(-rad, rad) + sway, y - r.randint(int(rad * 0.4), int(rad * 1.5))), fill=(46, 100, 86, 255))
            x += r.randint(8, 14)


def vegetation(img, t):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    palm(layer, 36, 230, 190, -18, t, 0.0, 1.1)
    palm(layer, 452, 236, 150, 14, t, 2.0, 0.9)
    palm(layer, 408, 214, 110, 8, t, 4.0, 0.7)
    bushes(layer, t)
    return draw_to(img, layer)



# ---------------------------------------------------------------- Nico lying on his back (drawn by hand, no backpack)
OUT = (6, 0, 0, 255)
BLUE, BLUE_L, BLUE_D = (11, 126, 212, 255), (58, 160, 240, 255), (14, 88, 153, 255)
CUFF = (120, 150, 190, 255)
PANT, PANT_L = (22, 27, 52, 255), (40, 60, 98, 255)
BOOT, BOOT_D, BOOT_L = (114, 63, 36, 255), (72, 36, 19, 255), (150, 92, 54, 255)
SCARF, SCARF_D, SCARF_L = (163, 52, 56, 255), (112, 47, 46, 255), (200, 84, 80, 255)
BELT, GOLD = (72, 36, 19, 255), (217, 180, 106, 255)
SKIN = (229, 174, 138, 255)
SKIN_D = (183, 136, 108, 255)
GROUND = 28           # row where Nico touches the sand in his own canvas
PIVOT = (53, 20)      # the hips: the torso swings around this point when he sits up


def _thick(d, a, b, w, fill):
    d.line((a, b), fill=fill, width=w)
    for p in (a, b):
        d.ellipse((p[0] - w // 2, p[1] - w // 2, p[0] + w // 2, p[1] + w // 2), fill=fill)


def _limb(d, pts, w, fill, light=None):
    for a, b in zip(pts, pts[1:]):
        _thick(d, a, b, w + 2, OUT)
    for a, b in zip(pts, pts[1:]):
        _thick(d, a, b, w, fill)
    if light:
        for a, b in zip(pts, pts[1:]):
            d.line(((a[0], a[1] - w // 2 + 1), (b[0], b[1] - w // 2 + 1)), fill=light, width=1)


def _head_parts():
    """The head of the reference sprite, turned to look up at the sky. Returns (image, eye positions)."""
    src = Image.open(NICO_SRC).convert("RGBA")
    box = (20, 0, 48, 26)
    head = src.crop(box).rotate(90, expand=True, resample=Image.NEAREST)   # counter-clockwise: face up
    cw = box[2] - box[0]
    px = np.array(src)
    eyes = []
    for y in range(17, 22):
        for x in range(33, 43):
            r_, g_, b_, a_ = (int(v) for v in px[y, x])
            if a_ and (r_ + g_ + b_ < 60 or (r_ > 235 and g_ > 235 and b_ > 235)):
                eyes.append((x, y))
    mapped = [((y - box[1]), (cw - 1) - (x - box[0])) for x, y in eyes]      # (x', y') in the rotated head
    return head, mapped


HEAD_IMG, HEAD_EYES = _head_parts()


def _upper(t, openness, breath, wind, turn, resting_arm=True):
    """Head, scarf, jacket and the resting arm, on a 120x60 canvas."""
    up = Image.new("RGBA", (120, 60), (0, 0, 0, 0))
    d = ImageDraw.Draw(up)
    # torso (jacket) lying along the sand, a little rounded at the shoulder
    ty = -breath
    d.polygon([(30, 14 + ty), (36, 11 + ty), (50, 12 + ty), (54, 14), (54, GROUND), (30, GROUND)], fill=OUT)
    d.polygon([(31, 15 + ty), (36, 12 + ty), (50, 13 + ty), (53, 15), (53, GROUND - 1), (31, GROUND - 1)], fill=BLUE)
    d.rectangle((32, 14 + ty, 52, 15 + ty), fill=BLUE_L)
    d.rectangle((31, 24, 53, GROUND - 1), fill=BLUE_D)
    for x in range(34, 52, 5):                                       # creases of the wet jacket
        d.line((x, 17 + ty, x - 2, 23), fill=BLUE_D)
    d.line((34, 16 + ty, 46, 26), fill=BELT)                         # strap across the chest
    # belt and compass at the hip
    d.rectangle((50, 13 + ty, 53, GROUND - 1), fill=BELT)
    d.rectangle((47, 20, 52, 25), fill=OUT)
    d.rectangle((48, 21, 51, 24), fill=GOLD)
    d.point((49, 22), (244, 236, 208, 255))
    # head: sits on the sand with the hair spread; it can turn a little
    hx, hy = 1, GROUND - HEAD_IMG.height + 1 + turn
    head = HEAD_IMG.copy()
    hp = head.load()
    ys = sorted({y for _, y in HEAD_EYES})
    xs = sorted({x for x, _ in HEAD_EYES})
    for ex, ey in HEAD_EYES:
        edge = (ex == xs[0]) if True else False             # the lowest eye row of the original is the first column here
        shut = openness < 0.35
        half = 0.35 <= openness < 0.75
        if shut or (half and not edge):
            hp[ex, ey] = SKIN_D if (edge and shut) else SKIN
    up.alpha_composite(head, (hx, hy))
    # scarf around the neck and its loose end, stirred by the wind
    d = ImageDraw.Draw(up)
    d.polygon([(25, 9 + turn), (35, 8 + turn), (36, GROUND), (26, GROUND - 1)], fill=OUT)
    d.polygon([(26, 10 + turn), (34, 9 + turn), (35, GROUND - 1), (27, GROUND - 2)], fill=SCARF)
    d.line((34, 10 + turn, 34, GROUND - 2), fill=SCARF_L)
    d.line((27, 12 + turn, 27, GROUND - 3), fill=SCARF_D)
    tail = [(34, 24), (42, 26 + wind * 0.4), (52, 27 + wind * 0.8), (60, 26 + wind)]
    _limb(d, tail, 3, SCARF, SCARF_L)
    d.line([(x, y + 1) for x, y in tail], fill=SCARF_D)
    # the arm resting on the sand, hand open
    if resting_arm:
        _limb(d, [(36, 18 + ty), (46, 24), (60, 26)], 5, BLUE, BLUE_L)
        d.rectangle((58, 24, 60, 28), fill=CUFF, outline=OUT)
        d.rectangle((61, 24, 66, 28), fill=SKIN, outline=OUT)
        d.line((62, 25, 65, 25), fill=SKIN_D)
    return up


def _legs():
    """Trousers and boots: one leg straight, the other knee up, feet falling outward."""
    lg = Image.new("RGBA", (120, 60), (0, 0, 0, 0))
    d = ImageDraw.Draw(lg)
    _limb(d, [(52, 24), (66, 25), (77, 25)], 8, PANT, PANT_L)         # far leg, straight
    d.polygon([(75, 29), (87, 29), (89, 24), (87, 19), (81, 18), (76, 20)], fill=OUT)
    d.polygon([(76, 28), (86, 28), (88, 24), (86, 20), (81, 19), (77, 21)], fill=BOOT)
    d.line((77, 27, 86, 27), fill=BOOT_D)
    d.line((79, 20, 85, 21), fill=BOOT_L)
    _limb(d, [(52, 20), (61, 8), (71, 15)], 8, PANT, PANT_L)          # near leg, knee raised
    d.line((59, 10, 64, 10), fill=PANT_L)
    d.polygon([(69, 21), (79, 21), (81, 17), (79, 11), (73, 10), (69, 13)], fill=OUT)   # boot, sole toward the sky
    d.polygon([(70, 20), (78, 20), (79, 17), (78, 12), (73, 11), (70, 14)], fill=BOOT)
    d.line((71, 19, 78, 19), fill=BOOT_D)
    d.line((72, 12, 77, 13), fill=BOOT_L)
    return lg


TOP = 34   # empty rows above Nico's canvas, so the head never leaves it while he sits up


def nico_image(t):
    """Eyes shut -> opening -> one slow blink -> a small head turn -> he props himself up on one hand."""
    if t < 2.6:
        openness = 0.0
    elif t < 3.3:
        openness = (t - 2.6) / 0.7
    elif 4.1 < t < 4.5:
        openness = abs(math.cos((t - 4.1) / 0.4 * math.pi))
    else:
        openness = 1.0
    breath = 1 if math.sin(t * 2.2) > 0.2 else 0
    wind = math.sin(t * 2.6) * 1.6
    turn = -1 if t > 4.6 else 0
    rise = 0.0
    if t > 5.3:
        rise = min(1.0, (t - 5.3) / 1.8)
        rise = rise * rise * (3 - 2 * rise)
    up_small = _upper(t, openness, breath, wind, turn, resting_arm=rise < 0.12)
    up = Image.new("RGBA", (120, 60 + TOP), (0, 0, 0, 0))
    up.paste(up_small, (0, TOP))
    center = (PIVOT[0], PIVOT[1] + TOP)
    angle = -26 * rise
    if rise:
        up = up.rotate(angle, center=center, resample=Image.NEAREST)
    out = Image.new("RGBA", (120, 60 + TOP), (0, 0, 0, 0))
    legs = Image.new("RGBA", (120, 60 + TOP), (0, 0, 0, 0))
    legs.paste(_legs(), (0, TOP))
    out.alpha_composite(legs)
    out.alpha_composite(up)
    if rise >= 0.12:
        # the hand that was resting now pushes against the sand under the shoulder
        phi = math.radians(angle)           # PIL turns counter-clockwise for positive angles
        dx, dy = 36 - center[0], 18 + TOP - center[1]
        sx = center[0] + dx * math.cos(phi) + dy * math.sin(phi)
        sy = center[1] - dx * math.sin(phi) + dy * math.cos(phi)
        d = ImageDraw.Draw(out)
        ground = GROUND + TOP - 1
        hx = sx + 5 + 4 * rise
        _limb(d, [(sx, sy), ((sx + hx) / 2, (sy + ground) / 2 - 1), (hx, ground - 3)], 5, BLUE, BLUE_L)
        d.rectangle((hx - 3, ground - 3, hx + 3, ground), fill=SKIN, outline=OUT)
        d.line((hx - 2, ground - 2, hx + 2, ground - 2), fill=SKIN_D)
    return out


# ---------------------------------------------------------------- effects
def fog(img, t):
    off = int(t * 4) % CLOUD_W
    cols = (np.arange(W) + off) % CLOUD_W
    n = FOG_TEX[:, cols]
    for y in range(176, 232):
        k = y - 176
        strength = math.sin(k / 56 * math.pi) * 0.55
        a = np.clip((n[min(k // 2, 39)] - 0.38) * 2.0, 0, 1) * strength
        sel = a > DITHER[y]
        img[y][sel] = img[y][sel] * 0.6 + c("#4a5896") * 0.4
    return img


def sky_clouds(img, t):
    off = int(t * 4) % CLOUD_W
    cols = (np.arange(W) + off) % CLOUD_W
    n = CLOUDS[np.ix_(np.clip(np.arange(H), 0, 139), cols)]
    fade = np.clip(1 - (YY - 30) / 90.0, 0, 1)
    v = n * (0.5 + 0.7 * fade)
    mask = v > 0.5
    body = v > 0.58
    img[mask] = CLOUD_DARK
    img[body] = CLOUD_MID
    above = np.roll(mask, 1, axis=0)
    top = mask & ~above
    img[top] = CLOUD_RIM
    img[np.roll(top, 1, axis=0) & mask & (DITHER > 0.5)] = c("#2a3a96")
    # one dedicated bank passes over the moon: half covered at first, then drifting off to the left
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cx = 404 - t * 5.0
    for dx, dy, rx, ry in ((0, 6, 30, 9), (-16, 0, 20, 8), (14, -4, 18, 8), (-4, -6, 14, 6)):
        d.ellipse((cx + dx - rx, 50 + dy - ry, cx + dx + rx, 50 + dy + ry), fill=(16, 26, 104, 255))
    for dx, dy, rx, ry in ((-2, 3, 22, 4), (-18, -2, 12, 3)):
        d.ellipse((cx + dx - rx, 47 + dy - ry, cx + dx + rx, 47 + dy + ry), fill=(30, 46, 140, 255))
    d.arc((cx - 24, 38, cx + 28, 56), 200, 340, fill=(110, 134, 220, 255))
    img = draw_to(img, layer)
    return img


def rain_residual(img, t, store={}):
    if "d" not in store:
        r = random.Random(3)
        store["d"] = [(r.uniform(0, W), r.uniform(0, H), r.uniform(0.6, 1.0)) for _ in range(34)]
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for x0, y0, k in store["d"]:
        y = (y0 + t * 70 * k) % (H + 20) - 10
        x = (x0 - t * 12 * k) % W
        d.line([(x, y), (x - 1, y - 5)], fill=(150, 168, 230, 110), width=1)
    return draw_to(img, layer)


def sand_dust(img, t, store={}):
    if "d" not in store:
        r = random.Random(14)
        store["d"] = [(r.uniform(0, W), r.uniform(205, 268), r.uniform(0.5, 1.0)) for _ in range(30)]
    for x0, y0, k in store["d"]:
        x = (x0 + t * 22 * k) % W
        y = y0 + math.sin(t * 2 + x0) * 2 - (t * 3 * k) % 6
        xi, yi = int(x), int(y)
        if 0 <= xi < W and 0 <= yi < H:
            img[yi, xi] = c("#c0aa98")
    return img


def vignette(img):
    dx = (XX - W / 2) / (W / 2)
    dy = (YY - H / 2) / (H / 2)
    v = np.clip(dx * dx + dy * dy - 0.5, 0, 1)
    m = v * 0.6 > DITHER
    img[m] = img[m] * 0.72
    return img


BACKDROP = None


def render_world(t):
    global BACKDROP
    if BACKDROP is None:
        BACKDROP = make_backdrop()
    img = BACKDROP.copy()
    img = sky_clouds(img, t)
    img = forest_silhouette(img)
    img = far_ocean(img, t)
    img = wreck_far(img, t)
    img = floating_wood(img, t)
    img, edge = beach(img, t)
    img = shore_debris(img, t, edge)
    img = sand_details(img, t)
    img = wood_pieces(img, t)
    # Nico, with a soft shadow on the sand
    nico = nico_image(t)
    nb = (0, 0, 120, 60)
    nx, ny = 176, 238 - GROUND - 1 - TOP
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse((nx - 2, 232, nx + 100, 244), fill=(16, 12, 28, 200))
    img = draw_to(img, shadow)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    layer.alpha_composite(nico, (nx, ny))
    # the scarf's loose end stirs in the wind: nudge its pixels up and down
    img = draw_to(img, layer)
    img = vegetation(img, t)
    img = fog(img, t)
    img = rain_residual(img, t)
    img = sand_dust(img, t)
    return np.clip(img, 0, 255).astype(np.uint8), (nx, ny, nb)


def smooth(a, b, k):
    k = min(1.0, max(0.0, k))
    k = k * k * (3 - 2 * k)
    return a + (b - a) * k


def camera(frame, t, nico_box):
    """Wide beach -> slow push-in on Nico -> down to his hands; then a brief hold."""
    nx, ny, nb = nico_box
    head = (nx + 16, ny + TOP + 14)
    hands = (nx + 56, ny + TOP + 24)
    if t < 1.0:
        z, cx, cy = 1.0, W / 2, H / 2
    elif t < 7.5:
        k = (t - 1.0) / 6.5
        z = smooth(1.0, 2.5, k)
        cx = smooth(W / 2, head[0], k)
        cy = smooth(H / 2, head[1], k)
    else:
        k = (t - 7.5) / 2.0
        z, cx = 2.5, smooth(head[0], hands[0], k)
        cy = smooth(head[1], hands[1] + 8, k)
    # a faint sway of the camera
    cy += math.sin(t * 0.9) * 0.6
    w, h = W / z, H / z
    cx = min(max(cx, w / 2), W - w / 2)
    cy = min(max(cy, h / 2), H - h / 2)
    box = (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)
    return Image.fromarray(frame).resize((W, H), Image.NEAREST, box=box)


def main():
    frames = []
    for i in range(FRAMES):
        t = i / FPS
        world, box = render_world(t)
        frame = np.array(camera(world, t, box))
        frame = vignette(frame.astype(np.float32))
        frames.append(Image.fromarray(np.clip(frame, 0, 255).astype(np.uint8)))
        if i % 40 == 0:
            print("frame", i, "of", FRAMES)
    frames[0].save(os.path.join(OUT, "scene2_wake.gif"), save_all=True, append_images=frames[1:], duration=1000 // FPS, loop=0)
    sheet = Image.new("RGB", (W * 2, H * 3))
    for k, tt in enumerate((0.0, 3.0, 4.3, 6.0, 7.4, 9.5)):
        sheet.paste(frames[min(int(tt * FPS), FRAMES - 1)], ((k % 2) * W, (k // 2) * H))
    sheet.resize((W * 3, H * 4 + 270), Image.NEAREST).save(os.path.join(OUT, "scene2_sheet.png"))
    world, _ = render_world(0.0)
    Image.fromarray(world).resize((W * 3, H * 3), Image.NEAREST).save(os.path.join(OUT, "scene2_wide.png"))
    print("ok")


if __name__ == "__main__":
    main()
