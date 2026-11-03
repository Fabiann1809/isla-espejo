"""Draws the Araña talladora's art (temple enemy, island 3) pixel by pixel.

The beasts pack's carving spider, scaled from 128 px down to the game, came out blurred, so it is
drawn at the game's own pixel size instead: a spider of volcanic rock seen three-quarters from its
right, facing right. A big rock abdomen behind, split by glowing lava cracks; a smaller head in
front with a cluster of little glowing eyes and an ember mouth (its brightest part); eight long
jointed legs ending in fine points, the far four (left side) darker and arching high over its back,
the near four splaying down in front; and its carving tool, a stone drill, under the mouth. Rock is
red-black, lava orange to yellow, light from the upper left, 1 px dark outline.

The body (abdomen and head) is painted through a small transform (shift, tilt, a vertical squash
that turns it over) so it can rear up, stab and roll on its back; each leg is hip, knee, ankle and
foot. Animations: idle (breathes, the legs drum), walk (four pairs in crossed phase), attack (rears
up, front legs raised, stabs down in a puff of dust), special (the drill: crouches, runs trailing
dust and cracks, drives the drill into the floor heaping up earth), hurt and death (flips over, its
legs curl up and its lava goes out). It also draws the floor patches it sinks (SinkingFloor.art)
and the crack that runs to them from its drill (SinkingFloor.trail_art).

Writes into `assets/sprites/arana_talladora/`:
    arana_talladora_<animation>.png   64x64 cells, facing right, feet on row 44: idle, walk,
                                      attack, special, hurt, death
    arana_talladora_pit.png           32x32 cells, a 2x2-tile patch: 5 cracking, 2 sinking,
                                      3 sunk (loop), 3 closing
    arana_talladora_crack.png         8x8 cells of the crack running from the drill, pointing
                                      right: 3 variants

    python tools/make_arana_talladora_art.py
Then tools/make_temple_enemy_frames.gd builds its SpriteFrames as for every temple enemy, and
tools/enemy_aseprite.lua keeps an editable `source/arana_talladora.aseprite`
(extras="pit:10:crack=1-5;sink=6-7;sunk=8-10;close=11-13,crack:8").
Needs Pillow.
"""
import math
import os
import random

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "arana_talladora")
CELL = 64
## Last row of the feet; their outline goes on the row below.
GROUND = 44
PIT = 32
CRACK_W, CRACK_H = 8, 8

PALETTE = {
    "O": (20, 8, 10),      # outline
    # the spider's volcanic rock: red-black, lit from the upper left
    "R0": (30, 12, 14),
    "R1": (52, 22, 22),
    "R2": (84, 38, 32),
    "R3": (128, 66, 50),
    # the floor's rock (the pits and the rubble)
    "K0": (50, 20, 20),
    "K1": (86, 36, 30),
    "K2": (126, 60, 44),
    "K3": (162, 96, 80),
    "K4": (198, 142, 126),
    # lava, eyes, joints
    "L0": (108, 28, 18),
    "L1": (188, 68, 22),
    "L2": (240, 128, 36),
    "L3": (255, 198, 78),
    "L4": (255, 244, 180),
    # the stone drill
    "S0": (84, 84, 100),
    "S1": (146, 148, 166),
    "S2": (214, 218, 230),
    # dust
    "D0": (112, 84, 64),
    "D1": (168, 134, 98),
    "D2": (218, 192, 148),
    # the pit's depths
    "P0": (12, 6, 8),
    "P1": (30, 14, 14),
    "W": (255, 243, 236),  # hurt flash
}
## Death: each step cools the lava and dims the rock.
COOL_STEPS = [
    {"L4": "L3", "L3": "L2", "L2": "L1"},
    {"L3": "L1", "L2": "L1", "L1": "L0", "R3": "R2"},
    {"L1": "L0", "L0": "R1", "S2": "S1"},
]

