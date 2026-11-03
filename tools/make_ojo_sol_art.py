"""Draws the Ojo del sol's art (temple enemy, island 3) pixel by pixel.

The bestiary pack's sun eye, scaled from 128 px down to the game, came out blurred, so it is drawn at
the game's own pixel size instead, following the pack's design: a bronze disc with eight gold spikes
(four long ones with a collar, four short ones), a dark ring and a red-orange eye with a flame-shaped
slit, floating over its shadow. It is built from a few parts (disc, iris, spikes, shadow, a fire
flare in front of the eye) that each animation moves frame by frame, as in the pack's sheet: idle
(floats and its eye pulses), walk (bobs and sways), attack (the eye charges a ball of fire and spurts
short rays: it plays while the ray on the floor aims and holds), special (the eye blasts: it plays
while the laser burns), hurt and death (it cracks, bursts into pieces and smokes).
It also draws its ray and laser on the floor (SunEye's beam, tiled along the aim).

Writes into `assets/sprites/ojo_sol/`:
    ojo_sol_<animation>.png   64x64 cells, facing right, shadow (feet) on row 52: idle, walk,
                              attack, special, hurt, death
    ojo_sol_beam.png          16x16 tiles, laid along the beam (x = along, y = across, centered):
                              0-3 aiming ray (marching), 4 held ray lit, 5 held ray dim,
                              6-7 laser burning (loop), 8-9 laser fading, 10-11 laser's end burst,
                              12-13 laser's start glow
    ojo_sol_aim.png           64x64 cells, one row per direction (16, clockwise from the right):
                              the attack drawn looking and charging that way (SunEyeData.aim_art)
    ojo_sol_spin.png          same rows: the special for that direction, its spikes spinning
                              clockwise (columns 0-7) or counter-clockwise (8-15), the way the
                              laser sweeps (SunEyeData.spin_art). The attack / special strips are
                              their first row. The eye is redrawn per direction, never rotated.

    python tools/make_ojo_sol_art.py
Then tools/make_temple_enemy_frames.gd builds its SpriteFrames as for every temple enemy, and
tools/enemy_aseprite.lua keeps an editable `source/ojo_sol.aseprite`
(extras="beam:10:aim=1-4;lock=5-6;laser=7-8;fade=9-10;end=11-12;start=13-14"); the lua reads one
row, so the aim / spin sheets are packed from copies laid out as one long strip (rows one after
another), one tag per direction (`e`, `ese`, ..., spin `e_cw` / `e_ccw`, ...).
Needs Pillow.
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "ojo_sol")
CELL = 64
TILE = 16
## The shadow's row: what the game takes as its feet.
GROUND = 52
## Center of the disc at rest (between pixels: the disc is symmetric around it).
CX, CY = 32.0, 35.0

PALETTE = {
    "O": (26, 14, 12),     # outline
    "H": (40, 28, 34),     # shadow on the floor
    # bronze disc
    "D0": (52, 26, 20),
    "D1": (88, 48, 30),
    "D2": (128, 76, 42),
    "D3": (172, 114, 60),
    "D4": (216, 166, 98),
    # gold spikes
    "G0": (122, 76, 22),
    "G1": (198, 140, 34),
    "G2": (244, 198, 74),
    "G3": (255, 238, 162),
    # the eye and its fire
    "R0": (88, 14, 12),
    "R1": (168, 38, 18),
    "R2": (226, 94, 26),
    "Y": (255, 180, 48),
    "Y2": (255, 232, 132),
    "W": (255, 251, 228),
    # smoke
    "K0": (62, 54, 58),
    "K1": (102, 92, 94),
    "K2": (148, 138, 136),
}
## Hurt: it flashes red, as in the pack.
RED_FLASH = {"D0": "R0", "D1": "R1", "D2": "R1", "D3": "R2", "D4": "R2", "G0": "R1", "G1": "R2",
             "G2": "R2", "G3": "Y", "R2": "R1", "Y": "R2", "Y2": "Y", "W": "Y2"}
## Charging: the spikes heat up step by step.
HEAT_STEPS = [
    {},
    {"G3": "Y2"},
    {"G3": "W", "G2": "Y2", "G1": "G2"},
    {"G3": "W", "G2": "W", "G1": "Y2", "G0": "G1", "D3": "D4", "D2": "D3"},
]
## Death: the eye goes out and the bronze dulls.
DIM_STEPS = [
    {"W": "Y2", "Y2": "Y", "Y": "R2", "G3": "G2"},
    {"Y": "R1", "R2": "R1", "Y2": "R2", "G3": "G1", "G2": "G1", "D4": "D3"},
    {"R2": "D1", "R1": "D0", "R0": "O", "Y": "R1", "G2": "G1", "G1": "G0", "D4": "D3", "D3": "D2"},
]


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

    def shifted(self, dx, dy):
        c = Canvas(self.size)
        for (x, y), col in self.px.items():
            c.set(x + dx, y + dy, col)
        return c

    def image(self, width=None, height=None):
        img = Image.new("RGBA", (width or self.size, height or self.size), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            if 0 <= x < img.width and 0 <= y < img.height:
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


# --- the eye ----------------------------------------------------------------------------------

def pose(**kw):
    # aim: where the eye looks and its fire points, in degrees clockwise from the right (the
    # drawing is redone for it, never rotated); dx is then a recoil away from it.
    p = dict(dx=0, dy=0, spin=0.0, look=1, aim=0.0, glow=1, pupil=1, heat=0, flare=0.0, ray=0,
             cone=0, flash=False, crack=0, burst=0, rubble=0, dim=0, smoke=(), fx=())
    p.update(kw)
    return p


def rnd(v):
    return int(math.floor(v + 0.5))


def aim_axis(p):
    a = math.radians(p["aim"])
    return math.cos(a), math.sin(a)


DISC_R = 10.4
## bronze rim, then a gold ring, then a dark ring around the iris
RIM_IN = 8.4
GOLD_IN = 7.4
IRIS_R = 6.5
## (angle offset in degrees, start radius, tip radius, half-width at the base, at the tip, collar)
SPIKES = [(a, 9.4, 16.2, 2.1, 0.45, True) for a in (0, 90, 180, 270)] + \
         [(a, 9.4, 13.4, 1.5, 0.4, False) for a in (45, 135, 225, 315)]


def draw_spikes(c, cx, cy, spin):
    for ang, r0, r1, w0, w1, collar in SPIKES:
        a = math.radians(ang + spin)
        ux, uy = math.cos(a), math.sin(a)
        vx, vy = -uy, ux
        lo_x, hi_x = int(cx - r1 - 2), int(cx + r1 + 2)
        lo_y, hi_y = int(cy - r1 - 2), int(cy + r1 + 2)
        for y in range(lo_y, hi_y + 1):
            for x in range(lo_x, hi_x + 1):
                px_, py_ = x + 0.5 - cx, y + 0.5 - cy
                u = px_ * ux + py_ * uy
                v = px_ * vx + py_ * vy
                if u < r0 or u > r1:
                    continue
                f = (u - r0) / (r1 - r0)
                hw = w0 + (w1 - w0) * f
                if collar and r0 + 1.4 <= u <= r0 + 2.6:
                    hw += 0.8
                if abs(v) > hw:
                    continue
                side = 1.0 if v >= 0 else -1.0
                l = lit(vx * side, vy * side) + 0.25 * lit(ux, uy)
                col = "G2" if l > 0.25 else "G1" if l > -0.35 else "G0"
                if collar and r0 + 1.4 <= u <= r0 + 2.6:
                    col = "G1" if l > -0.2 else "G0"
                if f > 0.78 and l > -0.35:
                    col = "G3"
                c.set(x, y, col)
        # the axis, so thin tips never break up
        steps = int((r1 - r0) * 3)
        for i in range(steps + 1):
            u = r0 + (r1 - r0 - 0.4) * i / steps
            x, y = math.floor(cx + u * ux), math.floor(cy + u * uy)
            if (x, y) not in c.px:
                c.set(x, y, "G1")


def draw_disc(c, p, cx, cy):
    for y in range(int(cy - DISC_R) - 1, int(cy + DISC_R) + 2):
        for x in range(int(cx - DISC_R) - 1, int(cx + DISC_R) + 2):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            r = math.hypot(dx, dy)
            if r > DISC_R:
                continue
            nx, ny = dx / max(r, 0.01), dy / max(r, 0.01)
            if r > RIM_IN:
                l = lit(nx, ny)
                col = "D4" if l > 0.75 else "D3" if l > 0.3 else "D2" if l > -0.3 else "D1"
            elif r > GOLD_IN:
                l = lit(nx, ny)
                col = "G2" if l > 0.45 else "G1" if l > -0.5 else "G0"
            elif r > IRIS_R:
                col = "D0"
            else:
                col = iris_color(p, dx, dy, r)
            c.set(x, y, col)
    # rivets on the rim between the spikes
    for k in range(8):
        a = math.radians(22.5 + 45 * k + p["spin"])
        x, y = math.floor(cx + 9.4 * math.cos(a)), math.floor(cy + 9.4 * math.sin(a))
        c.set(x, y, "G2" if lit(math.cos(a), math.sin(a)) > -0.2 else "G0")
    draw_pupil(c, p, cx, cy)


def iris_color(p, dx, dy, r):
    glow = p["glow"]
    # the eye looks a little ahead: its bright center leans that way
    ux, uy = aim_axis(p)
    q = math.hypot(dx - 0.6 * p["look"] * ux, dy - 0.6 * p["look"] * uy)
    inner = [2.4, 3.1, 3.9, 4.8][glow]
    core = [0.0, 1.5, 2.2, 3.2][glow]
    if q <= core:
        col = "W" if glow == 3 else "Y2"
    elif q <= inner:
        col = "Y" if glow < 3 else "Y2"
    elif r > 5.0:
        col = "R1" if lit(dx / r, dy / r) < -0.45 else "R2"
    else:
        col = "R2" if glow < 2 else "Y"
    # a cream glint on the upper left of the iris
    ang = math.degrees(math.atan2(dy, dx)) % 360
    if 4.6 < r <= 6.0 and 200 <= ang <= 250:
        col = "Y2"
    return col


def draw_pupil(c, p, cx, cy):
    """A flame-shaped slit: pointed at the top, round at the bottom."""
    if p["pupil"] == 0:
        return
    ux, uy = aim_axis(p)
    x0 = int(cx) - 1 + rnd(p["look"] * ux)
    y0 = int(cy) + rnd(p["look"] * uy)
    tall = {1: 3, 2: 4}[p["pupil"]]
    for k in range(-tall, tall):
        y = y0 + k
        if k == -tall:
            c.set(x0 + 1, y, "R1")
        elif k < tall - 2:
            c.set(x0, y, "R0")
            c.set(x0 + 1, y, "R0")
        else:
            c.set(x0, y, "R0")
            c.set(x0 + 1, y, "R1")
    if p["pupil"] == 2:
        c.set(x0 - 1, y0 + 1, "R1")


def flare_ball(c, x, y, r):
    """A ball of fire: white core, yellow, orange rim."""
    for yy in range(int(y - r) - 1, int(y + r) + 2):
        for xx in range(int(x - r) - 1, int(x + r) + 2):
            q = math.hypot(xx + 0.5 - x, (yy + 0.5 - y) * 1.15) / max(r, 0.5)
            if q > 1.0:
                continue
            c.set(xx, yy, "W" if q < 0.35 else "Y2" if q < 0.6 else "Y" if q < 0.85 else "R2")


def flare(p, cx, cy):
    """Fire in front of the eye: the charging ball, short rays and the laser's cone."""
    f = Canvas(CELL)
    if p["flare"] <= 0:
        return f
    ux, uy = aim_axis(p)
    vx, vy = -uy, ux
    # The fire's axis runs through the centre of the pixel at the disc's edge, along the aim
    # (facing right: row 35, from column 39 on).
    ax = math.floor(cx + 7.5 * ux) + 0.5
    ay = math.floor(cy + 7.5 * uy) + 0.5
    # the side of a ray that faces the light is yellow, the other orange
    lit_side = 1.0 if lit(vx, vy) > lit(-vx, -vy) else -1.0
    reach = max(p["cone"], int(p["flare"]) + p["ray"]) + 2
    for y in range(int(ay - reach) - 1, int(ay + reach) + 2):
        for x in range(int(ax - reach) - 1, int(ax + reach) + 2):
            du, dv = x + 0.5 - ax, y + 0.5 - ay
            u = du * ux + dv * uy
            v = du * vx + dv * vy
            if p["cone"] and -0.5 <= u < p["cone"] - 0.5:
                # the blast: a cone of light leaving the eye, tapering to a point
                w = 3.2 * (1 - max(u, 0.0) / p["cone"]) + 0.5
                if abs(v) <= w + 0.01:
                    a = abs(v) / max(w, 0.5)
                    f.set(x, y, "W" if a < 0.3 else "Y2" if a < 0.6 else "Y" if a < 0.9 else "R2")
            if p["ray"]:
                k = u - int(p["flare"])
                if -0.5 <= k < p["ray"] - 0.5:
                    if abs(v) < 0.55:
                        f.set(x, y, "Y2" if k < p["ray"] - 1.5 else "Y")
                    elif abs(v) < 1.45 and k < p["ray"] - 2.5:
                        f.set(x, y, "Y" if v * lit_side > 0 else "R2")
    flare_ball(f, cx + 8.0 * ux, cy + 8.0 * uy, p["flare"])
    return f


