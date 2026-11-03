"""Draws the Núcleo de cría's art (temple enemy, island 3) pixel by pixel.

The bestiary pack's hive, scaled from 128 px down to the game, came out blurred, so it is drawn at
the game's own pixel size instead, following the pack's design: a slab of dark brick with moss
draped over its edges, a honeycomb of lava hanging under it, dark roots that hang around the comb
with drops of lava at their tips, and the lava that drips from the comb's point into a small pool on
the floor. Its animations, as in the pack's sheet: idle (the comb's glow pulses and a drop falls),
walk (the same pulse while the comb sways: it never walks), attack (it squeezes and lets one
creature out), special (a glowing ring opens under it and a swarm bursts out), hurt and death (it
cracks, tears from the slab and falls into a pile of rubble and lava that cools).
It also draws the two effects of its destruction, which the game drew as plain circles: the
warning ring while it burns and the blast (SkillZone circles of `explosion_radius`, 44 px).
As it loses health it breaks in three stages (BroodCoreData.stages): whole; cracked (chunks
missing from the comb, cracks of lava, a corner of the slab and some roots and moss torn off,
pieces on the floor); broken (its point gone, holes through it, its white-hot heart showing
through a tear, the slab split, more lava leaking into a bigger pool). Each stage has its own
strips, a `crack` animation that enters it, and the broken one an `open` animation in which the
comb splits wide to let the queen out over a ring on the floor. Death starts from the broken hive.

Writes into `assets/sprites/nucleo_cria/`:
    nucleo_cria_<animation>.png   64x64 cells, facing right, pool on row 58: idle, walk, attack,
                                  special, hurt, death (stage 1, read by make_temple_enemy_frames.gd)
    nucleo_cria_<animation>_s2.png / _s3.png
                                  the same (but death) cracked and broken, plus crack_s2, crack_s3
                                  (6 frames) and open_s3 (8 frames); tools/make_nucleo_cria.gd
                                  builds their SpriteFrames
    nucleo_cria_warning.png       96x96 cells, 6 frames: the ring that warns of the blast (its
                                  inner ring closes in as the fuse burns)
    nucleo_cria_blast.png         96x96 cells, 6 frames: the explosion, out to the same radius
    nucleo_cria_queen_ring.png    64x64 cells, 8 frames: where the queen comes out (its ring
                                  burns and the floor melts to a flare as she appears)

    python tools/make_nucleo_cria_art.py
Then tools/make_temple_enemy_frames.gd builds its SpriteFrames as for every temple enemy, and
tools/enemy_aseprite.lua keeps an editable `source/nucleo_cria.aseprite`
(extras="warning:7,blast:16,queen_ring:6,idle_s2:6,...", see the end of this file). Needs Pillow.
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "nucleo_cria")
CELL = 64
FX_CELL = 96
## Last row of the lava pool under the comb; its outline goes on the row below.
GROUND = 58
## Radius of the blast and its warning (BroodCoreData.explosion_radius).
BLAST_RADIUS = 44
## The ring where the queen comes out (BroodCoreData.queen_ring_radius) and its cell.
QUEEN_RING = 24
QUEEN_CELL = 64

PALETTE = {
    "O": (22, 12, 16),     # outline
    # brick slab and roots
    "R0": (44, 26, 30),
    "R1": (74, 44, 40),
    "R2": (108, 66, 52),
    "R3": (146, 96, 72),
    "R4": (184, 134, 100),
    # moss
    "M0": (48, 58, 26),
    "M1": (84, 98, 32),
    "M2": (128, 140, 42),
    "M3": (178, 182, 72),
    # lava and honeycomb
    "S0": (58, 16, 22),
    "S1": (110, 28, 24),
    "S2": (176, 52, 26),
    "S3": (228, 98, 34),
    "S4": (250, 150, 52),
    "Y": (255, 206, 74),
    "Y2": (255, 244, 176),
    # wings of the creatures it lets out
    "W2": (236, 196, 136),
    # smoke of the blast
    "K1": (72, 60, 66),
    "K2": (112, 98, 98),
    "W": (255, 243, 224),  # hurt flash
}
## Lava ramp, dark to white-hot.
LAVA = ["S0", "S1", "S2", "S3", "S4", "Y", "Y2"]
STONE = ["R0", "R1", "R2", "R3", "R4"]
## Death: each step cools the lava and dims the stone.
COOL_STEPS = [
    {"Y2": "Y", "Y": "S4", "S4": "S3", "S3": "S2"},
    {"Y": "S3", "S4": "S2", "S3": "S2", "S2": "S1", "R4": "R3", "M3": "M2"},
    {"S3": "S1", "S2": "S1", "S1": "S0", "R3": "R2", "M2": "M1"},
]
## The special: the comb turns white-hot.
BLAZE = {"S0": "S1", "S1": "S2", "S2": "S3", "S3": "S4", "S4": "Y", "Y": "Y2"}

## The slab: x range and its top row; its bottom edge is ragged (`ledge_bottom`).
LEDGE_X0, LEDGE_X1, LEDGE_TOP = 6, 57, 18
## The comb hangs from under the slab down to its point.
HIVE_CX, HIVE_TOP, HIVE_TIP, HIVE_HW = 31.5, 24, 50, 15.5
## Moss drapes: how far each column hangs below the slab's top face (left and right patches).
MOSS_LEFT = (6, [4, 7, 5, 9, 6, 3, 8, 11, 6, 4, 7, 3, 5, 2, 1, 0])
MOSS_RIGHT = (42, [0, 1, 3, 2, 6, 4, 8, 5, 10, 7, 4, 9, 6, 8, 5, 3])
## Roots: (x, top row, length, wiggle phase); the ones at 19 and 44 hug the comb.
ROOTS = [(9, 26, 11, 0.0), (13, 27, 6, 1.8), (19, 26, 15, 3.1), (44, 26, 14, 0.7),
         (50, 27, 8, 2.4), (54, 26, 12, 4.0)]
## A creature leaving the hive, small (relative to its top left); outlined when drawn.
MINI_BUG = {(2, 0): "W2", (3, 0): "Y2", (1, 1): "W2", (2, 1): "W2",
            (0, 2): "S4", (1, 2): "S3", (2, 2): "R0", (3, 2): "S3", (4, 2): "R1", (5, 2): "Y",
            (1, 3): "S2", (2, 3): "S3", (3, 3): "R0", (4, 3): "R1"}

# --- damage stages (BroodCoreData.stages): 0 whole, 1 cracked, 2 broken ------------------------
## Chunks knocked out of the comb's rim: (x from the comb's center, y, radius, first stage).
BITES = [(14.5, 34.0, 4.0, 1), (-12.5, 41.0, 3.4, 1), (-16.0, 29.0, 3.6, 2), (10.0, 44.0, 3.2, 2),
         (5.0, 26.0, 2.0, 2)]
## Cracks of lava over the comb: polylines (x from the comb's center, y), first stage.
LAVA_CRACKS = [([(-7, 26), (-4, 30), (-7, 34), (-5, 39)], 1), ([(8, 28), (5, 32), (8, 37)], 1),
               ([(2, 40), (0, 43), (2, 46)], 2), ([(-11, 33), (-9, 37), (-10, 40)], 2)]
## Stage 2: holes through the comb (x from its center, y) and its heart, torn open (center x, y, rx, ry).
HOLES = [(-7, 44), (8, 31), (-3, 28)]
HEART = (-0.5, 37.0, 4.6, 4.4)
## Stage 2: the comb's point broke off below about this row (it lies on the floor).
TIP_CUT = 45
## Roots that broke, by stage: index in ROOTS -> length left.
BROKEN_ROOTS = [{}, {1: 3, 4: 4}, {0: 5, 1: 3, 3: 7, 4: 3, 5: 6}]
## Extra threads of lava that drip from the comb's lower edge (x from its center), by stage.
DRIPS = [[], [-8, 6], [-10, -4, 5, 11]]
## Pieces lying on the floor: (cx, cy, rx, ry, kind, first stage); kinds comb, brick, tip.
FLOOR_PIECES = [(15.5, 56.0, 2.6, 1.8, "comb", 1), (48.5, 56.5, 2.4, 1.6, "brick", 1),
                (42.0, 55.5, 3.8, 2.2, "tip", 2), (9.5, 57.0, 2.0, 1.4, "brick", 2),
                (22.5, 57.2, 1.8, 1.2, "comb", 2)]
## Moss drapes torn short (x), by stage, and the slab's corners left bare of moss.
TORN_MOSS = [set(), {13, 14, 49, 50, 51, 54, 55, 56, 57}, {7, 8, 9, 12, 13, 14, 16, 17, 43, 44, 45, 47, 48, 49, 50}]
BARE_MOSS = [set(), set(), set(range(51, 58)) | {6, 7}]


class Canvas:
    def __init__(self, size):
        self.size = size
        self.px = {}

    def set(self, x, y, c):
        if 0 <= x < self.size and 0 <= y < self.size:
            self.px[(x, y)] = c

    def over(self, other):
        self.px.update(other.px)

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

    def shifted(self, dx, dy, keep=None):
        out = Canvas(self.size)
        for (x, y), c in self.px.items():
            if keep is None or keep(x, y):
                out.set(x + dx, y + dy, c)
        return out

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


def line(x0, y0, x1, y1):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    return pixel_perfect([(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n)) for i in range(n + 1)])


def ramp(colors, i):
    return colors[max(0, min(len(colors) - 1, int(round(i))))]


# --- the hive --------------------------------------------------------------------------------

def pose(**kw):
    p = dict(glow=1, sway=0, drip=0, squeeze=0, blaze=False, flash=False, cracks=0, hive_dy=0,
             ledge_dy=(0, 0), ring=0, ring_hot=True, peek=False, bugs=(), fx=(), cool=0, stage=0,
             split=0)
    p.update(kw)
    return p


def ledge_bottom(x):
    """The slab's ragged lower edge."""
    return 26 + (1 if (x // 3 * 5) % 7 < 2 else 0) - (1 if x in (LEDGE_X0, LEDGE_X1) else 0)


def draw_ledge(p):
    c = Canvas(CELL)
    stage = p["stage"]
    for x in range(LEDGE_X0, LEDGE_X1 + 1):
        top = LEDGE_TOP + (1 if x in (LEDGE_X0, LEDGE_X1) else 0)
        bottom = ledge_bottom(x)
        light = 1 if x <= LEDGE_X0 + 2 else -1 if x >= LEDGE_X1 - 1 else 0
        for y in range(top, bottom + 1):
            if y == LEDGE_TOP:
                col = 4
            elif y <= LEDGE_TOP + 2:
                # bricks of the top face, their joints offset from course to course
                col = 2 if (x + (4 if y == LEDGE_TOP + 2 else 0)) % 8 == 0 else 3
            elif y == LEDGE_TOP + 3:
                col = 1
            elif y == LEDGE_TOP + 4:
                col = 2
            elif y == bottom:
                col = 0
            else:
                col = 0 if (x * 5) % 11 == 0 else 1
            c.set(x, y, ramp(STONE, col + light))
    for x0, lengths in (MOSS_LEFT, MOSS_RIGHT):
        for i, n in enumerate(lengths):
            x = x0 + i
            if x in BARE_MOSS[stage]:
                continue
            if x in TORN_MOSS[stage]:
                n = 0
            if (x * 3) % 7 < 3 and LEDGE_X0 < x < LEDGE_X1 and n > 0:
                c.set(x, LEDGE_TOP - 1, "M2")  # tufts break the slab's straight top
            for y in range(LEDGE_TOP, LEDGE_TOP + 3 + n):
                if (x, y) not in c.px and y > ledge_bottom(x) + 1:
                    break
                k = y - LEDGE_TOP
                if k == 0:
                    col = "M3" if x < 30 else "M2"
                elif k < 3:
                    col = "M2" if (x + k) % 3 else "M1"
                elif k == 2 + n:
                    col = "M0"
                else:
                    col = "M1"
                c.set(x, y, col)
    if stage >= 1:
        # a corner of the slab broke off; its broken face is the stone's dark inside
        chip = {q for q in c.px if (q[0] - (LEDGE_X1 - 4)) - (q[1] - LEDGE_TOP) >= 1 and q[1] <= LEDGE_TOP + 4}
        if stage >= 2:
            chip |= {q for q in c.px if (LEDGE_X0 + 3 - q[0]) + (q[1] - 23) >= 2 and q[1] >= 22}
        for q in chip:
            del c.px[q]
        for (x, y) in list(c.px):
            if any(n in chip for n in ((x + 1, y), (x - 1, y), (x, y - 1), (x, y + 1))):
                c.px[(x, y)] = "R1"
    if stage >= 2:
        # a crack right through the slab
        pts = line(37, LEDGE_TOP - 1, 35, 21) + line(35, 21, 38, 24) + line(38, 24, 37, 27)
        for (x, y) in pts:
            if (x, y) in c.px:
                c.px[(x, y)] = "O" if y <= LEDGE_TOP + 2 else "R0"
                if (x + 1, y) in c.px and (x + 1, y) not in pts:
                    c.px[(x + 1, y)] = "R3" if y <= LEDGE_TOP + 2 else "R2"
    return c


def hive_halfwidth(y, squeeze=0):
    t = (y + 0.5 - HIVE_TOP) / (HIVE_TIP + 1 - HIVE_TOP)
    if t < 0 or t > 1:
        return -1
    return (HIVE_HW - squeeze) * (1 - t ** 2.2) ** 0.6


def comb_cell(x, y):
    """Distances from a pixel to the two nearest cell centers of the honeycomb (hexagons 6 px
    apart, every other row offset by half a cell): a wall where they are about equal."""
    best = []
    j0 = int(y // 3.5)
    for j in range(j0 - 1, j0 + 3):
        off = 3.0 if j % 2 else 0.0
        i0 = int((x - off) // 6)
        for i in range(i0 - 1, i0 + 3):
            best.append(math.hypot(x + 0.5 - (i * 6 + off + 0.5), (y + 0.5 - (j * 3.5 + 1.0)) * 1.15))
    best.sort()
    return best[0], best[1]


def draw_hive(p):
    """The honeycomb: walls of bright lava around darker cells, hottest at its heart. From stage 1
    on chunks are missing from its rim and cracks of lava run over it; at stage 2 its point broke
    off, holes go through it and its glowing heart shows through a tear."""
    c = Canvas(CELL)
    cx = HIVE_CX + p["sway"]
    glow = p["glow"]
    stage = p["stage"]
    bites = [(cx + dx, y, r) for dx, y, r, first in BITES if 0 < first <= stage]
    for y in range(HIVE_TOP, HIVE_TIP + 1):
        hw = hive_halfwidth(y, p["squeeze"])
        for x in range(int(cx - hw) - 1, int(cx + hw) + 2):
            if abs(x + 0.5 - cx) > hw:
                continue
            if any(math.hypot(x + 0.5 - bx, y + 0.5 - by) < r for bx, by, r in bites):
                continue
            if stage >= 2 and y > TIP_CUT + (x * 5) % 3 - 1:
                continue
            d1, d2 = comb_cell(x - int(cx), y - HIVE_TOP)
            wall = d2 - d1 < 1.25
            d = math.hypot((x + 0.5 - (cx - 1.5)) / 13.0, (y + 0.5 - 36.0) / 12.0)
            heat = glow + 1.2 - 2.4 * d - 0.5 * (x + 0.5 - cx) / max(hw, 1)
            if y <= HIVE_TOP + 2:  # in the slab's shadow
                heat -= 1
            if wall:
                col = ramp(LAVA, heat + 2)
            else:
                col = ramp(LAVA, heat + (0.6 if d1 < 1.0 else -0.3))
            c.set(x, y, col)
    # the rim: a tone darker so the comb reads as a solid lump
    for (x, y) in list(c.px):
        if any(n not in c.px for n in ((x + 1, y), (x - 1, y), (x, y + 1))):
            c.px[(x, y)] = LAVA[max(1, LAVA.index(c.px[(x, y)]) - 1)]
    # where a chunk broke off, its dark broken face
    for (x, y) in list(c.px):
        if any(math.hypot(x + 0.5 - bx, y + 0.5 - by) < r + 1.2 for bx, by, r in bites):
            c.px[(x, y)] = "S1" if (x + y) % 3 else "S0"
    for pts, first in LAVA_CRACKS:
        if not 0 < first <= stage:
            continue
        path = []
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            path += line(int(cx) + ax, ay, int(cx) + bx, by)
        for (x, y) in path:
            if (x, y) in c.px:
                c.px[(x, y)] = "S0"
                if (x + 1, y) in c.px and (x + 1, y) not in path:
                    c.px[(x + 1, y)] = "Y" if glow >= 2 else "S4"
    if stage >= 2:
        draw_heart(c, cx, glow)
        for dx, y in HOLES:
            x = int(cx) + dx
            for q, col in (((x, y), "O"), ((x + 1, y), "O"), ((x - 1, y + 1), "O"), ((x, y + 1), "O"),
                           ((x + 1, y + 1), "O"), ((x + 2, y + 1), "S1"), ((x, y + 2), "S1"), ((x + 1, y + 2), "S0")):
                if q in c.px:
                    c.px[q] = col
    if p["peek"]:
        # creatures about to hatch light up a few cells low on the comb
        low = 2 if stage >= 2 else 0
        for x, y in ((int(cx) - 5, 43), (int(cx) + 3, 45 - low), (int(cx) - 1, 47 - low)):
            c.set(x, y, "Y2")
            c.set(x + 1, y, "Y")
    if p["blaze"]:
        c.remap(BLAZE)
    return c


def draw_heart(c, cx, glow):
    """Stage 2: the comb is torn open over its heart, a white-hot lump that throbs with the glow."""
    hx, hy, rx, ry = HEART
    hx += cx
    grow = 0.4 if glow >= 2 else 0.0
    for y in range(int(hy - ry) - 1, int(hy + ry) + 2):
        for x in range(int(hx - rx) - 1, int(hx + rx) + 2):
            if (x, y) not in c.px or not in_ellipse(x, y, hx, hy, rx + grow, ry + grow):
                continue
            q = math.hypot((x + 0.5 - hx) / (rx + grow), (y + 0.5 - hy) / (ry + grow))
            l = lit((x + 0.5 - hx) / rx, (y + 0.5 - hy) / ry)
            if q > 0.78:
                col = "S0" if l > -0.2 else "S1"  # the torn edge: in shadow on the side facing the light
            elif q > 0.55:
                col = "S4"
            elif q > 0.3:
                col = "Y"
            else:
                col = "Y2"
            c.px[(x, y)] = col


def draw_roots(p, hive):
    c = Canvas(CELL)
    broken = BROKEN_ROOTS[p["stage"]]
    for i, (x0, y0, n, phase) in enumerate(ROOTS):
        n = broken.get(i, n)
        pts = []
        for k in range(n):
            sway = p["sway"] * k / n
            pts.append((x0 + round(0.7 * math.sin(k * 0.55 + phase) + sway), y0 + k))
        pts = pixel_perfect(pts)
        for k, (x, y) in enumerate(pts):
            c.set(x, y, "R1")
            if k < len(pts) // 2:  # thick at the root, lit on its left
                c.set(x - 1, y, "R2")
        tip = pts[-1]
        if i in broken:
            # snapped: a pale splinter instead of a drop
            c.set(tip[0], tip[1], "R3")
            c.set(tip[0] + (1 if i % 2 else -1), tip[1] + 1, "R2")
            continue
        # a drop of lava gathers at the tip; it swells and falls on alternate frames
        swell = (p["drip"] + i) % 3
        c.set(tip[0], tip[1] + 1, "S3")
        if swell >= 1:
            c.set(tip[0], tip[1] + 2, "Y" if swell == 2 else "S4")
    return c


def draw_pool(p):
    """The little pool its drips feed, on the floor under the comb's point; it grows as the hive
    breaks, and the pieces that fell off lie around it."""
    c = Canvas(CELL)
    cx = HIVE_CX + p["sway"]
    hot = p["drip"] == 4
    stage = p["stage"]
    rx, ry = 7.5 + 1.5 * stage, 2.1 + 0.3 * stage
    for y in range(GROUND - 4, GROUND + 1):
        for x in range(int(cx) - 13, int(cx) + 14):
            if not in_ellipse(x, y, cx, GROUND - 0.5, rx, ry):
                continue
            q = math.hypot((x + 0.5 - cx) / rx, (y + 0.5 - (GROUND - 0.5)) / ry)
            c.set(x, y, "S1" if q > 0.8 else "S2" if q > 0.5 else ("Y" if hot else "S3"))
    if hot:
        for x, y in ((int(cx) - 4, GROUND - 3), (int(cx) + 4, GROUND - 3)):
            c.set(x, y, "S4")
    for px, py, prx, pry, kind, first in FLOOR_PIECES:
        if not 0 < first <= stage:
            continue
        for y in range(int(py - pry) - 1, int(py + pry) + 2):
            for x in range(int(px - prx) - 1, int(px + prx) + 2):
                if not in_ellipse(x, y, px, py, prx, pry) or y > GROUND:
                    continue
                l = lit((x + 0.5 - px) / prx, (y + 0.5 - py) / pry)
                if kind == "brick":
                    col = ramp(STONE, 2 + l * 2.2)
                else:
                    wall = (x + (y % 2) * 2) % 4 == 0
                    col = ramp(LAVA, (2.8 if wall else 1.6) + l * 1.4)
                c.set(x, y, col)
        if kind == "tip":
            c.set(int(px - prx) + 1, int(py), "Y")  # its broken end still glows
    return c


def comb_bottom(c, x, default):
    rows = [y for (px, y) in c.px if px == x]
    return max(rows) if rows else default


def draw_drip(p, c, hive):
    """The drop that gathers at the comb's point and falls into the pool, and the threads of lava
    that leak from a broken comb, each on its own beat."""
    x = int(HIVE_CX + p["sway"])
    tip = comb_bottom(hive, x, HIVE_TIP)
    stage = p["drip"]
    if stage == 1:
        c.set(x, tip + 1, "S4")
    elif stage == 2:
        c.set(x, tip + 1, "S4")
        c.set(x, tip + 2, "Y")
    elif stage == 3:
        c.set(x, tip + 1, "S3")
        c.set(x, tip + 4, "Y")
        c.set(x, tip + 5, "S4")
    for i, dx in enumerate(DRIPS[p["stage"]]):
        x = int(HIVE_CX + p["sway"]) + dx
        bottom = comb_bottom(hive, x, -1)
        if bottom < 0:
            continue
        beat = (p["drip"] + i * 2) % 4
        c.set(x, bottom + 1, "S3")
        if beat >= 1:
            c.set(x, bottom + 2, "S4")
        if beat == 2:
            c.set(x, bottom + 3, "Y")
        if beat == 3:
            c.set(x, bottom + 5, "Y")


def crack_lines(n, cx):
    """Dark cracks that split the comb as it dies."""
    cx = int(cx)
    lines = [line(cx - 2, 27, cx + 1, 33) + line(cx + 1, 33, cx - 1, 40) + line(cx - 1, 40, cx + 1, 47),
             line(cx - 10, 30, cx - 5, 35) + line(cx - 5, 35, cx - 6, 41),
             line(cx + 11, 29, cx + 6, 36) + line(cx + 6, 36, cx + 7, 42)]
    return [pt for ln in lines[:n] for pt in ln]


def split_open(upper, hive, k, cx):
    """The comb splits down its middle, each half pushed `k` px aside, and the white-hot inside
    shows in the gap (the queen is coming out)."""
    out = Canvas(CELL)
    for (x, y), col in upper.px.items():
        out.set(x - k if x < cx else x + k, y, col)
    rows = sorted({y for (x, y) in hive.px if abs(x - cx) <= 1})
    for y in rows:
        for x in range(cx - k, cx + k):
            out.set(x, y, "Y2" if abs(x + 0.5 - cx) < k * 0.6 else "Y")
    if k >= 3 and rows:
        # light pours down to the floor
        for y in range(rows[-1] + 1, GROUND - 2):
            out.set(cx - 1, y, "Y")
            out.set(cx, y, "Y2")
    return out


def draw_core(p):
    hive = draw_hive(p)
    if p["cracks"]:
        for (x, y) in crack_lines(p["cracks"], HIVE_CX + p["sway"]):
            if (x, y) in hive.px:
                hive.px[(x, y)] = "S0"
                if (x + 1, y) in hive.px:
                    hive.px[(x + 1, y)] = "Y2"
    roots = draw_roots(p, hive)
    ledge = draw_ledge(p)
    upper = Canvas(CELL)
    upper.over(hive.shifted(0, p["hive_dy"], keep=lambda x, y: y + p["hive_dy"] <= GROUND))
    upper.over(roots.shifted(0, p["hive_dy"] // 2))
    if p["hive_dy"] == 0:
        draw_drip(p, upper, hive)
    if p["split"]:
        upper = split_open(upper, hive, p["split"], int(HIVE_CX + p["sway"]))
    body = Canvas(CELL)
    body.over(upper)
    left_dy, right_dy = p["ledge_dy"]
    if left_dy or right_dy:
        # the slab breaks in two as it falls
        body.over(ledge.shifted(0, left_dy, keep=lambda x, y: x < 30))
        body.over(ledge.shifted(0, right_dy, keep=lambda x, y: x > 31))
    else:
        body.over(ledge)
    for step in COOL_STEPS[:p["cool"]]:
        body.remap(step)
    pool = draw_pool(p) if p["hive_dy"] == 0 else Canvas(CELL)
    body.outline()
    pool.outline(only_empty_of=body)
    pool.over(body)
    body = pool
    if p["flash"]:
        body.remap({c: "W" for c in PALETTE if c != "O"})
    if p["ring"]:
        ring = ground_ring(p["ring"], p["ring_hot"])
        ring.over(body)
        body = ring
    for bx, by in p["bugs"]:
        add_bug(body, bx, by)
    add_fx(body, p["fx"])
    return body


def ground_ring(rx, hot):
    """The glowing ring that opens on the floor under it when it breeds."""
    c = Canvas(CELL)
    cx, cy = HIVE_CX, GROUND - 3.5
    ry = max(1.5, rx * 0.3)
    for y in range(int(cy - ry) - 2, int(cy + ry) + 3):
        for x in range(int(cx - rx) - 2, int(cx + rx) + 3):
            if not in_ellipse(x, y, cx, cy, rx + 0.6, ry + 0.6):
                continue
            if in_ellipse(x, y, cx, cy, rx - 1.2, ry - 1.2):
                continue
            front = y + 0.5 > cy
            c.set(x, y, ("Y2" if front else "Y") if hot else ("S4" if front else "S3"))
    c.outline("S1")
    return c


def add_bug(c, x, y):
    bug = Canvas(c.size)
    for (dx, dy), col in MINI_BUG.items():
        bug.set(x + dx, y + dy, col)
    bug.outline(only_empty_of=c)
    c.over(bug)


def add_fx(canvas, fx):
    """Drops of lava, sparks and chunks: (x, y, size, color); size 1 is one pixel, 2 a 2x2 drop."""
    if not fx:
        return
    drops = Canvas(canvas.size)
    for x, y, size, col in fx:
        if size == 1:
            drops.set(x, y, col)
        else:
            drops.set(x, y, "Y2" if col == "Y" else col)
            drops.set(x + 1, y, col)
            drops.set(x, y + 1, col)
            drops.set(x + 1, y + 1, "S2" if col in LAVA else "R1")
    drops.outline(only_empty_of=canvas)
    canvas.over(drops)


# --- animations -----------------------------------------------------------------------------

def idle():
    glow = [0, 1, 2, 3, 2, 1]
    drip = [0, 1, 2, 3, 4, 0]
    return [pose(glow=glow[i], drip=drip[i]) for i in range(6)]


def walk():
    # It never walks: the comb swings a pixel to each side under its slab, still pulsing.
    sway = [0, 1, 1, 0, -1, -1]
    glow = [1, 2, 3, 3, 2, 1]
    return [pose(glow=glow[i], sway=sway[i], drip=i % 3) for i in range(6)]


def attack():
    # It squeezes while its heart heats up, a creature pushes out of a cell low on the comb and
    # flies off ahead of it, and the comb relaxes.
    return [
        pose(glow=1),
        pose(glow=2, squeeze=0.6),
        pose(glow=3, squeeze=1.2, peek=True),
        pose(glow=3, squeeze=1.6, peek=True, blaze=True),
        pose(glow=3, squeeze=0.4, bugs=[(33, 49)], fx=[(30, 51, 1, "Y")]),
        pose(glow=2, bugs=[(40, 44)], fx=[(35, 50, 1, "S4")]),
        pose(glow=2, bugs=[(48, 40)]),
        pose(glow=1, bugs=[(56, 37)]),
    ]


def special():
    # Breeding (it plays over the windup and the pose after it, the brood appearing about 70% in):
    # the comb blazes, a ring of light opens on the floor, the swarm bursts out of the comb.
    return [
        pose(glow=2, sway=-1),
        pose(glow=3, ring=8),
        pose(glow=3, ring=14, peek=True),
        pose(glow=3, ring=20, peek=True, blaze=True, sway=1),
        pose(glow=3, ring=24, peek=True, blaze=True, sway=-1),
        pose(glow=3, ring=26, blaze=True, bugs=[(13, 42), (45, 44), (35, 52)],
             fx=[(26, 49, 1, "Y"), (36, 50, 1, "Y2")]),
        pose(glow=2, ring=26, ring_hot=False, bugs=[(5, 36), (52, 37), (44, 53)],
             fx=[(20, 47, 1, "S4"), (44, 46, 1, "S4")]),
        pose(glow=1, bugs=[(3, 30), (57, 32)]),
    ]


def hurt():
    return [
        pose(flash=True, glow=2),
        pose(glow=3, sway=-1, drip=2, fx=[(14, 40, 1, "S4"), (47, 38, 1, "S4")]),
        pose(glow=2, sway=1, drip=3),
        pose(glow=1),
    ]


def rubble(cool, embers=()):
    """The pile it falls into: stones of the slab, pieces of comb, lava; `cool` 0..3."""
    c = Canvas(CELL)
    cx = HIVE_CX
    for y in range(GROUND - 6, GROUND + 1):
        for x in range(4, 60):
            if in_ellipse(x, y, cx, GROUND - 2.0, 22.0, 3.6):
                q = math.hypot((x + 0.5 - cx) / 22.0, (y + 0.5 - (GROUND - 2.0)) / 3.6)
                c.set(x, y, "S1" if q > 0.85 else "S2" if q > 0.6 else "S3" if q > 0.3 else "S4")
    # stones: (cx, cy, rx, ry, moss on top)
    stones = [(18.5, 52.5, 6.5, 4.5, True), (44.5, 52.5, 6.0, 4.2, False), (31.5, 54.5, 4.0, 2.8, False),
              (10.5, 55.5, 3.2, 2.3, False), (52.5, 56.0, 3.0, 2.0, True)]
    comb = (31.5, 48.5, 6.5, 5.5)
    ccx, ccy, crx, cry = comb
    for y in range(int(ccy - cry) - 1, int(ccy + cry) + 2):
        for x in range(int(ccx - crx) - 1, int(ccx + crx) + 2):
            if not in_ellipse(x, y, ccx, ccy, crx, cry):
                continue
            wall = (y - 43) % 4 == 0 or (x + (2 if (y - 43) // 4 % 2 else 0)) % 5 == 0
            l = lit((x + 0.5 - ccx) / crx, (y + 0.5 - ccy) / cry)
            c.set(x, y, ramp(LAVA, (4 if wall else 2) + l * 1.5))
    for sx, sy, rx, ry, moss in stones:
        for y in range(int(sy - ry) - 1, int(sy + ry) + 2):
            for x in range(int(sx - rx) - 1, int(sx + rx) + 2):
                if not in_ellipse(x, y, sx, sy, rx, ry) or y > GROUND:
                    continue
                l = lit((x + 0.5 - sx) / rx, (y + 0.5 - sy) / ry)
                col = ramp(STONE, 2 + l * 2.2)
                if moss and y <= sy - ry + 1.5 and l > -0.2:
                    col = "M2" if l > 0.5 else "M1"
                c.set(x, y, col)
    for step in COOL_STEPS[:cool]:
        c.remap(step)
    c.outline()
    add_fx(c, list(embers))
    return c


def death():
    # It only dies broken (stage 2): the fall starts from the torn hive.
    falling = [
        pose(stage=2, glow=3, cracks=1, fx=[(25, 52, 1, "Y")]),
        pose(stage=2, glow=3, cracks=2, sway=1, hive_dy=1, fx=[(18, 46, 1, "S4"), (42, 50, 2, "S3")]),
        pose(stage=2, glow=2, cracks=3, hive_dy=3, cool=1, fx=[(12, 44, 1, "S4"), (50, 46, 1, "S4")]),
        pose(stage=2, glow=2, cracks=3, hive_dy=8, ledge_dy=(6, 11), cool=1),
    ]
    frames = [draw_core(p) for p in falling]
    frames.append(rubble(0, [(14, 40, 2, "S3"), (48, 38, 2, "S3"), (30, 36, 1, "Y"), (38, 42, 1, "Y")]))
    frames.append(rubble(1, [(10, 34, 1, "S4"), (52, 32, 1, "S4"), (32, 40, 1, "Y")]))
    frames.append(rubble(2, [(28, 36, 1, "S3")]))
    frames.append(rubble(3))
    return frames


## Pieces the hive throws as it cracks into a stage: (x, y, speed x, speed y, size, color), flying
## from the new wounds and falling to the floor (gravity per frame squared).
SHARDS = {
    1: [(45, 33, 3.0, -2.5, 2, "S3"), (19, 41, -3.0, -1.5, 2, "S2"), (54, 19, 2.0, -3.0, 2, "R3"),
        (50, 22, 1.0, -1.0, 1, "M2"), (38, 30, 2.0, -3.5, 1, "Y"), (24, 30, -2.0, -3.0, 1, "Y"),
        (47, 38, 2.5, -1.0, 2, "S3"), (16, 38, -1.5, -2.5, 1, "Y2"), (52, 24, 3.5, -2.0, 1, "R2")],
    2: [(16, 29, -3.0, -2.5, 2, "S3"), (42, 44, 3.0, -1.5, 2, "S2"), (31, 47, 0.5, -1.0, 2, "S3"),
        (8, 24, -1.5, -2.0, 2, "R3"), (37, 20, 1.0, -3.5, 2, "R2"), (36, 26, 2.5, -2.5, 1, "Y"),
        (27, 33, -2.5, -3.0, 1, "Y2"), (31, 37, 0.5, -4.0, 1, "Y"), (24, 44, -2.0, -1.5, 2, "S2"),
        (45, 30, 3.5, -3.0, 1, "Y2"), (54, 20, 2.0, -2.5, 1, "M2")],
}
SHARD_GRAVITY = 1.4


def crack(stage):
    """Entering a stage: the hive blazes and shudders, cracks open with a burst of comb, brick, moss
    and lava, the pieces fall to the floor and it settles in its new state (its idle's first pose)."""
    def shards(t):
        out = []
        for x, y, vx, vy, size, col in SHARDS[stage]:
            px = round(x + vx * t)
            py = round(min(y + vy * t + SHARD_GRAVITY * t * t, GROUND - 1))
            out.append((px, py, size, col))
        return out
    return [
        pose(stage=stage - 1, glow=3, blaze=True, sway=-1),
        pose(stage=stage, glow=3, blaze=True, sway=1, fx=shards(1)),
        pose(stage=stage, glow=3, sway=-1, fx=shards(2)),
        pose(stage=stage, glow=2, fx=shards(3)),
        pose(stage=stage, glow=2, fx=shards(4.2)),
        pose(stage=stage, glow=1, drip=1),
    ]


def open_queen():
    """Broken hive only (stage 2): it shudders, its comb splits down the middle and opens wide on
    its white-hot inside while light pours to the floor: the queen comes out as it ends."""
    return [
        pose(stage=2, glow=3, sway=-1),
        pose(stage=2, glow=3, sway=1, blaze=True),
        pose(stage=2, glow=3, blaze=True, split=1),
        pose(stage=2, glow=3, blaze=True, split=2, fx=[(24, 34, 1, "Y"), (39, 32, 1, "Y")]),
        pose(stage=2, glow=3, blaze=True, split=4, fx=[(20, 30, 1, "Y2"), (43, 29, 1, "Y"), (30, 22, 1, "Y")]),
        pose(stage=2, glow=3, blaze=True, split=5, fx=[(16, 27, 1, "Y"), (47, 26, 1, "Y2"), (28, 16, 1, "Y"),
                                                       (36, 15, 1, "Y2")]),
        pose(stage=2, glow=3, blaze=True, split=6, fx=[(12, 24, 2, "Y"), (50, 22, 2, "Y"), (26, 11, 1, "Y2"),
                                                       (38, 10, 1, "Y"), (31, 13, 1, "Y2")]),
        pose(stage=2, glow=3, blaze=True, split=6, fx=[(8, 22, 1, "S4"), (55, 19, 1, "S4"), (24, 7, 1, "Y"),
                                                       (40, 6, 1, "S4")]),
    ]


# --- effects of its destruction ---------------------------------------------------------------

def warning(step, steps):
    """The ring of the blast's reach, burning on the floor, with ticks pointing at the core; an
    inner ring closes in on the core as the fuse runs out (`step` of `steps`)."""
    c = Canvas(FX_CELL)
    ctr = FX_CELL / 2.0
    inner = (BLAST_RADIUS - 14) * (1 - step / (steps - 1)) + 4
    hot = step % 2 == 0
    for y in range(FX_CELL):
        for x in range(FX_CELL):
            r = math.hypot(x + 0.5 - ctr, y + 0.5 - ctr)
            ang = math.atan2(y + 0.5 - ctr, x + 0.5 - ctr)
            seg = (ang + math.pi) / math.tau
            if BLAST_RADIUS - 2.0 <= r <= BLAST_RADIUS:
                front = r > BLAST_RADIUS - 1.0
                c.set(x, y, ("S4" if front else "S3") if hot else ("S3" if front else "S2"))
            elif BLAST_RADIUS - 6.0 <= r < BLAST_RADIUS - 2.0 and abs(seg * 12 - round(seg * 12)) / 12 * math.tau * r < 0.8:
                c.set(x, y, "S3" if hot else "S2")
            elif abs(r - inner) <= 1.0 and int(seg * 20 + step * 0.5) % 2 == 0:
                c.set(x, y, "Y" if hot else "S4")
    c.outline()
    return c


def blast(step):
    """The explosion: a white flash grows into a ring of fire out to the blast's radius, which
    breaks into smoke and embers."""
    c = Canvas(FX_CELL)
    ctr = FX_CELL / 2.0
    outer = [12, 26, 37, 44, 44, 44][step]
    hole = [0, 8, 24, 36, 39, 0][step]
    for y in range(FX_CELL):
        for x in range(FX_CELL):
            dx, dy = x + 0.5 - ctr, y + 0.5 - ctr
            r = math.hypot(dx, dy)
            ang = math.atan2(dy, dx)
            edge = outer + (1.5 * math.sin(ang * 9 + step) if step < 4 else 0)
            if step < 5 and hole <= r <= edge:
                f = (r - hole) / max(edge - hole, 1)  # 0 inner side, 1 outer side
                if step == 0:
                    col = "Y2" if r < 7 else "Y" if r < 10 else "S4"
                elif step <= 2:
                    col = "Y2" if f < 0.35 else "Y" if f < 0.65 else "S4" if f < 0.88 else "S3"
                elif step == 3:
                    col = "Y" if f < 0.4 else "S4" if f < 0.8 else "S3"
                else:
                    # the ring breaks up
                    if int((ang + math.pi) / math.tau * 14) % 2 == 0:
                        continue
                    col = "S3" if f < 0.5 else "S2"
                c.set(x, y, col)
    # smoke puffs around the rim at the end
    if step == 5:
        for k in range(14):
            a = k / 14 * math.tau + 0.2
            rr = 41 + (k % 3)
            px, py = ctr + rr * math.cos(a), ctr + rr * math.sin(a)
            size = 3.0 if k % 2 else 2.3
            for y in range(int(py - size) - 1, int(py + size) + 2):
                for x in range(int(px - size) - 1, int(px + size) + 2):
                    if in_ellipse(x, y, px, py, size, size):
                        l = lit((x + 0.5 - px) / size, (y + 0.5 - py) / size)
                        c.set(x, y, "K2" if l > 0.2 else "K1")
    c.outline()
    sparks = {1: [(10, 20, 1, "Y"), (82, 26, 1, "Y"), (20, 80, 1, "S4"), (76, 76, 1, "Y")],
              2: [(4, 40, 1, "Y"), (90, 50, 1, "S4"), (40, 4, 1, "Y"), (54, 90, 1, "S4")],
              3: [(6, 12, 2, "S3"), (86, 84, 2, "S3"), (88, 14, 1, "Y")],
              4: [(14, 6, 1, "S4"), (2, 70, 1, "S3")],
              5: [(30, 20, 1, "S3"), (66, 72, 1, "S4"), (70, 24, 1, "S3")]}
    add_fx(c, sparks.get(step, []))
    return c


def queen_ring(step, steps):
    """Where the queen will come out (`QUEEN_RING` px around it): a ring of lava burns on the
    floor, cracks run in from it and the ground in the middle melts into a pool that boils up
    to a white flare in the last frame, when she appears."""
    c = Canvas(QUEEN_CELL)
    ctr = QUEEN_CELL / 2.0
    t = step / (steps - 1)
    pool = 3 + (QUEEN_RING - 9) * t
    hot = step % 2 == 0
    last = step == steps - 1
    for y in range(QUEEN_CELL):
        for x in range(QUEEN_CELL):
            dx, dy = x + 0.5 - ctr, y + 0.5 - ctr
            r = math.hypot(dx, dy)
            ang = math.atan2(dy, dx)
            seg = (ang + math.pi) / math.tau
            if QUEEN_RING - 2.0 <= r <= QUEEN_RING:
                # the ring turns slowly, broken in eight dashes
                if last or int(seg * 16 + step * 0.5) % 2 == 0:
                    c.set(x, y, "Y2" if last else ("S4" if r > QUEEN_RING - 1.0 else "S3"))
            elif r <= pool:
                q = r / pool
                if last:
                    col = "Y2" if q < 0.6 else "Y"
                else:
                    col = "Y2" if q < 0.25 else "Y" if q < 0.5 else "S4" if q < 0.8 else "S2"
                c.set(x, y, col)
            elif r < QUEEN_RING - 3.0:
                # six cracks run from the ring toward the middle, a little further every frame
                k = seg * 6 + 0.08 * math.sin(r * 0.6)
                if abs(k - round(k)) * math.tau / 6 * r < 0.7 and r > QUEEN_RING - 3.0 - (QUEEN_RING - pool) * min(1.0, 0.3 + t):
                    c.set(x, y, "S3" if hot else "S2")
    c.outline()
    if last:
        add_fx(c, [(int(ctr) - 9, int(ctr) - 14, 1, "Y"), (int(ctr) + 8, int(ctr) - 16, 1, "Y2"),
                   (int(ctr) - 2, int(ctr) - 20, 2, "Y"), (int(ctr) + 14, int(ctr) - 6, 1, "S4")])
    elif step >= steps // 2:
        add_fx(c, [(int(ctr) - 4 + step, int(ctr) - 6 - step, 1, "Y"), (int(ctr) + 5 - step // 2, int(ctr) - 4 - step, 1, "S4")])
    return c


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
        strip([draw_core(p) for p in make()], os.path.join(OUT, "nucleo_cria_%s.png" % name))
        # the same animation, cracked (s2) and broken (s3)
        for stage in (1, 2):
            strip([draw_core(dict(p, stage=stage)) for p in make()],
                  os.path.join(OUT, "nucleo_cria_%s_s%d.png" % (name, stage + 1)))
    for stage in (1, 2):
        strip([draw_core(p) for p in crack(stage)], os.path.join(OUT, "nucleo_cria_crack_s%d.png" % (stage + 1)))
    strip([draw_core(p) for p in open_queen()], os.path.join(OUT, "nucleo_cria_open_s3.png"))
    strip(death(), os.path.join(OUT, "nucleo_cria_death.png"))
    strip([warning(i, 6) for i in range(6)], os.path.join(OUT, "nucleo_cria_warning.png"))
    strip([blast(i) for i in range(6)], os.path.join(OUT, "nucleo_cria_blast.png"))
    strip([queen_ring(i, 8) for i in range(8)], os.path.join(OUT, "nucleo_cria_queen_ring.png"))