## The body at rest, in its own coordinates (= cell coordinates when standing still). It turns
## about PIVOT, the waist under the joint of head and abdomen.
PIVOT = (33.0, 38.0)
ABDOMEN = (23.5, 30.5, 9.0, 7.0, -0.25)   # center x, center y, radius x, radius y, tilt (rad)
HEAD = (38.5, 34.0, 5.2, 3.9)
## Glowing cracks over the abdomen (polylines), the eyes (bright, dim) and the ember mouth.
## Glowing cracks over the abdomen, a map of its own pixels (u from 16, v from 24): 3 hottest.
CRACK_MAP = [
    ".........2.......",
    "..........2...1..",
    "...1......32.2...",
    "....2...232.32...",
    ".....333.....2...",
    "....2...2.....1..",
    "...1.....2.......",
    ".........1.......",
]
CRACK_ORIGIN = (15, 25)
## Rock spikes along the abdomen's top: base (u, v) and height.
SPIKES = [(20.0, 24.5, 2.0), (25.0, 24.0, 2.3)]
EYES = [((40.5, 31.5), "L4"), ((42.5, 32.5), "L4"), ((39.5, 32.5), "L2"), ((41.5, 30.5), "L2")]
MOUTH = (43.2, 35.4, 2.1, 1.75)
## The drill: its root under the mouth, its rest angle (degrees, 90 = straight down) and length.
DRILL_ROOT = (42.0, 37.5)
DRILL_ANGLE = 62.0
DRILL_LENGTH = 7.0
## The legs at rest (cell coordinates): hip, knee, ankle, foot. The first four are the far ones,
## its left side (darker, arching high over its back), front to back; then the near four.
LEGS = [
    ((40, 33), (45, 26), (49, 29), (51, 39)),
    ((38, 32), (41, 25), (45, 27), (47, 38)),
    ((36, 32), (31, 24), (26, 25), (23, 36)),
    ((35, 33), (25, 25), (19, 27), (15, 38)),
    ((41, 37), (47, 30), (50, 34), (52, 44)),
    ((39, 38), (44, 33), (47, 37), (48, 44)),
    ((36, 38), (31, 33), (28, 37), (26, 44)),
    ((35, 37), (25, 32), (20, 36), (18, 44)),
]
FAR = range(0, 4)
## Curled up dead (knee, ankle, foot from the hip, under the belly; turned over with the body).
CURLED = [
    ((4, 6), (3, 9), (1, 7)), ((2, 7), (0, 10), (-1, 8)),
    ((-2, 7), (-1, 10), (1, 8)), ((-5, 6), (-5, 9), (-3, 8)),
    ((6, 4), (7, 7), (5, 8)), ((3, 5), (3, 8), (1, 8)),
    ((-3, 5), (-4, 8), (-2, 8)), ((-7, 3), (-9, 6), (-7, 8)),
]
## The front pair (far, near), raised to stab.
FRONT = (0, 4)
## Walking in crossed phase: these four step together, the other four push.
SET_A = (0, 2, 5, 7)


class Canvas:
    def __init__(self, w, h=None):
        self.size = w
        self.height = h or w
        self.px = {}

    def set(self, x, y, c):
        if 0 <= x < self.size and 0 <= y < self.height:
            self.px[(x, y)] = c

    def over(self, other):
        self.px.update(other.px)

    def outline(self, color="O", only_empty_of=None):
        """A 1 px outline around everything drawn (4-neighbours: rounder than 8)."""
        ring = {}
        for (x, y) in self.px:
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if (nx, ny) in self.px or not (0 <= nx < self.size and 0 <= ny < self.height):
                    continue
                if only_empty_of is not None and (nx, ny) in only_empty_of.px:
                    continue
                ring[(nx, ny)] = color
        self.px.update(ring)

    def remap(self, mapping):
        self.px = {p: mapping.get(c, c) for p, c in self.px.items()}

    def image(self):
        img = Image.new("RGBA", (self.size, self.height), (0, 0, 0, 0))
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
    return pixel_perfect([(math.floor(a[0] + (b[0] - a[0]) * i / n + 0.5),
                           math.floor(a[1] + (b[1] - a[1]) * i / n + 0.5)) for i in range(n + 1)])


def seg_dist(px_, py_, a, b):
    vx, vy = b[0] - a[0], b[1] - a[1]
    vv = max(vx * vx + vy * vy, 0.001)
    t = max(0.0, min(1.0, ((px_ - a[0]) * vx + (py_ - a[1]) * vy) / vv))
    return math.hypot(px_ - a[0] - vx * t, py_ - a[1] - vy * t), t


def capsule(canvas, a, b, r, shade):
    """A limb from a to b, `r` thick; `shade` picks its color from how lit it is and how far along."""
    for y in range(int(min(a[1], b[1]) - r) - 1, int(max(a[1], b[1]) + r) + 2):
        for x in range(int(min(a[0], b[0]) - r) - 1, int(max(a[0], b[0]) + r) + 2):
            d, t = seg_dist(x + 0.5, y + 0.5, a, b)
            if d <= r:
                vx, vy = b[0] - a[0], b[1] - a[1]
                qx, qy = a[0] + vx * t, a[1] + vy * t
                n = max(d, 0.001)
                canvas.set(x, y, shade(lit((x + 0.5 - qx) / n if d > 0.15 else 0,
                                           (y + 0.5 - qy) / n if d > 0.15 else -1), t))


# --- the spider --------------------------------------------------------------------------------

def pose(**kw):
    p = dict(dx=0, dy=0, tilt=0.0, flip=1.0, breath=0.0, legs=None, curl=0.0, glow=1, flash=False,
             cool=0, eyes="open", drill=(DRILL_ANGLE, DRILL_LENGTH), mound=0, fx=(), dust=(),
             cracks=0, trail=None)
    p.update(kw)
    if p["legs"] is None:
        p["legs"] = [(0, 0, 0)] * 8
    return p


class Body:
    """The body's transform: about PIVOT it tilts (degrees, + rears the head up), squashes upside
    down (`flip` 1 standing, -1 on its back) and shifts by (dx, dy)."""

    def __init__(self, p):
        self.a = math.radians(p["tilt"])
        self.f = p["flip"]
        self.dx, self.dy = p["dx"], p["dy"]

    def to_cell(self, u, v):
        x, y = u - PIVOT[0], (v - PIVOT[1]) * self.f
        ca, sa = math.cos(self.a), math.sin(self.a)
        return (PIVOT[0] + x * ca + y * sa + self.dx, PIVOT[1] - x * sa + y * ca + self.dy)

    def to_body(self, x, y):
        x, y = x - PIVOT[0] - self.dx, y - PIVOT[1] - self.dy
        ca, sa = math.cos(self.a), math.sin(self.a)
        u, v = x * ca - y * sa, x * sa + y * ca
        f = self.f if abs(self.f) > 0.05 else 0.05
        return PIVOT[0] + u, PIVOT[1] + v / f

    def normal(self, nu, nv):
        """A body-space normal turned into the cell, for the light."""
        nv *= 1 if self.f >= 0 else -1
        ca, sa = math.cos(self.a), math.sin(self.a)
        return nu * ca + nv * sa, -nu * sa + nv * ca