def aimed_offset(p):
    """The disc's shift: its float (dy) plus its recoil (dx), pushed back away from the aim."""
    ux, uy = aim_axis(p)
    return rnd(p["dx"] * ux), p["dy"] + rnd(p["dx"] * uy)


def aimed_fx(p):
    """Sparks are placed for an eye facing right: turn them around the disc to its aim."""
    ux, uy = aim_axis(p)
    out = []
    for x, y, col in p["fx"]:
        dx, dy = x + 0.5 - CX, y + 0.5 - CY
        out.append((math.floor(CX + dx * ux - dy * uy), math.floor(CY + dx * uy + dy * ux), col))
    return out


def wedge_of(x, y, cx, cy, n, seed):
    """Which piece a pixel goes with when it bursts: wedges with jagged edges."""
    dx, dy = x + 0.5 - cx, y + 0.5 - cy
    ang = (math.degrees(math.atan2(dy, dx)) + 360 + 13 * math.sin(0.9 * math.hypot(dx, dy) + seed)) % 360
    return int(ang // (360 / n))


## Death: which way each piece flies when it bursts (it then drops).
PIECES = [(1.0, -0.6), (0.5, -1.0), (-0.5, -1.0), (-1.0, -0.6), (-0.9, 0.5), (0.9, 0.5)]


def burst_pieces(body, ids, t, cx, cy):
    """The disc split into its pieces, each `t` steps along its way and outlined on its own."""
    parts = {}
    for q, k in ids.items():
        parts.setdefault(k, {})[q] = body.px[q]
    out = Canvas(CELL)
    for k in sorted(parts, key=lambda k: -PIECES[k][1]):
        vx, vy = PIECES[k]
        pix = parts[k]
        ox, oy = vx * 5.0 * t, vy * 5.0 * t + 1.3 * t * t
        bottom = max(y for _, y in pix)
        oy = min(oy, GROUND - bottom)
        piece = Canvas(CELL)
        for (x, y), col in pix.items():
            piece.set(x + round(ox), y + round(oy), col)
        piece.outline()
        out.over(piece)
    return out


def lump(c, x, y, rx, ry, ramp):
    """A rounded chunk of bronze lying on the floor, lit from the upper left."""
    for yy in range(int(y - ry) - 1, int(y + ry) + 2):
        for xx in range(int(x - rx) - 1, int(x + rx) + 2):
            dx, dy = (xx + 0.5 - x) / rx, (yy + 0.5 - y) / ry
            if dx * dx + dy * dy > 1.0:
                continue
            l = lit(dx, dy)
            c.set(xx, yy, ramp[0] if l > 0.45 else ramp[1] if l > -0.2 else ramp[2])


def rubble(ember):
    """What is left: bronze chunks, two broken spikes and the dead eye's shard, on the floor."""
    c = Canvas(CELL)
    lump(c, 25.0, GROUND - 2.0, 4.6, 3.0, ("D3", "D2", "D1"))
    lump(c, 39.5, GROUND - 1.5, 3.6, 2.4, ("D3", "D2", "D1"))
    # spikes lying on the floor, tips out
    for k in range(7):
        c.set(16 + k, GROUND - 1, "G2" if k > 4 else "G1")
        if k < 4:
            c.set(16 + k, GROUND, "G0")
    for k in range(5):
        c.set(43 + k, GROUND, "G1" if k < 3 else "G2")
    lump(c, 32.0, GROUND - 3.5, 4.0, 3.6, ("D4", "D3", "D2"))
    # the eye's shard, its glow going out
    lump(c, 32.5, GROUND - 3.5, 2.0, 1.8, (["R2", "R1", "D1"][ember], ["R1", "R0", "D0"][ember], "R0" if ember < 2 else "D0"))
    c.set(33, GROUND - 4, ["Y", "R2", "R1"][ember])
    c.outline()
    return c


def draw_eye(p):
    ox, oy = aimed_offset(p)
    cx, cy = CX + ox, CY + oy
    body = Canvas(CELL)
    draw_spikes(body, cx, cy, p["spin"])
    draw_disc(body, p, cx, cy)
    if p["heat"]:
        for step in HEAT_STEPS[1:p["heat"] + 1]:
            body.remap(step)
    for step in DIM_STEPS[:p["dim"]]:
        body.remap(step)
    if p["crack"]:
        n = len(PIECES)
        ids = {q: wedge_of(q[0], q[1], cx, cy, n, 1.7) for q in body.px}
        # the cracks run between the pieces, from the eye outward
        for (x, y), k in ids.items():
            r = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if r > DISC_R + 0.5 or r < [0, 6.0, 2.0][p["crack"]]:
                continue
            if any(ids.get(nb, k) != k for nb in ((x + 1, y), (x, y + 1))):
                body.px[(x, y)] = "O"
    if p["rubble"]:
        body = rubble(p["rubble"] - 1)
    elif p["burst"]:
        body = burst_pieces(body, ids, p["burst"], cx, cy)
        if p["burst"] == 1:
            # the flash of the burst, at the heart of the eye
            pop = Canvas(CELL)
            flare_ball(pop, cx, cy, 5.0)
            pop.outline("R1")
            body.over(pop)
    else:
        body.outline()
    if p["flash"]:
        body.remap(RED_FLASH)
    fire = flare(p, cx, cy)
    fire.outline("R1", only_empty_of=body)
    body.over(fire)
    # The shadow lies under everything and never gets an outline.
    shadow = Canvas(CELL)
    if not p["burst"] and not p["rubble"]:
        rx = 6.5 - 0.5 * max(0, -p["dy"])
        for y in (GROUND - 1, GROUND):
            for x in range(int(CX - rx) - 1, int(CX + rx) + 2):
                if abs(x + 0.5 - CX) <= rx - (1.5 if y == GROUND else 0):
                    shadow.set(x, y, "H")
    shadow.over(body)
    add_smoke(shadow, p["smoke"])
    add_fx(shadow, aimed_fx(p))
    return shadow


def add_smoke(c, puffs):
    """Puffs of smoke: (x, y, radius[, thin]); each a little cloud of three blobs, lit on the
    upper left; a thinning puff breaks into a checker as it clears."""
    if not puffs:
        return
    s = Canvas(CELL)
    for puff in puffs:
        x, y, r = puff[:3]
        thin = len(puff) > 3 and puff[3]
        blobs = [(x, y, r), (x - r * 0.8, y + r * 0.35, r * 0.7), (x + r * 0.75, y + r * 0.3, r * 0.65)]
        for bx, by, br in blobs:
            for yy in range(int(by - br) - 1, int(by + br) + 2):
                for xx in range(int(bx - br) - 1, int(bx + br) + 2):
                    dx, dy = xx + 0.5 - bx, yy + 0.5 - by
                    d = math.hypot(dx, dy)
                    if d > br:
                        continue
                    if thin and (xx + yy) % 2:
                        continue
                    l = lit(dx / max(d, 0.1), dy / max(d, 0.1)) if d > br * 0.45 else 0.2
                    s.set(xx, yy, "K2" if l > 0.4 else "K1" if l > -0.35 else "K0")
    c.over(s)


def add_fx(c, fx):
    """Sparks and embers: (x, y, color), one pixel each, outlined dark red."""
    if not fx:
        return
    s = Canvas(CELL)
    for x, y, col in fx:
        s.set(x, y, col)
    s.outline("R0", only_empty_of=c)
    c.over(s)


# --- animations -----------------------------------------------------------------------------

def idle():
    bob = [0, 0, -1, -1, -1, 0]
    glow = [1, 1, 2, 2, 1, 1]
    return [pose(dy=bob[i], glow=glow[i], look=1 if i < 4 else 0) for i in range(6)]


def walk():
    # It drifts forward bobbing, its spikes swaying like a wheel that leans into the move.
    bob = [0, -1, -2, -1, 0, -1, -2, -1]
    return [pose(dy=bob[i], spin=round(9 * math.sin(math.tau * i / 8)), glow=1 + (i % 4 == 2))
            for i in range(8)]


## The eye looks along its aim this far (px) while it charges and fires (1 at rest).
AIM_LOOK = 2
## Directions drawn for the aim (rows of ojo_sol_aim.png / ojo_sol_spin.png), clockwise from the
## right, as SunEye picks them (SunEyeData.art_directions).
DIRECTIONS = 16
## While the laser burns the spikes turn this much per frame (degrees), the way the beam sweeps.
SPIN_STEP = 11.25


def attack(aim=0.0):
    # The eye fixes on its aim and heats up while a ball of fire gathers in front of it; while the
    # ray holds, it spurts short rays and shakes (the laser itself is the special).
    frames = [
        pose(glow=1),
        pose(glow=2, heat=1, flare=1.2),
        pose(glow=2, heat=1, flare=1.8, pupil=2),
        pose(glow=3, heat=2, flare=2.4, pupil=2),
        pose(glow=3, heat=2, flare=2.8, ray=3, pupil=2),
        pose(glow=3, heat=3, flare=3.2, ray=6, pupil=2, dx=-1, fx=[(47, 29, "Y"), (45, 41, "Y2")]),
        pose(glow=3, heat=2, flare=2.6, ray=4, pupil=2, fx=[(49, 31, "Y2"), (46, 40, "Y")]),
        pose(glow=3, heat=3, flare=3.3, ray=7, pupil=2, dx=-1, fx=[(48, 28, "Y2"), (50, 42, "Y")]),
    ]
    for f in frames:
        f.update(aim=aim, look=AIM_LOOK)
    return frames


def special(aim=0.0, turn=1):
    # The laser fires: a blast of white light from the eye, a cone that burns, then dies down. The
    # disc spins while it burns, clockwise (turn 1) or not (-1), as the laser sweeps after Nico.
    frames = [
        pose(glow=3, heat=3, flare=4.2, pupil=2, dx=-1, fx=[(44, 25, "Y2"), (45, 45, "Y2"), (52, 30, "Y")]),
        pose(glow=3, heat=3, flare=3.8, cone=13, pupil=2, dx=-2, fx=[(46, 27, "Y"), (47, 43, "Y")]),
        pose(glow=3, heat=3, flare=3.4, cone=17, pupil=2, dx=-2),
        pose(glow=3, heat=2, flare=3.8, cone=16, pupil=2, dx=-2, fx=[(49, 30, "Y2"), (50, 40, "Y2")]),
        pose(glow=3, heat=2, flare=3.4, cone=17, pupil=2, dx=-1),
        pose(glow=3, heat=2, flare=3.0, cone=12, pupil=2, dx=-1, fx=[(55, 33, "Y")]),
        pose(glow=2, heat=1, flare=2.0, cone=6, dx=-1, fx=[(52, 31, "R2"), (57, 36, "Y")]),
        pose(glow=2, flare=1.0, fx=[(46, 29, "R2"), (58, 34, "R2")]),
    ]
    for i, f in enumerate(frames):
        f.update(aim=aim, look=AIM_LOOK, spin=turn * SPIN_STEP * i)
    return frames


def aim_sheet():
    """Rows: the attack (charging) drawn for each direction."""
    return [attack(360.0 * k / DIRECTIONS) for k in range(DIRECTIONS)]


def spin_sheet():
    """Rows: the special (laser) for each direction, spinning clockwise then counter-clockwise."""
    return [special(360.0 * k / DIRECTIONS, 1) + special(360.0 * k / DIRECTIONS, -1)
            for k in range(DIRECTIONS)]


def hurt():
    return [
        pose(flash=True, dx=-1),
        pose(dx=-2, dy=-1, spin=-10, glow=0, pupil=2),
        pose(dx=-1, spin=-4, glow=1),
        pose(glow=1),
    ]


def death():
    # It cracks, shakes, bursts into pieces that drop to the floor and smoke while the eye goes out.
    return [
        pose(crack=1, glow=0, dim=1, pupil=2),
        pose(crack=2, glow=0, dim=1, pupil=2, dx=1, smoke=[(28, 22, 2.2)]),
        pose(crack=2, glow=0, dim=2, burst=1, smoke=[(29, 21, 3.4), (38, 25, 2.4)],
             fx=[(17, 26, "Y"), (47, 21, "Y2"), (44, 47, "Y"), (21, 45, "Y2")]),
        pose(crack=2, glow=0, dim=2, burst=2, smoke=[(28, 16, 4.0), (39, 20, 3.0)],
             fx=[(11, 30, "R2"), (53, 16, "Y"), (50, 44, "R2")]),
        pose(rubble=1, smoke=[(27, 12, 4.2), (39, 15, 3.4), (33, 42, 2.8)]),
        pose(rubble=1, smoke=[(28, 8, 4.0, True), (40, 10, 3.2), (32, 38, 3.4)]),
        pose(rubble=2, smoke=[(39, 6, 2.8, True), (31, 33, 3.4, True)]),
        pose(rubble=3, smoke=[(31, 29, 2.6, True)]),
    ]


# --- the ray and the laser on the floor --------------------------------------------------------

def tile():
    return Canvas(TILE)


def aim_ray(shift):
    """A thin dashed ray of light, its dashes marching toward Nico."""
    c = tile()
    for x in range(TILE):
        k = (x - shift) % 8
        if k < 5:
            c.set(x, 7, "Y2" if k == 4 else "Y")
    return c


def held_ray(on):
    c = tile()
    for x in range(TILE):
        if on:
            c.set(x, 7, "W")
            c.set(x, 6, "Y2" if x % 4 else "Y")
            c.set(x, 8, "Y")
        else:
            c.set(x, 7, "Y2" if x % 4 else "Y")
    return c


def laser(width, shift):
    """The burning beam, `width` px across (8 at full strength): a white core, yellow and orange
    bands, a dark red rim, and hot streaks flowing out along it."""
    c = tile()
    half = width / 2.0
    for y in range(TILE):
        a = abs(y + 0.5 - 8.0) / half
        if a > 1.0:
            continue
        for x in range(TILE):
            col = "W" if a < 0.3 else "Y2" if a < 0.55 else "Y" if a < 0.8 else "R2"
            streak = (x - shift + 3 * (y % 3)) % 8
            if col == "Y" and streak < 2:
                col = "Y2"
            elif col == "R2" and streak in (4, 5):
                col = "Y"
            c.set(x, y, col)
    c.outline("R1")
    return c


def burst(phase):
    """Where the laser hits a wall: a splash of light."""
    c = tile()
    flare_ball(c, 8.0, 8.0, 5.2 if phase == 0 else 4.4)
    rays = [(0, -1), (0, 1), (1, -1), (1, 1), (-1, -1), (-1, 1)] if phase == 0 else [(1, 0), (0, -1), (0, 1)]
    for dx, dy in rays:
        for k in range(5, 8):
            c.set(8 + dx * k - (1 if dx < 0 else 0), 8 + dy * k - (1 if dy < 0 else 0), "Y")
    c.outline("R1")
    return c


def start_glow(phase):
    """Where the laser leaves the eye: a round glow over the beam's flat end."""
    c = tile()
    flare_ball(c, 8.0, 8.0, 4.6 if phase == 0 else 4.0)
    c.outline("R1")
    return c


def beam():
    return ([aim_ray(s) for s in (0, 2, 4, 6)] + [held_ray(True), held_ray(False)] +
            [laser(8, 0), laser(8, 4), laser(6, 2), laser(4, 6)] + [burst(0), burst(1)] +
            [start_glow(0), start_glow(1)])


def grid(rows, path):
    cell = rows[0][0].size
    img = Image.new("RGBA", (cell * len(rows[0]), cell * len(rows)), (0, 0, 0, 0))
    for r, frames in enumerate(rows):
        for i, f in enumerate(frames):
            img.alpha_composite(f.image(), (i * cell, r * cell))
    img.save(path)
    print(os.path.relpath(path), len(rows), "rows of", len(rows[0]), "frames")


def strip(frames, path):
    cell = frames[0].size
    img = Image.new("RGBA", (cell * len(frames), cell), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        img.alpha_composite(f.image(), (i * cell, 0))
    img.save(path)
    print(os.path.relpath(path), len(frames), "frames")


if __name__ == "__main__":
    for name, make in (("idle", idle), ("walk", walk), ("attack", attack), ("special", special),
                       ("hurt", hurt), ("death", death)):
        strip([draw_eye(p) for p in make()], os.path.join(OUT, "ojo_sol_%s.png" % name))
    strip(beam(), os.path.join(OUT, "ojo_sol_beam.png"))
    grid([[draw_eye(p) for p in row] for row in aim_sheet()], os.path.join(OUT, "ojo_sol_aim.png"))
    grid([[draw_eye(p) for p in row] for row in spin_sheet()], os.path.join(OUT, "ojo_sol_spin.png"))
