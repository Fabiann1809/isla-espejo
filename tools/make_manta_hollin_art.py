"""Draws the Manta de hollín's art (temple enemy, island 3) pixel by pixel.

The beasts pack's soot manta, scaled from 128 px down to the game, came out blurred (and several of
its frames were cut badly), so it is drawn at the game's own pixel size instead, following the
pack's design, seen from the front as in the pack: a round soot-dark body with two little horns and
glowing orange eyes, a fiery chin, and broad bat wings whose membranes run from dark red at the arm
to a glowing orange-yellow hem. Its wings (a few points each, mirrored) flap frame by frame: idle
(hovering), walk (hard flapping, also its run), attack (the swoop: wings swept back, a white streak
behind it), special (it rears back and flips in a loop that leaves an arc of flame: played while
it marks its dive), hurt and death (it drops and lies flat, its glow going out).

Writes into `assets/sprites/manta_hollin/`:
    manta_hollin_<animation>.png   64x64 cells, facing right (the swoop and the loop lean that
                                   way), its chin's tip on row 39: idle, walk, attack, special,
                                   hurt, death

    python tools/make_manta_hollin_art.py
Then tools/make_temple_enemy_frames.gd builds its SpriteFrames as for every temple enemy, and
tools/enemy_aseprite.lua keeps an editable `source/manta_hollin.aseprite`.
Needs Pillow.
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "manta_hollin")
CELL = 64
## Tip of its chin at rest: the row its shadow is measured from (the art flies above it in game).
BASE = 39

PALETTE = {
    "O": (26, 12, 18),     # outline
    # soot body
    "B0": (50, 26, 36),
    "B1": (80, 44, 56),
    "B2": (116, 70, 82),
    "B3": (152, 102, 110),
    # wing membranes and fire
    "R0": (90, 18, 24),
    "R1": (140, 30, 28),
    "R2": (194, 58, 30),
    "R3": (236, 112, 36),
    "Y0": (255, 174, 56),
    "Y1": (255, 226, 120),
    "E": (255, 248, 206),  # hottest: eye cores, flame roots
    # white streak of the swoop
    "T0": (140, 136, 164),
    "T1": (206, 204, 222),
    "W": (255, 248, 240),  # hurt flash and streak core
}
## Death: each step dims the fire.
COOL_STEPS = [
    {"E": "Y1", "Y1": "Y0", "Y0": "R3"},
    {"Y1": "R3", "Y0": "R2", "R3": "R2", "R2": "R1", "B3": "B2"},
    {"R3": "R1", "R2": "R1", "R1": "R0", "B3": "B2", "B2": "B1"},
]

## Rest pose (cell coordinates): the body's center and radii, the right wing's points (the left
## one mirrors them around the body's center).
BODY = (32.0, 29.0, 5.5, 6.0)
SHOULDER = (36.0, 26.0)


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

    def transformed(self, fn):
        c = Canvas(self.size)
        for (x, y), col in self.px.items():
            nx, ny = fn(x, y)
            c.set(nx, ny, col)
        return c

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


def line(a, b):
    n = int(max(abs(b[0] - a[0]), abs(b[1] - a[1]))) * 2 + 1
    return pixel_perfect([(math.floor(a[0] + (b[0] - a[0]) * i / n), math.floor(a[1] + (b[1] - a[1]) * i / n))
                          for i in range(n + 1)])


def in_polygon(x, y, poly):
    inside = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


def seg_dist(px_, py_, a, b):
    vx, vy = b[0] - a[0], b[1] - a[1]
    t = max(0.0, min(1.0, ((px_ - a[0]) * vx + (py_ - a[1]) * vy) / max(vx * vx + vy * vy, 0.001)))
    return math.hypot(px_ - a[0] - vx * t, py_ - a[1] - vy * t)


# --- the manta ---------------------------------------------------------------------------------

def pose(**kw):
    p = dict(dx=0, dy=0, lean=0.0, flap=0.0, span=1.0, eyes="open", flash=False, cool=0, flat=0, squint=False,
             flip=False, back=False, fx=())
    p.update(kw)
    return p


def wing(flap, span):
    """The right wing's outline (cell coordinates at rest) for a flap from -1 (down) to 1 (up)
    and a span from 0 (folded) to 1 (spread); also its bones."""
    sx, sy = SHOULDER
    wrist = (sx + 5 * span, sy - 4 - 3 * flap)
    tip = (sx + 13 * span, sy - 1 - 6 * flap)
    hem = [(sx + 10.5 * span, sy + 4 - 4 * flap), (sx + 8 * span, sy + 3 - 2.2 * flap),
           (sx + 5.5 * span, sy + 6 - 1.8 * flap), (sx + 3 * span, sy + 5 - 0.5 * flap), (sx - 1, sy + 7)]
    poly = [(sx - 1, sy - 1), wrist, tip] + hem
    bones = [(wrist, tip), (wrist, hem[1]), (wrist, hem[3])]
    return poly, (sx, sy), wrist, tip, bones


def draw_wing(p, c):
    poly, shoulder, wrist, tip, bones = wing(p["flap"], p["span"])
    lead = [(shoulder, wrist), (wrist, tip)]
    xs = [q[0] for q in poly]
    ys = [q[1] for q in poly]
    for y in range(int(min(ys)) - 1, int(max(ys)) + 2):
        for x in range(int(min(xs)) - 1, int(max(xs)) + 2):
            px_, py_ = x + 0.5, y + 0.5
            if not in_polygon(px_, py_, poly):
                continue
            # dark red by the arm, glowing toward the hem
            d = min(seg_dist(px_, py_, *s) for s in lead)
            col = "R1" if d < 1.6 else "R2" if d < 3.2 else "R3" if d < 4.8 else "Y0"
            hem_d = min(seg_dist(px_, py_, poly[i], poly[i + 1]) for i in range(2, len(poly) - 1))
            if hem_d < 1.0 and d > 2.5:
                col = "Y1"
            c.set(x, y, col)
    # bones of the membrane, the arm along its leading edge
    for a, b in bones[1:]:
        for (x, y) in line(a, b)[1:-1]:
            if (x, y) in c.px and c.px[(x, y)] not in ("Y1",):
                c.px[(x, y)] = "R0"
    for a, b in lead:
        for (x, y) in line(a, b):
            c.set(x, y, "B2" if y < wrist[1] + 2 and x < wrist[0] else "B1")
    # the claw on the wrist, pointing up
    wx, wy = int(wrist[0]), int(wrist[1])
    for (x, y, col) in ((wx, wy - 1, "B2"), (wx, wy - 2, "B2"), (wx - 1, wy - 3, "B3")):
        c.set(x, y, col)


def draw_body(p, c):
    cx, cy, rx, ry = BODY
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if in_ellipse(x, y, cx, cy, rx, ry):
                l = lit((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
                c.set(x, y, "B3" if l > 0.55 else "B2" if l > 0.0 else "B1" if l > -0.55 else "B0")
    # two little horns, curving out
    for side in (-1, 1):
        for (dx, dy, col) in ((2, -5, "B2"), (2, -6, "B2"), (3, -6, "B3"), (3, -7, "B3"), (4, -8, "B3")):
            c.set(int(cx + side * dx - (1 if side < 0 else 0)), int(cy + dy), col)
    # glowing eyes
    ey = int(cy + 1)
    for side in (-1, 1):
        ex = int(cx + side * 2.5 - (1 if side < 0 else 0))
        if p["eyes"] == "open":
            c.set(ex, ey, "E")
            c.set(ex + side, ey, "Y0")
            c.set(ex, ey - 1, "B0")
        elif p["eyes"] == "shut":
            c.set(ex, ey, "B0")
            c.set(ex + side, ey, "B0")
    # the fiery chin: a point of flame under the face, little claws beside it
    chin = [(-2, 4, "R2"), (-1, 4, "R3"), (0, 4, "R3"), (1, 4, "R2"),
            (-2, 5, "R3"), (-1, 5, "Y0"), (0, 5, "Y0"), (1, 5, "R3"),
            (-1, 6, "Y1"), (0, 6, "Y0"), (-1, 7, "Y0"), (0, 7, "R3"), (0, 8, "R3"), (-1, 9, "R2")]
    for dx, dy, col in chin:
        c.set(int(cx) + dx, int(cy) + dy + 1, col)
    for side in (-1, 1):
        fx = int(cx + side * 4.5 - (1 if side < 0 else 0))
        c.set(fx, int(cy + 6), "B1")
        c.set(fx, int(cy + 7), "B0")


def draw_manta(p):
    c = Canvas(CELL)
    right = Canvas(CELL)
    draw_wing(p, right)
    # the left wing mirrors the right one around the body's center
    left = right.transformed(lambda x, y: (int(2 * BODY[0]) - 1 - x, y))
    c.over(left)
    c.over(right)
    draw_body(p, c)
    if p["flat"]:
        # lying flat: squashed down onto its base row
        f = p["flat"]
        c = c.transformed(lambda x, y: (x, int(BASE - (BASE - y) * (1.0 - 0.25 * f))))
    if p["lean"]:
        # leaning into the swoop: rows above the body's center slide forward, rows below back
        c = c.transformed(lambda x, y: (x + int(round(p["lean"] * (BODY[1] - y) / 8.0)), y))
    if p["flip"]:
        c = c.transformed(lambda x, y: (x, int(2 * BODY[1]) - y))
    for step in COOL_STEPS[:p["cool"]]:
        c.remap(step)
    c = c.transformed(lambda x, y: (x + p["dx"], y + p["dy"]))
    c.outline()
    if p["flash"]:
        c.remap({k: "W" for k in PALETTE if k != "O"})
    add_fx(c, p["fx"])
    return c


# --- effects in the cell ------------------------------------------------------------------------

def streak(c, ax, ay, bx, by):
    """A white streak from a (its fading tail) to b (right behind the manta)."""
    pts = line((ax, ay), (bx, by))
    for i, (x, y) in enumerate(pts):
        f = i / max(len(pts) - 1, 1)
        if (x, y) in c.px:
            continue
        c.set(x, y, "W" if f > 0.7 else "T1" if f > 0.35 else "T0")


def flame_arc(c, cx, cy, r, start, length, phase):
    """An arc of flame around (cx, cy): from angle `start` (degrees) going `length` degrees,
    white-hot at its head and red where it fades."""
    steps = int(abs(length) * r / 20) + 4
    for i in range(steps + 1):
        f = i / steps
        a = math.radians(start + length * f)
        rr = r + math.sin(f * 9 + phase) * 0.8
        x, y = cx + rr * math.cos(a), cy + rr * math.sin(a)
        width = 1.6 if f > 0.6 else 1.1 if f > 0.25 else 0.6
        col = "E" if f > 0.9 else "Y1" if f > 0.7 else "Y0" if f > 0.45 else "R3" if f > 0.2 else "R2"
        for yy in range(int(y - width) - 1, int(y + width) + 2):
            for xx in range(int(x - width) - 1, int(x + width) + 2):
                if math.hypot(xx + 0.5 - x, yy + 0.5 - y) <= width and (xx, yy) not in c.px:
                    c.set(xx, yy, col)
    # flickering tongues on the outside of the arc
    for k in range(3):
        f = 0.3 + 0.25 * k
        a = math.radians(start + length * f)
        for j in range(1, 3):
            c.set(int(cx + (r + 1 + j) * math.cos(a)), int(cy + (r + 1 + j) * math.sin(a) - (phase + k) % 2),
                  "R3" if j == 1 else "R2")


def add_fx(canvas, fx):
    """Extras over the figure: ("streak", ax, ay, bx, by), ("arc", cx, cy, r, start, length, phase),
    ("spark", x, y, color)."""
    if not fx:
        return
    extra = Canvas(canvas.size)
    for item in fx:
        if item[0] == "streak":
            streak(extra, *item[1:])
        elif item[0] == "arc":
            flame_arc(extra, *item[1:])
        elif item[0] == "spark":
            extra.set(item[1], item[2], item[3])
    for k in list(extra.px):
        if k in canvas.px:
            del extra.px[k]
    extra.outline(only_empty_of=canvas)
    for k in list(extra.px):
        if k in canvas.px:
            del extra.px[k]
    canvas.over(extra)


# --- animations -----------------------------------------------------------------------------

def idle():
    # Hovering: slow beats, the body bobbing against them.
    flap = [0.7, 0.3, -0.2, -0.5, -0.1, 0.4]
    dy = [0, 0, 1, 1, 0, 0]
    return [pose(flap=flap[i], dy=dy[i], eyes="shut" if i == 4 else "open") for i in range(6)]


def walk():
    # Hard flapping: full strokes, the body lifted on each downstroke.
    flap = [1.0, 0.6, 0.0, -0.7, -1.0, -0.5, 0.2, 0.8]
    span = [0.95, 1.0, 1.0, 1.0, 0.9, 0.8, 0.8, 0.9]
    dy = [1, 1, 0, -1, -2, -1, 0, 1]
    return [pose(flap=flap[i], span=span[i], dy=dy[i]) for i in range(8)]


def attack():
    # The swoop: it tucks its wings back and shoots forward and down, a white streak behind it,
    # then spreads them to pull out.
    return [
        pose(flap=0.9, span=0.8, dx=-1, dy=-1),
        pose(flap=1.0, span=0.55, dx=1, dy=0, lean=1, fx=[("streak", 18, 18, 25, 23)]),
        pose(flap=1.0, span=0.45, dx=3, dy=1, lean=2,
             fx=[("streak", 10, 14, 27, 24), ("streak", 14, 22, 26, 28)]),
        pose(flap=1.0, span=0.4, dx=5, dy=2, lean=2,
             fx=[("streak", 6, 12, 29, 25), ("streak", 9, 21, 28, 29), ("streak", 16, 30, 28, 33)]),
        pose(flap=0.9, span=0.45, dx=6, dy=2, lean=2,
             fx=[("streak", 8, 14, 30, 26), ("streak", 12, 23, 29, 30), ("streak", 18, 31, 29, 34)]),
        pose(flap=0.6, span=0.6, dx=6, dy=1, lean=1, fx=[("streak", 14, 17, 28, 26), ("streak", 18, 26, 28, 31)]),
        pose(flap=-0.2, span=0.9, dx=4, dy=0, fx=[("streak", 20, 22, 27, 27)]),
        pose(flap=-0.6, span=1.0, dx=2, dy=-1),
    ]


def special():
    # The loop: it rears back with its wings high, flips over backwards (upside down at the top)
    # drawing a ring of flame, comes round and hangs poised for the dive.
    cx, cy = 32, 26
    return [
        pose(flap=0.8, dy=1, dx=-1),
        pose(flap=1.0, span=0.8, dy=-2, dx=-2, fx=[("arc", cx, cy, 14, 90, 50, 0)]),
        pose(flap=0.5, span=0.7, dy=-5, dx=-3, flip=True, fx=[("arc", cx, cy, 14, 90, 120, 1)]),
        pose(flap=-0.3, span=0.7, dy=-6, dx=0, flip=True, fx=[("arc", cx, cy, 14, 90, 200, 2)]),
        pose(flap=0.2, span=0.8, dy=-4, dx=3, flip=True, fx=[("arc", cx, cy, 14, 100, 260, 3)]),
        pose(flap=0.8, span=0.9, dy=-1, dx=2, fx=[("arc", cx, cy, 14, 170, 230, 4)]),
        pose(flap=1.0, span=0.9, dy=0, dx=0, fx=[("arc", cx, cy, 15, 250, 160, 5)]),
        pose(flap=1.0, span=0.85, dy=0, dx=-1, fx=[("spark", 18, 14, "R3"), ("spark", 46, 12, "Y0"),
                                                   ("spark", 40, 8, "R2")]),
    ]


def hurt():
    return [
        pose(flash=True, flap=0.8, dy=-1),
        pose(flap=1.0, span=0.8, dy=-2, dx=-2, eyes="shut"),
        pose(flap=-0.4, dy=0, dx=-1, eyes="shut"),
        pose(flap=0.2),
    ]


def death():
    # Struck, it folds and drops (the game lowers it onto its shadow), lands flat and goes out.
    return [
        pose(flash=True, flap=0.8),
        pose(flap=1.0, span=0.7, dy=-1, eyes="shut"),
        pose(flap=-0.6, span=0.8, dy=1, eyes="shut", cool=1),
        pose(flap=-1.0, span=0.7, dy=3, eyes="shut", cool=1),
        pose(flap=0.0, span=1.0, flat=1, eyes="shut", cool=2,
             fx=[("spark", 14, 35, "R3"), ("spark", 50, 34, "Y0"), ("spark", 20, 31, "R2")]),
        pose(flap=-0.2, span=1.05, flat=2, eyes="shut", cool=2, fx=[("spark", 12, 31, "R2"), ("spark", 52, 30, "R3")]),
        pose(flap=-0.2, span=1.05, flat=2, eyes="shut", cool=3, fx=[("spark", 50, 27, "R1")]),
        pose(flap=-0.2, span=1.05, flat=2, eyes="shut", cool=3),
    ]


def strip(frames, path):
    img = Image.new("RGBA", (CELL * len(frames), CELL), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        img.alpha_composite(f.image(), (i * CELL, 0))
    img.save(path)
    print(os.path.relpath(path), len(frames), "frames")


if __name__ == "__main__":
    for name, make in (("idle", idle), ("walk", walk), ("attack", attack), ("special", special),
                       ("hurt", hurt), ("death", death)):
        strip([draw_manta(p) for p in make()], os.path.join(OUT, "manta_hollin_%s.png" % name))