def leg_points(p, i, body):
    """Hip, knee, ankle and foot of leg `i` in this pose. The hip rides the body; the foot moves by
    (fdx, lift) and the knee and ankle follow it, the knee also by kdy; `curl` folds the leg up
    against the body (on its back, the legs point at the sky)."""
    hip0, knee0, ankle0, foot0 = LEGS[i]
    fdx, lift, kdy = p["legs"][i]
    hip = body.to_cell(*hip0)
    sx, sy = hip[0] - hip0[0], hip[1] - hip0[1]
    knee = (knee0[0] + sx * 0.8 + fdx * 0.45, knee0[1] + sy * 0.8 - lift * 0.55 + kdy)
    ankle = (ankle0[0] + sx * 0.5 + fdx * 0.85, ankle0[1] + sy * 0.4 - lift * 0.9 + kdy * 0.5)
    foot = (foot0[0] + p["dx"] + fdx, foot0[1] - lift)
    c = p["curl"]
    if c:
        # folded in a fist against the belly, the points hooked back in; on its back the fist
        # points at the sky
        f = body.f
        ck, ca, cf = [(hip[0] + ox, hip[1] + oy * f) for ox, oy in CURLED[i]]
        knee = tuple(knee[j] + (ck[j] - knee[j]) * c for j in (0, 1))
        ankle = tuple(ankle[j] + (ca[j] - ankle[j]) * c for j in (0, 1))
        foot = tuple(foot[j] + (cf[j] - foot[j]) * c for j in (0, 1))
    return hip, knee, ankle, foot


def draw_leg(p, i, body, c):
    """A long jointed leg: a thick thigh up to a glowing knee, a shank down to the ankle, and a fine
    point to the floor. The far legs are darker."""
    far = i in FAR
    hip, knee, ankle, foot = leg_points(p, i, body)
    if far:
        thigh = lambda l, t: "R2" if l > 0.35 else "R1" if l > -0.3 else "R0"
        shank = lambda l, t: "R1" if l > 0.0 else "R0"
    else:
        # the near legs catch the lava's glow on their top edge, as in the pack
        thigh = lambda l, t: ("L1" if t > 0.35 else "R3") if l > 0.45 else "R2" if l > -0.25 else "R1"
        shank = lambda l, t: ("L1" if t < 0.4 else "R2") if l > 0.45 else "R2" if l > -0.1 else "R1"
    capsule(c, hip, knee, 1.0, thigh)
    capsule(c, knee, ankle, 0.7, shank)
    for (x, y) in line(ankle, foot):
        c.set(x, y, "R1" if far else "R2")
    # the point: a fine dark tip
    c.set(int(math.floor(foot[0] + 0.5)), int(math.floor(foot[1] + 0.5)), "R0" if far else "R1")
    # glowing joints: lava shows through at the knee, dimmer at the ankle
    hot = {0: "L1", 1: "L2", 2: "L3"}[p["glow"]] if not far else {0: "L0", 1: "L1", 2: "L2"}[p["glow"]]
    c.set(int(math.floor(knee[0] + 0.5)), int(math.floor(knee[1] + 0.5)), hot)
    if not far:
        # a 2 px glowing knee on the near legs, the hot side toward the light
        kx, ky = int(math.floor(knee[0] + 0.5)), int(math.floor(knee[1] + 0.5))
        c.set(kx, ky + 1, "L1" if p["glow"] else "L0")
        c.set(int(math.floor(ankle[0] + 0.5)), int(math.floor(ankle[1] + 0.5)), "L1" if p["glow"] else "L0")


