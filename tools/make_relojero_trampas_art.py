"""Draws the Relojero de trampas' art (temple enemy, island 3) pixel by pixel.

The pack's clockmaker, scaled from 128 px down to the game, came out blurred, so it is drawn at
the game's own pixel size instead, following the pack's design: a squat, blocky golem of warm
brown stone with a small head block (one glowing eye slit), heavy shoulders, fists with molten
fingertips and, set in its chest, a big molten core inside a gold clock ring whose hand ticks
round. It is built from a few parts that each animation moves frame by frame, as in the pack's
sheet: idle, walk, attack (the core charges and fires a ball of fire), special (it winds itself up,
shaking, slams and spikes rise from the lava around it), hurt and death (it sags and collapses
into a pile of rocks, its gold ring lying in front). It also draws its floor traps (ClockTrap):
the spike plate, the saw with its track, and the fire nozzle with its jet.

Writes into `assets/sprites/relojero_trampas/`:
    relojero_trampas_<animation>.png  64x64 cells, facing right, feet on row 52: idle, walk,
                                      attack, special, hurt, death
    relojero_trampas_spikes.png       24x24 cells (a 16 px plate): ready, warn a, warn b, rising,
                                      up a, up b, dormant
    relojero_trampas_saw.png          16x16 cells (radius 7): 4 spin, warn, dormant
    relojero_trampas_track.png        60x8 cells (56 px track, pointing right): normal, dormant
    relojero_trampas_fire.png         64x16 cells, nozzle at (4, 8), pointing right: spout,
                                      spout warn, spout dormant, warn line a, b, 4 jet (56x12)
    relojero_trampas_nozzle.png       12x12 cells (an 8 px base): normal, warn, dormant

    python tools/make_relojero_trampas_art.py
Then tools/make_temple_enemy_frames.gd builds its SpriteFrames as for every temple enemy, and
tools/enemy_aseprite.lua keeps an editable `source/relojero_trampas.aseprite`
(extras="spikes:10,saw:20,nozzle:10"; the track's and the fire's cells are not square, which that
tool cannot split, so their `source/*.aseprite` hold one cell per frame, packed apart).
Needs Pillow.
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "relojero_trampas")
CELL = 64
## Last row of the feet; their outline goes on the row below.
GROUND = 52

PALETTE = {
    "O": (28, 14, 12),      # outline
    "L": (58, 32, 24),      # inner line between parts
    # stone
    "K0": (54, 30, 22),
    "K1": (88, 52, 34),
    "K2": (126, 82, 52),
    "K3": (166, 120, 80),
    "K4": (206, 162, 112),
    # gold ring and rivets
    "G0": (122, 72, 20),
    "G1": (198, 132, 36),
    "G2": (240, 194, 72),
    "G3": (255, 234, 150),
    # core and fire
    "S1": (132, 34, 10),
    "S2": (196, 70, 16),
    "S3": (236, 116, 26),
    "S4": (252, 166, 44),
    "Y": (255, 210, 84),
    "Y2": (255, 246, 188),
    # trap metal
    "M0": (52, 50, 58),
    "M1": (94, 92, 102),
    "M2": (148, 146, 152),
    "M3": (208, 206, 206),
    "W": (255, 243, 224),   # hurt flash
}
## The far side of the body is a step darker.
FAR = {"K4": "K3", "K3": "K2", "K2": "K1", "K1": "K0", "G3": "G2", "G2": "G1", "G1": "G0"}
## Death: each step cools the core and dims the stone.
COOL_STEPS = [
    {"Y2": "Y", "Y": "S4", "S4": "S3", "S3": "S2"},
    {"Y": "S3", "S4": "S2", "S3": "S2", "S2": "S1", "K4": "K3", "G3": "G2"},
    {"S3": "S1", "S2": "S1", "K3": "K2", "G2": "G1"},
]
## A trap gone dormant: dull and dark.
DORMANT = {"M3": "M1", "M2": "M1", "M1": "M0", "K4": "K2", "K3": "K1", "K2": "K1", "K1": "K0",
           "G3": "G1", "G2": "G0", "G1": "G0", "S4": "S1", "S3": "S1", "S2": "S1", "Y": "S1", "Y2": "S1"}
STONE = ("K0", "K1", "K2", "K3", "K4")
## Fireball (the core's shot): 7x7, relative to its top-left corner.
BALL = [
    "..YSS..",
    ".YyYSs.",
    "YyyYSs3",
    "yyyYS3s",
    "YyYS3s2",
    ".SS3s2.",
    "..322..",
]
## The same ball, spent, a moment later: 4x4.
BALL_SMALL = [
    ".YS.",
    "YyS3",
    "YS32",
    ".32.",
]
BALL_KEYS = {"y": "Y2", "Y": "Y", "S": "S4", "s": "S3", "3": "S3", "2": "S2"}


class Canvas:
    def __init__(self, w, h=None):
        self.w = w
        self.h = w if h is None else h
        self.size = w
        self.px = {}

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[(x, y)] = c

    def over(self, other):
        self.px.update(other.px)

    def layer(self, part):
        """Puts `part` over what is drawn; where its edge meets the figure it gets a dark inner
        line instead of a second outline."""
        for (x, y), c in part.px.items():
            against = any(n not in part.px and n in self.px
                          for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
            self.px[(x, y)] = "L" if against and c not in ("Y", "Y2", "S4", "G1", "G2", "G3") else c

    def outline(self, color="O", only_empty_of=None):
        """A 1 px outline around everything drawn (4-neighbours: rounder than 8)."""
        ring = {}
        for (x, y) in self.px:
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if (nx, ny) in self.px or not (0 <= nx < self.w and 0 <= ny < self.h):
                    continue
                if only_empty_of is not None and (nx, ny) in only_empty_of.px:
                    continue
                ring[(nx, ny)] = color
        self.px.update(ring)

    def remap(self, mapping):
        self.px = {p: mapping.get(c, c) for p, c in self.px.items()}

    def image(self):
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            img.putpixel((x, y), PALETTE[c] + (255,))
        return img


def lit(nx, ny):
    """How much a surface with normal (nx, ny) faces the light (upper left)."""
    return -0.55 * nx - 0.8 * ny


def shade(l, ramp):
    k = 4 if l > 0.62 else 3 if l > 0.2 else 2 if l > -0.3 else 1 if l > -0.72 else 0
    return ramp[k]


def lump(cx, cy, rx, ry, ramp, power=2.0, w=CELL):
    """A shaded lump of a five-tone ramp; `power` 2 is round, 4 a block with rounded corners."""
    c = Canvas(w)
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if abs(dx) ** power + abs(dy) ** power > 1.0:
                continue
            # a block faces mostly up, left, right or down: push the normal to its sides
            nx = math.copysign(abs(dx) ** (power - 1), dx)
            ny = math.copysign(abs(dy) ** (power - 1), dy)
            c.set(x, y, shade(lit(nx, ny), ramp))
    for (x, y) in list(c.px):
        if sum(n in c.px for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))) <= 1:
            del c.px[(x, y)]
    return c


def far(c):
    c.remap(FAR)
    return c


# --- the clockmaker ----------------------------------------------------------------------------

def pose(**kw):
    p = dict(dx=0, dy=0, lean=0, hx=0, hy=0, bfx=0, bfy=0, ffx=0, ffy=0, bleg=0, fleg=0,
             blx=0, flx=0, glow=1, hand=0, blink=False, flash=False, cool=0, tilt=0, ring_glow=False,
             fx=(), ball=None, trail=0, waves=0, lava=0, spikes=0, dust=())
    p.update(kw)
    return p


def line(x0, y0, x1, y1):
    """The pixels of a 1 px line (Bresenham)."""
    pts = []
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        pts.append((x0, y0))
        if (x0, y0) == (x1, y1):
            return pts
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def core(cx, cy, p):
    """The clock that fills its chest: a thick gold ring with hour notches round a molten face, a
    long hand that ticks round (`hand`, eighths of a turn) and a short one."""
    c = Canvas(CELL)
    ramp = [("S3", "S2", "S1"), ("Y", "S4", "S3", "S2"), ("Y2", "Y", "S4", "S3"), ("Y2", "Y2", "Y", "S4")][p["glow"]]
    if len(ramp) == 3:
        ramp = ramp + ("S1",)
    for y in range(int(cy) - 9, int(cy) + 10):
        for x in range(int(cx) - 9, int(cx) + 10):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            q = math.hypot(dx, dy)
            h = math.hypot(dx + 1.0, dy + 1.0)
            if q <= 4.5:
                # a molten face: hot up left, dark red at its rim, so the gold ring stands apart
                c.set(x, y, ramp[0] if h <= 1.8 else ramp[1] if h <= 3.2 else ramp[2] if q <= 3.7 else ramp[3])
            elif q <= 5.1:
                c.set(x, y, "L" if not p["ring_glow"] else "S2")
            elif q <= 7.0:
                if p["ring_glow"]:
                    c.set(x, y, "Y" if lit(dx / q, dy / q) > 0 else "S4")
                else:
                    l = lit(dx / q, dy / q)
                    inner = q <= 6.0
                    c.set(x, y, ("G2" if l > 0.3 else "G1" if l > -0.4 else "G0") if inner else
                          ("G3" if l > 0.45 else "G2" if l > -0.2 else "G1"))
            elif q <= 7.7:
                # its own dark line against the chest
                c.set(x, y, "L")
    ix, iy = int(cx), int(cy)
    # hour notches cut into the ring at 12, 3, 6 and 9
    for (nx, ny) in ((0, -6), (6, 0), (0, 6), (-6, 0)):
        c.set(ix + nx, iy + ny, "G0" if not p["ring_glow"] else "S3")
    hand = "O" if p["glow"] < 3 else "S1"
    a = p["hand"] / 8 * math.tau - math.pi / 2
    for (x, y) in line(ix, iy, ix + round(3.6 * math.cos(a)), iy + round(3.6 * math.sin(a))):
        c.set(x, y, hand)
    for (x, y) in line(ix, iy, ix - 2, iy + 1):
        c.set(x, y, hand)
    c.set(ix, iy, "G3")
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
            if math.hypot(px_ - qx, py_ - qy) > r:
                continue
            l = lit((px_ - qx) / r, (py_ - qy) / r)
            c.set(x, y, ramp[3] if l > 0.3 else ramp[2] if l > -0.3 else ramp[1])
    return c


def plate(part, cx, cy, rx, ry):
    """A shoulder plate: a lighter cap over its top with a gold rivet."""
    for (x, y) in list(part.px):
        if (y + 0.5 - cy) / ry < -0.15 and part.px[(x, y)] not in ("K0",):
            part.px[(x, y)] = "K4" if (y + 0.5 - cy) / ry < -0.6 else "K3"
        elif -0.15 <= (y + 0.5 - cy) / ry < 0.15:
            part.px[(x, y)] = "K1"
    part.set(int(cx), int(cy - ry * 0.45), "G2")
    return part


def draw_golem(p):
    """A wide, squat stone automaton seen from the front, turned a little to the right: a flat
    helmet of a head, plated shoulders, arms at its sides with molten fingertips, two short legs,
    and the clock filling its chest."""
    ox, oy = p["dx"], p["dy"]
    lean = p["lean"]
    fig = Canvas(CELL)
    tx, ty = 32.0 + ox + lean, 43.5 + oy
    sbx, sby = 21.5 + ox + lean, 39.5 + oy + p["tilt"]
    sfx, sfy = 43.0 + ox + lean, 39.5 + oy - p["tilt"]
    fbx, fby = 17.5 + ox + p["bfx"], 47.0 + oy + p["bfy"] + p["tilt"]
    ffx, ffy = 46.5 + ox + p["ffx"], 47.0 + oy + p["ffy"] - p["tilt"]
    hx, hy = 30.0 + ox + lean + p["hx"], 34.6 + oy + p["hy"]

    # back arm and fist
    fig.layer(far(capsule(sbx - 1.0, sby + 1.0, fbx, fby - 1, 2.4, STONE)))
    fig.layer(far(lump(fbx, fby, 3.2, 2.9, STONE)))
    _fingertips(fig, fbx - 1, fby + 2, far_side=True)
    # two short legs, wide apart
    for (x0, x1, lift, lx, back) in ((23, 28, p["bleg"], p["blx"], True), (36, 41, p["fleg"], p["flx"], False)):
        leg = Canvas(CELL)
        for y in range(int(47 + oy), GROUND + 1 - lift):
            for x in range(x0 + ox + lx, x1 + ox + lx):
                leg.set(x, y, "K3" if x == x0 + ox + lx else "K1" if x == x1 + ox + lx - 1 else "K2")
        leg.set(x1 + ox + lx, GROUND - lift, "K1")
        fig.layer(far(leg) if back else leg)
    # torso: a wide stone block, rivets at its corners
    torso = lump(tx, ty, 10.5, 7.0, STONE, power=3.5)
    for x, y in ((tx - 8, ty - 4), (tx + 7, ty - 4), (tx - 8, ty + 4), (tx + 7, ty + 4)):
        torso.set(int(x), int(y), "G2")
    fig.layer(torso)
    # the clock sits a little toward the front (right), the helmet a little back, as in the pack
    fig.over(core(tx + 1.5, ty + 0.5, p))
    # plated shoulders
    fig.layer(far(plate(lump(sbx, sby, 4.4, 4.0, STONE), sbx, sby, 4.4, 4.0)))
    fig.layer(capsule(sfx + 1.0, sfy + 1.0, ffx, ffy - 1, 2.5, STONE))
    fig.layer(lump(ffx, ffy, 3.4, 3.0, STONE))
    _fingertips(fig, ffx, ffy + 2)
    fig.layer(plate(lump(sfx, sfy, 4.6, 4.1, STONE), sfx, sfy, 4.6, 4.1))
    # head: a flat helmet with a gold brim and an eye slit on its front
    head = lump(hx, hy, 6.4, 2.7, STONE, power=3.0)
    hxi, hyi = int(hx), int(hy)
    for x in range(hxi - 6, hxi + 7):
        if (x, hyi + 2) in head.px:
            head.set(x, hyi + 2, "G1" if x % 3 else "G2")
    for x in range(hxi + 1, hxi + 6):
        if (x, hyi) in head.px:
            head.set(x, hyi, "O")
    if not p["blink"]:
        head.set(hxi + 3, hyi, "Y")
        head.set(hxi + 4, hyi, "Y2" if p["glow"] >= 2 else "S4")
    fig.layer(head)

    for step in COOL_STEPS[:p["cool"]]:
        fig.remap(step)
    fig.outline()
    if p["flash"]:
        fig.remap({c: "W" for c in PALETTE if c not in ("O", "L")})
    return fig


def _fingertips(fig, x, y, far_side=False):
    """The molten tips of its fingers, under the fist."""
    for k, c in enumerate(("S3", "S4", "S3")):
        fig.set(int(x) - 1 + k, int(y), FAR.get(c, "S2") if far_side else c)


# --- effects in its strips ----------------------------------------------------------------------

def ball(c, x, y, small=False):
    """The fireball it shoots, top-left at (x, y)."""
    b = Canvas(CELL)
    for j, row in enumerate(BALL_SMALL if small else BALL):
        for i, ch in enumerate(row):
            if ch != ".":
                b.set(x + i, y + j, BALL_KEYS.get(ch, ch))
    b.outline("S1", only_empty_of=c)
    c.over(b)


def trail(c, x0, x1, y, strength):
    """The streak the ball leaves from the core: a hot line that thins and breaks up."""
    for x in range(x0, x1):
        f = (x - x0) / max(x1 - x0, 1)
        if strength == 1 and (x % 2 or f < 0.4):
            continue
        c.set(x, y, "Y2" if f > 0.6 and strength == 2 else "Y" if f > 0.3 else "S4")
        if strength == 2 and f > 0.35:
            c.set(x, y - 1, "S4")
            c.set(x, y + 1, "S3")


def waves(c, n):
    """Wind-up shakes: orange arcs on both sides of it."""
    for k in range(n):
        r = 15 + 3 * k
        for t in range(-6, 7):
            a = t / 6 * 0.75
            for side in (1, -1):
                x = int(round(31.5 + side * r * math.cos(a)))
                y = int(round(43 + r * 0.8 * math.sin(a)))
                if (x, y) not in c.px:
                    c.set(x, y, "S4" if abs(t) < 4 else "S3")


## Lava strip and spikes of its special, around it: (x, base row, height scale, in front).
SPECIAL_SPIKES = [(9, 51, 0.8, False), (15, 50, 1.0, False), (48, 50, 1.0, False), (54, 51, 0.8, False),
                  (12, 55, 0.6, True), (20, 56, 0.7, True), (43, 56, 0.7, True), (51, 55, 0.6, True)]


def lava_strip(stage):
    """The lava that spreads around its feet as it slams: `stage` 1 cracks, 2 molten, 3 cooling."""
    c = Canvas(CELL)
    rx, ry = (14.0, 2.4) if stage == 1 else (27.0, 4.2)
    for y in range(GROUND - 5, GROUND + 7):
        for x in range(2, CELL - 2):
            q = math.hypot((x + 0.5 - 31.5) / rx, (y + 0.5 - (GROUND + 2)) / ry)
            if q > 1.0:
                continue
            if stage == 1:
                if (x * 7 + y * 3) % 5 or q > 0.95:
                    continue
                c.set(x, y, "S3")
                continue
            col = "S1" if q > 0.85 else "S2" if q > 0.6 else "S3" if q > 0.3 else "S4"
            if stage == 3:
                col = "S1" if q < 0.7 and (x * 5 + y * 3) % 11 == 0 else "K0"
            c.set(x, y, col)
    c.outline("O" if stage == 3 else "S1")
    return c


def spike(c, x, base, h):
    """A metal spike rising from the lava, lit from the left."""
    s = Canvas(CELL)
    for k in range(h):
        y = base - k
        if k < max(2, h * 0.45):
            s.set(x - 1, y, "M3")
            s.set(x, y, "M2")
            s.set(x + 1, y, "M1")
        else:
            s.set(x, y, "M3" if k < h - 1 else "M2")
    s.set(x - 1, base, "S4")
    s.set(x + 1, base, "S3")
    s.outline()
    c.over(s)


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
                if ((x + 0.5 - x0) / rr) ** 2 + ((y + 0.5 - y0) / (rr * 0.75)) ** 2 > 1.0:
                    continue
                if tone == 1 and ((x + 0.5 - x0 - rr * 0.5) / (rr * 0.45)) ** 2 + \
                        ((y + 0.5 - y0 + rr * 0.4) / (rr * 0.4)) ** 2 <= 1.0:
                    continue
                put(x, y, "K4" if (y + 0.5 - y0) < -rr * 0.25 else "K3")


def add_fx(canvas, fx):
    """Sparks: (x, y, color), one pixel each, outlined where they float free."""
    if not fx:
        return
    drops = Canvas(canvas.size)
    for x, y, col in fx:
        drops.set(x, y, col)
    drops.outline(only_empty_of=canvas)
    canvas.over(drops)


def frame(p):
    fig = draw_golem(p)
    if p["lava"]:
        ground = lava_strip(p["lava"])
        behind = Canvas(CELL)
        front = Canvas(CELL)
        for (x, base, scale, in_front) in SPECIAL_SPIKES:
            h = int(round(p["spikes"] * scale))
            if h >= 1:
                spike(front if in_front else behind, x, base, h)
        ground.over(behind)
        ground.over(fig)
        ground.over(front)
        fig = ground
    if p["waves"]:
        waves(fig, p["waves"])
    if p["trail"]:
        end = p["ball"][0] if p["ball"] else 58
        # a short streak behind the ball, clear of its own arm
        trail(fig, max(39 + p["dx"] + p["lean"], end - 9), end, 42 + p["dy"], p["trail"])
    if p["ball"]:
        ball(fig, *p["ball"])
    if p["dust"]:
        dust_puffs(fig, p["dust"])
    add_fx(fig, p["fx"])
    return fig


# --- animations -------------------------------------------------------------------------------

def idle():
    # it hums: a pixel up and down, the core pulses and the hand ticks round
    dy = [0, 0, -1, -1, 0, 0]
    glow = [1, 1, 2, 2, 1, 1]
    return [pose(dy=dy[i], glow=glow[i], hand=i, blink=i == 4) for i in range(6)]


def walk():
    # quick little steps: one leg lifts and swings forward while the body bobs
    bleg = [0, 1, 2, 1, 0, 0, 0, 0]
    fleg = [0, 0, 0, 0, 0, 1, 2, 1]
    blx = [-1, 0, 1, 1, 1, 0, -1, -1]
    flx = [1, 0, -1, -1, -1, 0, 1, 1]
    dy = [0, -1, -1, 0, 0, -1, -1, 0]
    swing = [1, 1, 0, -1, -1, -1, 0, 1]
    return [pose(bleg=bleg[i], fleg=fleg[i], blx=blx[i], flx=flx[i], dy=dy[i], bfx=-swing[i],
                 ffx=swing[i], hand=i, glow=1) for i in range(8)]


def attack():
    # The core charges for the first 3/4 of the strip (the windup): arms pull back, the ring
    # glows, sparks gather; then it fires a ball of fire from the core and rocks back.
    cx, cy = 34, 42
    return [
        pose(glow=2, bfx=-1, ffx=-1, hand=0),
        pose(glow=2, lean=-1, bfx=-2, ffx=-2, hand=2, fx=[(cx + 9, cy - 6, "S4"), (cx + 8, cy + 6, "S3")]),
        pose(glow=3, lean=-1, bfx=-2, ffx=-3, hand=4, fx=[(cx + 7, cy - 5, "Y"), (cx + 7, cy + 5, "S4"),
                                                           (cx + 10, cy, "S4")]),
        pose(glow=3, lean=-1, bfx=-2, ffx=-3, hand=6, ring_glow=True,
             fx=[(cx + 6, cy - 4, "Y2"), (cx + 6, cy + 4, "Y"), (cx + 8, cy, "Y")]),
        pose(glow=3, lean=-2, bfx=-3, ffx=-4, hand=7, ring_glow=True, fx=[(cx + 6, cy - 1, "Y2")]),
        pose(glow=3, lean=-2, bfx=-3, ffx=-4, hand=0, ring_glow=True),
        pose(glow=3, lean=-1, dx=-1, bfx=-1, ffx=-2, hand=0, ring_glow=True, ball=(47, 39), trail=2),
        pose(glow=1, hand=1, ball=(57, 40, True), trail=1, fx=[(62, 41, "S4")]),
    ]


def special():
    # Winds itself up, shaking (arcs either side), slams down: lava spreads round its feet and
    # spikes rise from it, hold, and sink as the lava crusts over.
    return [
        pose(dy=1, glow=2, hand=1, bfy=-1, ffy=-1),
        pose(dx=1, glow=2, hand=3, waves=1, bfy=-2, ffy=-2),
        pose(dx=-1, glow=3, hand=5, waves=2, bfy=-3, ffy=-3, ring_glow=True),
        pose(dy=1, glow=3, hand=7, bfy=1, ffy=1, lava=1, fx=[(10, 49, "S4"), (54, 48, "Y")]),
        pose(glow=3, hand=0, lava=2, spikes=6, ring_glow=True),
        pose(glow=2, hand=1, lava=2, spikes=12),
        pose(glow=2, hand=2, lava=2, spikes=11, fx=[(15, 40, "Y2"), (48, 41, "Y2")]),
        pose(glow=1, hand=3, lava=3, spikes=4),
    ]


def hurt():
    return [
        pose(flash=True, lean=-1),
        pose(lean=-2, hx=-1, hy=1, dy=1, blink=True, glow=2, hand=5, bfx=-1, ffx=-2),
        pose(lean=-1, glow=2, hand=6),
        pose(glow=1, hand=7),
    ]


## The pile it falls into: boulders (x, height above the ground, rx, ry).
RUBBLE = [(18, 3, 4.0, 3.0), (45, 3, 4.0, 3.0), (25, 4, 5.0, 4.0), (38, 4, 5.0, 4.0),
          (31, 7, 6.5, 5.0), (12, 1, 2.5, 2.0), (51, 1, 2.5, 2.0)]


def rubble(settle, ember, cool):
    c = Canvas(CELL)
    for (bx, h, rx, ry) in sorted(RUBBLE, key=lambda b: b[1]):
        y = GROUND + 1 - h * (1.0 - settle * 0.4)
        x = 31.5 + (bx - 31.5) * (1.0 + settle * 0.12)
        c.layer(lump(x, y - ry + 1, rx, ry, STONE))
    # glowing seams between the rocks
    for x, y in ((24, GROUND - 4), (36, GROUND - 3), (30, GROUND - 8)):
        c.set(x, int(y + settle * 2), "S3" if cool < 2 else "S1")
    # its gold ring lies on the pile with the last of the core inside it
    rx, ry = 4.5, 2.0
    gx, gy = 33.5, GROUND - 9 + settle * 3
    for y in range(int(gy - ry) - 1, int(gy + ry) + 2):
        for x in range(int(gx - rx) - 1, int(gx + rx) + 2):
            q = math.hypot((x + 0.5 - gx) / rx, (y + 0.5 - gy) / ry)
            if 0.6 <= q <= 1.0:
                c.set(x, y, "G2" if y < gy else "G1")
            elif q < 0.6 and ember >= 0:
                c.set(x, y, [("Y2", "Y"), ("Y", "S4"), ("S4", "S3"), ("S2", "S1")][ember][x % 2])
            elif q < 0.6:
                c.set(x, y, "K0")
    for step in COOL_STEPS[:cool]:
        c.remap(step)
    c.outline()
    return c


def death():
    # A jolt, its head knocked askew and arms dropping, it sags lopsided spitting sparks, then
    # collapses into a heap of rocks with its ring on top; the core goes out.
    frames = [
        frame(pose(glow=3, hand=2, dx=-1, blink=True, fx=[(44, 36, "Y2"), (39, 34, "Y")])),
        frame(pose(glow=1, hand=5, hx=1, hy=1, bfy=2, ffy=2, tilt=1, blink=True, cool=1)),
        frame(pose(glow=0, hand=5, dy=3, hx=2, hy=2, bfy=2, ffy=2, tilt=2, blink=True, cool=1,
                   fx=[(42, 30, "Y"), (36, 27, "S4"), (47, 33, "S4")], dust=[(12, 50, 3, 1), (52, 50, 3, 1)])),
    ]
    for settle, ember, cool, dust in (
            (0.0, 1, 1, [(10, 48, 4, 0), (54, 48, 4, 0), (31, 39, 3, 1)]),
            (0.5, 2, 1, [(8, 46, 5, 1), (57, 46, 5, 1), (23, 37, 3, 2), (41, 36, 3, 2)]),
            (0.8, 3, 2, [(6, 44, 5, 2), (59, 44, 5, 2)]),
            (1.0, -1, 3, [])):
        c = rubble(settle, ember, cool)
        dust_puffs(c, dust)
        frames.append(c)
    return frames


# --- the traps (ClockTrap) -----------------------------------------------------------------------

SPIKE_CELL = 24
## The plate's 16 px square inside the cell, and its 3x3 holes.
PLATE = (4, 4, 20, 20)
HOLES = [(x, y) for y in (6, 12, 17) for x in (6, 12, 17)]


def spike_plate(state):
    """state: ready, warn_a, warn_b, rise, up_a, up_b, dormant."""
    c = Canvas(SPIKE_CELL)
    x0, y0, x1, y1 = PLATE
    for y in range(y0, y1):
        for x in range(x0, x1):
            edge_tl = x == x0 or y == y0
            edge_br = x == x1 - 1 or y == y1 - 1
            if state == "warn_a" and (edge_tl or edge_br):
                col = "G2"
            else:
                col = "K3" if edge_tl else "K0" if edge_br else "K1"
            c.set(x, y, col)
    # chips in the stone
    for (x, y, col) in ((9, 9, "K2"), (14, 8, "K0"), (8, 15, "K0"), (15, 14, "K2"), (10, 18, "K2")):
        c.set(x, y, col)
    for (x, y) in ((x0 + 1, y0 + 1), (x1 - 2, y0 + 1), (x0 + 1, y1 - 2), (x1 - 2, y1 - 2)):
        c.set(x, y, "M2")
    glow = {"ready": None, "warn_a": "S3", "warn_b": "S2", "rise": "Y", "up_a": "S4", "up_b": "S3",
            "dormant": None}[state]
    for (hx, hy) in HOLES:
        for dx in (0, 1):
            c.set(hx + dx - 1, hy, glow or "O")
            c.set(hx + dx - 1, hy - 1, "O")
    spikes = Canvas(SPIKE_CELL)
    h = {"warn_a": 1, "warn_b": 1, "rise": 2, "up_a": 4, "up_b": 4}.get(state, 0)
    for i, (hx, hy) in enumerate(HOLES):
        if h == 1:
            spikes.set(hx, hy - 1, "M3" if state == "warn_a" else "M2")
            continue
        # a cone: wide at the hole, a point at the top, lit on its left
        for k in range(h):
            y = hy - k
            if k == 0:
                for dx, col in ((-1, "M3"), (0, "M2"), (1, "M1")):
                    spikes.set(hx + dx, y, col)
            elif k == 1 and h > 2:
                spikes.set(hx - 1, y, "M3")
                spikes.set(hx, y, "M1")
            else:
                tip = state == "up_b" and i % 4 == 0 and k == h - 1
                spikes.set(hx - (1 if h > 2 else 0), y, "Y2" if tip else "M3" if k < h - 1 else "M2")
    if h > 1:
        spikes.outline()
    c.over(spikes)
    c.outline()
    if state == "dormant":
        c.remap(DORMANT)
    return c


SAW_CELL = 16
SAW_R = 7.0
SAW_TEETH = 8


def saw(spin, hub="K1", dull=False):
    """The saw blade (radius 7), its teeth turned by `spin` of a tooth."""
    c = Canvas(SAW_CELL)
    cx = cy = SAW_CELL / 2
    for y in range(SAW_CELL):
        for x in range(SAW_CELL):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            q = math.hypot(dx, dy)
            ang = math.atan2(dy, dx)
            phase = (ang / math.tau * SAW_TEETH + spin) % 1.0
            reach = SAW_R * 0.68 + SAW_R * 0.32 * (1.0 - phase)
            if q > reach - 0.5:
                continue
            if q <= 2.2:
                c.set(x, y, hub)
            elif q <= 3.0:
                c.set(x, y, "M0")
            elif q > SAW_R * 0.68:
                c.set(x, y, "M3" if lit(dx / q, dy / q) > -0.2 else "M1")
            else:
                l = lit(dx / q, dy / q)
                c.set(x, y, "M3" if l > 0.55 else "M2" if l > -0.4 else "M1")
    c.outline()
    if dull:
        c.remap(DORMANT)
    return c


TRACK_W, TRACK_H = 60, 8


def track(dull=False):
    """The saw's 56 px track, lying along x."""
    c = Canvas(TRACK_W, TRACK_H)
    for x in range(2, 58):
        c.set(x, 3, "K2")
        c.set(x, 4, "O" if 4 <= x < 56 else "K1")
        c.set(x, 5, "K0")
    for x0 in (1, 56):
        for y in (3, 4, 5):
            for x in (x0, x0 + 1, x0 + 2):
                c.set(x, y, "M2" if y == 3 else "M1")
        c.set(x0 + 1, 4, "G2")
    c.outline()
    if dull:
        c.remap(DORMANT)
    return c


