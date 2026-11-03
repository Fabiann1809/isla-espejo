"""Draws the Baldosa hambrienta's art (temple enemy, island 3) pixel by pixel.

The pack's tile, scaled from 128 px down to the game, came out blurred, so it is drawn at the game's
own pixel size instead, following the pack's design: a square slab of grey-brown temple stone seen
from above and in front, a recessed panel with a purple ring and a gold glyph, gold plates on its
corners and gold rivets along its front. It is built from three parts that each animation moves:
the lid (the top face and the upper rows of its front), the jaw (the lower rows of its front) and
the molten mouth between them, with its glowing teeth. Animations, as in the pack's sheet: idle
(a faint glint), walk (it hops forward, the lid ajar), attack (cracks glow, it opens and bites),
special (it trembles, its cracks glow, the jaws gape with sparks and close again), hurt, and death
(it splits and collapses into rubble over a lava pool that cools).

The game uses some frames on their own (scripts/enemies/baldosa_hambrienta.gd): idle 0 is the calm
tile it hides as, special 1-4 the warning (cracks glowing), special 5 the open jaws and the last
attack frame its open mouth while it is out.

Writes into `assets/sprites/baldosa_hambrienta/`:
    baldosa_hambrienta_<animation>.png   64x64 cells, facing right, the front's last row on row 50:
                                         idle, walk, attack, special, hurt, death

    python tools/make_baldosa_hambrienta_art.py
Then tools/make_temple_enemy_frames.gd builds its SpriteFrames as for every temple enemy, and
tools/enemy_aseprite.lua keeps an editable `source/baldosa_hambrienta.aseprite`.
Needs Pillow.
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "baldosa_hambrienta")
CELL = 64
## Last row of the tile's front; its outline goes on the row below.
GROUND = 50
## The slab: 28 px wide, a 12-row top face over a 5-row front (the lid owns the front's upper 2).
X0, X1 = 18, 45
TOP = GROUND - 16
FRONT = GROUND - 4
LID_ROWS = 2
CX = (X0 + X1 + 1) / 2.0
CY = (TOP + FRONT) / 2.0

PALETTE = {
    "O": (24, 14, 22),      # outline
    # temple stone, grey-brown with a purple cast
    "T0": (50, 34, 44),
    "T1": (80, 58, 68),
    "T2": (110, 84, 90),
    "T3": (142, 114, 112),
    "T4": (176, 150, 138),
    # the ring of the emblem
    "P0": (54, 32, 74),
    "P1": (92, 58, 122),
    "P2": (136, 98, 160),
    # gold plates, rivets and glyph
    "G0": (122, 78, 26),
    "G1": (214, 158, 52),
    "G2": (255, 226, 138),
    # lava: mouth, cracks, teeth
    "S0": (66, 14, 18),
    "S1": (126, 30, 22),
    "S2": (192, 62, 26),
    "S3": (238, 118, 34),
    "S4": (255, 176, 60),
    "Y": (255, 222, 110),
    "Y2": (255, 248, 200),
    # dust
    "D1": (120, 104, 98),
    "D2": (162, 146, 134),
    "W": (255, 243, 232),   # hurt flash
}
## Death: the lava under the rubble cools down step by step.
COOL_STEPS = [
    {"Y2": "Y", "Y": "S4", "S4": "S3"},
    {"Y": "S3", "S4": "S2", "S3": "S2", "S2": "S1"},
    {"S3": "S1", "S2": "S1", "S1": "T0", "S0": "T0"},
]

## Hurt: everything jumps to its lightest tones (a plain white slab would lose its shape).
FLASH = {"T0": "T2", "T1": "T3", "T2": "T4", "T3": "W", "T4": "W", "P0": "P2", "P1": "W", "P2": "W",
         "G0": "G2", "G1": "W", "G2": "W", "S0": "S2", "S1": "S3", "S2": "S4", "S3": "Y", "S4": "Y2",
         "Y": "W", "Y2": "W"}
## Cracks of the top face, from its corners toward the ring (tile coordinates).
CRACKS = [
    [(X0 + 3, TOP + 3), (X0 + 5, TOP + 4), (X0 + 7, TOP + 4), (X0 + 9, TOP + 5)],
    [(X1 - 3, TOP + 3), (X1 - 5, TOP + 3), (X1 - 6, TOP + 4), (X1 - 8, TOP + 5)],
    [(X0 + 3, FRONT - 4), (X0 + 5, FRONT - 5), (X0 + 7, FRONT - 5), (X0 + 9, FRONT - 6)],
    [(X1 - 3, FRONT - 4), (X1 - 6, FRONT - 5), (X1 - 8, FRONT - 6)],
    [(int(CX), TOP + 2), (int(CX), TOP + 3), (int(CX) + 1, TOP + 4)],
]
## Joints between the three blocks of the front.
SEAMS = [X0 + 9, X0 + 18]
## Crack colours per glow level (line, hot core).
GLOW = {1: ("S1", "S1"), 2: ("S2", "S3"), 3: ("S3", "S4"), 4: ("S4", "Y")}


class Canvas:
    def __init__(self, size):
        self.size = size
        self.px = {}

    def set(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < self.size and 0 <= y < self.size:
            self.px[(x, y)] = c

    def over(self, other):
        self.px.update(other.px)

    def shifted(self, dx, dy):
        c = Canvas(self.size)
        for (x, y), col in self.px.items():
            c.set(x + dx, y + dy, col)
        return c

    def outline(self, color="O", only_empty_of=None):
        """A 1 px outline around everything drawn (4-neighbours: rounder than 8)."""
        ring = {}
        for (x, y) in self.px:
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if (nx, ny) in self.px or not (0 <= nx < self.size and 0 <= ny < self.size):
                    continue
                if only_empty_of is not None and (nx, ny) in only_empty_of.px:
                    continue
                ring[(nx, ny)] = color
        self.px.update(ring)

    def remap(self, mapping):
        self.px = {p: mapping.get(c, c) for p, c in self.px.items()}

    def image(self):
        img = Image.new("RGBA", (self.size, self.size), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            img.putpixel((x, y), PALETTE[c] + (255,))
        return img


def in_ellipse(x, y, cx, cy, rx, ry):
    return ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0


def lit(nx, ny):
    """How much a surface with normal (nx, ny) faces the light (upper left)."""
    return -0.55 * nx - 0.8 * ny


def pixel_perfect(pts):
    """Drops the doubled corners of a 1 px line so it stays clean."""
    out = []
    for p in pts:
        if p in out:
            continue
        out.append(p)
        if len(out) >= 3:
            a, b, c = out[-3], out[-2], out[-1]
            if (a[0] == b[0] or a[1] == b[1]) and (b[0] == c[0] or b[1] == c[1]) and \
                    a[0] != c[0] and a[1] != c[1]:
                out.pop(-2)
    return out


def polyline(points):
    pts = []
    for (ax, ay), (bx, by) in zip(points, points[1:]):
        n = int(max(abs(bx - ax), abs(by - ay), 1))
        for i in range(n + 1):
            pts.append((round(ax + (bx - ax) * i / n), round(ay + (by - ay) * i / n)))
    return pixel_perfect(pts)


# --- the tile ----------------------------------------------------------------------------------

def pose(**kw):
    p = dict(lift=0, dx=0, dy=0, glow=0, seam=0, glint=-1, flash=False, fx=(), dust=())
    p.update(kw)
    return p


def draw_lid(p):
    """The top face and the lid's share of the front, as if closed."""
    lid = Canvas(CELL)
    for y in range(TOP, FRONT + LID_ROWS):
        for x in range(X0, X1 + 1):
            if y == TOP and x in (X0, X1):
                continue  # rounded back corners
            if y >= FRONT:
                # the lid's front rows: lit top edge, block joints
                c = "T2" if y == FRONT else "T1"
                if x in SEAMS:
                    c = "T0"
            elif y in (TOP, TOP + 1) or x in (X0, X0 + 1):
                # the raised rim, lit on its top and left
                c = "T4" if (y == TOP and x < CX + 4) or (x == X0 and y < CY) else "T3"
            elif x in (X1, X1 - 1):
                c = "T2" if x == X1 - 1 else "T1"
            elif y == FRONT - 1:
                c = "T3"  # the front edge of the top catches the light
            elif y == FRONT - 2:
                c = "T2"
            else:
                # the recessed panel: shadowed under its top and left rims, lit at the others
                if y == TOP + 2 or x == X0 + 2:
                    c = "T1"
                elif y == FRONT - 3 or x == X1 - 2:
                    c = "T3"
                else:
                    c = "T2"
            lid.set(x, y, c)
    # speckles of wear on the panel
    for x, y in ((X0 + 5, TOP + 6), (X1 - 6, TOP + 7), (X0 + 7, FRONT - 4), (X1 - 4, TOP + 4)):
        lid.set(x, y, "T3")
    for x, y in ((X0 + 6, TOP + 7), (X1 - 5, FRONT - 4)):
        lid.set(x, y, "T1")
    # gold plates on the rim's corners and the middle of its sides
    for gx, gy in ((X0 + 1, TOP + 1), (X1 - 2, TOP + 1), (X0 + 1, FRONT - 3), (X1 - 2, FRONT - 3)):
        lid.set(gx, gy, "G2" if gx < CX and gy < CY else "G1")
        lid.set(gx + 1, gy, "G1")
        lid.set(gx, gy + 1, "G1")
        lid.set(gx + 1, gy + 1, "G0")
    for gy in (int(CY) - 1, int(CY)):
        lid.set(X0, gy, "G1" if gy < CY else "G0")
        lid.set(X1, gy, "G0")
    # the ring of the emblem, its dark heart and the gold glyph
    rx, ry = 6.5, 3.8
    for y in range(TOP + 2, FRONT - 2):
        for x in range(X0 + 2, X1 - 1):
            if not in_ellipse(x, y, CX, CY, rx, ry):
                continue
            if in_ellipse(x, y, CX, CY, rx - 1.4, ry - 1.1):
                lid.set(x, y, "T0" if y < CY else "T1")
            else:
                l = lit((x + 0.5 - CX) / rx, (y + 0.5 - CY) / ry)
                lid.set(x, y, "P2" if l > 0.35 else "P1" if l > -0.45 else "P0")
    cx, cy = int(CX), int(CY)
    for dx, dy, c in ((-2, 0, "G1"), (-1, -1, "G2"), (0, -1, "G1"), (0, 0, "G1"), (1, 0, "G1"),
                      (1, 1, "G0"), (2, 0, "G1"), (-1, 1, "G0")):
        lid.set(cx + dx, cy + dy, c)
    return lid


