"""Preview of the Ruinas' new look (design proposal, nothing in the game uses it yet). Run from the project root:
    python tools/make_ruins_v2_preview.py [out_dir]
Writes, outside the repo by default (~/Documents/capturas-mapas/ruinas_v2/):
  pilares.png         carved pillars in six styles and three sizes, next to the one we have
  piso.png            the floor we have against two new floors with bigger, more structured slabs
  sala.png            a room as an island of the new floor over deep water, with cliffs and bridges
Same palette as the pillar we have (the previews_columnas pilar_mediano): outline, three blues, light, moss."""
import math
import os
import random
import sys

import time

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

_save_png = Image.Image.save


def _retrying_save(self, fp, *args, **kwargs):
    """Windows can hold a picture open for a moment (the folder's preview pane): try again a few times."""
    for attempt in range(8):
        try:
            return _save_png(self, fp, *args, **kwargs)
        except OSError:
            time.sleep(0.6)
    return _save_png(self, fp, *args, **kwargs)


Image.Image.save = _retrying_save

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
OUT = ARGS[0] if ARGS else os.path.join(os.path.expanduser("~"), "Documents", "capturas-mapas", "ruinas_v2")
REF_PILLAR = os.path.join(os.path.expanduser("~"), "Documents", "previews_columnas", "v2", "pilar_mediano.png")


def C(h, a=255):
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), a)


# --- pillar palette: measured from the pillar we have ------------------------------------------------------
OUTLINE = C("#090a1c")
S2, S1 = C("#262b62"), C("#343b78")
M0, M, M2 = C("#475496"), C("#4d5aa0"), C("#53609f")
L, HI = C("#6f7fc0"), C("#95a4de")
MOSS_D, MOSS, MOSS_L = C("#1c5a4c"), C("#2e9460"), C("#5bd08a")
RUNE_D, RUNE, RUNE_L = C("#2f8fe0"), C("#5cc8ff"), C("#d8f6ff")

# --- floor / cliff / water palette: the game's own (tools/make_ruins_tileset_art.py), floor calmer ----------
FLOOR_JOINT = C("#2a3049")
FLOOR_TONES = (C("#454b6a"), C("#495070"), C("#4d5474"))
FLOOR_HI = C("#5a6286")
ROCK_D, ROCK_1, ROCK_2, ROCK_3, ROCK_4, ROCK_HI = (C("#131a30"), C("#212a44"), C("#2c3a53"), C("#3a4666"),
                                                    C("#4e557a"), C("#7a82a6"))
WOOD_D, WOOD_1, WOOD_2, WOOD_HI = C("#4a2a14"), C("#6e4020"), C("#9a5c2a"), C("#c88442")
CLEAR = (0, 0, 0, 0)


def shade(c, f):
    return (max(0, min(255, int(c[0] * f))), max(0, min(255, int(c[1] * f))), max(0, min(255, int(c[2] * f))), c[3])


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