def body_color(p, body, x, y):
    """The color of the body at cell pixel (x, y), or None: abdomen, waist and head."""
    u, v = body.to_body(x + 0.5, y + 0.5)
    # head in front
    hx, hy, hrx, hry = HEAD
    qh = ((u - hx) / hrx) ** 2 + ((v - hy) / hry) ** 2 * (1.0 if v < hy else 1.3)
    mx, my, mrx, mry = MOUTH
    qm = ((u - mx) / mrx) ** 2 + ((v - my) / mry) ** 2
    if qm <= 1.0:
        # the ember maw, jutting out of the front of the head
        ramp = {0: ("L0", "L1", "L1"), 1: ("L1", "L2", "L4"), 2: ("L2", "L3", "L4")}[p["glow"]]
        if p["eyes"] == "dead":
            ramp = ("R0", "L0", "L0")
        return ramp[2] if qm < 0.22 else ramp[1] if qm < 0.6 else ramp[0]
    if qh <= 1.0:
        for (ex, ey), col in EYES:
            if abs(u - ex) < 0.6 and abs(v - ey) < 0.6:
                if p["eyes"] == "open":
                    return col if p["glow"] else {"L4": "L2", "L3": "L1", "L2": "L0"}[col]
                return "R0"
        if qm <= 1.9:
            return "R0"
        nu, nv = body.normal((u - hx) / hrx, (v - hy) / hry)
        l = lit(nu, nv)
        # a dark brow ridge over the eyes
        if 0.2 < (u - hx) / hrx < 0.75 and -0.95 < (v - hy) / hry < -0.6:
            return "R1"
        return "R3" if l > 0.6 else "R2" if l > 0.1 else "R1" if l > -0.5 else "R0"
    # the waist joining them
    if seg_dist(u, v, (31.5, 33.5), (34.0, 33.5))[0] < 1.4:
        return "R1"
    # abdomen behind, a little raised at its back
    ax, ay, arx, ary, at = ABDOMEN
    ary += p["breath"]
    ca, sa = math.cos(at), math.sin(at)
    du, dv = u - ax, v - ay
    lu, lv = du * ca + dv * sa, -du * sa + dv * ca
    nu_, nv_ = lu / arx, lv / ary
    for sx, sy, h in SPIKES:
        if sy - h <= v <= sy + 0.8 and abs(u - sx) <= (v - (sy - h)) * 0.42:
            return "R3" if u < sx else "R1"
    if nu_ * nu_ + nv_ * nv_ <= 1.0:
        row, col = int(math.floor(v)) - CRACK_ORIGIN[1], int(math.floor(u)) - CRACK_ORIGIN[0]
        if 0 <= row < len(CRACK_MAP) and 0 <= col < len(CRACK_MAP[row]) and CRACK_MAP[row][col] != ".":
            heat = int(CRACK_MAP[row][col]) + p["glow"] - 1
            return ("L1", "L1", "L2", "L3", "L4")[max(0, min(4, heat))]
        wn = body.normal(nu_ * ca - nv_ * sa, nu_ * sa + nv_ * ca)
        l = lit(*wn)
        # lava glowing through the seam along its belly
        if p["flip"] > 0 and nv_ > 0.0 and nu_ * nu_ + nv_ * nv_ > 0.78 and -0.75 < nu_ < 0.55:
            return "L1" if p["glow"] else "L0"
        return "R3" if l > 0.62 else "R2" if l > 0.15 else "R1" if l > -0.45 else "R0"
    return None


def draw_body(p, body, c):
    for y in range(8, 56):
        for x in range(4, 60):
            col = body_color(p, body, x, y)
            if col:
                c.set(x, y, col)


def draw_drill(p, body, c, floor=None):
    """The carving drill: a stone cone from under the mouth, banded like a screw, sharp at its tip."""
    angle, length = p["drill"]
    rx_, ry_ = body.to_cell(*DRILL_ROOT)
    a = math.radians(angle - p["tilt"] * body.f)
    ux, uy = math.cos(a), math.sin(a) * (1 if body.f >= 0 else -1)
    nx, ny = -uy, ux
    steps = int(length * 4)
    for i in range(steps + 1):
        t = i / steps
        half = 1.25 * (1.0 - t) + 0.15
        for k in range(-5, 6):
            s_ = k / 5 * half
            x = rx_ + ux * length * t + nx * s_
            y = ry_ + uy * length * t + ny * s_
            if floor is not None and y >= floor:
                continue
            side = s_ * (-0.55 * nx - 0.8 * ny)
            band = int(length * t * 1.6 + s_ * 0.8) % 3 == 0
            col = "S2" if side > 0.35 or t > 0.85 else "S1" if side > -0.45 else "S0"
            if band and t < 0.8:
                col = {"S2": "S1", "S1": "S0", "S0": "S0"}[col]
            c.set(int(math.floor(x)), int(math.floor(y)), col)


def dirt_mound(c, x, size):
    """The heap of earth the drill throws up: `size` 1 small, 2 full."""
    w, h = (4.0, 2.2) if size == 1 else (6.0, 3.4)
    base = GROUND + 1
    for y in range(int(base - h) - 1, base + 1):
        for xx in range(int(x - w) - 1, int(x + w) + 2):
            dx, dy = (xx + 0.5 - x) / w, (y + 0.5 - base) / h
            if dx * dx + dy * dy > 1.0 or y > base:
                continue
            l = lit(dx, dy)
            col = "D2" if l > 0.45 else "D1" if l > -0.1 else "D0"
            if (xx * 5 + y * 3) % 7 == 0:
                col = "K2"
            c.set(xx, y, col)