def add_glint(lid, step):
    """Idle: a glint runs along the gold (corner plates, then the glyph)."""
    spots = [(X0 + 1, TOP + 1), (int(CX) - 1, int(CY) - 1), (X1 - 2, TOP + 1), (X1 - 2, FRONT - 3)]
    if 0 <= step < len(spots):
        x, y = spots[step]
        lid.set(x, y, "Y2")
        lid.set(x + 1, y, "G2")


def add_cracks(c, level, dy=0):
    if level <= 0:
        return
    line, core = GLOW[level]
    count = len(CRACKS) if level >= 2 else 3
    for k, crack in enumerate(CRACKS[:count]):
        pts = polyline(crack)
        for i, (x, y) in enumerate(pts):
            c.set(x, y + dy, core if i == len(pts) - 1 or (level >= 3 and i % 2) else line)
    if level >= 3:
        # the ring heats up too
        for (x, y), col in list(c.px.items()):
            if col in ("P0", "P1", "P2"):
                c.px[(x, y)] = {"P0": "S1", "P1": "S2", "P2": "S3"}[col] if level == 3 else \
                    {"P0": "S2", "P1": "S3", "P2": "S4"}[col]


def draw_jaw(p):
    """The lower rows of the front, with its joints and rivets."""
    jaw = Canvas(CELL)
    for y in range(FRONT + LID_ROWS, GROUND + 1):
        for x in range(X0, X1 + 1):
            if y == GROUND and x in (X0, X1):
                continue
            c = "T0" if y == GROUND or x in SEAMS else "T1"
            if p["lift"] and y == FRONT + LID_ROWS:
                c = "T2"  # open, the jaw's lip shows its lit top
            jaw.set(x, y, c)
    for bx in (X0 + 4, X0 + 13, X1 - 4):
        jaw.set(bx, GROUND - 1, "G2")
        jaw.set(bx + 1, GROUND - 1, "G1")
    return jaw


