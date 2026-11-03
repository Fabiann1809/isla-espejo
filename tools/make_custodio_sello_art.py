"""Draws the Custodio del sello's art (temple enemy, island 3) pixel by pixel.

The pack's guardian, scaled from 128 px down to the game, came out blurred, so it is drawn at the
game's own pixel size instead, following the pack's design: a round golem of warm brown stone with
lilac shoulder plates trimmed in gold, a small head behind a gold face plate with glowing eyes, big
fists hanging at its sides and a molten core glowing in its chest. It is built from a few parts
(legs, torso, shoulders, arms, fists, head) that each animation moves frame by frame, as in the
pack's sheet: idle, walk, attack (a punch that sweeps an arc of fire along the ground), special
(it raises its arms and a translucent golden dome grows over it, holds and fades), hurt and death
(it crumbles into a pile of rubble with dust). It also draws the dome it lays over the allies it
shields (SealGuardian draws it over each one).

Writes into `assets/sprites/custodio_sello/`:
    custodio_sello_<animation>.png   64x64 cells, facing right, feet on row 52: idle, walk,
                                     attack, special, hurt, death
    custodio_sello_dome.png          48x48 cells, its base on row 40: 3 rise, 4 hold (loop), 2 fade

    python tools/make_custodio_sello_art.py
Then tools/make_temple_enemy_frames.gd builds its SpriteFrames as for every temple enemy, and
tools/enemy_aseprite.lua keeps an editable `source/custodio_sello.aseprite`
(extras="dome:10:rise=1-3;hold=4-7;fade=8-9").
Needs Pillow.
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "custodio_sello")
CELL = 64
DOME_CELL = 48
## Last row of the feet; their outline goes on the row below.
GROUND = 52
## The dome over an ally: the middle of its base (the ally's feet go there).
DOME_BASE = 40

PALETTE = {
    "O": (26, 14, 14),      # outline
    "L": (54, 32, 28),      # inner line between parts
    # stone
    "K0": (52, 31, 26),
    "K1": (82, 52, 38),
    "K2": (116, 80, 58),
    "K3": (152, 116, 88),
    "K4": (190, 160, 132),
    # lilac shoulder plates
    "P0": (70, 54, 66),
    "P1": (104, 86, 98),
    "P2": (140, 122, 132),
    "P3": (182, 168, 172),
    # gold trim
    "G0": (120, 70, 22),
    "G1": (194, 128, 40),
    "G2": (236, 188, 82),
    "G3": (255, 230, 148),
    # core and fire
    "S1": (128, 36, 14),
    "S2": (192, 72, 18),
    "S3": (234, 118, 30),
    "S4": (250, 168, 50),
    "Y": (255, 212, 88),
    "Y2": (255, 246, 190),
    "W": (255, 243, 224),   # hurt flash
    # the dome's glass: the one translucent tone (fixed alpha)
    "F": (255, 186, 64, 104),
}
## The far side of the body is a step darker.
FAR = {"K4": "K3", "K3": "K2", "K2": "K1", "K1": "K0", "P3": "P2", "P2": "P1", "P1": "P0",
       "G3": "G2", "G2": "G1", "G1": "G0"}
## Death: each step cools the core and dims the stone.
COOL_STEPS = [
    {"Y2": "Y", "Y": "S4", "S4": "S3", "S3": "S2"},
    {"Y": "S3", "S4": "S2", "S3": "S2", "S2": "S1", "K4": "K3", "G3": "G2"},
    {"S3": "S1", "S2": "S1", "K3": "K2", "G2": "G1", "P3": "P2"},
]
## The fist about to punch glows like the core.
HOT = {"K4": "Y", "K3": "S4", "K2": "S3", "K1": "S2", "K0": "S1"}
STONE = ("K0", "K1", "K2", "K3", "K4")
PLATE = ("P0", "P0", "P1", "P2", "P3")


class Canvas:
    def __init__(self, size):
        self.size = size
        self.px = {}

    def set(self, x, y, c):
        if 0 <= x < self.size and 0 <= y < self.size:
            self.px[(x, y)] = c

    def over(self, other):
        self.px.update(other.px)

    def layer(self, part):
        """Puts `part` over what is drawn; where its edge meets the figure it gets a dark inner
        line instead of a second outline."""
        for (x, y), c in part.px.items():
            against = any(n not in part.px and n in self.px
                          for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
            self.px[(x, y)] = "L" if against and c not in ("Y", "Y2", "S4") else c

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

    def shift(self, dx, dy):
        self.px = {(x + dx, y + dy): c for (x, y), c in self.px.items()}

    def image(self):
        img = Image.new("RGBA", (self.size, self.size), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            col = PALETTE[c]
            img.putpixel((x, y), col if len(col) == 4 else col + (255,))
        return img


def in_ellipse(x, y, cx, cy, rx, ry):
    return ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0


def lit(nx, ny):
    """How much a surface with normal (nx, ny) faces the light (upper left)."""
    return -0.55 * nx - 0.8 * ny


def blob(cx, cy, rx, ry, ramp, size=CELL):
    """A shaded rounded lump of a five-tone ramp (dark to light)."""
    c = Canvas(size)
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if not in_ellipse(x, y, cx, cy, rx, ry):
                continue
            l = lit((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
            k = 4 if l > 0.62 else 3 if l > 0.2 else 2 if l > -0.3 else 1 if l > -0.72 else 0
            c.set(x, y, ramp[k])
    # no lone pixel sticking out of the rim
    for (x, y) in list(c.px):
        if sum(n in c.px for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))) <= 1:
            del c.px[(x, y)]
    return c


def capsule(ax, ay, bx, by, r, ramp):
    """A shaded limb from (ax, ay) to (bx, by)."""
    c = Canvas(CELL)
    vx, vy = bx - ax, by - ay
    ll = max(vx * vx + vy * vy, 0.001)
    for y in range(int(min(ay, by) - r) - 1, int(max(ay, by) + r) + 2):
        for x in range(int(min(ax, bx) - r) - 1, int(max(ax, bx) + r) + 2):
            px_, py_ = x + 0.5, y + 0.5
            t = max(0.0, min(1.0, ((px_ - ax) * vx + (py_ - ay) * vy) / ll))
            qx, qy = ax + vx * t, ay + vy * t
            d = math.hypot(px_ - qx, py_ - qy)
            if d > r:
                continue
            l = lit((px_ - qx) / r, (py_ - qy) / r)
            c.set(x, y, ramp[3] if l > 0.3 else ramp[2] if l > -0.3 else ramp[1])
    return c


def far(c):
    c.remap(FAR)
    return c


# --- the golem ---------------------------------------------------------------------------------

def pose(**kw):
    p = dict(dx=0, dy=0, hx=0, hy=0, sy=0, lean=0, bfx=0, bfy=0, ffx=0, ffy=0, bleg=0, fleg=0,
             glow=1, blink=False, hot=False, flash=False, cool=0, arc=0, dome=0.0, dome_kind=0,
             spread=0, fx=(), dust=())
    p.update(kw)
    return p


def core(cx, cy, glow):
    """The big round core in the middle of its chest: white-hot at its heart, and a 1 px halo of
    glow on the stone around it."""
    c = Canvas(CELL)
    ramp = [("S4", "S3", "S3", "S2"), ("Y", "S4", "S3", "S2"), ("Y2", "Y", "S4", "S3"),
            ("Y2", "Y2", "Y", "S4")][glow]
    for y in range(int(cy) - 6, int(cy) + 7):
        for x in range(int(cx) - 6, int(cx) + 7):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            q = math.hypot(dx, dy)
            # the light sits a little up and left in the ball
            h = math.hypot(dx + 0.8, dy + 0.8)
            if q <= 4.3:
                c.set(x, y, ramp[0] if h <= 1.6 else ramp[1] if h <= 2.9 else ramp[2] if q <= 3.5 else ramp[3])
            elif q <= 5.3:
                c.set(x, y, "S2" if glow >= 2 else "S1")
    return c


def draw_golem(p):
    """A round stone golem seen from the front, turned a little to the right: a small head with a
    gold face between two big lilac shoulder plates, arms hanging at its sides ending in big fists,
    two short legs apart, and the core in the middle of its chest."""
    ox, oy = p["dx"], p["dy"]
    lean = p["lean"]
    sy = p["sy"]
    fig = Canvas(CELL)
    # everything above the legs moves with dy; the shoulders (and the arms' tops) sag by `sy`
    tx, ty = 32.5 + ox + lean, 41.5 + oy
    sbx, sby = 24.5 + ox + lean - p["spread"], 36.0 + oy + sy
    sfx, sfy = 40.5 + ox + lean + p["spread"], 36.0 + oy + sy
    fbx, fby = 21.5 + ox + p["bfx"] - p["spread"], 47.0 + oy + p["bfy"]
    ffx, ffy = 44.0 + ox + p["ffx"] + p["spread"], 47.0 + oy + p["ffy"]
    hx, hy = 33.0 + ox + lean + p["hx"], 32.6 + oy + p["hy"]

    # back arm and fist, behind everything
    fig.layer(far(capsule(sbx - 1.5, sby + 1.5, fbx, fby - 1, 2.8, STONE)))
    fig.layer(far(knuckles(blob(fbx, fby, 3.8, 3.6, STONE), fbx, fby)))
    # two short legs apart (one lifts while walking); a foot pokes forward
    for (x0, x1, lift, shade_) in ((26, 31, p["bleg"], True), (34, 39, p["fleg"], False)):
        leg = Canvas(CELL)
        for y in range(int(45 + oy), GROUND + 1 - lift):
            for x in range(x0 + ox, x1 + ox):
                leg.set(x, y, "K3" if x == x0 + ox else "K1" if x == x1 + ox - 1 else "K2")
        leg.set(x1 + ox, GROUND - lift, "K1")
        fig.layer(far(leg) if shade_ else leg)
    # torso: a round chest narrower than the shoulders, gold plates at the hips
    torso = blob(tx, ty, 8.4, 7.0, STONE)
    for x in range(int(tx - 6), int(tx - 3)):
        torso.set(x, int(ty + 5), "G2" if x == int(tx - 6) else "G1")
    for x in range(int(tx + 3), int(tx + 6)):
        torso.set(x, int(ty + 5), "G2" if x == int(tx + 3) else "G1")
    fig.layer(torso)
    fig.over(core(tx + 0.5, ty + 0.5, p["glow"]))
    # the far shoulder plate
    fig.layer(far(trim(blob(sbx, sby, 5.6, 4.9, PLATE), sbx, sby, 5.6, 4.9)))
    # front arm and fist, then its shoulder plate over the arm's root; a fist raised over the
    # shoulder goes in front of it instead
    fist = knuckles(blob(ffx, ffy, 4.0, 3.7, STONE), ffx, ffy)
    if p["hot"]:
        fist.remap(HOT)
    plate = trim(blob(sfx, sfy, 5.8, 5.0, PLATE), sfx, sfy, 5.8, 5.0)
    raised = ffy < sfy - 2
    if raised:
        fig.layer(plate)
    fig.layer(capsule(sfx + 1.0, sfy + 1.5, ffx, ffy - 1, 2.9, STONE))
    fig.layer(fist)
    if not raised:
        fig.layer(plate)
    # the head last: it sits between the shoulders, its face in full view
    head = blob(hx, hy, 4.0, 3.8, STONE)
    hxi, hyi = int(hx), int(hy)
    # its face: a dark brow over two glowing eyes, a gold jaw plate with a slit of a mouth
    for x in range(hxi - 2, hxi + 4):
        if (x, hyi - 1) in head.px:
            head.set(x, hyi - 1, "K1")
        for dy in (1, 2):
            if (x, hyi + dy) in head.px:
                head.set(x, hyi + dy, "G2" if dy == 1 else "G1")
    for x in (hxi - 1, hxi + 2):
        head.set(x, hyi - 1, "O")
        head.set(x, hyi, "G0" if p["blink"] else ("Y2" if p["glow"] >= 2 and x > hxi else "Y"))
    head.set(hxi, hyi + 2, "O")
    head.set(hxi + 1, hyi + 2, "O")
    fig.layer(head)

    for step in COOL_STEPS[:p["cool"]]:
        fig.remap(step)
    fig.outline()
    if p["flash"]:
        fig.remap({c: "W" for c in PALETTE if c not in ("O", "L", "F")})
    return fig


def knuckles(fist, cx, cy):
    """Finger grooves across the front of a fist."""
    for k in (-1, 1):
        for dy in (0, 1):
            if (int(cx) + k, int(cy) + dy) in fist.px:
                fist.set(int(cx) + k, int(cy) + dy, "K1")
    return fist


def trim(part, cx, cy, rx, ry):
    """The gold rim of a shoulder plate: a band round its lower half, bright where it turns up."""
    for (x, y) in list(part.px):
        dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
        q = math.hypot(dx, dy)
        if 0.48 <= q <= 0.8 and dy > -0.25:
            part.px[(x, y)] = "G2" if dy < 0.3 else "G1"
    return part


# --- fire arc, dome, dust, rubble -----------------------------------------------------------------

def fire_arc(fade=0):
    """The crescent of fire the punch sweeps along the ground in front of it: what is inside one
    ellipse and outside another a little behind it, so it is thick and white-hot at the front and
    thin at its ends; fading, its tail burns out first and it cools."""
    c = Canvas(CELL)
    ox, oy, orx, ory = 41.0, 45.5, 19.0, 7.5
    ix, iy, irx, iry = 36.5, 44.0, 18.0, 7.0
    for y in range(36, GROUND + 3):
        for x in range(28, CELL):
            if not in_ellipse(x, y, ox, oy, orx, ory) or in_ellipse(x, y, ix, iy, irx, iry):
                continue
            if x < 30 + fade * 8 or y < 37:
                continue
            q_out = math.hypot((x + 0.5 - ox) / orx, (y + 0.5 - oy) / ory)
            q_in = math.hypot((x + 0.5 - ix) / irx, (y + 0.5 - iy) / iry)
            depth = (q_in - 1.0) / max((q_in - 1.0) + (1.0 - q_out), 0.01)  # 0 inner, 1 outer
            front = (x - 30) / 30.0
            heat = 1.0 - abs(depth - 0.35) * 1.6 + front * 0.45 - fade * 0.45
            col = "Y2" if heat > 1.05 else "Y" if heat > 0.8 else "S4" if heat > 0.55 else "S3" if heat > 0.3 else "S2"
            c.set(x, y, col)
    c.outline("S1")
    return c


def dome(size, cx, base, rx, h, kind, avoid=None):
    """The seal's dome: one translucent tone of golden glass, an opaque rim with a highlight on its
    upper left, and its base ring on the ground. `kind`: 0 whole, 1 flashing, 2 shimmer a..d (2-5),
    6 fading (rim broken, no glass), 7 last sparks. Glass is laid only where `avoid` has nothing,
    so the figure inside keeps its colors."""
    c = Canvas(size)
    ry = max(2.0, rx * 0.22)

    def inside(x, y):
        dx = (x + 0.5 - cx) / rx
        if y + 0.5 <= base:
            return dx * dx + ((base - y - 0.5) / h) ** 2 <= 1.0
        return dx * dx + ((y + 0.5 - base) / ry) ** 2 <= 1.0

    cells = [(x, y) for y in range(int(base - h) - 1, int(base + ry) + 2)
             for x in range(int(cx - rx) - 1, int(cx + rx) + 2) if inside(x, y)]
    cellset = set(cells)
    rim = {p for p in cells if any(n not in cellset for n in
                                   ((p[0] + 1, p[1]), (p[0] - 1, p[1]), (p[0], p[1] + 1), (p[0], p[1] - 1)))}
    if kind < 6:
        for p in cells:
            if avoid is None or p not in avoid.px:
                c.set(*p, "F")
    # the base ring: back half darker, front half bright
    for i in range(160):
        t = i / 160 * math.tau
        x = int(math.floor(cx + (rx - 0.6) * math.cos(t)))
        y = int(math.floor(base + (ry - 0.6) * math.sin(t)))
        if kind == 6 and i % 4 >= 2:
            continue
        if math.sin(t) < 0:
            if avoid is None or (x, y) not in avoid.px:
                c.set(x, y, "G1")
        else:
            c.set(x, y, "G2" if kind != 1 else "Y")
    for (x, y) in rim:
        if kind == 7:
            continue
        if kind == 6 and (x * 3 + y) % 5 >= 2:
            continue
        ang = math.atan2(base - y - 0.5, x + 0.5 - cx)  # 0 right, pi/2 top
        hi = 1.75 < ang < 2.75
        c.set(x, y, ("Y2" if hi else "Y") if kind == 1 else ("G3" if hi else "G2"))
    # the highlight streak inside the rim, up left
    if kind < 6:
        for i in range(40):
            t = 1.9 + i / 40 * 0.8
            x = int(math.floor(cx + (rx - 2.3) * math.cos(t)))
            y = int(math.floor(base - (h - 2.3) * math.sin(t)))
            if (x, y) in cellset and (x, y) not in rim and (avoid is None or (x, y) not in avoid.px):
                c.set(x, y, "G3" if kind != 1 else "Y2")
    # sparkles drifting over the glass
    if kind >= 2:
        sparks = {2: [(-0.5, 0.55), (0.45, 0.3)], 3: [(-0.3, 0.75), (0.55, 0.45)],
                  4: [(-0.1, 0.5), (0.3, 0.7)], 5: [(-0.6, 0.3), (0.15, 0.85)],
                  6: [(-0.4, 0.6), (0.5, 0.5), (0.0, 0.9)], 7: [(-0.5, 0.8), (0.4, 0.95), (0.1, 1.15)]}[kind]
        for fx_, fy_ in sparks:
            x, y = int(cx + fx_ * rx), int(base - fy_ * h)
            if avoid is None or (x, y) not in avoid.px:
                c.set(x, y, "Y2")
                if kind in (3, 6):
                    for n in ((x + 1, y), (x - 1, y), (x, y - 1), (x, y + 1)):
                        if avoid is None or n not in avoid.px:
                            c.set(*n, "Y")
    return c


def dust_puffs(c, puffs):
    """Clouds of stone dust: (x, y, r, tone), tone 0 a dense puff, 1 a smaller one breaking up,
    2 a few last specks. Never over the figure."""
    def put(x, y, col):
        if (x, y) not in c.px:
            c.set(x, y, col)
    for (x0, y0, r, tone) in puffs:
        if tone == 2:
            for dx, dy in ((-r, 0), (r - 1, -1), (0, -r + 1), (-r // 2, -r // 2 - 1)):
                put(int(x0 + dx), int(y0 + dy), "K3")
            continue
        rr = r if tone == 0 else r * 0.7
        for y in range(int(y0 - rr) - 1, int(y0 + rr) + 2):
            for x in range(int(x0 - rr) - 1, int(x0 + rr) + 2):
                if not in_ellipse(x, y, x0, y0, rr, rr * 0.75):
                    continue
                if tone == 1 and in_ellipse(x, y, x0 + rr * 0.5, y0 - rr * 0.4, rr * 0.45, rr * 0.4):
                    continue
                put(x, y, "K4" if (y + 0.5 - y0) < -rr * 0.25 else "K3")


## The pile it falls into: boulders (center x, center y from the ground, rx, ry, ramp).
RUBBLE = [
    (20, -3, 4.5, 3.5, STONE), (43, -3, 4.5, 3.5, STONE), (26, -4, 5.0, 4.0, PLATE),
    (37, -4, 5.0, 4.2, PLATE), (31, -7, 6.0, 5.0, STONE), (33, -12, 4.0, 3.5, STONE),
    (15, -1, 2.5, 2.0, STONE), (48, -1, 2.5, 2.0, STONE),
]


def rubble(drop, settle, ember, cool):
    """The pile: each boulder falls by `drop` (scaled by its height) and spreads by `settle`."""
    c = Canvas(CELL)
    # the ones lying low go last: they are in front
    for (bx, by, rx, ry, ramp) in sorted(RUBBLE, key=lambda b: -b[1]):
        y = GROUND + 0.5 + by * (1.0 - settle * 0.35) - drop * (-by / 12.0)
        x = 31.5 + (bx - 31.5) * (1.0 + settle * 0.15)
        c.layer(blob(x, y - ry + 1, rx, ry, ramp))
    # the head on top, its gold plate still showing
    hx, hy = 33, int(GROUND - 13 + 3 * settle)
    c.set(hx + 1, hy, "G1")
    c.set(hx + 2, hy, "G2")
    c.set(hx + 1, hy + 1, "G0")
    # the core's ember, cooling
    if ember >= 0:
        ex, ey = 30, int(GROUND - 6 + 2 * settle)
        cols = [("Y2", "Y"), ("Y", "S4"), ("S4", "S3"), ("S2", "S1")][ember]
        c.set(ex, ey, cols[0])
        c.set(ex + 1, ey, cols[1])
        c.set(ex, ey + 1, cols[1])
    for step in COOL_STEPS[:cool]:
        c.remap(step)
    c.outline()
    return c


def add_fx(canvas, fx):
    """Sparks and embers: (x, y, size, color); size 1 is one pixel, 2 a 2x2 ember."""
    if not fx:
        return
    drops = Canvas(canvas.size)
    for x, y, size, col in fx:
        if size == 1:
            drops.set(x, y, col)
        else:
            drops.set(x, y, "Y2" if col == "Y" else "Y")
            drops.set(x + 1, y, col)
            drops.set(x, y + 1, col)
            drops.set(x + 1, y + 1, "S3")
    drops.outline(only_empty_of=canvas)
    canvas.over(drops)


def frame(p):
    fig = draw_golem(p)
    if p["arc"]:
        a = p["arc"]
        arc = fire_arc(fade=a - 1)
        arc.over(fig)
        fig = arc
    if p["dome"]:
        scale = p["dome"]
        fig.over(dome(CELL, 31.5, GROUND + 0.5, 22.0 * scale, 29.0 * scale, p["dome_kind"], avoid=fig))
    if p["dust"]:
        dust_puffs(fig, p["dust"])
    add_fx(fig, p["fx"])
    return fig


# --- animations -------------------------------------------------------------------------------

def idle():
    # a slow heavy breath: shoulders and head rise a pixel, the core pulses
    sy = [0, 0, -1, -1, 0, 0]
    hy = [0, 0, -1, -1, -1, 0]
    glow = [1, 1, 2, 2, 1, 1]
    return [pose(sy=sy[i], hy=hy[i], glow=glow[i], blink=i == 4) for i in range(6)]


def walk():
    # heavy steps: one leg lifts, the body sinks onto the other, the fists swing against the legs
    bleg = [0, 1, 2, 1, 0, 0, 0, 0]
    fleg = [0, 0, 0, 0, 0, 1, 2, 1]
    dy = [1, 0, 0, 0, 1, 0, 0, 0]
    swing = [0, 1, 1, 1, 0, -1, -1, -1]
    return [pose(bleg=bleg[i], fleg=fleg[i], dy=dy[i], sy=dy[i], bfx=-swing[i], ffx=swing[i],
                 bfy=-abs(swing[i]) if swing[i] < 0 else 0, ffy=-abs(swing[i]) if swing[i] > 0 else 0,
                 glow=1 + (i % 4 == 0)) for i in range(8)]


def attack():
    # Raises the front fist over its shoulder while it heats up (the first 3/4 of the strip: the
    # windup), then brings it down in a low punch that sweeps an arc of fire in front, and settles.
    return [
        pose(glow=2, ffy=-3),
        pose(glow=2, lean=-1, ffx=-1, ffy=-8, sy=-1),
        pose(glow=3, lean=-1, hx=-1, ffx=-2, ffy=-13, sy=-1, hot=True),
        pose(glow=3, lean=-2, hx=-1, ffx=-3, ffy=-15, sy=-1, hot=True,
             fx=[(44, 26, 1, "Y"), (36, 27, 1, "S4")]),
        pose(glow=3, lean=-2, hx=-1, ffx=-3, ffy=-15, sy=-1, hot=True,
             fx=[(45, 24, 1, "S4"), (35, 25, 1, "S3"), (47, 30, 1, "Y")]),
        pose(glow=3, lean=0, ffx=3, ffy=-9, hot=True),
        pose(glow=2, lean=2, hx=2, ffx=12, ffy=-8, sy=1, dy=1, hot=True, arc=1),
        pose(glow=1, lean=1, hx=1, ffx=10, ffy=-6, sy=1, arc=2,
             fx=[(59, 38, 1, "S4"), (55, 35, 1, "S3")]),
    ]


def special():
    # Raises its fists and the dome grows over it during the windup; it flashes as the seal goes up
    # (about 2/3 into the strip, when the allies get their shields) and then fades.
    return [
        pose(glow=2, bfy=-2, ffy=-2, bfx=-1, ffx=1),
        pose(glow=3, bfy=-6, ffy=-6, bfx=-2, ffx=2, sy=-1, hy=-1, spread=1),
        pose(glow=3, bfy=-8, ffy=-8, bfx=-2, ffx=2, sy=-1, hy=-1, spread=1, dome=0.5, dome_kind=2),
        pose(glow=3, bfy=-8, ffy=-8, bfx=-2, ffx=2, sy=-1, hy=-1, spread=1, dome=0.8, dome_kind=3),
        pose(glow=3, bfy=-8, ffy=-8, bfx=-2, ffx=2, sy=-1, hy=-1, spread=1, dome=1.0, dome_kind=4),
        pose(glow=3, bfy=-5, ffy=-5, bfx=-1, ffx=1, hy=-1, dome=1.0, dome_kind=1),
        pose(glow=2, bfy=-2, ffy=-2, dome=1.0, dome_kind=6),
        pose(glow=1, dome=1.0, dome_kind=7),
    ]


def hurt():
    return [
        pose(flash=True, lean=-1, hx=-1),
        pose(lean=-2, hx=-2, hy=1, sy=1, dy=1, blink=True, glow=2, bfx=-1, ffx=-2),
        pose(lean=-1, hx=-1, glow=2),
        pose(glow=1),
    ]


def death():
    # It staggers, its knees give, it breaks apart into a pile of rubble in a cloud of dust and its
    # core goes out.
    frames = [
        frame(pose(glow=1, hy=1, hx=1, blink=True, sy=1)),
        frame(pose(glow=0, cool=1, dy=2, hy=2, sy=2, bfy=1, ffy=1, blink=True, bleg=0)),
        frame(pose(glow=0, cool=1, dy=5, hy=3, sy=4, spread=2, bfy=1, ffy=1, blink=True,
                   dust=[(14, 50, 3, 1), (50, 50, 3, 1)])),
    ]
    for drop, settle, ember, cool, dust in (
            (1.0, 0.0, 1, 1, [(12, 48, 4, 0), (52, 48, 4, 0), (31, 40, 3, 1)]),
            (0.0, 0.4, 2, 1, [(10, 46, 5, 1), (55, 46, 5, 1), (24, 38, 3, 2), (40, 37, 3, 2)]),
            (0.0, 0.8, 3, 2, [(8, 44, 5, 2), (57, 44, 5, 2)]),
            (0.0, 1.0, -1, 3, [])):
        c = rubble(drop, settle, ember, cool)
        dust_puffs(c, dust)
        frames.append(c)
    return frames


# --- the dome over an ally ------------------------------------------------------------------

def ally_dome():
    cx, base = DOME_CELL / 2, DOME_BASE + 0.5
    # wide and tall enough to cover an ally of Nico's size standing in it
    rx, h = 21.5, 31.0
    frames = [
        dome(DOME_CELL, cx, base, rx * 0.45, h * 0.45, 1),
        dome(DOME_CELL, cx, base, rx * 0.8, h * 0.8, 1),
        dome(DOME_CELL, cx, base, rx, h, 1),
    ]
    for k in (2, 3, 4, 5):
        frames.append(dome(DOME_CELL, cx, base, rx, h, k))
    frames.append(dome(DOME_CELL, cx, base, rx, h, 6))
    frames.append(dome(DOME_CELL, cx, base, rx, h, 7))
    return frames


def strip(frames, path):
    cell = frames[0].size
    img = Image.new("RGBA", (cell * len(frames), cell), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        img.paste(f.image(), (i * cell, 0))
    img.save(path)
    print(os.path.relpath(path), len(frames), "frames")


if __name__ == "__main__":
    for name, make in (("idle", idle), ("walk", walk), ("attack", attack), ("special", special),
                       ("hurt", hurt)):
        strip([frame(p) for p in make()], os.path.join(OUT, "custodio_sello_%s.png" % name))
    strip(death(), os.path.join(OUT, "custodio_sello_death.png"))
    strip(ally_dome(), os.path.join(OUT, "custodio_sello_dome.png"))