def draw_spider(p):
    body = Body(p)
    # far legs first, back to front, then the body over their hips, then the near legs and the
    # head over theirs; each part gets a dark line where it lies over the one behind
    layers = []
    behind = (3, 2, 1, 0) if p["flip"] > 0 else ()
    for i in behind:
        layers.append(Canvas(CELL))
        draw_leg(p, i, body, layers[-1])
    bodyc = Canvas(CELL)
    draw_body(p, body, bodyc)
    layers.append(bodyc)
    for i in (7, 6, 5, 4) if behind else (3, 7, 2, 6, 1, 5, 0, 4):
        layers.append(Canvas(CELL))
        draw_leg(p, i, body, layers[-1])
    head = Canvas(CELL)
    # the head (and mouth) goes over the near legs' hips
    hx, hy, hrx, hry = HEAD
    for (x, y), col in bodyc.px.items():
        u, v = body.to_body(x + 0.5, y + 0.5)
        if ((u - hx) / hrx) ** 2 + ((v - hy) / hry) ** 2 * (1.0 if v < hy else 1.3) <= 1.0:
            head.px[(x, y)] = col
    layers.append(head)
    drill = Canvas(CELL)
    draw_drill(p, body, drill, GROUND - 1 if p["mound"] else None)
    layers.append(drill)
    mound = Canvas(CELL)
    if p["mound"]:
        dirt_mound(mound, 49 + p["dx"], p["mound"])
    layers.append(mound)
    c = Canvas(CELL)
    if p["cracks"]:
        ground_cracks(c, p["cracks"], 47 + p["dx"])
    if p["trail"]:
        trail_cracks(c, *p["trail"])
    for layer in layers:
        for (x, y) in layer.px:
            for n in ((x + 1, y), (x - 1, y), (x, y - 1), (x, y + 1)):
                if n not in layer.px and n in c.px and c.px[n][0] in "RKSD" and layer is not head:
                    c.px[n] = "O"
        c.over(layer)
    for step in COOL_STEPS[:p["cool"]]:
        c.remap(step)
    c.outline()
    if p["flash"]:
        c.remap({k: "W" for k in PALETTE if k != "O"})
    add_dust(c, p["dust"])
    add_fx(c, p["fx"])
    return c


# --- effects in the cell ------------------------------------------------------------------------