def fang(m, x, root, h, down):
    """A glowing fang 4 px wide at its root tapering to a point `h` rows away, shaded on its right."""
    step = 1 if down else -1
    for k in range(h):
        y = root + step * k
        if k == h - 1:
            row = [(x, "Y2")] if h > 1 else [(x - 1, "S4"), (x, "Y"), (x + 1, "Y"), (x + 2, "S3")]
        elif k == 0:
            row = [(x - 1, "S4"), (x, "Y"), (x + 1, "Y"), (x + 2, "S3")]
        else:
            row = [(x, "Y"), (x + 1, "S4")]
        for xx, c in row:
            m.set(xx, y, c)


def draw_mouth(lift):
    """The molten mouth between lid and jaw: dark under the lid, a glowing throat, and fangs that
    interlock (upper ones hang from the lid, lower ones rise from the jaw)."""
    m = Canvas(CELL)
    bottom = FRONT + LID_ROWS - 1   # last row of the gap (just over the jaw)
    top = bottom - lift + 1
    for y in range(top, bottom + 1):
        f = (y - top + 0.5) / lift
        for x in range(X0, X1 + 1):
            if x in (X0, X1):
                m.set(x, y, "T0")  # the corners of the mouth
                continue
            mid = abs(x + 0.5 - CX) / (X1 - X0)
            if f < 0.3 or f > 0.9 and lift >= 5:
                c = "S0"
            elif f < 0.5:
                c = "S1"
            elif mid > 0.32:
                c = "S1" if f > 0.8 else "S2"
            else:
                c = "S2" if f > 0.8 or mid > 0.2 else "S3"
            m.set(x, y, c)
    if lift >= 6:
        gy = top + int(lift * 0.62)
        for x in range(int(CX) - 3, int(CX) + 3):
            m.set(x, gy, "S4" if abs(x + 0.5 - CX) < 2 else "S3")
        m.set(int(CX) - 1, gy, "Y")
    h = max(1, min(4, lift // 2))
    for tx in range(X0 + 3, X1 - 1, 5):
        fang(m, tx, top, h, True)
    if lift >= 3:
        for tx in range(X0 + 6, X1 - 2, 5):
            fang(m, tx, bottom, h, False)
    return m


def draw_tile(p):
    lift = p["lift"]
    lid = draw_lid(p)
    add_glint(lid, p["glint"])
    add_cracks(lid, p["glow"])
    if p["glow"] >= 2:
        # the front's joints glow as well
        for x in SEAMS:
            lid.set(x, FRONT + 1, GLOW[p["glow"]][0])
    tile = draw_jaw(p)
    if p["glow"] >= 2:
        for x in SEAMS:
            for y in range(FRONT + LID_ROWS, GROUND):
                tile.set(x, y, GLOW[p["glow"]][0] if y == FRONT + LID_ROWS else GLOW[max(1, p["glow"] - 1)][0])
    if p["seam"] and not lift:
        # the line between lid and jaw glows: about to open
        col = {1: "S2", 2: "S3", 3: "S4"}[p["seam"]]
        for x in range(X0 + 1, X1):
            tile.set(x, FRONT + LID_ROWS, col if x % 3 else GLOW[min(4, p["seam"] + 1)][1])
    if lift:
        tile.over(draw_mouth(lift))
    tile.over(lid.shifted(0, -lift))
    tile = tile.shifted(p["dx"], p["dy"])
    tile.outline()
    if p["flash"]:
        tile.remap(FLASH)
    add_dust(tile, p["dust"])
    add_fx(tile, p["fx"])
    return tile


def add_fx(canvas, fx):
    """Sparks and drops: (x, y, size, color); size 1 is one pixel, 2 a 2x2 drop. Outlined only where
    they stand on empty cell."""
    if not fx:
        return
    drops = Canvas(canvas.size)
    for x, y, size, c in fx:
        if size == 1:
            drops.set(x, y, c)
        else:
            drops.set(x, y, "Y2" if c == "Y" else "Y")
            drops.set(x + 1, y, c)
            drops.set(x, y + 1, c)
            drops.set(x + 1, y + 1, "S3")
    drops.outline(only_empty_of=canvas)
    canvas.over(drops)


def spark(x, y, dx, dy, n=3):
    """A short streak of sparks flying (dx, dy), hottest at its head."""
    cols = ["Y2", "Y", "S4", "S3"]
    return [(x - dx * k, y - dy * k, 1, cols[min(k, 3)]) for k in range(n)]


def add_dust(canvas, puffs):
    """Little puffs of dust kicked up behind it (no outline: they are soft)."""
    for x, y, r in puffs:
        for yy in range(y - r, y + 1):
            for xx in range(x - r, x + r + 1):
                if (xx, yy) in canvas.px:
                    continue
                if in_ellipse(xx, yy, x + 0.5, y + 0.5, r + 0.6, r * 0.8 + 0.4):
                    canvas.set(xx, yy, "D2" if yy < y and xx <= x else "D1")


# --- animations --------------------------------------------------------------------------------

def idle():
    # A still tile (frame 0 is what it hides as); a faint glint runs over its gold.
    return [pose(glint=g) for g in (-1, -1, 0, 1, 2, 3)]


def walk():
    # Little hops forward, the lid ajar on its glowing teeth; dust where it lands.
    dy = [0, -1, -3, -4, -3, -1, 0, 0]
    lift = [1, 2, 2, 1, 1, 1, 2, 1]
    dust = [[(X0 - 2, GROUND, 2)], [(X0 - 4, GROUND - 1, 1)], [], [], [], [], [(X0 - 1, GROUND, 2), (X1 + 2, GROUND, 1)],
            [(X0 - 3, GROUND - 1, 1)]]
    return [pose(dy=dy[i], lift=lift[i], seam=1, dust=dust[i], dx=1 if 2 <= i <= 4 else 0) for i in range(8)]


def attack():
    # Its cracks glow, the lid lifts on a molten mouth, it snaps shut on its prey and stays gaping.
    return [
        pose(glow=1),
        pose(glow=2, seam=1),
        pose(glow=3, seam=2, dy=1),
        pose(glow=3, lift=4, dy=-1),
        pose(glow=2, lift=9, dy=-2, fx=spark(X1 + 3, TOP - 6, 1, -1) + spark(X0 - 3, TOP - 5, -1, -1, 2)),
        pose(glow=2, lift=2, dx=2, fx=spark(X1 + 4, FRONT - 2, 1, 0, 2) + [(X1 + 2, TOP - 2, 1, "S4")]),
        pose(glow=1, lift=6),
    ]


def special():
    # It trembles, its cracks glow brighter and brighter, the jaws gape with sparks, then it shuts.
    sparks = spark(X1 + 4, TOP - 8, 1, -1) + spark(X1 + 6, TOP - 2, 1, 0) + spark(X0 - 4, TOP - 4, -1, -1, 2) \
        + [(X1 + 3, TOP - 12, 1, "S4"), (X0 - 2, TOP - 9, 1, "Y")]
    return [
        pose(),
        pose(glow=1),
        pose(glow=2, dx=1),
        pose(glow=3, seam=1, dx=-1),
        pose(glow=4, seam=3, dx=1, dy=-1),
        pose(glow=4, lift=10, dy=-2, fx=sparks),
        pose(glow=2, lift=2, fx=[(X1 + 5, TOP - 14, 1, "S3"), (X0 - 3, TOP - 11, 1, "S3")]),
        pose(glow=1),
    ]


def hurt():
    return [
        pose(lift=4, flash=True),
        pose(lift=2, dx=-2, dy=1, glow=1),
        pose(lift=3, dx=-1),
        pose(lift=5),
    ]


# --- death: it splits and collapses into rubble -------------------------------------------------

def lava_pool(rx, ry, cool, cx=CX):
    c = Canvas(CELL)
    for y in range(GROUND - 6, GROUND + 4):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if not in_ellipse(x, y, cx, GROUND + 0.5, rx, ry):
                continue
            q = math.hypot((x + 0.5 - cx) / rx, (y - GROUND) / ry)
            c.set(x, y, "S1" if q > 0.85 else "S2" if q > 0.6 else "S3" if q > 0.3 else "S4")
    for step in COOL_STEPS[:cool]:
        c.remap(step)
    return c


def rubble(lumps, hot=True):
    """Chunks of the broken tile: (cx, cy, rx, ry, gold); lava glows in their cracks while hot."""
    c = Canvas(CELL)
    for cx, cy, rx, ry, gold in lumps:
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if not in_ellipse(x, y, cx, cy, rx, ry):
                    continue
                l = lit((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
                c.set(x, y, "T4" if l > 0.6 else "T3" if l > 0.2 else "T2" if l > -0.3 else "T1")
        if gold:
            c.set(int(cx), int(cy), "G1")
            c.set(int(cx) - 1, int(cy), "G2")
    # a dark line where two chunks meet
    keys = list(c.px)
    owner = {}
    for idx, (cx, cy, rx, ry, _g) in enumerate(lumps):
        for p in keys:
            if in_ellipse(p[0], p[1], cx, cy, rx, ry):
                owner[p] = idx
    for (x, y) in keys:
        o = owner.get((x, y))
        if o is not None and (owner.get((x + 1, y), o) != o or owner.get((x, y + 1), o) != o):
            c.px[(x, y)] = "S3" if hot else "T0"
    return c


def split_tile(gap, glow):
    """The closed tile cracked in two halves `gap` px apart, lava welling up between them."""
    whole = draw_lid(pose())
    add_cracks(whole, glow)
    whole.over(draw_jaw(pose()))
    left, right = Canvas(CELL), Canvas(CELL)
    for (x, y), c in whole.px.items():
        cut = CX + (y - CY) * 0.25  # the crack runs slightly slanted
        (left if x + 0.5 < cut else right).set(x, y, c)
    out = left.shifted(-gap, gap // 2)
    out.over(right.shifted(gap, gap // 2 + (1 if gap else 0)))
    if gap:
        for y in range(TOP + 1, GROUND + 1):
            cut = int(CX + (y - CY) * 0.25)
            for x in range(cut - gap, cut + gap):
                if (x, y) not in out.px:
                    out.set(x, y, "Y" if abs(x + 0.5 - cut) < 1 else "S4")
    return out


def death():
    frames = []
    # 0: it shudders, every crack white-hot
    frames.append(draw_tile(pose(glow=4, seam=3, flash=False)))
    # 1: it splits in two, lava welling up
    t = split_tile(1, 4)
    t.outline()
    add_fx(t, spark(CX + 2, TOP - 4, 0, -1) + spark(X0 - 2, TOP + 2, -1, -1, 2))
    frames.append(t)
    lumps = [(24, GROUND - 4, 4.5, 3.5, True), (31.5, GROUND - 6, 5, 4.5, False), (39, GROUND - 4, 4.5, 3.5, True),
             (20, GROUND - 1, 3, 2.5, False), (44, GROUND - 1, 3, 2.5, False), (28, GROUND - 1, 3.5, 2.5, False),
             (36, GROUND - 1, 3.5, 2.5, True)]
    steps = [
        # (lump drop, lump shrink, pool rx, pool cool, hot cracks, fx)
        (0, 0.0, 14, 0, True, spark(CX, TOP - 2, 0, -1) + spark(X1 + 2, TOP + 2, 1, -1, 2) + spark(X0 - 2, TOP + 4, -1, -1, 2)),
        (1, 0.5, 17, 0, True, [(CX - 6, TOP + 2, 1, "S4"), (CX + 7, TOP, 1, "Y"), (X1 + 4, TOP + 6, 1, "S3")]),
        (2, 1.0, 17, 1, True, [(CX + 3, TOP + 4, 1, "S3")]),
        (3, 1.4, 16, 2, False, []),
        (4, 1.8, 15, 3, False, []),
    ]
    for drop, shrink, prx, cool, hot, fx in steps:
        c = lava_pool(prx, 3.2, cool)
        ls = [(x, y + drop * (1 if y < GROUND - 2 else 0.4), max(1.5, rx - shrink * 0.6), max(1.2, ry - shrink), g)
              for x, y, rx, ry, g in lumps]
        if cool >= 3:
            ls = ls[:3] + ls[4:6]
        c.over(rubble(ls, hot))
        c.outline()
        add_fx(c, fx)
        frames.append(c)
    return frames


def strip(frames, path):
    cell = frames[0].size
    img = Image.new("RGBA", (cell * len(frames), cell), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        img.alpha_composite(f.image(), (i * cell, 0))
    img.save(path)
    print(os.path.relpath(path), len(frames), "frames")


if __name__ == "__main__":
    for name, make in (("idle", idle), ("walk", walk), ("attack", attack), ("special", special),
                       ("hurt", hurt)):
        strip([draw_tile(p) for p in make()], os.path.join(OUT, "baldosa_hambrienta_%s.png" % name))
    strip(death(), os.path.join(OUT, "baldosa_hambrienta_death.png"))