class Cv:
    """A pixel canvas with the few drawing helpers pixel art needs."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), CLEAR)
        self.px = self.img.load()

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = c

    def at(self, x, y):
        return self.px[x, y] if 0 <= x < self.w and 0 <= y < self.h else CLEAR

    def solid(self, x, y):
        return self.at(x, y)[3] > 0

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def line_v(self, x, y0, y1, c):
        for y in range(y0, y1 + 1):
            self.put(x, y, c)

    def outline(self, color=OUTLINE):
        """A 1 px line around the opaque pixels; the canvas grows by one pixel on every side to hold it."""
        grown = Image.new("RGBA", (self.w + 2, self.h + 2), CLEAR)
        grown.alpha_composite(self.img, (1, 1))
        src = grown.copy().load()
        out = grown.load()
        for y in range(grown.height):
            for x in range(grown.width):
                if src[x, y][3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < grown.width and 0 <= ny < grown.height and src[nx, ny][3] > 0:
                            out[x, y] = color
                            break
        self.img, self.px, self.w, self.h = grown, out, grown.width, grown.height
        return self


# =====================================================================================================================
# PILLARS
# =====================================================================================================================
SIZES = {  # width, height, abacus height, plinth height
    "s": (22, 42, 7, 5),
    "m": (30, 56, 9, 6),
    "l": (36, 70, 11, 7),
}
STYLES = ("bloques", "acanalado", "friso", "medallon", "roto", "hiedra")


def _blocks(cv, x0, x1, y0, y1, course_h, block_w, rng, rows_light=True):
    """Courses of cut stone: each block lit on its top edge, a dark joint under and to the right."""
    y, row = y0, 0
    while y <= y1:
        h = min(course_h, y1 - y + 1)
        off = 0 if row % 2 == 0 else block_w // 2
        x = x0 - off
        while x <= x1:
            bw = block_w + rng.choice((-1, 0, 0, 1))
            tone = rng.choice((M, M, M2, M0))
            for yy in range(y, y + h):
                for xx in range(x, x + bw):
                    if not (x0 <= xx <= x1):
                        continue
                    c = tone
                    if yy == y + h - 1 or xx == x + bw - 1:
                        c = S1
                    elif yy == y:
                        c = mix(tone, L, 0.45)
                    cv.put(xx, yy, c)
            x += bw
        y += h
        row += 1


def _cylinder(cv, x0, x1, y0, y1):
    """Round the shaft: light on the left, shade on the right (over whatever is drawn)."""
    n = x1 - x0 + 1
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            t = (x - x0) / max(1, n - 1)
            c = cv.at(x, y)
            if c[3] == 0:
                continue
            if t < 0.12:
                c = mix(c, HI, 0.30)
            elif t > 0.84:
                c = shade(c, 0.74)
            elif t > 0.70:
                c = shade(c, 0.88)
            cv.put(x, y, c)


def _crack(cv, rng, x, y, length, x0, x1):
    for _ in range(length):
        if x0 <= x <= x1:
            cv.put(x, y, S2)
        x += rng.choice((-1, 0, 0, 1))
        y += 1
        if rng.random() < 0.25 and x0 <= x + 1 <= x1:
            cv.put(x + 1, y, S2)


def _moss(cv, x, y, big=False):
    cv.put(x, y, MOSS)
    cv.put(x + 1, y, MOSS_D)
    cv.put(x, y + 1, MOSS_D)
    if big:
        cv.put(x - 1, y, MOSS_D)
        cv.put(x, y - 1, MOSS_L)
        cv.put(x + 1, y + 1, MOSS)


def _vine(cv, rng, x, y0, length, x0, x1):
    for i in range(length):
        c = MOSS if i % 3 else MOSS_D
        if cv.at(x, y0 + i)[3] == 0 and i > 2:
            break
        cv.put(x, y0 + i, c)
        if i % 4 == 3:
            cv.put(x + rng.choice((-1, 1)), y0 + i, MOSS_L)
        if rng.random() < 0.15:
            x = max(x0, min(x1, x + rng.choice((-1, 1))))


def _pillar(style, size="m", seed=1):
    W, H, ah, ph = SIZES[size]
    rng = random.Random(seed * 131 + len(style))
    extra = 14 if style == "roto" else 0
    cv = Cv(W + extra, H)
    sw = W - 8                                  # the shaft
    x0, x1 = (W - sw) // 2, (W - sw) // 2 + sw - 1
    th = 3                                      # torus under the shaft
    ys, ye = ah + 4, H - ph - th - 1            # the shaft's first and last row
    broken = style == "roto"
    top = ys + (int((ye - ys) * 0.36) if broken else 0)

    # --- capital: abacus (a slab with a seam), echinus, neck -------------------------------------------------
    if not broken:
        for y in range(ah):
            inset = 2 if y == 0 else (1 if y == 1 else 0)
            for x in range(inset, W - inset):
                c = M
                if y == 0:
                    c = L
                elif y == 1:
                    c = mix(M, L, 0.55)
                elif y == ah - 1:
                    c = S1
                elif y == ah - 2:
                    c = M0
                if x == inset:
                    c = mix(c, HI, 0.35)
                if x >= W - inset - 2:
                    c = shade(c, 0.82)
                cv.put(x, y, c)
        seam = int(W * 0.62)
        cv.line_v(seam, 2, ah - 2, S1)
        if style == "friso":                    # a second seam and carved corner marks
            cv.line_v(int(W * 0.25), 3, ah - 2, S1)
            for cx in (2, W - 3):
                cv.put(cx, 3, S1)
                cv.put(cx, 4, S2)
        for i in range(3):                      # echinus
            inset = 2 + i
            for x in range(inset, W - inset):
                c = M0 if i < 2 else S1
                if i == 0:
                    c = mix(M0, L, 0.35)
                if x == inset:
                    c = mix(c, HI, 0.3)
                cv.put(x, ah + i, c)
            if style in ("friso", "medallon") and i == 1:      # egg-and-dart ticks
                for x in range(inset + 1, W - inset - 1, 3):
                    cv.put(x, ah + i, S1)
        for x in range(x0 - 1, x1 + 2):         # neck
            cv.put(x, ah + 3, L if x < x1 else M0)

    # --- shaft -----------------------------------------------------------------------------------------------
    if style == "acanalado":
        for y in range(ys, ye + 1):
            for x in range(x0, x1 + 1):
                k = (x - x0) % 4
                c = (L, M2, M, S1)[k] if k != 3 else S1
                if k == 0:
                    c = mix(M2, L, 0.6)
                cv.put(x, y, c)
        for x in range(x0, x1 + 1):             # flutes end in a small arch under the neck and above the foot
            if (x - x0) % 4 in (1, 2):
                cv.put(x, ys, M0)
                cv.put(x, ye, M0)
        _cylinder(cv, x0, x1, ys, ye)
        for y in (ys + 2, ye - 2):              # two thin rings
            for x in range(x0, x1 + 1):
                cv.put(x, y, mix(cv.at(x, y), HI, 0.25))
    else:
        course = 8 if size != "s" else 7
        _blocks(cv, x0, x1, top, ye, course, 11 if size != "s" else 9, rng)
        _cylinder(cv, x0, x1, top, ye)
        # a thin stone ring where the column is split in two drums (large) or at the third (others)
        ring = ys + (ye - ys) // 2 if size == "l" else ys + int((ye - ys) * 0.38)
        if style in ("bloques", "hiedra", "medallon", "friso") and not broken:
            for y in (ring, ring + 1):
                for x in range(x0 - 1, x1 + 2):
                    cv.put(x, y, L if y == ring else S1)
            for x in range(x0 - 1, x1 + 2):
                cv.put(x, ring - 1, M0)

    if style == "friso":                        # a band of carved key pattern, with a faint blue glow in the grooves
        by = ys + int((ye - ys) * 0.58)
        key = ("XXXXX.",
               "X...X.",
               "X.X.X.",
               "X.XXX.",
               "X.....")
        for y in range(by, by + 7):
            for x in range(x0, x1 + 1):
                cv.put(x, y, S1 if y not in (by, by + 6) else S2)
        for x in range(x0 + 1, x1, 6):
            for ky, row in enumerate(key):
                for kx, ch in enumerate(row):
                    if ch == "X" and x + kx <= x1 - 1:
                        cv.put(x + kx, by + 1 + ky, RUNE_D if (kx + ky) % 4 else RUNE)
    if style == "medallon":                     # a round carved emblem with a spark of blue in the middle
        cx, cy, r = (x0 + x1) // 2, ys + int((ye - ys) * 0.30), 5 if size != "s" else 4
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r, cx + r + 1):
                d = math.hypot(x - cx, y - cy)
                if d <= r:
                    cv.put(x, y, L if d > r - 1 else (S2 if d > r - 2.2 else S1))
        cv.put(cx, cy, RUNE_L)
        for dx, dy in ((0, -2), (0, 2), (-2, 0), (2, 0)):
            cv.put(cx + dx, cy + dy, RUNE)
        for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
            cv.put(cx + dx, cy + dy, RUNE_D)

    # --- the foot: torus and plinth ----------------------------------------------------------------------------
    for i in range(th):
        inset = 3 - i if i else 3
        inset = 2 if i == 0 else 1 if i == 1 else 2
        for x in range(x0 - inset, x1 + inset + 1):
            c = (L if i == 0 else M if i == 1 else S1)
            if x == x0 - inset:
                c = mix(c, HI, 0.3)
            cv.put(x, ye + 1 + i, c)
    for y in range(H - ph, H):
        inset = 1 if y == H - 1 else 0
        for x in range(inset, W - inset):
            c = M
            if y == H - ph:
                c = HI if x < W // 2 else L
            elif y == H - ph + 1:
                c = L
            elif y == H - 1:
                c = S2
            elif y == H - 2:
                c = S1
            if x == inset:
                c = mix(c, HI, 0.3)
            if x >= W - inset - 3:
                c = shade(c, 0.78)
            cv.put(x, y, c)
    seam = int(W * 0.34)
    cv.line_v(seam, H - ph + 2, H - 3, S1)

    # --- wear: cracks everywhere, moss and vines by style ---------------------------------------------------
    for _ in range(2 if size != "s" else 1):
        _crack(cv, rng, rng.randrange(x0 + 3, x1 - 2), top + rng.randrange(1, 6), rng.randrange(6, 12), x0, x1)
    if style in ("hiedra", "bloques", "acanalado"):
        _moss(cv, 3, H - ph - 1 if style != "hiedra" else H - ph - 1, big=True)
        _moss(cv, W - 6, 2)
    if style == "hiedra":
        _moss(cv, 4, 2, big=True)
        _moss(cv, W - 8, H - ph - 2, big=True)
        for x in (x0 + 1, x0 + 6, x1 - 3, x1 - 1):
            _vine(cv, rng, x, ah + 3, rng.randrange(14, 30 if size != "s" else 22), x0, x1)
        for dx in (-2, 0, 2):                   # a few blue crystals sprout at the foot
            hgt = 6 - abs(dx)
            for yy in range(hgt):
                cv.put(W - 5 + dx, H - ph - 1 - yy, RUNE_D if yy < hgt - 1 else RUNE_L)
                cv.put(W - 5 + dx + 1, H - ph - 1 - yy, RUNE if yy else RUNE_L)
    if style in ("medallon", "friso"):
        _moss(cv, 3, H - ph - 1)

    # --- a snapped column: jagged top, bright break, the fallen drum and rubble ---------------------------
    if broken:
        for x in range(x0, x1 + 1):
            cut = top + rng.choice((-2, -1, 0, 0, 1, 2)) + (2 if x > x0 + sw // 2 else 0)
            for y in range(ys, cut):
                cv.put(x, y, CLEAR)
            if cv.solid(x, cut):
                cv.put(x, cut, HI)
            if cv.solid(x, cut + 1):
                cv.put(x, cut + 1, L)
            if cv.solid(x, cut + 2) and rng.random() < 0.5:
                cv.put(x, cut + 2, M2)
        # the fallen drum, lying to the right of the plinth
        dx0, dy0 = W + 1, H - 14
        for y in range(dy0, dy0 + 11):
            for x in range(dx0, dx0 + 12):
                t = (y - dy0) / 10.0
                c = L if t < 0.2 else (M if t < 0.65 else (S1 if t < 0.9 else S2))
                if x in (dx0, dx0 + 11) and y in (dy0, dy0 + 10):
                    continue
                cv.put(x, y, c)
        for x in range(dx0 + 3, dx0 + 12, 4):
            cv.line_v(x, dy0 + 1, dy0 + 9, S1)
        for sx, sy in ((W - 3, H - 3), (W + 12, H - 2), (W + 8, H - 15), (W + 2, H - 3)):
            cv.rect(sx, sy, sx + 2, sy + 1, M2)
            cv.put(sx, sy, L)
        _moss(cv, W + 3, dy0 - 1)
        _moss(cv, x0 + 2, top + 8)

    # --- the capital's top gets a few leaves of moss (as on the pillar we have) ----------------------------------
    if not broken:
        _moss(cv, int(W * 0.4), 2)
    return cv.outline().img


PILLAR_DARK = 0.68


def pillar(style, size="m", seed=1):
    """The pillar of the proposal: the drawing of _pillar with the stone darker and a little less bright."""
    img = _pillar(style, size, seed)
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = px[x, y]
            if a == 0 or g > b or (g >= 143 and b >= 225):
                continue                          # moss and the blue runes keep their color
            f = PILLAR_DARK
            px[x, y] = (int(r * f), int(g * f), int(b * (f + 0.04)), a)
    return img


def sheet_pillars(path):
    cols = ["medallon", "roto"]
    rows = ("s", "m")
    pad, label_h = 14, 16
    cell_w = 36 + 14 + 8
    cell_h = 70
    ref = Image.open(REF_PILLAR).convert("RGBA") if os.path.exists(REF_PILLAR) else None
    W = pad + (len(cols) + 1) * (cell_w + pad)
    H = pad + label_h + len(rows) * (cell_h + pad)
    img = Image.new("RGBA", (W, H), C("#1a1d33"))
    d = ImageDraw.Draw(img)
    names = ["actual"] + cols
    for i, name in enumerate(names):
        d.text((pad + i * (cell_w + pad), 4), name, fill=H_COL)
    for r, size in enumerate(rows):
        base_y = pad + label_h + r * (cell_h + pad) + cell_h
        if ref is not None and size == "m":
            img.alpha_composite(ref, (pad, base_y - ref.height))
        for i, style in enumerate(cols):
            sp = pillar(style, size, seed=3 + i)
            img.alpha_composite(sp, (pad + (i + 1) * (cell_w + pad), base_y - sp.height))
    img = img.resize((img.width * 5, img.height * 5), Image.NEAREST)
    img.save(path)


H_COL = (200, 210, 235, 255)


# =====================================================================================================================
# FLOOR
# =====================================================================================================================
def floor_bond(seed, wear=0, tone=None):
    """Slabs of 16x8 in two rows offset by half: twice the old 8x8 slabs, lit on the top and left edge, one joint."""
    rng = random.Random(seed)
    cv = Cv(16, 16)
    tones = [rng.choice(FLOOR_TONES) if tone is None else tone for _ in range(4)]
    for row in range(2):
        off = 0 if row == 0 else 8
        for k in range(2):                      # the offset row's slab wraps around the tile: two pieces of one slab
            base = tones[row * 2 + k if row else 0]
        slab_tone = tones[row]
        for y in range(8):
            for x in range(16):
                px, py = x, row * 8 + y
                sx = (px - off) % 16            # x inside its slab
                c = slab_tone
                if y == 7 or sx == 15:
                    c = FLOOR_JOINT
                elif y == 0 or sx == 0:
                    c = mix(slab_tone, FLOOR_HI, 0.5)
                elif (px * 7 + py * 13 + seed) % 29 == 0:
                    c = shade(slab_tone, 0.94)  # a very faint speck, not a texture
                cv.put(px, py, c)
    if wear == 1:                               # a hairline crack across one slab
        x, y = rng.randrange(3, 12), 1
        for _ in range(6):
            cv.put(x, y, shade(FLOOR_JOINT, 1.1))
            x = max(1, min(14, x + rng.choice((-1, 0, 1))))
            y += 1
    elif wear == 2:                             # a chipped corner
        for dx, dy in ((14, 0), (15, 0), (15, 1), (14, 6), (15, 6)):
            cv.put(dx, dy, FLOOR_JOINT)
    elif wear == 3:                             # moss in the joint
        for dx, dy in ((2, 7), (3, 7), (3, 6), (4, 7), (10, 15), (11, 15), (11, 14)):
            cv.put(dx, dy, MOSS_D if dy % 2 else MOSS)
    return cv.img


def floor_flag(seed, wear=0):
    """One flagstone per tile with a beveled edge: the ceremonial floor for the focal part of a room."""
    rng = random.Random(seed)
    cv = Cv(16, 16)
    tone = rng.choice(FLOOR_TONES)
    for y in range(16):
        for x in range(16):
            c = tone
            if y == 15 or x == 15:
                c = FLOOR_JOINT
            elif y == 0 or x == 0:
                c = mix(tone, FLOOR_HI, 0.55)
            elif y == 1 or x == 1:
                c = mix(tone, FLOOR_HI, 0.2)
            elif y == 14 or x == 14:
                c = shade(tone, 0.9)
            cv.put(x, y, c)
    if wear == 1:
        x, y = rng.randrange(4, 11), 2
        for _ in range(9):
            cv.put(x, y, FLOOR_JOINT)
            x = max(2, min(13, x + rng.choice((-1, 0, 1))))
            y += 1
    return cv.img


def floor_patch(kind, tw, th, seed):
    rng = random.Random(seed)
    img = Image.new("RGBA", (tw * 16, th * 16))
    tiles_plain = [floor_bond(s) if kind == "bond" else floor_flag(s) for s in range(100, 104)]
    wears = ([floor_bond(200 + w, wear=w) for w in (1, 2, 3)] if kind == "bond"
             else [floor_flag(200 + w, wear=1) for w in (1, 2, 3)])
    for ty in range(th):
        for tx in range(tw):
            r = rng.random()
            t = rng.choice(tiles_plain) if r < (0.82 if kind == "bond" else 0.95) else rng.choice(wears)
            img.paste(t, (tx * 16, ty * 16))
    return img


def sheet_floor(path):
    old_path = os.path.join(os.path.dirname(OUT), "ruinas", "ruins_river.png")
    tw, th = 16, 11
    patches = []
    labels = ["actual", "A: lajas de 16x8 (recomendado)", "B: losas de 16x16"]
    if os.path.exists(old_path):
        old = Image.open(old_path).convert("RGBA").crop((144, 104, 144 + tw * 16, 104 + th * 16))
        patches.append(old)
    else:
        patches.append(Image.new("RGBA", (tw * 16, th * 16), (60, 60, 80, 255)))
    patches.append(floor_patch("bond", tw, th, 5))
    patches.append(floor_patch("flag", tw, th, 5))
    pad = 12
    W = pad + 3 * (tw * 16 + pad)
    H = pad + 14 + th * 16 + pad
    img = Image.new("RGBA", (W, H), C("#1a1d33"))
    d = ImageDraw.Draw(img)
    for i, p in enumerate(patches):
        x = pad + i * (tw * 16 + pad)
        d.text((x, 3), labels[i], fill=H_COL)
        img.alpha_composite(p, (x, pad + 14))
    img.resize((img.width * 3, img.height * 3), Image.NEAREST).save(path)


# =====================================================================================================================
# ROOM: an island of floor over deep water, with cliffs
# =====================================================================================================================
TILE = 16
ROWS = {2: (8, 21), 3: (6, 23), 4: (5, 24), 5: (4, 25), 6: (4, 25), 7: (3, 26), 8: (3, 26), 9: (3, 26),
        10: (3, 26), 11: (4, 25), 12: (4, 25), 13: (5, 23), 14: (7, 21)}
CW, CH = 30, 19
CLIFF_ROWS = 2


def is_floor(x, y):
    r = ROWS.get(y)
    return r is not None and r[0] <= x <= r[1]


def cliff_face(seed, variant=0):
    """A cliff two tiles tall (16x32) that never repeats: courses of uneven height, blocks of uneven width, some
    that jut out (lit top, a shadow under them on the wall), some sunk in, an overhanging lip, moss, cracks,
    a wet and ragged foot."""
    rng = random.Random(seed)
    cv = Cv(16, 32)
    ramp = (ROCK_4, ROCK_3, ROCK_2, ROCK_1)
    courses, y = [], 0
    while y < 32:
        h = min(rng.choice((6, 7, 8, 9)), 32 - y)
        courses.append((y, h))
        y += h
    jut = []
    for y0, h in courses:
        base = ramp[min(3, y0 * 4 // 32)]
        x = -rng.randrange(0, 8)
        while x < 16:
            bw = rng.choice((6, 8, 10, 12))
            tone = shade(base, rng.uniform(0.90, 1.10))
            sunk = rng.random() < 0.18
            if rng.random() < 0.30 and 3 < y0 and y0 + h < 27:
                jut.append((x, bw, y0, h, base, tone))
            for yy in range(h):
                for xx in range(bw):
                    px, py = x + xx, y0 + yy
                    if not 0 <= px < 16:
                        continue
                    c = tone
                    if yy == h - 1 or xx == bw - 1:
                        c = shade(base, 0.5)
                    elif yy == 0:
                        c = shade(base, 1.25)
                    elif xx == 0:
                        c = shade(base, 1.12)
                    cv.put(px, py, shade(c, 0.74) if sunk else c)
            x += bw
    for x, bw, y0, h, base, tone in jut:         # a shadow under every block that juts out
        for xx in range(bw):
            px = x + xx
            if 0 <= px < 16:
                for k in range(1, 4):
                    cv.put(px, y0 + h - 1 + k, shade(cv.at(px, y0 + h - 1 + k), 0.58 + 0.1 * k))
    for x, bw, y0, h, base, tone in jut:         # then the blocks themselves, a little in front of the wall
        for yy in range(-1, h):
            for xx in range(-1, bw):
                px, py = x + xx, y0 + yy
                if not 0 <= px < 16:
                    continue
                c = shade(tone, 1.16)
                if yy == h - 1 or xx == bw - 1:
                    c = shade(base, 0.45)
                elif yy <= 0:
                    c = shade(base, 1.5)
                elif xx <= 0:
                    c = shade(base, 1.25)
                if yy == -1 and (xx == -1 or xx == bw - 1):
                    continue
                cv.put(px, py, c)
        if rng.random() < 0.7:                   # moss sits on top of some
            for xx in range(1, bw - 1):
                if rng.random() < 0.7:
                    cv.put(x + xx, y0 - 1, rng.choice((MOSS, MOSS_L, MOSS_D)) if 0 <= x + xx < 16 else CLEAR)
    for x in range(16):                          # overhanging lip: bright edge, then a dark band under it
        cv.put(x, 0, mix(ROCK_HI, FLOOR_HI, 0.5))
        cv.put(x, 1, shade(ROCK_4, 1.05))
        for k in (2, 3):
            cv.put(x, k, shade(cv.at(x, k), 0.62 if k == 2 else 0.8))
    for x0 in rng.sample(range(1, 15), rng.choice((2, 3))):      # moss drips from the lip
        for i in range(rng.randrange(5, 14)):
            cv.put(x0, 2 + i, MOSS if i % 2 else MOSS_D)
            if i % 3 == 2:
                cv.put(x0 + rng.choice((-1, 1)), 2 + i, MOSS_D)
    for _ in range(rng.choice((1, 2))):          # cracks that wander down through the blocks
        x = rng.randrange(3, 13)
        y = rng.randrange(3, 10)
        for _ in range(rng.randrange(10, 20)):
            cv.put(x, y, ROCK_D)
            x = max(1, min(14, x + rng.choice((-1, 0, 0, 1))))
            y += 1
            if y > 29:
                break
    for y in range(24, 32):                      # wet foot, darker toward the water
        for x in range(16):
            cv.put(x, y, shade(cv.at(x, y), 0.80 - (y - 24) * 0.035))
    for x in range(16):                          # ragged bottom edge
        cut = rng.choice((0, 0, 1, 2)) if rng.random() < 0.5 else 0
        for k in range(cut):
            cv.put(x, 31 - k, CLEAR)
    return cv.img


def deep_water(mask, seed):
    """Deep water: dark everywhere, darkest in the shade of a cliff, a few ripples and glints. mask = land."""
    rng = np.random.default_rng(seed)
    h, w = mask.shape
    dist = np.full((h, w), 99, dtype=int)
    cur = mask.copy()
    dist[cur] = 0
    for d in range(1, 31):
        grown = cur.copy()
        grown[1:, :] |= cur[:-1, :]
        grown[:-1, :] |= cur[1:, :]
        grown[:, 1:] |= cur[:, :-1]
        grown[:, :-1] |= cur[:, 1:]
        dist[grown & ~cur] = d
        cur = grown
    noise = rng.random((h // 6 + 2, w // 6 + 2))
    big = np.kron(noise, np.ones((6, 6)))[:h, :w]
    tones = [C("#07142b"), C("#0b1f3e"), C("#10294f"), C("#153460")]
    out = Image.new("RGBA", (w, h))
    px = out.load()
    for y in range(h):
        for x in range(w):
            d = dist[y, x] + (big[y, x] - 0.5) * 7
            k = 0 if d <= 3 else (1 if d <= 9 else (2 if d <= 20 else 3))
            px[x, y] = tones[k]
    r = random.Random(seed)
    for _ in range(190):                        # ripples: short light dashes
        x, y = r.randrange(0, w - 6), r.randrange(0, h)
        if dist[y, x] > 4 and dist[y, min(w - 1, x + 4)] > 4:
            k = 1 + (0 if dist[y, x] < 12 else 1)
            for i in range(r.choice((3, 4, 5))):
                px[x + i, y] = shade(tones[min(3, k + 1)], 1.25)
    for _ in range(46):                         # glints
        x, y = r.randrange(0, w), r.randrange(0, h)
        if dist[y, x] > 6:
            px[x, y] = C("#3a8fb4") if r.random() < 0.7 else C("#6fe6ff")
    return out, dist


def foam(img, mask_cliff_base):
    """A broken line of foam where the cliff meets the water."""
    px = img.load()
    r = random.Random(3)
    for x, y in mask_cliff_base:
        if r.random() < 0.55:
            px[x, y] = C("#8fd0e8") if r.random() < 0.5 else C("#4f9cc0")
        if r.random() < 0.25:
            px[x, y + 1] = C("#2a6a94")


def plank_bridge(length_tiles, lane_h, horizontal=True):
    """A stone and plank bridge: boards across the way, low stone parapets on both sides, a shade on the water."""
    L_ = length_tiles * TILE
    Hh = lane_h * TILE
    cv = Cv(L_, Hh + 10)
    rng = random.Random(9)
    for y in range(Hh):
        for x in range(L_):
            bx = x % 5
            c = (WOOD_2, WOOD_1, WOOD_2, WOOD_1, WOOD_D)[bx]
            if y % 16 == 0 or y == Hh - 1:
                pass
            if bx == 0:
                c = WOOD_HI if (x // 5) % 3 else WOOD_2
            cv.put(x, y + 5, c)
    for yy, hi in ((0, True), (Hh + 1, False)):  # parapets
        for x in range(L_):
            for i in range(5):
                c = ROCK_3 if i else ROCK_HI
                if i == 4:
                    c = ROCK_1
                cv.put(x, yy + i, c)
            if x % 16 in (0, 1):                # posts
                for i in range(-3, 5):
                    cv.put(x, yy + i if yy else yy + i, ROCK_4 if i < 0 else ROCK_2)
    return cv.outline().img


def pillar_scaled(style, size, seed):
    return pillar(style, size, seed)


def altar():
    cv = Cv(56, 44)
    # dais: two steps of block
    for y in range(26, 44):
        for x in range(0, 56):
            t = (y - 26) / 18.0
            c = mix(ROCK_4, ROCK_2, t)
            if y == 26:
                c = L
            if (x + (y // 6) * 8) % 16 == 15 or y % 9 == 8:
                c = shade(c, 0.6)
            cv.put(x, y, c)
    for y in range(18, 28):
        for x in range(8, 48):
            t = (y - 18) / 10.0
            c = mix(M2, M0, t)
            if y == 18:
                c = HI
            if (x + (y // 5) * 6) % 13 == 12 or y == 27:
                c = S1
            cv.put(x, y, c)
    for dx in range(-8, 9):                     # glowing rune on the top step
        cv.put(28 + dx, 19, RUNE_D)
    cv.put(28, 19, RUNE_L)
    # the crystal
    shape = [2, 4, 6, 6, 7, 7, 7, 7, 6, 6, 4, 2]
    for i, w in enumerate(shape):
        y = 6 + i
        for x in range(28 - w // 2, 28 + (w + 1) // 2):
            c = RUNE_D
            if x < 28 - w // 2 + max(1, w // 3):
                c = RUNE_L if i < 8 else RUNE
            elif x >= 28 + (w + 1) // 2 - 2:
                c = C("#1a5aa8")
            cv.put(x, y, c)
    return cv.outline().img


def room_scene(path, final=False):
    W, H = CW * TILE, CH * TILE
    land = np.zeros((H, W), dtype=bool)
    for y, (xa, xb) in ROWS.items():
        land[y * TILE:(y + 1) * TILE, xa * TILE:(xb + 1) * TILE] = True
    cliff_cells = []
    for y, (xa, xb) in ROWS.items():
        for x in range(xa, xb + 1):
            if not is_floor(x, y + 1):
                cliff_cells.append((x, y + 1))
                land[(y + 1) * TILE:(y + 3) * TILE, x * TILE:(x + 1) * TILE] = True
    img, dist = deep_water(land, 7)
    land_img = Image.fromarray((land * 255).astype("uint8"), "L")
    shifted = Image.new("L", land_img.size, 0)
    shifted.paste(land_img, (0, 7))
    under = shifted.filter(ImageFilter.GaussianBlur(7)).point(lambda v: int(v * 0.75))
    around = land_img.filter(ImageFilter.GaussianBlur(4)).point(lambda v: int(v * 0.40))
    for soft in (under, around):
        img = Image.composite(Image.new("RGBA", img.size, (2, 6, 18, 255)), img, soft)
    rng = random.Random(11)
    foam_px = []
    for (x, y) in cliff_cells:                  # cliffs
        face = cliff_face(rng.randrange(1000), rng.randrange(3))
        img.alpha_composite(face, (x * TILE, y * TILE))
        for i in range(TILE):
            foam_px.append((x * TILE + i, (y + 2) * TILE))
    foam(img, foam_px)
    rr = random.Random(21)
    for (x, y) in rr.sample(cliff_cells, min(9, len(cliff_cells))):
        sx, sy = x * TILE + rr.randrange(0, 10), (y + 2) * TILE + rr.randrange(2, 7)
        for dx in range(-1, 6):
            for dy in range(-1, 4):
                edge = dx in (-1, 5) or dy in (-1, 3)
                c = C("#8fd0e8") if (edge and rr.random() < 0.35) else None
                if 0 <= dx < 5 and 0 <= dy < 3:
                    c = ROCK_HI if dy == 0 else (ROCK_3 if dy == 1 else ROCK_1)
                if c:
                    img.putpixel((sx + dx, sy + dy), c)
    plain = [floor_bond(s) for s in range(100, 104)]
    wears = [floor_bond(200 + w, wear=w) for w in (1, 2, 3)]
    for y, (xa, xb) in ROWS.items():            # floor
        for x in range(xa, xb + 1):
            t = rng.choice(plain) if rng.random() < 0.84 else rng.choice(wears)
            img.alpha_composite(t, (x * TILE, y * TILE))
    # a flagstone path from door to door and a ceremonial square at the middle
    for x in range(3, 27):
        for y in (8, 9):
            img.alpha_composite(floor_flag(300 + (x * 3 + y) % 5), (x * TILE, y * TILE))
    for x in range(12, 18):
        for y in range(4, 8):
            img.alpha_composite(floor_flag(310 + (x + y) % 4), (x * TILE, y * TILE))
    px = img.load()
    for y, (xa, xb) in ROWS.items():            # rims where the floor meets water without a cliff
        for x in range(xa, xb + 1):
            for i in range(TILE):
                if not is_floor(x, y - 1) and y - 1 >= 2 or (y == 2):
                    px[x * TILE + i, y * TILE] = OUTLINE
                    px[x * TILE + i, y * TILE + 1] = mix(FLOOR_HI, HI, 0.4)
                    px[x * TILE + i, y * TILE + 2] = FLOOR_TONES[2]
                if not is_floor(x - 1, y) and not (y in (7, 8, 9, 10) and x == 3):
                    px[x * TILE, y * TILE + i] = OUTLINE
                    px[x * TILE + 1, y * TILE + i] = mix(FLOOR_HI, HI, 0.3)
                if not is_floor(x + 1, y) and not (y in (7, 8, 9, 10) and x == 26):
                    px[x * TILE + 15, y * TILE + i] = OUTLINE
                    px[x * TILE + 14, y * TILE + i] = shade(FLOOR_TONES[0], 0.8)
    # bridges at the two doors
    bridge = plank_bridge(3, 3)
    shade_w = Image.new("RGBA", bridge.size, (0, 0, 0, 0))
    img.alpha_composite(bridge, (0, 7 * TILE + 8 - 5))
    img.alpha_composite(bridge, (27 * TILE, 7 * TILE + 8 - 5))
    if final:
        return final_props(img, path)
    # props sorted by their feet
    props = []
    # (style, size, tile x, tile y, flipped): the altar's pair, a pair at each door, a pair in the south
    layout = [("medallon", "m", 11, 4, False), ("medallon", "m", 18, 4, True),
              ("roto", "s", 5, 6, False), ("roto", "s", 5, 11, False),
              ("roto", "s", 24, 6, True), ("roto", "s", 24, 11, True),
              ("medallon", "s", 10, 13, False), ("medallon", "s", 19, 13, True)]
    for k, (style, size, tx, ty, flip) in enumerate(layout):
        sp = pillar(style, size, seed=3 + k)
        sw = SIZES[size][0]
        extra = sp.width - sw
        left = tx * TILE + TILE // 2 - sw // 2
        if flip:
            sp = sp.transpose(Image.FLIP_LEFT_RIGHT)
            left = tx * TILE + TILE // 2 - extra - sw // 2 if style == "roto" else left
        props.append((ty * TILE + TILE, sp, (left, ty * TILE + TILE - sp.height)))
    al = altar()
    props.append((4 * TILE + 8, al, (15 * TILE - al.width // 2 + 8, 4 * TILE + 8 - al.height + 6)))
    nico_path = os.path.join(ROOT, "assets", "sprites", "nico", "nico_idle_down.png")
    if os.path.exists(nico_path):
        nico = Image.open(nico_path).convert("RGBA").crop((0, 0, 32, 32))
        props.append((8 * TILE + 24, nico, (13 * TILE - 16 + 8, 8 * TILE + 24 - 30)))
    for _, sp, pos in sorted(props, key=lambda p: p[0]):
        shadow = Image.new("RGBA", sp.size, (0, 0, 0, 0))
        sd = ImageDraw.Draw(shadow)
        sd.ellipse((1, sp.height - 6, sp.width - 2, sp.height), fill=(0, 0, 0, 70))
        img.alpha_composite(shadow, pos)
        img.alpha_composite(sp, pos)
    # a soft blue glow around the crystal, additive
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy = 15 * TILE + 8, 4 * TILE - 6
    for r_, a in ((54, 10), (40, 14), (28, 18), (16, 26)):
        gd.ellipse((cx - r_, cy - r_, cx + r_, cy + r_), fill=(60, 160, 255, a))
    img = Image.alpha_composite(img, glow)
    img.resize((img.width * 3, img.height * 3), Image.NEAREST).save(path)


# =====================================================================================================================
# THE ROOM WITH THE MAP'S OWN PIECES (the tileset of the Ruinas), in the new look
# =====================================================================================================================
def _sheet():
    import json
    d = json.load(open(os.path.join(ROOT, "assets", "tilesets", "ruins", "ruins_tiles.json")))
    sheet = Image.open(os.path.join(ROOT, "assets", "tilesets", "ruins", "ruins_sheet.png")).convert("RGBA")
    return d["tiles"], sheet


def final_props(img, path):
    tiles, sheet = _sheet()

    def tile(name):
        x, y = tiles[name]
        return sheet.crop((x * 16, y * 16, x * 16 + 16, y * 16 + 16))

    def stack(*names):                           # tiles one above the other
        out = Image.new("RGBA", (16, 16 * len(names)), CLEAR)
        for i, n in enumerate(names):
            out.alpha_composite(tile(n), (0, i * 16))
        return out

    def block(grid):                             # a rectangle of tiles: rows of names
        out = Image.new("RGBA", (16 * len(grid[0]), 16 * len(grid)), CLEAR)
        for j, row in enumerate(grid):
            for i, n in enumerate(row):
                out.alpha_composite(tile(n), (i * 16, j * 16))
        return out

    # --- the waterfall that falls off the south cliff into the deep water -----------------------------------------
    for x in (14, 15):
        img.alpha_composite(tile("waterfall_top"), (x * TILE, 14 * TILE))
        img.alpha_composite(tile("waterfall_mid_a" if x == 14 else "waterfall_mid_b"), (x * TILE, 15 * TILE))
        img.alpha_composite(tile("waterfall_mid_b" if x == 14 else "waterfall_mid_c"), (x * TILE, 16 * TILE))
        img.alpha_composite(tile("waterfall_base_a" if x == 14 else "waterfall_base_b"), (x * TILE, 17 * TILE))
    # --- flat things: the floor's symbol, armor, bones ------------------------------------------------------------
    img.alpha_composite(block([["floor_symbol_tl", "floor_symbol_tr"], ["floor_symbol_bl", "floor_symbol_br"]]),
                        (14 * TILE, 5 * TILE))
    for name, tx, ty in (("armor_fallen_a", 7, 12), ("bones", 6, 13), ("sword_fallen", 8, 13)):
        img.alpha_composite(tile(name), (tx * TILE, ty * TILE))
    # --- upright props, sorted by their feet -------------------------------------------------------------------------
    props = []

    def add(sprite, tx, ty, flip=False, dx=0):   # tx, ty: the tile where the foot stands
        if flip:
            sprite = sprite.transpose(Image.FLIP_LEFT_RIGHT)
        props.append(((ty + 1) * TILE, sprite, (tx * TILE + dx, (ty + 1) * TILE - sprite.height)))

    add(block([["altar_tl", "altar_tr"], ["altar_bl", "altar_br"]]), 14, 4)
    for x, flip in ((12, False), (17, True)):
        add(stack("crystal_top", "crystal_base"), x, 4, flip)
    for k, (tx, flip) in enumerate(((9, False), (20, True))):
        sp = pillar("medallon", "m", seed=5 + k)
        add(sp, tx, 4, flip, dx=8 - sp.width // 2)
    for k, (tx, ty, flip) in enumerate(((6, 5, False), (6, 12, False), (23, 5, True), (23, 12, True))):
        sp = pillar("roto", "s", seed=9 + k)
        extra = sp.width - SIZES["s"][0]
        add(sp, tx, ty, flip, dx=(8 - SIZES["s"][0] // 2) - (extra if flip else 0))
    for tx, ty in ((4, 6), (4, 11), (25, 6), (25, 11)):
        add(tile("torch_a"), tx, ty)
    for tx in (11, 18):
        add(tile("brazier_a"), tx, 6)
    statue_dir = os.path.join(OUT, "estatuas", "h72")       # make_ruins_statues.py writes them there
    for tx, variant in ((11, "clean"), (18, "vines")):
        path_ = os.path.join(statue_dir, f"statue_{variant}.png")
        if os.path.exists(path_):
            sp = Image.open(path_).convert("RGBA")
            add(sp, tx, 13, dx=8 - sp.width // 2)
        else:
            add(stack("statue_a_top", "statue_a_base"), tx, 13)
    add(stack("gravestone_a"), 22, 3)
    add(tile("gravestone_b"), 21, 3)
    add(tile("chest_closed"), 21, 12)
    add(tile("crate"), 22, 12)
    add(tile("barrel"), 22, 13)
    add(tile("urn_a"), 6, 3)
    add(tile("vase_a"), 7, 3)
    for name, tx, ty in (("fern_a", 7, 14), ("mushroom_0", 8, 14), ("fern_b", 21, 14), ("mushroom_2", 20, 14),
                         ("glow_flower_0", 13, 13), ("glow_flower_1", 16, 13), ("mushroom_1", 9, 3), ("fern_blue", 5, 12)):
        add(tile(name), tx, ty)
    nico_path = os.path.join(ROOT, "assets", "sprites", "nico", "nico_idle_down.png")
    if os.path.exists(nico_path):
        add(Image.open(nico_path).convert("RGBA").crop((0, 0, 32, 32)), 12, 9, dx=-8)
    for _, sp, pos in sorted(props, key=lambda p: p[0]):
        shadow = Image.new("RGBA", sp.size, (0, 0, 0, 0))
        ImageDraw.Draw(shadow).ellipse((1, sp.height - 5, sp.width - 2, sp.height), fill=(0, 0, 0, 62))
        img.alpha_composite(shadow, pos)
        img.alpha_composite(sp, pos)
    # --- lights: a cold glow from the crystals, a warm one from the torches ------------------------------------
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    lights = [(15 * TILE, 4 * TILE - 6, 1.1, (60, 160, 255)), (12 * TILE + 8, 4 * TILE - 2, 0.8, (60, 160, 255)),
              (17 * TILE + 8, 4 * TILE - 2, 0.8, (60, 160, 255)), (11 * TILE + 8, 6 * TILE + 4, 0.6, (60, 160, 255)),
              (18 * TILE + 8, 6 * TILE + 4, 0.6, (60, 160, 255))]
    lights += [(tx * TILE + 8, ty * TILE + 4, 0.7, (255, 160, 70)) for tx, ty in ((4, 6), (4, 11), (25, 6), (25, 11))]
    for cx, cy, k, col in lights:
        for r_, a in ((int(52 * k), 8), (int(38 * k), 12), (int(26 * k), 16), (int(14 * k), 22)):
            gd.ellipse((cx - r_, cy - r_, cx + r_, cy + r_), fill=col + (a,))
    img = Image.alpha_composite(img, glow)
    img.resize((img.width * 3, img.height * 3), Image.NEAREST).save(path)


PROPS_DIR = os.path.join(ROOT, "assets", "sprites", "ruins_props")


def export_props():
    """The game's own copies: medallion and broken pillars (small and medium) and the eight statues made by
    tools/make_ruins_statues.py (run it first: it writes them to OUT/estatuas/h72)."""
    os.makedirs(PROPS_DIR, exist_ok=True)
    for style, name in (("medallon", "medallion"), ("roto", "broken")):
        for size in ("s", "m"):
            pillar(style, size, seed=3).save(os.path.join(PROPS_DIR, f"pillar_{name}_{size}.png"))
    src = os.path.join(OUT, "estatuas", "h72")
    for variant in ("clean", "vines", "cracked", "ruined", "plain", "ivy", "worn", "headless"):
        Image.open(os.path.join(src, f"statue_{variant}.png")).save(os.path.join(PROPS_DIR, f"statue_{variant}.png"))
    print("exported to", PROPS_DIR)


def main():
    if "--export" in sys.argv:
        export_props()
        return
    os.makedirs(OUT, exist_ok=True)
    sheet_pillars(os.path.join(OUT, "pilares.png"))
    sheet_floor(os.path.join(OUT, "piso.png"))
    room_scene(os.path.join(OUT, "sala.png"))
    room_scene(os.path.join(OUT, "sala_final.png"), final=True)
    print("ok ->", OUT)


if __name__ == "__main__":
    main()
