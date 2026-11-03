"""Draws the Forjador condenado's art (temple enemy, island 3) pixel by pixel.

The bestiary pack's smith is tiny in its 128 px cells and came out as a blur at game size, so it is
drawn here at the game's own pixel size instead, following the pack's design: a hunched stone smith
with a bald head, a gold face plate and glowing eyes, a stone pauldron trimmed in gold and forearms
cracked with lava, crouched behind an iron anvil with a white-hot ingot, on a pool of lava. It is
built from a few parts (pool, legs, torso, head, pauldron, arms, hammer, anvil) that each animation
moves frame by frame, as in the pack's sheet: idle, walk, attack (raises the hammer and strikes the
ingot in a burst of sparks), special (raises its arms and great pillars of fire burst from the pool:
the call of the iron blocks), hurt (a red flash) and death (it slumps over the anvil and crumbles
into a pile while the pool crusts over). It also draws its IronBlock (IronBlock.art).

Writes into `assets/sprites/forjador_condenado/`:
    forjador_condenado_<animation>.png   64x64 cells, facing right, pool's last row 53: idle, walk,
                                         attack, special, hurt, death
    forjador_condenado_block.png         48x48 cells, footprint centered on (24, 30): 4 shadow sizes,
                                         falling, impact, 5 cooling (hottest first), 4 shattering

    python tools/make_forjador_condenado_art.py
Then tools/make_temple_enemy_frames.gd builds its SpriteFrames as for every temple enemy, and
tools/enemy_aseprite.lua keeps an editable `source/forjador_condenado.aseprite`
(extras="block:8:shadow=1-4;fall=5-5;impact=6-6;cool=7-11;shatter=12-15").
Needs Pillow.
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "forjador_condenado")
CELL = 64
BLOCK_CELL = 48
## Last row of the lava pool under its feet; its outline goes on the row below.
GROUND = 53

PALETTE = {
    "O": (24, 12, 14),      # outline
    # stone (body, head, pauldron)
    "K0": (52, 36, 36),
    "K1": (88, 64, 60),
    "K2": (128, 100, 90),
    "K3": (170, 144, 128),
    "K4": (212, 192, 172),
    # iron (anvil, hammer head, blocks)
    "I1": (74, 70, 92),
    "I2": (112, 108, 132),
    "I3": (162, 158, 180),
    # leather (apron, belt, handle) and the pool's crust
    "R0": (64, 34, 26),
    "R1": (110, 60, 36),
    # lava
    "S0": (84, 22, 18),
    "S1": (140, 36, 22),
    "S2": (196, 70, 26),
    "S3": (238, 124, 36),
    "S4": (252, 176, 64),
    "Y": (255, 218, 104),
    "Y2": (255, 248, 200),
    # gold face plate and trims
    "G0": (130, 86, 32),
    "G1": (212, 158, 58),
    "G2": (250, 218, 128),
    # hurt flash (the pack's smith flashes red)
    "H1": (196, 30, 58),
    "H2": (244, 104, 120),
}
## Death: each step cools the lava and dims the stone and the gold.
COOL_STEPS = [
    {"Y2": "Y", "Y": "S4", "S4": "S3", "S3": "S2"},
    {"Y": "S3", "S4": "S2", "S3": "S2", "S2": "S1", "K4": "K3", "G2": "G1"},
    {"S3": "S1", "S2": "S1", "S1": "S0", "K3": "K2", "G1": "G0", "I3": "I2"},
    {"S1": "R0", "S0": "R0", "K2": "K1", "I2": "I1"},
]
FLASH = {c: "H2" for c in ("Y2", "Y", "S4", "K4", "K3", "G2", "I3")}
FLASH.update({c: "H1" for c in ("S3", "S2", "K2", "G1", "I2", "R1", "I1", "K1", "G0")})
FLASH.update({c: "S1" for c in ("S1", "S0", "K0", "R0")})

STONE = ("K4", "K3", "K2", "K1")
BODY = ("K3", "K2", "K1", "K0")
LEGS = ("K2", "K1", "K0", "K0")
LAVA = ("S4", "S3", "S2", "S1")
IRON = ("I3", "I2", "I1", "K0")
GOLD = ("G2", "G1", "G1", "G0")

## Rest pose (cell coordinates).
POOL = (33.0, 51.5, 16.0, 2.8)       # center x, center y, radius x, radius y
TORSO = (28.0, 39.5, 8.5, 7.0)
HEAD = (35.5, 31.6, 4.6, 4.6)
NEAR_SHOULDER = (24.0, 36.0)          # the hammer arm, under the pauldron
FAR_SHOULDER = (32.0, 37.0)
HIPS = ((24.0, 44.5), (29.0, 44.5))
FEET = ((23.0, 51.0), (31.0, 51.0))
ARM = 5.5                             # upper arm and forearm length
## Anvil: its top plate's first row and left column.
ANVIL_TOP = 40
ANVIL_X = 36
## Hammer: handle length and where the head sits along it.
HANDLE = 7


class Canvas:
    def __init__(self, size):
        self.size = size
        self.px = {}

    def set(self, x, y, c):
        if 0 <= x < self.size and 0 <= y < self.size:
            self.px[(x, y)] = c

    def over(self, other):
        self.px.update(other.px)

    def paste(self, part, sep=None):
        """Draws `part` over this canvas; where its edge lies on something already drawn, that edge
        pixel becomes `sep` (a dark inner line instead of a second outline)."""
        for (x, y), c in part.px.items():
            if sep is not None and any(n in self.px and n not in part.px for n in neighbours(x, y)):
                c = sep
            self.px[(x, y)] = c

    def trim(self):
        """No lone pixel sticking out of a shape's rim."""
        for (x, y) in list(self.px):
            if sum(n in self.px for n in neighbours(x, y)) <= 1:
                del self.px[(x, y)]

    def outline(self, color="O", only_empty_of=None):
        """A 1 px outline around everything drawn (4-neighbours: rounder than 8)."""
        ring = {}
        for (x, y) in self.px:
            for nx, ny in neighbours(x, y):
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
            if 0 <= x < self.size and 0 <= y < self.size:
                img.putpixel((x, y), PALETTE[c] + (255,))
        return img


