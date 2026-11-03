"""Draws the Campanero de bronce's art (temple enemy, island 3) pixel by pixel.

The bestiary pack's bell, scaled from 128 px down to the game, came out blurred, so it is drawn at
the game's own pixel size instead, following the pack's design: a golden bronze bell with a glowing
rune on its face, two engraved bands, a flared lip and its clapper peeking out, and the chain that
rises from its crown, arcs back and hangs down behind it ending in a hook. The bell is drawn from
its profile, so it can rock and tip over cleanly: every animation is a list of poses (tilt, lift,
chain sway, rune glow) as in the pack's sheet: idle, walk (rocks along), attack (rocks and rings
with sound waves, then rises for the first stroke), special (one stroke: it slams down and a ring
of fire bursts around its lip), hurt and death (it tips over, cracks and breaks).
It also draws the ring of fire its strokes send along the floor (BronzeBellRinger's rings).

Writes into `assets/sprites/campanero_bronce/`:
    campanero_bronce_<animation>.png   64x64 cells, facing right, feet on row 52: idle, walk,
                                       attack, special, hurt, death
    campanero_bronce_ring.png          248x248 cells: the ring at 24 radii from 0 to its max
                                       radius (120 px; frame = radius / max * 23), cooling as it
                                       grows; its band (10 px) runs inward from the radius

    python tools/make_campanero_bronce_art.py
Then tools/make_temple_enemy_frames.gd builds its SpriteFrames as for every temple enemy, and
tools/enemy_aseprite.lua keeps an editable `source/campanero_bronce.aseprite` (extras="ring:26").
Needs Pillow.
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "campanero_bronce")
CELL = 64
## Last row of the shadow under the lip: what the game takes as its feet.
GROUND = 52
## Center of the lip at rest; the bell's profile is measured up from it.
LIP_X, LIP_Y = 33.0, 49.0
BELL_H = 17.0

RING_CELL = 248
RING_FRAMES = 24
RING_MAX = 120.0
RING_BAND = 10.0

PALETTE = {
    "O": (30, 16, 10),     # outline
    "H": (40, 28, 34),     # shadow on the floor
    # bronze
    "B0": (64, 34, 14),
    "B1": (110, 64, 22),
    "B2": (162, 102, 30),
    "B3": (210, 150, 50),
    "B4": (242, 202, 102),
    "B5": (255, 240, 182),
    # chain
    "C0": (96, 58, 26),
    "C1": (166, 108, 40),
    "C2": (226, 172, 78),
    # rune, sound and fire
    "F0": (126, 26, 14),
    "F1": (222, 92, 26),
    "F2": (255, 166, 46),
    "F3": (255, 228, 132),
    "W": (255, 250, 228),
    # dust
    "K0": (70, 58, 54),
    "K1": (112, 98, 88),
    "K2": (156, 140, 124),
}
RED_FLASH = {"B0": "F0", "B1": "F0", "B2": "F1", "B3": "F1", "B4": "F2", "B5": "F3",
             "C0": "F0", "C1": "F0", "C2": "F1"}
## The stroke: the lip goes white-hot for a moment.
HOT = {"B2": "B3", "B3": "B4", "B4": "B5", "B5": "W"}
## Death: the bronze dulls.
DULL = {"B5": "B4", "B4": "B3", "B3": "B2", "C2": "C1"}

## Half-width of the bell (px) going up from the lip (t = 0) to its crown (t = 1).
PROFILE = [(0.0, 10.0), (0.07, 9.6), (0.18, 8.4), (0.35, 7.2), (0.6, 6.4), (0.8, 6.0),
           (0.9, 5.0), (0.96, 3.6), (1.0, 1.6)]


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


def half_width(t):
    for (t0, w0), (t1, w1) in zip(PROFILE, PROFILE[1:]):
        if t0 <= t <= t1:
            return w0 + (w1 - w0) * (t - t0) / (t1 - t0)
    return 0.0


def rot(x, y, a):
    return x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a)


# --- the bell ---------------------------------------------------------------------------------

def pose(**kw):
    p = dict(tilt=0.0, lift=0, dx=0, sway=0.0, open=False, rune=1, clap=0, hot=False, flash=False, dull=False,
             crack=False, split=0, waves=(), fire=0.0, dust=(), fx=())
    p.update(kw)
    return p


## The rune on its face, relative to its center (it faces a little to the right).
RUNE = [(0, 0), (-1, 1), (0, 1), (1, 1), (0, 2), (-1, 3), (1, 3)]
## A jagged crack down the bell, local (x, height up from the lip).
CRACK = [(1, 16), (1, 15), (0, 14), (0, 13), (1, 12), (2, 11), (2, 10), (1, 9), (1, 8), (2, 7),
         (3, 6), (3, 5), (2, 4), (2, 3), (3, 2), (3, 1), (4, 0)]


def bell_local(lx, ly, p):
    """The color of the bell at local (lx, ly) (ly negative up from the lip), or None."""
    if p["open"] and ly > -1.5:
        # tipped over, its open mouth shows: a dark hollow inside the rim of the lip
        q = (lx / 10.4) ** 2 + ((ly - 0.6) / 2.8) ** 2
        if q > 1.0:
            return None
        if (lx / 8.6) ** 2 + ((ly - 0.6) / 1.7) ** 2 <= 1.0:
            return "B2" if abs(lx - p["clap"] - 2) <= 1.2 and ly > 0.3 else "B0"
        return "B3" if lx < 0 else "B2"
    if ly > 1.0:
        # under the lip: the dark mouth and the clapper hanging in it
        if ly <= 3.0 and abs(lx - p["clap"]) <= 1.3:
            return "B4" if lx - p["clap"] < 0 and ly < 2.0 else "B2"
        if ly <= 2.0 and abs(lx) <= 8.6:
            return "B0"
        return None
    if ly > -2.0:
        # the flared lip, a little wider than the bell
        hw = half_width(0.0) + 0.6
        if abs(lx) > hw:
            return None
        l = lit(lx / hw, 0.2) + (0.3 if ly < -1.0 else -0.3)
        return "B4" if l > 0.45 else "B3" if l > 0.0 else "B2" if l > -0.45 else "B1"
    t = -ly / BELL_H
    if t > 1.0:
        # the crown: a small loop the chain hangs from
        if t <= 1.0 + 3.2 / BELL_H and abs(lx) <= 1.6:
            if abs(lx) < 0.6 and -ly < BELL_H + 2.0:
                return "B0"
            return "B3" if lx < 0 else "B2"
        return None
    hw = half_width(t)
    if abs(lx) > hw:
        return None
    nx = lx / max(hw, 0.5)
    ny = -max(0.0, (t - 0.8) / 0.2)
    l = lit(nx, ny)
    col = "B5" if l > 0.62 else "B4" if l > 0.32 else "B3" if l > -0.05 else "B2" if l > -0.42 else "B1"
    hgt = -ly
    # two engraved bands, a little lighter just under each
    if 3.0 <= hgt < 4.0 or 13.0 <= hgt < 14.0:
        col = "B1" if l > -0.42 else "B0"
    rx, ry = lx - 1.0, hgt - 7.0
    if (round(rx - 0.5), 3 - round(ry - 0.5)) in [(x, y) for x, y in RUNE]:
        col = ["B1", "F1", "F2", "F3"][p["rune"]]
    return col


def draw_bell(p):
    a = math.radians(p["tilt"])
    px_, py_ = LIP_X + p["dx"], LIP_Y
    body = Canvas(CELL)
    for y in range(CELL):
        for x in range(CELL):
            wx, wy = x + 0.5 - px_, y + 0.5 - py_
            lx, ly = rot(wx, wy, -a)
            col = bell_local(lx, ly, p)
            if col is not None:
                body.set(x, y, col)
    # Then it rests its lowest pixel on the floor (rocking pivots on whichever corner is down).
    drop = (GROUND - 1 - p["lift"]) - max(y for _, y in body.px)
    body.px = {(x, y + drop): col for (x, y), col in body.px.items()}
    py_ += drop
    if p["hot"]:
        body.remap(HOT)
    if p["crack"] or p["split"]:
        crack = set()
        for (cx_, cy_) in CRACK:
            wx, wy = rot(cx_, -cy_, a)
            crack.add((math.floor(px_ + wx), math.floor(py_ + wy)))
        if p["split"]:
            # the two halves fall apart along the crack
            left, right = Canvas(CELL), Canvas(CELL)
            for (x, y), col in body.px.items():
                wx, wy = x + 0.5 - px_, y + 0.5 - py_
                lx, ly = rot(wx, wy, -a)
                edge = 2.0 + 0.12 * (-ly)
                (right if lx > edge else left).set(x, y, col)
            s = p["split"]
            body = Canvas(CELL)
            for half, (dx, dy) in ((left, (-s, 0)), (right, (s + 1, 1))):
                moved = Canvas(CELL)
                for (x, y), col in half.px.items():
                    moved.set(x + dx, min(y + dy, GROUND - 1), col)
                moved.outline()
                body.over(moved)
        else:
            for q in crack:
                if q in body.px:
                    body.px[q] = "B0"
    chain = draw_chain(p, a, px_, py_)
    chain.over(body)
    body = chain
    if not p["split"]:
        body.outline()
    if p["dull"]:
        body.remap(DULL)
    if p["flash"]:
        body.remap(RED_FLASH)
    back, front = fire_ring(p["fire"])
    out = shadow(p)
    out.over(back)
    out.over(body)
    out.over(front)
    add_waves(out, p["waves"], px_, py_)
    add_dust(out, p["dust"])
    add_fx(out, p["fx"])
    return out


def draw_chain(p, a, px_, py_):
    """From the crown the chain arcs back and hangs down behind the bell, ending in a hook; its
    loose end lags behind the bell's rocking (`sway`)."""
    c = Canvas(CELL)
    ax, ay = rot(0.0, -BELL_H - 2.6, a)
    ax, ay = px_ + ax, py_ + ay
    ex, ey = ax - 12.5 + p["sway"], ay + 8.0
    floor = GROUND - 2
    ey = min(ey, floor)
    c1 = (ax - 1.0, ay - 6.5)
    c2 = (ax - 12.0 + p["sway"] * 0.4, min(ay - 6.0, floor))
    pts = []
    for i in range(200):
        t = i / 199
        x = (1 - t) ** 3 * ax + 3 * (1 - t) ** 2 * t * c1[0] + 3 * (1 - t) * t * t * c2[0] + t ** 3 * ex
        y = (1 - t) ** 3 * ay + 3 * (1 - t) ** 2 * t * c1[1] + 3 * (1 - t) * t * t * c2[1] + t ** 3 * ey
        pts.append((math.floor(x), math.floor(min(y, floor + 0.9))))
    pts = pixel_perfect(pts)
    for i, (x, y) in enumerate(pts[1:], 1):
        k = i % 4
        c.set(x, y, "C2" if k == 1 else "C1" if k in (0, 2) else "C0")
        if k == 1:
            # every other link shows its side: a 2 px link
            px, py = pts[i - 1]
            c.set(x + (y - py), y - (x - px), "C1")
    hx, hy = pts[-1]
    for dx, dy, col in ((0, 1, "C2"), (0, 2, "C1"), (1, 3, "C1"), (2, 3, "C1"), (3, 2, "C2"), (3, 1, "C1")):
        c.set(hx + dx, min(hy + dy, GROUND - 1), col)
    return c


