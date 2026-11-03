"""Draws the Reina volcánica's art (temple mini boss, island 3) pixel by pixel.

The queen of the Núcleo de cría's brood: the cría volcánica grown big and fearsome (same palette
family and build, see tools/make_cria_volcanica_art.py). A lava wasp: a thorax of dark rock with
glowing cracks, a long abdomen ringed with bands of bright lava and dark rock ending in an obsidian
stinger with a white-hot tip, a crowned head (a crest of lava crystal, a big glowing eye, lava
mandibles, feelers), legs hanging under it and two pairs of wings of fire (solid pixels; where the
near wing lies over the body it takes a darker tone, as if seen through). It flies over its own
shadow. Its animations: idle (hovers, wings beating, the abdomen pulsing), walk (flies leaning
forward), attack (backs off and rises while it curls its abdomen under itself until the stinger
points forward, then lunges with the stinger out), special (rises, flares up and a burst of sparks
throws two little crías out to its sides: the summon), hurt and death (its wings fold, it drops to
the floor, burns out and crumbles into ash around its cracked crown).

Writes into `assets/sprites/reina_volcanica/`:
    reina_volcanica_<animation>.png   64x64 cells, facing right, shadow's lowest row 57: idle,
                                      walk, attack, special, hurt, death

    python tools/make_reina_volcanica_art.py
Then tools/make_temple_enemy_frames.gd builds its SpriteFrames as for every temple enemy, and
tools/enemy_aseprite.lua keeps an editable `source/reina_volcanica.aseprite`. Needs Pillow.
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "reina_volcanica")
CELL = 64
## Lowest row of its shadow on the floor (it flies: the shadow stands for its feet).
GROUND = 57

PALETTE = {
    "O": (26, 12, 16),     # outline
    "SH": (30, 20, 30),    # shadow on the floor
    # rock chitin
    "B0": (40, 24, 30),
    "B1": (70, 38, 40),
    "B2": (106, 60, 52),
    "B3": (146, 90, 68),
    # lava
    "S0": (58, 16, 22),
    "S1": (110, 28, 24),
    "S2": (176, 52, 26),
    "S3": (228, 98, 34),
    "S4": (250, 150, 52),
    "Y": (255, 206, 74),
    "Y2": (255, 244, 176),
    # wings of fire
    "F0": (196, 92, 58),   # the near wing over the body
    "F1": (255, 214, 150),
    "F2": (252, 160, 84),
    # lava crystal of the crown
    "C0": (124, 22, 34),
    "C1": (220, 58, 44),
    "C2": (255, 140, 84),
    # ash
    "A1": (88, 78, 80),
    "A2": (128, 116, 112),
    "W": (255, 243, 224),  # hurt flash
}
LAVA = ["S0", "S1", "S2", "S3", "S4", "Y", "Y2"]
CHITIN = ["B0", "B1", "B2", "B3"]
## Death: each step cools the lava and the wings.
COOL_STEPS = [
    {"Y2": "Y", "Y": "S4", "S4": "S3", "F1": "F2"},
    {"Y": "S3", "S4": "S2", "S3": "S2", "S2": "S1", "B3": "B2", "F1": "F2", "F2": "F0", "C2": "C1"},
    {"S3": "S1", "S2": "S1", "S1": "S0", "B2": "B1", "F2": "S1", "F0": "S1", "C1": "C0"},
]
BLAZE = {"S0": "S1", "S1": "S2", "S2": "S3", "S3": "S4", "S4": "Y", "Y": "Y2", "B1": "B2", "B2": "B3"}

## Rest pose: thorax and head (center x, center y, radius x, radius y).
THORAX = (35.0, 29.0, 7.0, 7.5)
HEAD = (45.0, 24.0, 5.0, 4.8)
## The abdomen: segments from the back of the thorax to the tip (radius of each), how far apart,
## and the direction of the first one (degrees, 180 = straight back, 90 = down).
ABDOMEN_ROOT = (29.0, 32.5)
ABDOMEN_RADII = [6.4, 7.2, 7.4, 7.0, 6.2, 5.2, 4.0, 2.8]
ABDOMEN_STEP = 3.0
ABDOMEN_ANGLE = 160.0
## At rest the abdomen droops a little more at every segment.
ABDOMEN_DROOP = -2.0
## Where the wings join the thorax, and each beat's angle (degrees, 0 = forward, -90 = up).
WING_ROOT = (34.0, 23.0)
WING_ANGLE = {"up": -108, "mid": -140, "down": -170, "fold": 174, "spread": -82}
## The crown: crystal spikes on top of the head (x from the head's center, height, lean).
CROWN = [(-4, 4, -1), (-2, 6, -1), (0, 7, 0), (2, 5, 1)]


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


def ramp(colors, i):
    return colors[max(0, min(len(colors) - 1, int(round(i))))]


def seam(top, under, color="B0"):
    """Where a part lies over another, its edge becomes a dark seam instead of a second outline."""
    for (x, y) in list(top.px):
        if any(n in under.px and n not in top.px for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))):
            top.px[(x, y)] = color


def blob(c, cx, cy, rx, ry, color_at):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if in_ellipse(x, y, cx, cy, rx, ry):
                c.set(x, y, color_at(x, y, lit((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)))


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
    return pixel_perfect([(int(round(x0 + (x1 - x0) * i / n)), int(round(y0 + (y1 - y0) * i / n)))
                          for i in range(n + 1)])


# --- the queen -------------------------------------------------------------------------------

def pose(**kw):
    p = dict(dx=0, dy=0, wing="up", glow=1, tilt=0, lift=0.0, curl=0.0, step=ABDOMEN_STEP, legs="hang",
             sting=0, phase=0, crown=0, ring=0, ring_hot=True, blaze=False, flash=False, cool=0, shadow=True, fx=(), streak=())
    p.update(kw)
    return p


def abdomen_segments(p, ox, oy):
    """Centers and radii of the abdomen's segments, root first. `lift` turns the whole abdomen
    (positive = up), `curl` bends it a bit more at every segment (negative = under the body)."""
    x, y = ABDOMEN_ROOT[0] + ox, ABDOMEN_ROOT[1] + oy
    angle = ABDOMEN_ANGLE + p["lift"]
    segs = []
    for i, r in enumerate(ABDOMEN_RADII):
        if i:
            a = math.radians(angle)
            x += math.cos(a) * p["step"]
            y += math.sin(a) * p["step"]
            angle += p["curl"] + ABDOMEN_DROOP
        segs.append((x, y, r, angle))
    return segs


def draw_abdomen(p, ox, oy):
    glow = p["glow"]
    segs = abdomen_segments(p, ox, oy)
    abd = Canvas(CELL)
    # The stinger first, under the tip: obsidian, its point white-hot.
    tx, ty, tr, ta = segs[-1]
    a = math.radians(ta)
    ux, uy = math.cos(a), math.sin(a)
    length = 5 + p["sting"]
    pts = line(int(round(tx + ux * (tr - 0.5))), int(round(ty + uy * (tr - 0.5))),
               int(round(tx + ux * (tr + length))), int(round(ty + uy * (tr + length))))
    sting = Canvas(CELL)
    for k, (x, y) in enumerate(pts):
        last = k == len(pts) - 1
        sting.set(x, y, ("Y2" if glow >= 2 else "Y") if last else "S4" if k == len(pts) - 2 and glow >= 2 else
                  "B2" if k < 2 else "B1")
        if k < 2:  # thick at its root
            sting.set(x + (0 if abs(ux) > abs(uy) else 1), y + (1 if abs(ux) > abs(uy) else 0), "B0")
    abd.over(sting)
    # Bands: lava and rock, tip first, so every segment nearer the thorax overlaps the next one and
    # its rim becomes the dark seam between two bands.
    # The lava bands are a little fatter than the rock ones, so they show as wide glowing stripes.
    for i in range(len(segs) - 1, -1, -1):
        cx, cy, r, _ = segs[i]
        seg = Canvas(CELL)
        if i % 2:
            r += 0.7
            blob(seg, cx, cy, r, r * 0.92, lambda x, y, l: ramp(LAVA, glow + 1.6 + l * 1.8))
            seam(seg, abd, "S1")
        else:
            r -= 0.4
            blob(seg, cx, cy, r, r * 0.92, lambda x, y, l: ramp(CHITIN, 1.4 + l * 1.7))
            seam(seg, abd)
        abd.over(seg)
    if p["blaze"]:
        abd.remap(BLAZE)
    return abd


def wing(c, ax, ay, angle, length, width, near, body=None, phase=0):
    """A wing of fire as a slim ellipse from its root: pale and bright toward its tip, orange at its
    root, a white-hot leading edge, a vein and a trailing edge that flickers like a flame (`phase`
    moves the flicker); over the body (near wing) it takes a darker tone."""
    a = math.radians(angle)
    ux, uy = math.cos(a), math.sin(a)
    cx, cy = ax + ux * length / 2, ay + uy * length / 2
    for y in range(int(cy - length) - 1, int(cy + length) + 2):
        for x in range(int(cx - length) - 1, int(cx + length) + 2):
            vx, vy = x + 0.5 - cx, y + 0.5 - cy
            u = vx * ux + vy * uy
            v = -vx * uy + vy * ux
            if (u / (length / 2)) ** 2 + (v / width) ** 2 > 1.0:
                continue
            f = (u + length / 2) / length
            if v < -width * 0.45:
                col = "Y2" if near else "F1"
            elif v > width * 0.55 and f > 0.25:
                col = ("S3" if (x + y + phase) % 3 == 0 else "S4") if near else "S2"
            elif f < 0.35:
                col = "F2" if near else "S3"
            else:
                col = "F1" if near else "F2"
            if near and body is not None and (x, y) in body.px and col not in ("Y2", "S3", "S4"):
                col = "F0"
            c.set(x, y, col)
    # the vein: one clean line from the root out to two thirds of the wing
    inside = set(c.px)
    vein = line(int(ax), int(ay), int(round(ax + ux * length * 0.68)), int(round(ay + uy * length * 0.68)))
    for x, y in vein:
        if (x, y) in inside and c.px[(x, y)] != "Y2":
            c.set(x, y, "S3" if near else "S2")


def draw_legs(c, p, tx, ty):
    """Three legs hanging under the thorax (reaching forward in the sting, tucked when dying)."""
    tx, ty = int(tx), int(ty)
    legs = {
        "hang": [[(3, 6), (5, 9), (5, 11), (6, 13)], [(0, 7), (0, 10), (-1, 12), (-1, 14)],
                 [(-3, 6), (-5, 9), (-6, 11), (-7, 13)]],
        "reach": [[(3, 6), (7, 8), (9, 9), (11, 9)], [(0, 7), (3, 10), (6, 11), (7, 11)],
                  [(-3, 6), (-3, 9), (-2, 11), (-1, 12)]],
        "tuck": [[(3, 6), (5, 7), (6, 7)], [(0, 7), (1, 8), (3, 8)], [(-3, 6), (-3, 8), (-1, 8)]],
    }[p["legs"]]
    for k, pts in enumerate(legs):
        path = []
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            path += line(tx + ax, ty + ay, tx + bx, ty + by)
        path = pixel_perfect(path)
        for i, (x, y) in enumerate(path):
            c.set(x, y, "S3" if i == len(path) - 1 else "B2" if k == 0 and i < 2 else "B1")


def draw_crown(c, p, hx, hy):
    """A crest of lava crystal on top of the head: a band and three spikes, lit from the left."""
    hxi, top = int(hx), int(hy - HEAD[3]) + 1
    for x in range(hxi - 5, hxi + 4):
        c.set(x, top, "C0" if x >= hxi + 2 else "C1")
    for bx, h, lean in CROWN:
        h += p["crown"]
        for k in range(1, h + 1):
            f = k / h
            x = hxi + bx + (lean if f > 0.6 else 0)
            y = top - k
            if f < 0.5:
                c.set(x, y, "C2")
                c.set(x + 1, y, "C1")
            else:
                c.set(x, y, "Y2" if k == h else "C2" if f < 0.8 else "C1")
    if p["crown"]:
        c.set(hxi - 1, top - 6 - p["crown"], "Y2")


def draw_queen(p):
    dx, dy = p["dx"], p["dy"]
    glow = p["glow"]
    body = draw_abdomen(p, dx, dy)
    # Thorax: dark rock, lit from the upper left, with a crack of lava.
    tx, ty, trx, try_ = THORAX
    tx, ty = tx + dx, ty + dy
    thorax = Canvas(CELL)
    blob(thorax, tx, ty, trx, try_, lambda x, y, l: ramp(CHITIN, 1.5 + l * 2.0))
    for k, (cx, cy) in enumerate(((-3, 1), (-2, 2), (-1, 2), (0, 3), (1, 3), (2, 2))):
        thorax.set(int(tx) + cx, int(ty) + cy, ramp(LAVA, glow + (2 if k in (2, 3) else 1)))
    seam(thorax, body)
    body.over(thorax)
    # Head, a little lower when it leans forward; then the crown, the eye, the mandibles, the feelers.
    hx, hy, hrx, hry = HEAD
    hx += dx
    hy += dy + p["tilt"]
    head = Canvas(CELL)
    blob(head, hx, hy, hrx, hry, lambda x, y, l: ramp(CHITIN, 1.7 + l * 2.0))
    seam(head, body)
    body.over(head)
    hxi, hyi = int(hx), int(hy)
    draw_crown(body, p, hx, hy)
    # a big compound eye
    for (ex, ey), col in (((1, -2), "Y2"), ((2, -2), "Y"), ((1, -1), "Y"), ((2, -1), "Y2"), ((3, -1), "S4"),
                          ((1, 0), "S4"), ((2, 0), "Y"), ((3, 0), "S3"), ((2, 1), "S3")):
        body.set(hxi + ex, hyi + ey, col)
    jaw = "Y" if glow >= 3 else "S4"
    body.set(hxi + 4, hyi + 2, "S3")
    body.set(hxi + 5, hyi + 2, jaw)
    body.set(hxi + 3, hyi + 3, "S3")
    body.set(hxi + 4, hyi + 3, jaw)
    for x, y in line(hxi + 3, hyi - 3, hxi + 7, hyi - 7) + [(hxi + 8, hyi - 7)]:
        body.set(x, y, "B1")
    body.set(hxi + 9, hyi - 7, "S4")
    draw_legs(body, p, tx, ty)
    # Wings: the far one behind everything, the near one over the body.
    wa = WING_ANGLE[p["wing"]]
    wx, wy = WING_ROOT[0] + dx, WING_ROOT[1] + dy
    back = Canvas(CELL)
    wing(back, wx - 3, wy + 1, wa - (8 if p["wing"] != "spread" else 26), 15.0, 4.2, False, phase=p["phase"])
    front = Canvas(CELL)
    wing(front, wx, wy, wa, 17.0, 5.0, True, body, p["phase"])
    back.over(body)
    back.over(front)
    queen = back
    if p["blaze"]:
        queen.remap({"F2": "F1", "S3": "S4", "C1": "C2"})
    for step in COOL_STEPS[:p["cool"]]:
        queen.remap(step)
    queen.outline("S2" if p["blaze"] else "O")
    if p["blaze"]:
        queen.outline()
    if p["flash"]:
        queen.remap({c: "W" for c in PALETTE if c not in ("O", "SH")})
    return finish(queen, p)


def ground_ring(r, hot, cx):
    """The summon's ring of fire on the floor around its shadow, seen from above (a flat ellipse);
    its near half is brighter."""
    c = Canvas(CELL)
    cy = GROUND - 0.5
    ry = max(1.6, r * 0.3)
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            if not in_ellipse(x, y, cx, cy, r, ry) or in_ellipse(x, y, cx, cy, r - 1.6, ry - 1.0):
                continue
            near = y + 0.5 > cy
            c.set(x, y, ("Y2" if near else "Y") if hot else ("S4" if near else "S2"))
    return c


def finish(queen, p):
    if p["ring"]:
        ring = ground_ring(p["ring"], p["ring_hot"], 32.0 + p["dx"] * 0.5)
        ring.over(queen)
        queen = ring
    if p["shadow"]:
        shadow = Canvas(CELL)
        # it shrinks a little as she rises
        rx = 10.0 + min(p["dy"], 0) * 0.5
        blob(shadow, 32.0 + p["dx"] * 0.5, GROUND - 0.5, rx, 1.5, lambda x, y, l: "SH")
        shadow.over(queen)
        queen = shadow
    add_streak(queen, p["streak"])
    add_fx(queen, p["fx"])
    return queen


## A tiny cría thrown out by the summon: (dx, dy) -> color, facing right; flipped for the left one.
MINI_BUG = {(2, -2): "F1", (3, -2): "F1", (2, -1): "F2", (3, -1): "F1",
            (0, 0): "S4", (1, 0): "S3", (2, 0): "S4", (3, 0): "B1", (4, 0): "B2",
            (0, 1): "S3", (1, 1): "S2", (2, 1): "S3", (3, 1): "B1", (4, 1): "Y"}


def add_fx(canvas, fx):
    """Sparks and embers: (x, y, size, color); size 1 is one pixel, 2 a small flame, 3 a tiny cría
    (color "R" faces right, "L" left)."""
    if not fx:
        return
    sparks = Canvas(canvas.size)
    for x, y, size, col in fx:
        if size == 3:
            for (bx, by), c in MINI_BUG.items():
                sparks.set(x + (bx if col == "R" else -bx), y + by, c)
            continue
        sparks.set(x, y, col)
        if size == 2:
            sparks.set(x, y + 1, "S3")
            sparks.set(x + 1, y + 1, "S4")
            sparks.set(x - 1, y + 1, "S3")
    sparks.outline(only_empty_of=canvas)
    canvas.over(sparks)


def add_streak(canvas, streaks):
    """Speed lines behind the lunge (no outline): (x, y, length), hot at their head."""
    for x, y, n in streaks:
        for k in range(n):
            if (x - k, y) not in canvas.px:
                canvas.set(x - k, y, "Y2" if k == 0 else "Y" if k < n // 2 else "S3")


def ash(stage, embers=()):
    """What is left on the floor: a heap of ash around the cracked crown, then a pinch of ash."""
    c = Canvas(CELL)
    if stage == 0:
        blob(c, 33.0, GROUND - 3.0, 14.0, 4.5, lambda x, y, l: "A2" if l > 0.3 else "A1" if l > -0.4 else "B1")
        for x, y in ((24, GROUND - 2), (31, GROUND - 1), (36, GROUND - 3), (28, GROUND - 4)):
            c.set(x, y, "S2")
        # the crown's crystals lie on the heap, cracked and dull
        for x, y, col in ((40, GROUND - 8, "C1"), (41, GROUND - 8, "C0"), (40, GROUND - 9, "C2"),
                          (42, GROUND - 7, "C0"), (38, GROUND - 7, "C1"), (43, GROUND - 6, "C1"),
                          (39, GROUND - 7, "C0")):
            c.set(x, y, col)
    else:
        blob(c, 33.0, GROUND - 1.5, 11.0, 2.5, lambda x, y, l: "A2" if l > 0.2 else "A1")
        c.set(39, GROUND - 4, "C0")
        c.set(40, GROUND - 4, "C1")
    c.outline()
    add_fx(c, list(embers))
    return c


# --- animations -----------------------------------------------------------------------------

def idle():
    wings = ["up", "mid", "down", "up", "mid", "down"]
    bob = [0, -1, -1, 0, 1, 0]
    glow = [1, 2, 3, 3, 2, 1]
    sway = [0, 2, 4, 4, 2, 0]
    return [pose(wing=wings[i], dy=bob[i], glow=glow[i], lift=sway[i], phase=i) for i in range(6)]


def walk():
    # Flies leaning forward, its abdomen raised behind it, its wings beating faster.
    wings = ["up", "down", "mid", "up", "down", "mid"]
    bob = [0, 1, 0, -1, 0, 1]
    return [pose(wing=wings[i], dy=bob[i], tilt=1, glow=2, dx=1, lift=8, phase=i) for i in range(6)]


def attack():
    # Backs off and rises while it curls its abdomen under itself until the stinger points forward
    # (the warning), then lunges with the stinger out, about 3/4 of the way through
    # (attack_windup 0.6 s of 0.8 s); it holds the last frame while it recovers.
    return [
        pose(wing="up", glow=1),
        pose(wing="down", dx=-1, dy=-1, glow=2, lift=-4, curl=-5),
        pose(wing="up", dx=-2, dy=-2, glow=2, lift=-14, curl=-10, step=3.0, legs="reach"),
        pose(wing="mid", dx=-3, dy=-3, glow=3, lift=-30, curl=-14, step=3.0, legs="reach", crown=1),
        pose(wing="down", dx=-4, dy=-3, glow=3, lift=-38, curl=-16, step=2.9, legs="reach", crown=1,
             fx=[(26, 54, 1, "Y")]),
        pose(wing="up", dx=-4, dy=-4, glow=3, lift=-42, curl=-17, step=2.9, legs="reach", crown=1, sting=1,
             fx=[(40, 52, 1, "Y2")]),
        pose(wing="down", dx=5, dy=-1, glow=3, lift=-44, curl=-17, step=2.9, legs="reach", sting=3,
             streak=[(14, 26, 6), (12, 33, 8), (16, 40, 5)]),
        pose(wing="mid", dx=7, dy=-1, glow=3, lift=-44, curl=-17, step=2.9, legs="reach", sting=3,
             fx=[(60, 48, 1, "Y2"), (58, 45, 1, "Y"), (61, 51, 1, "S4")]),
    ]


def special():
    # Rises and flares up, the abdomen white-hot, then a burst of sparks throws a little cría out to
    # each side (where the summoned ones appear), about 2/3 of the way through
    # (summon_windup 0.8 s of 1.2 s).
    return [
        pose(wing="up", glow=2),
        pose(wing="spread", dy=-1, glow=3, lift=6, crown=1),
        pose(wing="mid", dy=-2, glow=3, lift=10, crown=1, blaze=True, ring=5, fx=[(16, 18, 1, "Y")]),
        pose(wing="spread", dy=-3, glow=3, lift=12, crown=2, blaze=True, ring=9,
             fx=[(14, 16, 2, "Y"), (52, 12, 1, "S4"), (22, 10, 1, "Y")]),
        pose(wing="down", dy=-3, glow=3, lift=12, crown=2, blaze=True, ring=13,
             fx=[(10, 24, 2, "Y"), (54, 18, 2, "Y"), (18, 8, 1, "S4"), (46, 6, 1, "Y")]),
        pose(wing="spread", dy=-2, glow=3, lift=8, crown=1, blaze=True, ring=16,
             fx=[(8, 44, 3, "L"), (52, 44, 3, "R"), (10, 32, 1, "Y2"), (54, 32, 1, "Y2"),
                 (6, 22, 1, "S4"), (58, 24, 1, "S4")]),
        pose(wing="up", dy=-1, glow=2, lift=4, ring=18, ring_hot=False,
             fx=[(5, 47, 3, "L"), (56, 47, 3, "R"), (4, 36, 1, "S3"), (60, 36, 1, "S3")]),
        pose(wing="mid", glow=1, fx=[(3, 50, 1, "S3"), (61, 50, 1, "S3")]),
    ]


def hurt():
    return [
        pose(flash=True, wing="down", dx=-1),
        pose(wing="down", dx=-3, dy=-1, glow=0, tilt=-1, lift=10),
        pose(wing="up", dx=-2, glow=1, lift=4),
        pose(wing="mid", dx=-1, glow=1),
    ]


def death():
    # Its wings fold, it drops to the floor in a burst of embers, burns out and crumbles to ash
    # around its cracked crown.
    frames = [
        draw_queen(pose(flash=True, wing="down")),
        draw_queen(pose(wing="fold", dy=2, tilt=1, glow=2, cool=1, lift=10, legs="tuck")),
        draw_queen(pose(wing="fold", dy=6, dx=1, tilt=1, glow=1, cool=1, lift=14, legs="tuck",
                        fx=[(20, 20, 1, "Y")])),
        draw_queen(pose(wing="fold", dy=17, dx=1, tilt=2, glow=1, cool=2, lift=20, curl=2, legs="tuck",
                        shadow=False, fx=[(12, 50, 1, "Y"), (52, 48, 1, "Y"), (30, 30, 2, "Y")])),
        draw_queen(pose(wing="fold", dy=17, dx=1, tilt=2, glow=0, cool=3, lift=20, curl=2, legs="tuck",
                        shadow=False, fx=[(10, 40, 1, "S4"), (54, 36, 1, "S3"), (34, 24, 1, "S4")])),
    ]
    frames.append(ash(0, [(22, 44, 2, "Y"), (40, 40, 1, "S4"), (31, 36, 1, "S3")]))
    frames.append(ash(0, [(30, 34, 1, "S3")]))
    frames.append(ash(1))
    return frames


def strip(frames, path):
    cell = frames[0].size
    img = Image.new("RGBA", (cell * len(frames), cell), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        img.alpha_composite(f.image(), (i * cell, 0))
    img.save(path)
    print(os.path.relpath(path), len(frames), "frames")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for name, make in (("idle", idle), ("walk", walk), ("attack", attack), ("special", special),
                       ("hurt", hurt)):
        strip([draw_queen(p) for p in make()], os.path.join(OUT, "reina_volcanica_%s.png" % name))
    strip(death(), os.path.join(OUT, "reina_volcanica_death.png"))