FIRE_W, FIRE_H = 64, 16
FIRE_X0, FIRE_Y0 = 4, 8
FIRE_LEN, FIRE_WIDTH = 56, 12


def spout(state):
    c = Canvas(FIRE_W, FIRE_H)
    for x in range(FIRE_X0, FIRE_X0 + 6):
        c.set(x, FIRE_Y0 - 1, "M3")
        c.set(x, FIRE_Y0, "M2")
        c.set(x, FIRE_Y0 + 1, "M1")
    for y in (FIRE_Y0 - 1, FIRE_Y0, FIRE_Y0 + 1):
        c.set(FIRE_X0 + 6, y, "M0")
    if state == "warn":
        c.set(FIRE_X0 + 6, FIRE_Y0, "Y")
        c.set(FIRE_X0 + 6, FIRE_Y0 - 1, "S4")
        c.set(FIRE_X0 + 6, FIRE_Y0 + 1, "S3")
    c.outline()
    if state == "dull":
        c.remap(DORMANT)
    return c


def warn_line(bright):
    """Where the jet will fire: a dotted line of embers."""
    c = Canvas(FIRE_W, FIRE_H)
    for x in range(FIRE_X0 + 8, FIRE_X0 + FIRE_LEN, 3):
        c.set(x, FIRE_Y0, ("Y" if (x // 3) % 2 else "S4") if bright else "S2")
    return c


FLICKER = [0.85, 1.0, 0.9, 0.95]


def jet(k):
    """The fire jet, 56 long and 12 wide at its end, flickering (frame k): white-hot along its
    middle, orange to red at its edges, its end rounding off in ragged tongues."""
    c = Canvas(FIRE_W, FIRE_H)
    flick = FLICKER[k]
    for x in range(FIRE_X0, FIRE_X0 + FIRE_LEN):
        d = (x - FIRE_X0 + 0.5) / FIRE_LEN
        half = 2.4 + (FIRE_WIDTH / 2 * flick - 2.4) * d
        # ragged edges that crawl along the jet
        half += (0.6 if ((x + 3 * k) // 3) % 3 == 0 else -0.4 if ((x + 3 * k) // 3) % 3 == 1 else 0.0)
        if d > 0.86:
            half *= 1.0 - (d - 0.86) / 0.14 * 0.7
        for y in range(FIRE_H):
            off = abs(y + 0.5 - (FIRE_Y0 + 0.5))
            if off > half:
                continue
            f = off / max(half, 0.1) + max(0.0, d - 0.7) * 0.8
            col = "Y2" if f < 0.22 else "Y" if f < 0.48 else "S4" if f < 0.74 else "S3" if f < 0.95 else "S2"
            c.set(x, y, col)
    c.outline("S1")
    # licks of flame past its end
    for (x, y) in [((FIRE_X0 + FIRE_LEN + 1, FIRE_Y0 - 2), (FIRE_X0 + FIRE_LEN - 3, FIRE_Y0 + 5)),
                   ((FIRE_X0 + FIRE_LEN + 1, FIRE_Y0 + 2), (FIRE_X0 + FIRE_LEN - 4, FIRE_Y0 - 6)),
                   ((FIRE_X0 + FIRE_LEN, FIRE_Y0 - 1), (FIRE_X0 + FIRE_LEN - 2, FIRE_Y0 + 6)),
                   ((FIRE_X0 + FIRE_LEN + 1, FIRE_Y0 + 1), (FIRE_X0 + FIRE_LEN - 3, FIRE_Y0 - 5))][k]:
        if (x, y) not in c.px:
            c.set(x, y, "S3")
    return c


NOZZLE_CELL = 12


def nozzle(state):
    """The nozzle's 8 px base with a round vent; it glows before firing."""
    c = Canvas(NOZZLE_CELL)
    for y in range(2, 10):
        for x in range(2, 10):
            c.set(x, y, "K3" if x == 2 or y == 2 else "K0" if x == 9 or y == 9 else "K1")
    for (x, y) in ((3, 3), (8, 3), (3, 8), (8, 8)):
        c.set(x, y, "G1")
    vent = {"normal": ("M2", "O"), "warn": ("Y", "S4"), "dull": ("M2", "O")}[state]
    for (x, y) in ((5, 4), (6, 4), (4, 5), (7, 5), (4, 6), (7, 6), (5, 7), (6, 7)):
        c.set(x, y, "M1" if state != "warn" else "S3")
    for (x, y) in ((5, 5), (6, 5), (5, 6), (6, 6)):
        c.set(x, y, vent[1] if (x, y) != (5, 5) else vent[0])
    c.outline()
    if state == "dull":
        c.remap(DORMANT)
    return c


def strip(frames, path):
    w, h = frames[0].w, frames[0].h
    img = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        img.paste(f.image(), (i * w, 0))
    img.save(path)
    print(os.path.relpath(path), len(frames), "frames")


if __name__ == "__main__":
    for name, make in (("idle", idle), ("walk", walk), ("attack", attack), ("special", special),
                       ("hurt", hurt)):
        strip([frame(p) for p in make()], os.path.join(OUT, "relojero_trampas_%s.png" % name))
    strip(death(), os.path.join(OUT, "relojero_trampas_death.png"))
    strip([spike_plate(s) for s in ("ready", "warn_a", "warn_b", "rise", "up_a", "up_b", "dormant")],
          os.path.join(OUT, "relojero_trampas_spikes.png"))
    strip([saw(k / 4) for k in range(4)] + [saw(0, hub="Y"), saw(0, dull=True)],
          os.path.join(OUT, "relojero_trampas_saw.png"))
    strip([track(), track(dull=True)], os.path.join(OUT, "relojero_trampas_track.png"))
    strip([spout("normal"), spout("warn"), spout("dull"), warn_line(True), warn_line(False)]
          + [jet(k) for k in range(4)], os.path.join(OUT, "relojero_trampas_fire.png"))
    strip([nozzle("normal"), nozzle("warn"), nozzle("dull")], os.path.join(OUT, "relojero_trampas_nozzle.png"))