def shadow(p):
    s = Canvas(CELL)
    if p["split"] or abs(p["tilt"]) > 40:
        return s
    rx = 10.5 - 0.6 * p["lift"]
    for y in (GROUND - 1, GROUND):
        for x in range(int(LIP_X - rx) - 1, int(LIP_X + rx) + 2):
            if abs(x + 0.5 - LIP_X - p["dx"]) <= rx - (2.0 if y == GROUND else 0):
                s.set(x, y, "H")
    return s


def fire_ring(rx):
    """The ring of fire bursting from the lip on the floor, split into the half behind the bell
    and the half in front of it."""
    back, front = Canvas(CELL), Canvas(CELL)
    if rx <= 0:
        return back, front
    cx, cy = LIP_X, GROUND - 1.0
    ry = rx * 0.34
    for y in range(int(cy - ry) - 3, int(cy + ry) + 4):
        for x in range(int(cx - rx) - 3, int(cx + rx) + 4):
            q = math.hypot((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
            band = 2.4 / rx
            if q > 1.0 or q < 1.0 - 2 * band:
                continue
            col = "F3" if q > 1.0 - band * 0.6 else "F2" if q > 1.0 - band * 1.3 else "F1"
            if rx > 20 and col == "F3":
                col = "F2"
            (front if y + 0.5 >= cy else back).set(x, y, col)
    # flames licking up from the ring
    for k in range(10):
        ang = k / 10 * math.tau + 0.4
        x, y = cx + rx * math.cos(ang), cy + ry * math.sin(ang)
        h = 2 + (k % 3)
        if rx > 20:
            h -= 1
        dest = front if y >= cy else back
        for j in range(h):
            dest.set(math.floor(x), math.floor(y) - 1 - j, "F3" if j == 0 else "F2" if j < h - 1 else "F1")
    back.outline("F0")
    front.outline("F0", only_empty_of=back)
    return back, front


def add_waves(c, waves, px_, py_):
    """Sound waves: arcs leaving the bell's front, (radius, strength 1..2)."""
    if not waves:
        return
    s = Canvas(CELL)
    cx, cy = px_, py_ - 8.0
    for r, k in waves:
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            for x in range(int(cx), int(cx + r) + 2):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                ang = math.degrees(math.atan2(y + 0.5 - cy, x + 0.5 - cx))
                if abs(d - r) <= 0.55 and abs(ang) <= 34 - r * 0.3:
                    s.set(x, y, "F3" if k == 2 and abs(ang) < 12 else "F2" if k == 2 else "F1")
    s.outline("F0", only_empty_of=c)
    c.over(s)


def add_dust(c, puffs):
    """Dust: (x, y, radius[, thin]); each puff three blobs, lit on the upper left."""
    if not puffs:
        return
    s = Canvas(CELL)
    for puff in puffs:
        x, y, r = puff[:3]
        thin = len(puff) > 3 and puff[3]
        for bx, by, br in ((x, y, r), (x - r * 0.8, y + r * 0.35, r * 0.7), (x + r * 0.8, y + r * 0.3, r * 0.65)):
            for yy in range(int(by - br) - 1, int(by + br) + 2):
                for xx in range(int(bx - br) - 1, int(bx + br) + 2):
                    dx, dy = xx + 0.5 - bx, yy + 0.5 - by
                    d = math.hypot(dx, dy)
                    if d > br or (thin and (xx + yy) % 2):
                        continue
                    l = lit(dx / max(d, 0.1), dy / max(d, 0.1)) if d > br * 0.45 else 0.2
                    s.set(xx, yy, "K2" if l > 0.4 else "K1" if l > -0.35 else "K0")
    c.over(s)


def add_fx(c, fx):
    """Sparks: (x, y, color), one pixel each, outlined dark red."""
    if not fx:
        return
    s = Canvas(CELL)
    for x, y, col in fx:
        s.set(x, y, col)
    s.outline("F0", only_empty_of=c)
    c.over(s)


def lump(c, x, y, rx, ry, ramp):
    for yy in range(int(y - ry) - 1, int(y + ry) + 2):
        for xx in range(int(x - rx) - 1, int(x + rx) + 2):
            dx, dy = (xx + 0.5 - x) / rx, (yy + 0.5 - y) / ry
            if dx * dx + dy * dy > 1.0:
                continue
            l = lit(dx, dy)
            c.set(xx, yy, ramp[0] if l > 0.45 else ramp[1] if l > -0.2 else ramp[2])


def wreck(dust=()):
    """What is left: two shards of the bell, its clapper and the chain lying on the floor."""
    c = Canvas(CELL)
    # the chain, stretched out on the floor with the hook at its end
    for k, x in enumerate(range(10, 24)):
        y = GROUND - (1 if 13 <= x <= 16 else 0)
        c.set(x, y, "C2" if k % 4 == 1 else "C1" if k % 4 in (0, 2) else "C0")
    for dx, dy, col in ((-1, -1, "C1"), (-2, -2, "C2"), (-2, -3, "C1"), (-1, -4, "C1")):
        c.set(10 + dx, GROUND + dy, col)
    lump(c, 28.0, GROUND - 2.5, 5.5, 3.2, ("B4", "B3", "B1"))
    lump(c, 40.5, GROUND - 2.0, 4.5, 2.6, ("B3", "B2", "B1"))
    # the curve of the broken lip on the big shard
    for x in range(24, 33):
        c.set(x, GROUND - 1, "B1")
    lump(c, 34.0, GROUND - 1.0, 1.4, 1.3, ("B4", "B3", "B2"))
    c.set(27, GROUND - 4, "F1")
    c.set(28, GROUND - 3, "F1")
    c.outline()
    add_dust(c, dust)
    return c


# --- animations -----------------------------------------------------------------------------

def idle():
    rune = [1, 1, 2, 2, 2, 1]
    sway = [0, 0.5, 1, 1, 0.5, 0]
    return [pose(rune=rune[i], sway=sway[i]) for i in range(6)]


def walk():
    # It rocks from lip to lip to shuffle along; the chain's end lags behind the rocking.
    frames = []
    for i in range(8):
        s = math.sin(math.tau * i / 8)
        frames.append(pose(tilt=8 * s, sway=-3 * math.sin(math.tau * (i - 1) / 8),
                           clap=-round(s * 1.5), lift=1 if i in (2, 6) else 0))
    return frames


def attack():
    # It rocks back and forth ringing (sound waves), then rises for the first stroke, which the
    # special plays when it falls.
    return [
        pose(rune=1),
        pose(tilt=-7, sway=1, clap=1, rune=2),
        pose(tilt=9, sway=-2, clap=-1, rune=2, waves=[(13, 2)]),
        pose(tilt=-9, sway=2, clap=1, rune=2, waves=[(16, 1), (12, 2)]),
        pose(tilt=10, sway=-2, clap=-2, rune=3, waves=[(19, 1), (14, 2)]),
        pose(tilt=-4, lift=2, sway=1, rune=3, waves=[(22, 1), (17, 1)]),
        pose(tilt=-6, lift=4, sway=2, rune=3, waves=[(20, 1)]),
        pose(tilt=-6, lift=5, sway=2, rune=3, hot=True),
    ]


def special():
    # One stroke: it slams down white-hot, a ring of fire bursts from its lip along the floor, it
    # shivers ringing, settles and rises a little for the next stroke.
    return [
        pose(rune=3, hot=True, fire=8, fx=[(18, 44, "F3"), (49, 43, "F3"), (22, 40, "F2")]),
        pose(tilt=3, rune=3, hot=True, fire=14, fx=[(14, 41, "F2"), (53, 40, "F2")]),
        pose(tilt=-3, rune=3, fire=19),
        pose(tilt=2, rune=2, fire=23),
        pose(tilt=-1, rune=2),
        pose(rune=2),
        pose(lift=1, rune=2, sway=1),
        pose(lift=2, tilt=-2, rune=3, sway=1),
    ]


def hurt():
    return [
        pose(flash=True, tilt=-5),
        pose(tilt=-10, sway=3, clap=2, rune=0, dx=-1),
        pose(tilt=-4, sway=1, rune=1),
        pose(rune=1),
    ]


def death():
    # It cracks, tips over forward, hits the floor, breaks in two and leaves its wreck in the dust.
    return [
        pose(crack=True, rune=0, tilt=6),
        pose(crack=True, rune=0, tilt=24, dx=-3, sway=-3, dull=True),
        pose(crack=True, rune=0, tilt=56, dx=-7, sway=4, dull=True, open=True),
        pose(crack=True, rune=0, tilt=90, dx=-9, sway=17, dull=True, open=True,
             dust=[(44, 48, 2.6), (20, 48, 2.2)]),
        pose(split=1, rune=0, tilt=90, dx=-9, sway=18, dull=True, open=True,
             dust=[(46, 45, 3.4), (18, 46, 2.8)], fx=[(36, 33, "F2"), (47, 36, "F1")]),
        pose(split=3, rune=0, tilt=90, dx=-9, sway=18, dull=True, open=True,
             dust=[(47, 41, 3.6, True), (16, 42, 3.2)]),
        "wreck1",
        "wreck2",
    ]


def death_frames():
    frames = []
    for p in death():
        if p == "wreck1":
            frames.append(wreck([(30, 42, 3.4, True), (44, 44, 2.6, True)]))
        elif p == "wreck2":
            frames.append(wreck())
        else:
            frames.append(draw_bell(p))
    return frames


# --- the ring of fire on the floor -------------------------------------------------------------

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def ring(k):
    """The ring at frame `k`: radius k / 23 of its max, its 10 px band running inward from the
    radius: a white-hot rim, a solid orange band and a dithered red glow that thins inward. It
    cools as it grows and, near its max radius, breaks into arcs."""
    c = Canvas(RING_CELL)
    progress = k / (RING_FRAMES - 1)
    r = RING_MAX * progress
    cx = cy = RING_CELL / 2.0
    if r < 1.0:
        for y in range(int(cy) - 3, int(cy) + 3):
            for x in range(int(cx) - 3, int(cx) + 3):
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                if d <= 2.6:
                    c.set(x, y, "W" if d < 1.2 else "F3")
        c.outline("F0")
        return c
    lo = max(r - RING_BAND, 0.0)
    for y in range(int(cy - r) - 3, int(cy + r) + 4):
        for x in range(int(cx - r) - 3, int(cx + r) + 4):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            if d > r + 1.6 or d < lo - 0.5:
                continue
            ang = math.atan2(dy, dx)
            # its rim flickers a pixel in and out like a flame front
            edge = r + (0.7 if math.sin(ang * 23 + k * 1.7) > 0.3 else 0.0)
            if progress > 0.72 and math.sin(ang * 7 + k * 0.9) > 1.6 - 1.9 * (progress - 0.72) / 0.28:
                continue  # it breaks up into arcs as it fades
            if d > edge + 1.0:
                continue
            if d > edge:
                if progress < 0.9:
                    c.set(x, y, "F0")
                continue
            t = (edge - d) / RING_BAND
            if t < 0.15:
                col = "W" if progress < 0.3 else "F3" if progress < 0.7 else "F2"
            elif t < 0.32:
                col = "F3" if progress < 0.3 else "F2"
            elif t < 0.5:
                col = "F2" if progress < 0.45 else "F1"
            elif t < 0.68:
                col = "F1"
            else:
                # the inner part of the band glows in a dither that thins inward and as it cools
                density = (0.3 + (1.0 - t) * 1.2) * (1.0 - 0.35 * progress)
                if BAYER[y % 4][x % 4] / 16.0 >= density:
                    continue
                col = "F1" if t < 0.84 and progress < 0.6 else "F0"
            c.set(x, y, col)
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
        strip([draw_bell(p) for p in make()], os.path.join(OUT, "campanero_bronce_%s.png" % name))
    strip(death_frames(), os.path.join(OUT, "campanero_bronce_death.png"))
    strip([ring(k) for k in range(RING_FRAMES)], os.path.join(OUT, "campanero_bronce_ring.png"))