def ground_cracks(c, stage, ox, oy=45):
    """Cracks splitting the floor where its drill went in (around (ox, oy)), glowing; `stage`
    is how far they have run."""
    rays = [[(2, 0), (3, 0), (4, 1), (5, 1), (6, 1), (7, 2), (8, 2), (9, 2)],
            [(-2, 0), (-3, 0), (-4, 1), (-5, 1), (-6, 1), (-7, 1), (-8, 2), (-9, 2)],
            [(1, 1), (2, 2), (2, 3), (3, 4)],
            [(-1, 1), (-1, 2), (-2, 3), (-3, 4)],
            [(5, 1), (6, 0), (7, -1), (8, -1)]]
    for k, ray in enumerate(rays):
        n = min(len(ray), stage * 2 - (k // 2))
        for j, (x, y) in enumerate(ray[:max(n, 0)]):
            hot = j < 2 and stage < 5
            c.set(ox + x, oy + y, "L3" if hot else "L2" if stage < 5 else "L1")
            if (ox + x, oy + y + 1) not in c.px:
                c.set(ox + x, oy + y + 1, "O")


def trail_cracks(c, x0, x1, oy=45):
    """A short glowing crack the run leaves behind it on the floor, from x0 to x1."""
    path = [(x, oy + (1 if (x // 3) % 2 else 0)) for x in range(x0, x1)]
    for j, (x, y) in enumerate(path):
        c.set(x, y, "L2" if j > len(path) - 3 else "L1")
        if (x, y + 1) not in c.px:
            c.set(x, y + 1, "O")


def dust_puff(c, cx, cy, r, stage):
    """A billowing puff of dust (three lumps): `stage` 0 dense, 1 thinning, 2 a few wisps."""
    lumps = ((cx, cy, r), (cx - r * 0.9, cy + r * 0.35, r * 0.7), (cx + r * 0.8, cy + r * 0.3, r * 0.75))
    for lx, ly, lr in lumps:
        for y in range(int(ly - lr) - 1, int(ly + lr) + 2):
            for x in range(int(lx - lr) - 1, int(lx + lr) + 2):
                dx, dy = (x + 0.5 - lx) / lr, (y + 0.5 - ly) / lr
                q = dx * dx + dy * dy
                if q > 1.0 or y > GROUND + 1:
                    continue
                if stage == 1 and q > 0.45 and (x + y) % 2 == 0:
                    continue
                if stage == 2 and (q > 0.55 or (x + y) % 2 == 0):
                    continue
                l = lit(dx, dy)
                col = "D2" if l > 0.3 else "D1" if l > -0.35 else "D0"
                if (x, y) not in c.px or col == "D2":
                    c.set(x, y, col)


def add_dust(canvas, puffs):
    if not puffs:
        return
    d = Canvas(canvas.size)
    for x, y, r, stage in puffs:
        dust_puff(d, x, y, r, stage)
    for k in list(d.px):
        if k in canvas.px:
            del d.px[k]
    canvas.over(d)


def add_fx(canvas, fx):
    """Sparks and chips: (x, y, color), one pixel each."""
    for x, y, col in fx:
        if (x, y) not in canvas.px:
            canvas.set(x, y, col)


# --- animations -----------------------------------------------------------------------------

def gait(phase, stride=2):
    """Leg moves of the walk: SET_A swings forward lifted while the other four push back, then
    they swap (8 phases)."""
    swing = [(-stride, 0), (-stride // 2, 2), (stride // 2, 3), (stride, 1),
             (stride, 0), (stride // 2, 0), (0, 0), (-stride // 2, 0)]
    out = []
    for k in range(8):
        dx_, lift = swing[(phase + (0 if k in SET_A else 4)) % 8]
        out.append((dx_, lift, 0))
    return out


def idle():
    # It breathes, the abdomen swelling and the mouth's glow pulsing, while its legs drum the
    # floor one after another.
    taps = [(4, 5), (5, 6), (0, 4), (6, 7), (4, 5), (1, 5)]
    frames = []
    for i in range(6):
        legs = [(0, 0, 0)] * 8
        for k, leg in enumerate(taps[i]):
            legs[leg] = (0, 2 if k == 0 else 1, 0)
        frames.append(pose(legs=legs, breath=[0, 0.4, 0.8, 0.8, 0.4, 0][i], dy=[0, 0, 1, 1, 0, 0][i],
                           glow=[1, 1, 2, 2, 1, 1][i], eyes="shut" if i == 5 else "open"))
    return frames


def walk():
    return [pose(legs=gait(i), dy=-1 if i % 4 in (1, 2) else 0, breath=0.3 if i % 4 == 0 else 0)
            for i in range(8)]


def front(fdx, lift, kdy, rest=(0, 0, 0)):
    legs = [rest] * 8
    for i in FRONT:
        legs[i] = (fdx, lift, kdy)
    return legs


def attack():
    # It rears up on its back legs, front legs and drill raised high, then stabs down with all
    # three in a puff of dust and chips.
    return [
        pose(dy=1, legs=front(-1, 0, 1, (0, 0, 1)), drill=(60, 5.5)),
        pose(tilt=10, legs=front(2, 5, -3), drill=(80, 5.5), glow=2),
        pose(tilt=18, dx=-1, legs=front(4, 9, -5), drill=(90, 5), glow=2),
        pose(tilt=20, dx=-2, legs=front(4, 10, -6), drill=(95, 5), glow=2,
             fx=[(57, 27, "L3"), (53, 22, "L2")]),
        pose(tilt=4, dx=1, legs=front(3, 4, -2), drill=(70, 7), glow=2),
        pose(tilt=-6, dx=3, dy=1, legs=front(5, 0, 1), drill=(55, 8.5), glow=2,
             dust=[(57, 42, 3, 0)], fx=[(60, 37, "L3"), (59, 40, "L2"), (55, 38, "S2"), (61, 41, "D2")]),
        pose(tilt=-3, dx=2, dy=1, legs=front(4, 0, 0), drill=(62, 7.5), dust=[(57, 41, 3.5, 1)]),
        pose(drill=(70, 6.5), dust=[(58, 40, 3.5, 2)]),
    ]


def special():
    # The drill: it crouches, runs trailing dust and a crack, rears and drives the drill into the
    # floor, which heaps up a mound of earth and cracks open around it.
    return [
        pose(dy=2, glow=2, legs=[(0, 0, 2)] * 8, breath=-0.3),
        pose(legs=gait(1, 3), dx=1, dy=-1, glow=2, dust=[(12, 42, 2.5, 0)]),
        pose(legs=gait(3, 3), dx=3, glow=2, dust=[(10, 41, 3.5, 0), (17, 43, 2, 0)], trail=(18, 26)),
        pose(legs=gait(5, 3), dx=4, tilt=10, glow=2, drill=(95, 4.5), dust=[(8, 40, 4, 1), (15, 42, 3, 0)],
             trail=(16, 30)),
        pose(dx=4, dy=1, tilt=-8, glow=2, drill=(78, 10), mound=1, cracks=1, legs=front(1, 0, 1),
             dust=[(6, 39, 4, 2), (58, 41, 3, 0)], fx=[(56, 37, "L3"), (45, 40, "D2")]),
        pose(dx=4, dy=1, tilt=-8, glow=2, drill=(78, 10), mound=2, cracks=3, legs=front(1, 0, 1),
             dust=[(59, 40, 3.5, 1)], fx=[(60, 35, "D2"), (42, 38, "D1"), (57, 33, "L2")]),
        pose(dx=4, dy=1, tilt=-6, drill=(78, 9), mound=2, cracks=5, dust=[(60, 39, 3.5, 2)]),
        pose(dx=2, drill=(74, 7), mound=2, cracks=6),
    ]


def hurt():
    return [
        pose(flash=True, dx=-1),
        pose(legs=[(0, 1, -2)] * 8, dx=-2, dy=-1, tilt=8, eyes="shut", glow=0, drill=(50, 6)),
        pose(dx=-1, dy=1, glow=2, tilt=-2),
        pose(),
    ]


def death():
    # It jerks up, rolls onto its back and its legs curl up in a fist while the lava goes out.
    return [
        pose(flash=True),
        pose(dy=-3, tilt=10, eyes="shut", legs=[(0, 3, -2)] * 8, glow=0, curl=0.3),
        pose(dy=-4, tilt=25, flip=0.4, eyes="shut", glow=0, curl=0.5, cool=1, drill=(80, 4.5)),
        pose(dy=-5, flip=-0.6, eyes="shut", glow=0, curl=0.7, cool=1, drill=(80, 4),
             dust=[(16, 43, 2.5, 0), (49, 43, 2.5, 0)]),
        pose(dy=-6, flip=-0.9, eyes="shut", glow=0, curl=0.9, cool=2, drill=(85, 3.5),
             dust=[(14, 42, 3, 1), (51, 42, 3, 1)]),
        pose(dy=-6, flip=-0.9, eyes="dead", glow=0, curl=1.0, cool=2, drill=(85, 3.5), dust=[(13, 41, 3, 2)]),
        pose(dy=-6, flip=-0.9, eyes="dead", glow=0, curl=1.0, cool=2, drill=(85, 3.5)),
        pose(dy=-6, flip=-0.9, eyes="dead", glow=0, curl=1.0, cool=3, drill=(85, 3.5)),
    ]


# --- the sinking floor ----------------------------------------------------------------------------

def jagged_ray(rng, angle, length):
    """A crooked crack from the patch's middle outwards: it wanders a little either side of its
    heading, one pixel at a time."""
    pts = []
    x, y = 16.0, 16.0
    heading = angle
    for _ in range(length * 3):
        heading += rng.uniform(-0.35, 0.35)
        heading = angle + max(-0.5, min(0.5, heading - angle))
        x += math.cos(heading) * 0.5
        y += math.sin(heading) * 0.5
        pts.append((int(math.floor(x)), int(math.floor(y))))
    return pixel_perfect(pts)


def _pit_layout():
    rng = random.Random(7)
    rays = [jagged_ray(rng, a, 15) for a in (-0.75, -2.35, 0.8, 2.3, 0.05, -1.6)]
    # the broken rim: how far each edge pixel sits in from the square
    rim = {}
    for d in range(PIT):
        for side in range(4):
            rim[(side, d)] = 1 if rng.random() < 0.18 else 0
    # rubble in chunks of about 3 px, each lit on its upper left and dark on its lower right
    chunk = {}
    for cy in range(PIT // 3 + 1):
        for cx in range(PIT // 3 + 1):
            chunk[(cx, cy)] = rng.choice((0, 1, 1, 2))
    rubble = {}
    for x in range(PIT):
        for y in range(PIT):
            base = chunk[(x // 3, y // 3)]
            col = ("K1", "K2", "K3")[base]
            if x % 3 == 2 or y % 3 == 2:
                col = "K0" if base < 2 else "K1"
            elif x % 3 == 0 and y % 3 == 0:
                col = ("K2", "K3", "K4")[base]
            rubble[(x, y)] = col
    mask = {(x, y): rng.random() for x in range(PIT) for y in range(PIT)}
    return rays, rim, rubble, mask


PIT_RAYS, PIT_RIM, PIT_RUBBLE, PIT_RUBBLE_MASK = _pit_layout()


def in_pit(x, y, shrink=0):
    """Is (x, y) inside the broken square of the patch (moved in by `shrink`)?"""
    n = PIT
    sides = ((0, x, y), (1, y, n - 1 - x), (2, x, n - 1 - y), (3, y, x))
    for side, along, inward in sides:
        if inward < shrink + PIT_RIM[(side, min(max(along, 0), n - 1))]:
            return False
    return True


def pit_frame(kind, k):
    """One 32x32 frame of the patch. kind: crack (k 0..4, growing), sink (k 0..1), sunk (k 0..2,
    looping), close (k 0..2)."""
    c = Canvas(PIT)
    n = PIT
    if kind == "crack":
        # the cracks spread from the middle; the patch's square edge breaks open last
        reach = [0.15, 0.35, 0.55, 0.8, 1.0][k]
        for r, ray in enumerate(PIT_RAYS):
            m = max(2, int(len(ray) * reach * (0.75 if r >= 4 else 1.0)))
            for j, (x, y) in enumerate(ray[:m]):
                if not (0 <= x < n and 0 <= y < n):
                    continue
                tip = j >= m - 2
                c.set(x, y, ("L4" if tip and k >= 2 else "L3") if tip else ("L2" if j < m * 0.6 else "L1"))
                if (x, y + 1) not in c.px:
                    c.set(x, y + 1, "O")
        # corner marks warn of the whole patch, then its rim splits
        edge_col = ["L0", "L1", "L1", "L2", "L2"][k]
        arm = [3, 4, 5, 7, 16][k]
        for (cx, cy, sx, sy) in ((0, 0, 1, 1), (n - 1, 0, -1, 1), (0, n - 1, 1, -1), (n - 1, n - 1, -1, -1)):
            for d in range(arm):
                if k == 4 and d % 6 == 4:
                    continue
                c.set(cx + sx * d, cy, edge_col)
                c.set(cx, cy + sy * d, edge_col)
        c.set(16, 16, "L4" if k >= 2 else "L3")
        return c
    if kind == "close":
        return pit_closing(k)
    # the hole: broken rim, rock walls lit from the upper left, darkness and embers at the bottom
    depth = {"sink": [0.45, 0.85]}.get(kind, [1.0] * 3)[k]
    wall = max(1, int(round(4 * depth)))
    for y in range(n):
        for x in range(n):
            if not in_pit(x, y):
                continue
            if not in_pit(x, y, 1):
                c.set(x, y, "L1" if (x * 5 + y * 3) % 7 == 0 and kind != "close" else "K2")
                continue
            inner = min(x, y, n - 1 - x, n - 1 - y) - 1
            if inner < wall:
                if y <= x and y <= n - 1 - x:          # far wall: lit
                    col = ["K3", "K3", "K2", "K1"][min(inner, 3)]
                elif x < y and x <= n - 1 - y:         # left wall
                    col = ["K2", "K2", "K1", "K1"][min(inner, 3)]
                else:                                  # near walls: in shadow
                    col = ["K1", "K0", "K0", "P1"][min(inner, 3)]
                c.set(x, y, col)
            else:
                c.set(x, y, "P1" if inner < wall + 2 else "P0")
    if kind in ("sunk", "sink") and depth > 0.6:
        # embers glowing deep down, drifting a little each frame
        glow = [[(14, 15), (17, 17), (15, 18)], [(15, 15), (16, 18), (18, 16)], [(13, 16), (16, 16), (17, 18)]]
        for j, (x, y) in enumerate(glow[k % 3]):
            c.set(x, y, "L1" if j else "L2")
    if kind == "sink":
        # chunks of the floor falling in
        for (x, y, col) in ((10 + 2 * k, 11 + 3 * k, "K3"), (11 + 2 * k, 11 + 3 * k, "K2"),
                            (20 - k, 13 + 2 * k, "K2"), (21 - k, 13 + 2 * k, "K1"),
                            (16, 19 + k, "K3"), (17, 19 + k, "K1")):
            c.set(x, y, col)
    return c


def pit_closing(k):
    """The pit closing (k 0..2) over the room's own floor: the hole shrinks to its middle, ringed
    by rubble, and the cracks around it go out; nothing else is painted."""
    c = Canvas(PIT)
    n = PIT
    inset = [6, 10, 13][k]
    ring = 3
    # cracks first, out on the floor around the hole, dimming
    crack = ["L1", "L0", "L0"][k]
    for r, ray in enumerate(PIT_RAYS):
        for j, (x, y) in enumerate(ray):
            if not (0 <= x < n and 0 <= y < n):
                continue
            if min(x, y, n - 1 - x, n - 1 - y) >= inset:
                continue
            if j > [14, 11, 8][k] or (k == 2 and j % 3 == 2):
                continue
            c.set(x, y, crack)
            if (x, y + 1) not in c.px:
                c.set(x, y + 1, "O")
    for y in range(n):
        for x in range(n):
            e = min(x, y, n - 1 - x, n - 1 - y)
            if e >= inset:
                # what is left of the hole
                inner = e - inset
                if inner == 0:
                    c.set(x, y, "K1" if y < n // 2 else "K0")
                else:
                    c.set(x, y, "P1" if inner == 1 else "P0")
            elif e >= inset - ring:
                # rubble heaped round it, thinning toward the floor
                keep = PIT_RUBBLE_MASK[(x, y)] < (1.0 - (inset - e) / (ring + 1.0))
                if keep:
                    c.set(x, y, PIT_RUBBLE[(x, y)])
    if k < 2:
        c.set(15 + k, 16, "L0")
    # rubble chunks get an outline so they read on any floor
    rubble = Canvas(PIT)
    rubble.px = {xy: col for xy, col in c.px.items() if col[0] == "K"}
    for (x, y) in list(rubble.px):
        for nb in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if nb not in c.px and 0 <= nb[0] < n and 0 <= nb[1] < n:
                c.px[nb] = "O"
    return c


def pit():
    frames = [pit_frame("crack", k) for k in range(5)]
    frames += [pit_frame("sink", k) for k in range(2)]
    frames += [pit_frame("sunk", k) for k in range(3)]
    frames += [pit_frame("close", k) for k in range(3)]
    return frames


def crack_segment(variant):
    """An 8x8 piece of the crack that runs across the floor from the drill, pointing right (its
    middle on row 4)."""
    c = Canvas(CRACK_W, CRACK_H)
    paths = [[(0, 2), (1, 2), (2, 1), (3, 1), (4, 2), (5, 2), (6, 3), (7, 2)],
             [(0, 2), (1, 3), (2, 3), (3, 2), (4, 2), (5, 1), (6, 2), (7, 2)],
             [(0, 2), (1, 2), (2, 2), (3, 3), (4, 3), (5, 2), (6, 1), (7, 2)]]
    paths = [[(x, y + 2) for (x, y) in path] for path in paths]
    for j, (x, y) in enumerate(paths[variant]):
        c.set(x, y, "L2" if j % 3 else "L3")
        if (x, y + 1) not in c.px and y + 1 < CRACK_H:
            c.set(x, y + 1, "O")
    # a hairline branch
    bx, by = [(4, 4), (2, 5), (5, 4)][variant]
    c.set(bx, by - 1 if variant != 1 else by + 1, "L1")
    return c


def strip(frames, path):
    w, h = frames[0].size, frames[0].height
    img = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        img.alpha_composite(f.image(), (i * w, 0))
    img.save(path)
    print(os.path.relpath(path), len(frames), "frames")


if __name__ == "__main__":
    for name, make in (("idle", idle), ("walk", walk), ("attack", attack), ("special", special),
                       ("hurt", hurt), ("death", death)):
        strip([draw_spider(p) for p in make()], os.path.join(OUT, "arana_talladora_%s.png" % name))
    strip(pit(), os.path.join(OUT, "arana_talladora_pit.png"))
    strip([crack_segment(v) for v in range(3)], os.path.join(OUT, "arana_talladora_crack.png"))