def neighbours(x, y):
    return ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))


def in_ellipse(x, y, cx, cy, rx, ry):
    return ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0


def lit(nx, ny):
    """How much a surface with normal (nx, ny) faces the light (upper left)."""
    return -0.55 * nx - 0.8 * ny


def shade(l, ramp, cuts=(0.55, 0.15, -0.35)):
    return ramp[0] if l > cuts[0] else ramp[1] if l > cuts[1] else ramp[2] if l > cuts[2] else ramp[3]


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


def line(ax, ay, bx, by):
    n = int(max(abs(bx - ax), abs(by - ay)) * 2) + 1
    return pixel_perfect([(math.floor(ax + (bx - ax) * i / n), math.floor(ay + (by - ay) * i / n))
                          for i in range(n + 1)])


def ellipse(c, cx, cy, rx, ry, ramp, cuts=(0.55, 0.15, -0.35)):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if in_ellipse(x, y, cx, cy, rx, ry):
                c.set(x, y, shade(lit((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry), ramp, cuts))


def capsule(c, ax, ay, bx, by, r, ramp, cuts=(0.55, 0.15, -0.35)):
    """A limb: every pixel within `r` of the segment a-b, shaded by its round normal."""
    vx, vy = bx - ax, by - ay
    vv = max(vx * vx + vy * vy, 0.0001)
    for y in range(int(min(ay, by) - r) - 1, int(max(ay, by) + r) + 2):
        for x in range(int(min(ax, bx) - r) - 1, int(max(ax, bx) + r) + 2):
            px_, py_ = x + 0.5, y + 0.5
            t = max(0.0, min(1.0, ((px_ - ax) * vx + (py_ - ay) * vy) / vv))
            qx, qy = ax + vx * t, ay + vy * t
            d = math.hypot(px_ - qx, py_ - qy)
            if d <= r:
                c.set(x, y, shade(lit((px_ - qx) / r, (py_ - qy) / r), ramp, cuts))


def elbow(sx, sy, hx, hy, bend):
    """Two-bone joint between shoulder and hand; `bend` +1/-1 picks the side it sticks out to."""
    dx, dy = hx - sx, hy - sy
    d = math.hypot(dx, dy)
    mx, my = (sx + hx) / 2, (sy + hy) / 2
    if d >= ARM * 2 or d < 0.01:
        return mx, my
    h = math.sqrt(ARM * ARM - (d / 2) ** 2)
    return mx - dy / d * h * bend, my + dx / d * h * bend


# --- the smith -------------------------------------------------------------------------------

def pose(**kw):
    p = dict(bx=0, by=0, hdx=0, hdy=0, near=(21.0, 45.0), near_bend=1, hammer=118.0, far=(38.0, 41.0),
             far_bend=-1, arm_front=False, feet=(0, 0), lift=(0, 0), glow=2, phase=0, bubbles=(),
             blink=False, mouth=False, flash=False, cool=0, anvil_sink=0, smear=None, pillars=(),
             front_flames=0, fx=(), pile=0)
    p.update(kw)
    return p


def lava_pool(p):
    cx, cy, rx, ry = POOL
    c = Canvas(CELL)
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if not in_ellipse(x, y, cx, cy, rx, ry):
                continue
            q = math.hypot((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
            # a crust at the rim and under the smith, molten toward the anvil
            hot = (x - 30) / 14.0 - q * 0.9
            col = "Y" if hot > 0.45 else "S4" if hot > 0.15 else "S3" if hot > -0.2 else "S2" if hot > -0.55 \
                else "S1" if hot > -0.85 else "R1" if q < 0.9 else "R0"
            if (x * 3 + y * 7 + p["phase"] * 5) % 11 == 0 and col in ("S2", "S3", "S4"):
                col = {"S2": "S3", "S3": "S4", "S4": "Y"}[col]
            c.set(x, y, col)
    for (x, y, stage) in p["bubbles"]:
        if stage == 0:
            c.set(x, y, "Y")
        else:
            c.set(x, y, "Y2")
            c.set(x + 1, y, "Y")
            c.set(x, y - 1, "Y")
    return c


def legs(p):
    c = Canvas(CELL)
    for i in range(2):
        hx, hy = HIPS[i][0] + p["bx"], HIPS[i][1] + p["by"]
        fx_, fy = FEET[i][0] + p["feet"][i], FEET[i][1] - p["lift"][i]
        kx, ky = (hx + fx_) / 2 + 2.5, (hy + fy) / 2 - 0.5     # knees point forward
        ramp = LEGS if i == 0 else ("K3", "K2", "K1", "K0")
        capsule(c, hx, hy, kx, ky, 3.0, ramp)
        capsule(c, kx, ky, fx_, fy, 2.4, ramp)
        # the foot, a flat block pointing forward
        for x in range(int(fx_) - 1, int(fx_) + 4):
            c.set(x, int(fy) + 1, "K1" if i else "K0")
            c.set(x, int(fy) + 2, "K0")
    return c


def torso(p):
    cx, cy, rx, ry = TORSO
    cx += p["bx"]
    cy += p["by"]
    c = Canvas(CELL)
    ellipse(c, cx, cy, rx, ry, BODY)
    c.trim()
    # the leather apron over its belly, a belt with a gold buckle
    belt = int(cy) + 3
    for (x, y) in list(c.px):
        if y > belt and x > cx - 4:
            l = lit((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
            c.px[(x, y)] = "R1" if l > -0.2 else "R0"
        elif y == belt:
            c.px[(x, y)] = "R0"
    c.set(int(cx) + 3, belt, "G1")
    # a lava crack across its chest
    for k, (dx, dy) in enumerate(((-1, -5), (0, -4), (0, -3), (1, -2), (2, -2), (3, -1))):
        if (int(cx) + dx, int(cy) + dy) in c.px:
            c.set(int(cx) + dx, int(cy) + dy, "S4" if k in (2, 3) else "S3")
    return c


def head(p):
    hx, hy = HEAD[0] + p["bx"] + p["hdx"], HEAD[1] + p["by"] + p["hdy"]
    c = Canvas(CELL)
    ellipse(c, hx, hy, HEAD[2], HEAD[3], STONE, cuts=(0.45, 0.05, -0.45))
    hxi, hyi = int(hx), int(hy)
    # the gold face plate over the front of its face
    for (x, y) in list(c.px):
        if x >= hxi and y >= hyi - 2:
            l = lit((x + 0.5 - hx) / HEAD[2], (y + 0.5 - hy) / HEAD[3])
            c.px[(x, y)] = "G2" if l > 0.1 else "G1" if l > -0.55 else "G0"
    for x in range(hxi, hxi + 5):
        c.set(x, hyi - 2, "K1")                     # brow ridge
    if p["blink"]:
        c.set(hxi + 2, hyi - 1, "G0")
        c.set(hxi + 3, hyi - 1, "G0")
    else:
        c.set(hxi + 2, hyi - 1, "Y2")
        c.set(hxi + 3, hyi - 1, "S4")
    for x in range(hxi + 1, hxi + 5):
        c.set(x, hyi + 2, "O")                      # the mouth slit
    if p["mouth"]:
        for x in range(hxi + 2, hxi + 5):
            c.set(x, hyi + 3, "O")
        c.set(hxi + 3, hyi + 2, "S3")
    return c


def pauldron(p):
    sx, sy = NEAR_SHOULDER[0] + p["bx"], NEAR_SHOULDER[1] + p["by"] - 1.5
    c = Canvas(CELL)
    ellipse(c, sx, sy, 4.6, 3.6, STONE, cuts=(0.35, -0.05, -0.5))
    c.trim()
    # its gold trim along the lower rim and a rivet
    for (x, y) in list(c.px):
        if (x, y + 1) not in c.px and y > sy:
            c.px[(x, y)] = "G1" if x < sx + 1 else "G0"
    c.set(int(sx) - 1, int(sy) - 1, "G2")
    return c


def arm(sx, sy, hx, hy, bend, fist=True):
    """Stone upper arm, lava-cracked forearm and fist."""
    c = Canvas(CELL)
    ex, ey = elbow(sx, sy, hx, hy, bend)
    capsule(c, sx, sy, ex, ey, 2.3, STONE)
    capsule(c, ex, ey, hx, hy, 2.0, LAVA, cuts=(0.45, -0.1, -0.6))
    if fist:
        ellipse(c, hx, hy, 2.3, 2.2, LAVA, cuts=(0.35, -0.2, -0.7))
    # a bright crack along the forearm
    for (x, y) in line(ex, ey, (ex + hx) / 2, (ey + hy) / 2)[1:]:
        if (x, y) in c.px:
            c.set(x, y, "Y")
    return c


def hammer(hx, hy, angle):
    """Handle from the fist along `angle` (degrees, 0 = right, -90 = up) and its iron head across it."""
    c = Canvas(CELL)
    a = math.radians(angle)
    dx, dy = math.cos(a), math.sin(a)
    for (x, y) in line(hx, hy, hx + dx * HANDLE, hy + dy * HANDLE):
        c.set(x, y, "R1")
    cx, cy = hx + dx * (HANDLE + 0.5), hy + dy * (HANDLE + 0.5)
    for y in range(int(cy) - 5, int(cy) + 6):
        for x in range(int(cx) - 5, int(cx) + 6):
            u = (x + 0.5 - cx) * dx + (y + 0.5 - cy) * dy        # along the handle
            v = -(x + 0.5 - cx) * dy + (y + 0.5 - cy) * dx       # across it
            if abs(u) <= 1.7 and abs(v) <= 3.0:
                c.set(x, y, shade(lit((x + 0.5 - cx) / 3.0, (y + 0.5 - cy) / 3.0), IRON, (0.3, -0.1, -0.5)))
    return c


def anvil(p):
    c = Canvas(CELL)
    top, x0 = ANVIL_TOP + p["anvil_sink"], ANVIL_X
    for x in range(x0, x0 + 14):                        # top plate
        c.set(x, top, "I3")
        c.set(x, top + 1, "I2")
        c.set(x, top + 2, "I1")
    for x, ys in ((x0 + 14, (top, top + 1)), (x0 + 15, (top, top + 1)), (x0 + 16, (top,))):   # horn
        for y in ys:
            c.set(x, y, "I3" if y == top else "I2")
    for y in range(top + 3, top + 6):                   # waist
        for x in range(x0 + 4, x0 + 11):
            c.set(x, y, "I2" if x == x0 + 4 else "K0" if x == x0 + 10 else "I1")
    for x in range(x0 + 3, x0 + 12):                    # foot
        c.set(x, top + 6, "I2")
    for y in (top + 7, top + 8):
        for x in range(x0 + 1, x0 + 14):
            c.set(x, y, "I2" if x < x0 + 4 and y == top + 7 else "K0" if y == top + 8 else "I1")
    # the ingot on the plate
    glow = p["glow"]
    hot_top, hot_low = [("S2", "S1"), ("S3", "S2"), ("S4", "S3"), ("Y2", "Y")][glow]
    for x in range(x0 + 5, x0 + 11):
        c.set(x, top - 2, hot_top if x < x0 + 9 else hot_low)
        c.set(x, top - 1, hot_low)
    c.set(x0 + 5, top - 2, hot_low)
    # it glows on the plate's top
    if glow >= 2:
        c.set(x0 + 4, top, "S4")
        c.set(x0 + 11, top, "S4")
    if p["anvil_sink"]:
        c.px = {(x, y): col for (x, y), col in c.px.items() if y <= GROUND - 1}
    return c


def flame_pillar(c, x, h, w, phase):
    """A column of fire `h` px tall rising from the pool: white at its root, red at its tips."""
    for k in range(h):
        y = GROUND - 1 - k
        f = k / max(h, 1)
        half = w / 2.0 * (1.0 - 0.55 * f ** 1.6)
        wob = math.sin(k * 0.45 + phase * 1.7 + x) * (0.6 + 1.2 * f)
        # forked tongues at the top
        if f > 0.7 and (k + phase) % 3 == 0:
            half -= 1
        for xx in range(int(x - half + wob) - 1, int(x + half + wob) + 2):
            d = abs(xx + 0.5 - (x + wob)) / max(half, 0.5)
            if d > 1.0:
                continue
            core = d < 0.35 and f < 0.75
            col = ("Y2" if f < 0.35 else "Y") if core else ("Y" if d < 0.65 and f < 0.5 else
                                                           "S4" if d < 0.8 or f < 0.3 else "S3")
            if f > 0.82:
                col = "S3" if d < 0.5 else "S2"
            c.set(xx, y, col)


def low_flames(c, height, phase):
    """Short tongues of fire licking along the pool, in front of the smith."""
    for i, x in enumerate(range(18, 50, 4)):
        h = int(round(height * (0.6, 1.0, 0.75, 0.9)[(i + phase) % 4]))
        for k in range(h):
            y = GROUND - k
            f = k / max(h, 1)
            xs = (x - 1, x, x + 1) if f < 0.4 else (x, x + (1 if (i + phase) % 2 else -1)) if f < 0.75 else (x,)
            for xx in xs:
                c.set(xx, y, "Y" if f < 0.3 and xx == x else "S4" if f < 0.6 else "S3")


def add_fx(canvas, fx):
    """Sparks and embers: (x, y, kind); kind 1 a pixel ('Y2'/'Y'/'S4' by its color), 3 a 3x3 star."""
    for x, y, kind, col in fx:
        if kind == 1:
            canvas.set(x, y, col)
        else:
            canvas.set(x, y, "Y2")
            for nx, ny in neighbours(x, y):
                canvas.set(nx, ny, col)


def smear(canvas, cx, cy, r, a0, a1):
    """The hammer's swing: an arc of pale pixels behind the moving head."""
    steps = 24
    for i in range(steps + 1):
        a = math.radians(a0 + (a1 - a0) * i / steps)
        x, y = int(cx + math.cos(a) * r), int(cy + math.sin(a) * r)
        if (x, y) not in canvas.px:
            canvas.set(x, y, "K4" if i > steps * 0.5 else "K3")


def rubble(p):
    """What is left of it: a low pile of stone chunks over the anvil, the gold plate on top."""
    c = Canvas(CELL)
    s = p["pile"]          # 1 slumped .. 3 flattest
    chunks = [(22, 50, 4.2, 2.6), (28, 49, 4.6, 3.0), (34, 50, 4.0, 2.6), (40, 50, 4.4, 2.4),
              (25, 46 + s, 3.4, 2.6), (31, 45 + s, 3.8, 2.8), (37, 46 + s, 3.2, 2.4)]
    for i, (x, y, rx, ry) in enumerate(chunks):
        if i >= 4 and s >= 3 and i != 5:
            continue
        part = Canvas(CELL)
        ellipse(part, x, min(y, GROUND - ry + 0.5), rx, ry, STONE if i % 2 else LEGS)
        part.trim()
        c.paste(part, "K0")
    gx, gy = 33, 45 + s if s < 3 else 47
    for x, col in ((gx, "G1"), (gx + 1, "G2"), (gx + 2, "G1"), (gx + 3, "G0")):
        c.set(x, gy, col)
    c.set(gx + 1, gy + 1, "O")
    c.set(gx + 2, gy + 1, "S3" if s < 3 else "S1")
    # lava still glowing in the cracks between the chunks
    for (x, y) in ((26, 48), (31, 50), (36, 49), (29, 47)):
        if (x, y) in c.px:
            c.set(x, y, "S3" if s == 1 else "S2" if s == 2 else "S1")
    return c


def draw_forger(p):
    bx, by = p["bx"], p["by"]
    scene = Canvas(CELL)
    scene.paste(lava_pool(p))
    if p["pile"]:
        scene.paste(anvil(p), "O")
        scene.paste(rubble(p), "O")
    else:
        nsx, nsy = NEAR_SHOULDER[0] + bx, NEAR_SHOULDER[1] + by
        fsx, fsy = FAR_SHOULDER[0] + bx, FAR_SHOULDER[1] + by
        far = arm(fsx, fsy, p["far"][0], p["far"][1], p["far_bend"], fist=False)
        scene.paste(far, "O")
        scene.paste(legs(p), "K0")
        scene.paste(torso(p), "K0")
        scene.paste(anvil(p), "O")
        fist = Canvas(CELL)
        ellipse(fist, p["far"][0], p["far"][1], 2.3, 2.2, LAVA, cuts=(0.35, -0.2, -0.7))
        scene.paste(fist, "O")
        near = arm(nsx, nsy, p["near"][0], p["near"][1], p["near_bend"])
        tool = hammer(p["near"][0], p["near"][1], p["hammer"])
        if not p["arm_front"]:
            scene.paste(tool, "O")
            scene.paste(near, "O")
        scene.paste(head(p), "O")
        scene.paste(pauldron(p), "K1")
        if p["arm_front"]:
            scene.paste(tool, "O")
            scene.paste(near, "O")
    for step in COOL_STEPS[:p["cool"]]:
        scene.remap(step)
    scene.outline()
    if p["smear"]:
        smear(scene, *p["smear"])
    if p["flash"]:
        scene.remap(FLASH)
    if p["pillars"] or p["front_flames"]:
        back, front = Canvas(CELL), Canvas(CELL)
        for (x, h, w, layer) in p["pillars"]:
            flame_pillar(back if layer == 0 else front, x, h, w, p["phase"])
        if p["front_flames"]:
            low_flames(front, p["front_flames"], p["phase"])
        back.outline("S1")
        back.over(scene)
        scene = back
        front.outline("S1", only_empty_of=scene)
        scene.over(front)
    add_fx(scene, p["fx"])
    return scene


# --- animations -----------------------------------------------------------------------------

def idle():
    # Slow breathing over the anvil while the ingot pulses and the pool bubbles.
    by = [0, 0, -1, -1, 0, 0]
    glow = [1, 2, 3, 3, 2, 1]
    bubbles = [[(41, 51, 0)], [(41, 51, 1)], [], [(26, 52, 0)], [(26, 52, 1)], []]
    return [pose(by=by[i], hdy=0, glow=glow[i], phase=i, bubbles=bubbles[i], blink=i == 4,
                 near=(21.0, 45.0 + by[i])) for i in range(6)]


def walk():
    # A heavy shuffle: one foot at a time, the body dipping on each step; its forge goes with it.
    feet = [(0, 0), (-1, 2), (-2, 3), (-1, 2), (0, 0), (2, -1), (3, -2), (2, -1)]
    lift = [(0, 0), (0, 2), (0, 1), (0, 0), (0, 0), (2, 0), (1, 0), (0, 0)]
    by = [0, -1, -1, 0, 1, 0, -1, 0]
    swing = [0, -1, -1, 0, 1, 1, 0, 0]
    return [pose(by=by[i], feet=feet[i], lift=lift[i], glow=2, phase=i,
                 near=(21.0 + swing[i], 45.0 + by[i]), hammer=118.0 + swing[i] * 4,
                 far=(38.0, 41.0 + (1 if by[i] > 0 else 0))) for i in range(8)]


def attack():
    # Lifts the hammer from its side, cocks it far over its head, then brings it down on the ingot:
    # the blow falls at about 0.55 / 0.75 of the strip (frame 6) in a burst of sparks.
    hit = [(49, 36, 3, "Y"), (52, 33, 1, "Y2"), (47, 31, 1, "Y"), (54, 37, 1, "S4"), (50, 30, 1, "Y"),
           (40, 34, 1, "S4")]
    fall = [(53, 38, 1, "S4"), (49, 30, 1, "S4"), (55, 33, 1, "Y"), (44, 31, 1, "S3")]
    return [
        pose(near=(21.0, 43.0), hammer=150.0, glow=2, phase=0),
        pose(near=(20.0, 38.0), hammer=235.0, glow=2, by=-1, phase=1),
        pose(near=(21.0, 28.0), near_bend=-1, hammer=250.0, bx=-1, by=-1, hdx=-1, glow=2, phase=2),
        pose(near=(21.0, 25.0), near_bend=-1, hammer=200.0, bx=-1, by=-2, hdx=-1, hdy=-1, glow=3, phase=3),
        pose(near=(20.0, 25.0), near_bend=-1, hammer=185.0, bx=-2, by=-2, hdx=-1, hdy=-1, glow=3, phase=4,
             mouth=True),
        pose(near=(31.0, 27.0), near_bend=-1, hammer=290.0, bx=0, by=-1, glow=3, phase=5,
             smear=(23, 34, 14, 240, 285)),
        pose(near=(37.0, 40.0), near_bend=1, hammer=335.0, bx=1, by=1, hdx=-1, glow=3,
             mouth=True, phase=6, fx=hit),
        pose(near=(37.0, 39.0), near_bend=1, hammer=322.0, bx=1, glow=2, phase=7, fx=fall[:1]),
    ]


def special():
    # Hunches, raises both arms and pillars of fire burst from the pool around it, peaking as the
    # iron blocks are called (frame 6 of 8), then sink back.
    up = dict(near=(18.0, 26.0), near_bend=1, hammer=250.0, far=(41.0, 24.0), far_bend=-1, hdy=-1)
    embers = [(14, 20, 1, "Y"), (52, 16, 1, "S4"), (30, 8, 1, "Y"), (44, 10, 1, "S4"), (20, 12, 1, "S3")]
    return [
        pose(by=1, near=(23.0, 44.0), hammer=210.0, glow=3, phase=0, bubbles=[(40, 51, 1), (24, 52, 0)]),
        pose(by=0, near=(22.0, 34.0), hammer=250.0, far=(37.0, 33.0), far_bend=1, glow=3, phase=1,
             mouth=True, front_flames=2, bubbles=[(42, 51, 1), (27, 52, 1)]),
        pose(by=-1, glow=3, phase=2, mouth=True, front_flames=4,
             pillars=[(17, 10, 6, 0), (50, 8, 6, 1)], **up),
        pose(by=-2, glow=3, phase=3, mouth=True, front_flames=5,
             pillars=[(17, 22, 8, 0), (31, 16, 9, 0), (50, 20, 8, 1)], fx=embers[:2], **up),
        pose(by=-2, glow=3, phase=4, mouth=True, front_flames=6,
             pillars=[(17, 34, 9, 0), (31, 42, 11, 0), (50, 32, 9, 1)], fx=embers[:3], **up),
        pose(by=-2, glow=3, phase=5, mouth=True, front_flames=6,
             pillars=[(17, 38, 9, 0), (31, 46, 11, 0), (50, 36, 9, 1)], fx=embers, **up),
        pose(by=-1, glow=3, phase=6, front_flames=4,
             pillars=[(17, 24, 8, 0), (31, 30, 10, 0), (50, 22, 8, 1)], fx=embers[1:], **up),
        pose(by=0, near=(21.0, 43.0), hammer=140.0, glow=3, phase=7, bubbles=[(44, 51, 0)],
             fx=[(26, 22, 1, "S3"), (46, 24, 1, "S4")]),
    ]


def hurt():
    return [
        pose(flash=True, bx=-1, hdx=-1, glow=2),
        pose(bx=-1, by=1, hdx=-2, hdy=1, mouth=True, blink=True, near=(20.0, 46.0), glow=2),
        pose(bx=-1, hdx=-1, near=(20.0, 45.0), glow=2),
        pose(glow=2),
    ]


def death():
    # It slumps over its anvil, the forge goes cold and the smith crumbles into a pile of stones.
    return [draw_forger(p) for p in (
        pose(bx=-1, hdx=-1, hdy=1, mouth=True, glow=2, near=(20.0, 46.0)),
        pose(by=2, hdx=1, hdy=3, mouth=True, blink=True, glow=1, cool=1, near=(22.0, 47.0), hammer=180.0,
             far=(38.0, 42.0)),
        pose(bx=2, by=4, hdx=1, hdy=5, blink=True, glow=1, cool=1, near=(25.0, 48.0), hammer=170.0,
             far=(39.0, 43.0), feet=(1, 0)),
        pose(bx=3, by=6, hdx=1, hdy=6, blink=True, glow=0, cool=2, near=(27.0, 49.0), hammer=175.0,
             far=(39.0, 44.0), feet=(1, 0), fx=[(30, 30, 1, "S3"), (22, 34, 1, "K3")]),
        pose(pile=1, glow=0, cool=2, anvil_sink=1, fx=[(18, 42, 1, "K2"), (46, 40, 1, "K2"), (33, 36, 1, "S3")]),
        pose(pile=2, glow=0, cool=2, anvil_sink=3, fx=[(16, 46, 1, "K1"), (49, 45, 1, "K1"), (34, 34, 1, "S2")]),
        pose(pile=3, glow=0, cool=3, anvil_sink=5),
        pose(pile=3, glow=0, cool=4, anvil_sink=6),
    )]


# --- the iron block ------------------------------------------------------------------------

## The block's footprint is centered on this pixel of its cell (IronBlock's origin).
BLOCK_ORIGIN = (24, 30)
## Footprint and height in px, as IronBlock draws it by default (block_size 22x14, block_height 14).
BLOCK_W, BLOCK_D, BLOCK_H = 22, 14, 14
## Heat ramps, hottest first: top face, front face, seams/edges.
HEAT = [
    ("Y", "S4", "S3", "Y2"),
    ("S3", "S2", "S1", "Y"),
    ("S2", "S1", "S0", "S4"),
    ("I2", "I1", "K0", "S2"),
    ("I3", "I2", "I1", "K0"),
]


def iron_block(heat, lift=0):
    """The block standing on its footprint: a lit top face, a darker front face, beveled edges and
    seams that glow while it is hot."""
    top_c, front_c, dark, seam = HEAT[heat]
    light = {"Y": "Y2", "S3": "S4", "S2": "S3", "I2": "I3", "I3": "I3"}[top_c]
    c = Canvas(BLOCK_CELL)
    ox, oy = BLOCK_ORIGIN
    x0, x1 = ox - BLOCK_W // 2, ox + BLOCK_W // 2 - 1
    top0 = oy - BLOCK_D // 2 - BLOCK_H - lift
    front0 = oy - BLOCK_D // 2 + BLOCK_D - BLOCK_H - lift
    for y in range(top0, front0 + BLOCK_H):
        for x in range(x0, x1 + 1):
            if y < front0:
                # top face: lit edge on the back and the left, a bevel highlight
                col = light if (y == top0 or x == x0) else top_c
                if y == front0 - 1:
                    col = seam if heat < 3 else light
            else:
                col = dark if (x == x1 or y == front0 + BLOCK_H - 1) else front_c
                if x == x0:
                    col = top_c
            c.set(x, y, col)
    # a cast recess on the top face, shadowed on its back and left inner edges
    for x in range(x0 + 3, x1 - 2):
        for y in range(top0 + 3, front0 - 3):
            edge = x == x0 + 3 or y == top0 + 3
            c.set(x, y, front_c if edge else top_c)
        c.set(x, front0 - 3, light)
    for y in range(top0 + 3, front0 - 2):
        c.set(x1 - 2, y, light)
    # cut corners so it reads as a heavy cast block, not a box
    for (x, y) in ((x0, top0), (x1, top0), (x0, front0 + BLOCK_H - 1), (x1, front0 + BLOCK_H - 1)):
        c.px.pop((x, y), None)
    # cracks and rivets: glowing while hot, dark once cold
    cracks = [(5, 2), (6, 3), (7, 3), (8, 4), (14, 6), (15, 7), (15, 8), (16, 9), (3, 9), (4, 10)]
    for dx, dy in cracks:
        c.set(x0 + dx, top0 + dy, seam if heat < 4 else "K0")
    for dx, dy in ((4, 4), (17, 4), (9, 10), (13, 11)):
        c.set(x0 + dx, front0 + dy, seam if heat < 2 else dark)
        c.set(x0 + dx, front0 + dy - 1, light if heat < 2 else top_c)
    # a band across the front face
    for x in range(x0 + 1, x1):
        c.set(x, front0 + 6, dark if heat >= 2 else seam)
    c.outline("O")
    return c


def block_shadow(progress):
    c = Canvas(BLOCK_CELL)
    ox, oy = BLOCK_ORIGIN
    rx = BLOCK_W / 2 * (0.4 + 0.6 * progress)
    ry = rx * BLOCK_D / BLOCK_W
    for y in range(BLOCK_CELL):
        for x in range(BLOCK_CELL):
            if in_ellipse(x, y, ox, oy + 0.5, rx, ry):
                c.set(x, y, "O")
    return c


def block_strip():
    frames = [block_shadow(t) for t in (0.25, 0.5, 0.75, 1.0)]
    # falling: white-hot, with streaks of light above it
    fall = iron_block(0)
    ox, oy = BLOCK_ORIGIN
    top0 = oy - BLOCK_D // 2 - BLOCK_H
    for x, length in ((ox - 7, 5), (ox - 1, 7), (ox + 6, 4)):
        for k in range(1, length + 1):
            fall.set(x, top0 - 1 - k, "Y" if k < 3 else "S4" if k < 5 else "S3")
    frames.append(fall)
    # impact: sparks and a puff of hot dust at its base
    impact = iron_block(0)
    base = oy + BLOCK_D // 2 - 1
    burst = [(-14, 0, "Y"), (-13, -2, "Y2"), (-15, -4, "S4"), (13, 0, "Y"), (14, -3, "Y2"), (16, -5, "S4"),
             (-12, 2, "S3"), (12, 2, "S3"), (-9, -10, "Y"), (10, -12, "S4"), (-17, -1, "S3"), (17, -1, "S3")]
    for dx, dy, col in burst:
        impact.set(ox + dx, base + dy, col)
    frames.append(impact)
    for heat in range(5):
        frames.append(iron_block(heat))
    frames.extend(shards())
    return frames


def shards():
    """It bursts into hot chunks that fly out and drop (IronBlock: SHATTER_TIME)."""
    out = []
    ox, oy = BLOCK_ORIGIN
    cracked = iron_block(0)
    for (x, y) in line(ox - 9, oy - 18, ox + 2, oy - 6) + line(ox + 2, oy - 6, ox + 8, oy + 5) + \
            line(ox - 5, oy - 4, ox - 10, oy + 4):
        if (x, y) in cracked.px:
            cracked.set(x, y, "Y2")
    out.append(cracked)
    for step, progress in enumerate((0.4, 0.7, 1.0)):
        c = Canvas(BLOCK_CELL)
        for i in range(6):
            a = math.tau * i / 6.0 + 0.3
            # out along a spoke, rising and then falling like the code's shards
            px_ = ox + math.cos(a) * BLOCK_W * 0.6 * progress
            py_ = oy - BLOCK_H * 0.5 + math.sin(a) * BLOCK_D * 0.6 * progress - 6 * math.sin(progress * math.pi) \
                + 4 * progress
            size = 3 if step < 2 else 2
            col = (("Y", "S4", "S3"), ("S4", "S3", "S2"), ("S3", "S2", "S1"))[step]
            chunk = Canvas(BLOCK_CELL)
            for dx in range(size):
                for dy in range(size):
                    chunk.set(int(px_) + dx, int(py_) + dy, col[0] if dx + dy == 0 else col[1] if dx + dy < 3 else col[2])
            chunk.outline("O")
            c.over(chunk)
        for k, (dx, dy) in enumerate(((-3, 4), (4, 5), (0, 6), (-7, 6), (7, 3))):
            if k < 5 - step:
                c.set(ox + dx, oy + dy - (2 - step), ("Y", "S4", "S3")[step])
        out.append(c)
    return out


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
        strip([draw_forger(p) for p in make()], os.path.join(OUT, "forjador_condenado_%s.png" % name))
    strip(death(), os.path.join(OUT, "forjador_condenado_death.png"))
    strip(block_strip(), os.path.join(OUT, "forjador_condenado_block.png"))
