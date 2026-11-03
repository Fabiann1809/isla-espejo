"""Draws the Rueda devoradora's art (temple enemy, island 3) pixel by pixel.

The bestiary pack's wheel, scaled from 128 px down to the game, came out blurred, so it is drawn at
the game's own pixel size instead, following the pack's design: a stone gear of pinkish copper with
round studded teeth, a dark inner disc and a carved golden face (angry brows, eyes, a grille of
teeth). It is built from two parts, the toothed rim and the face, that each animation moves frame by
frame, as in the pack's sheet: idle (its eyes smoulder), walk (the rim turns: the game also spins
the whole sprite around the hub while it rolls), attack (the face heats up red, the mouth opens
glowing and bites), special (the launch: it spins up, dust and then streaks of fire behind it),
hurt and death (it cracks in two and falls into rubble).
The wheel is centered on its hub, so the game can spin the sprite around it (DevouringWheelData's
`hub_offset`); nothing is drawn under it that should not spin (no shadow).

Writes into `assets/sprites/rueda_devoradora/`:
    rueda_devoradora_<animation>.png   64x64 cells, facing right, hub at (32, 38), lowest teeth on
                                       row 51: idle, walk, attack, special, hurt, death

    python tools/make_rueda_devoradora_art.py
Then tools/make_temple_enemy_frames.gd builds its SpriteFrames as for every temple enemy, and
tools/enemy_aseprite.lua keeps an editable `source/rueda_devoradora.aseprite`.
Needs Pillow.
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "rueda_devoradora")
CELL = 64
## The hub (between pixels: the wheel is symmetric around it), and the lowest row of its teeth.
CX, CY = 32.0, 38.0
GROUND = 51

PALETTE = {
    "O": (30, 16, 16),     # outline
    # the stone rim: pinkish copper
    "S0": (70, 38, 36),
    "S1": (116, 68, 58),
    "S2": (160, 102, 84),
    "S3": (200, 140, 114),
    "S4": (234, 188, 158),
    "S5": (252, 230, 206),
    # the dark inner disc
    "D0": (30, 18, 18),
    "D1": (58, 36, 32),
    # the golden face
    "A0": (100, 58, 18),
    "A1": (162, 106, 28),
    "A2": (216, 154, 42),
    "A3": (250, 208, 92),
    # glow and fire
    "F0": (134, 28, 14),
    "F1": (222, 82, 24),
    "F2": (255, 152, 42),
    "F3": (255, 222, 122),
    "W": (255, 250, 228),
    # dust
    "K0": (74, 60, 58),
    "K1": (116, 100, 94),
    "K2": (160, 142, 132),
}
RED_FLASH = {"S0": "F0", "S1": "F0", "S2": "F1", "S3": "F1", "S4": "F2", "S5": "F3",
             "D1": "F0", "A0": "F0", "A1": "F1", "A2": "F2", "A3": "F3"}
## The face heating up for its bite.
HOT_FACE = [
    {},
    {"A0": "F0"},
    {"A0": "F0", "A1": "F1", "A2": "F2", "A3": "F3"},
]
## Death: the stone dulls and the face goes out.
DULL = {"S5": "S4", "S4": "S3", "A3": "A2", "A2": "A1", "F2": "F1", "F3": "F1"}

TEETH = 10
TOOTH_TIP = 14.0
RIM_OUT = 12.0
RIM_IN = 8.6
FACE_R = 8.0


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


def line(x0, y0, x1, y1):
    n = max(abs(x1 - x0), abs(y1 - y0)) * 4 + 1
    return pixel_perfect([(math.floor(x0 + (x1 - x0) * i / n), math.floor(y0 + (y1 - y0) * i / n))
                          for i in range(n + 1)])


# --- the wheel --------------------------------------------------------------------------------

def pose(**kw):
    p = dict(dx=0, dy=0, turn=0.0, blur=False, brow=0, eyes=1, shut=False, mouth=0, glow=0, hot=0,
             flash=False, crack=0, split=0.0, dull=False, trail=0, phase=0, dust=(), fx=())
    p.update(kw)
    return p


def draw_rim(c, p, cx, cy):
    period = 360.0 / TEETH
    for y in range(int(cy - TOOTH_TIP) - 1, int(cy + TOOTH_TIP) + 2):
        for x in range(int(cx - TOOTH_TIP) - 1, int(cx + TOOTH_TIP) + 2):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            r = math.hypot(dx, dy)
            if r < RIM_IN or r > TOOTH_TIP:
                continue
            ang = math.degrees(math.atan2(dy, dx))
            # angle from the nearest tooth's middle
            off = (ang - p["turn"] + period / 2) % period - period / 2
            tooth = abs(off) < 12.0
            if r > RIM_OUT and not (tooth and r <= RIM_OUT + 2.0 * math.cos(math.radians(off) * 7.0)):
                if not (p["blur"] and r <= RIM_OUT + 0.8):
                    continue
            nx, ny = dx / r, dy / r
            if r < RIM_IN + 1.0:
                # the inner bevel faces inward: lit on the lower right
                l = lit(-nx, -ny)
                col = "S2" if l > 0.3 else "S1" if l > -0.3 else "S0"
            else:
                l = lit(nx, ny)
                col = "S4" if l > 0.62 else "S3" if l > 0.2 else "S2" if l > -0.35 else "S1"
            if not p["blur"]:
                # the grooves between the rim's blocks, halfway between teeth
                if abs(abs(off) - period / 2) < 1.6 and RIM_IN + 1.0 <= r <= RIM_OUT:
                    col = "S0" if l < 0.2 else "S1"
                # a stud on every tooth
                if tooth and abs(off) < 3.6 and RIM_OUT + 0.2 <= r <= RIM_OUT + 1.4:
                    col = "S5" if l > -0.2 else "S3"
            elif r > RIM_OUT - 1.0 and int(ang // 9) % 2 == 0:
                col = "S4" if l > -0.2 else "S2"  # streaks of the blurred teeth
            c.set(x, y, col)


def draw_face(c, p, cx, cy):
    """The dark inner disc and the carved golden face on it."""
    ix, iy = int(cx), int(cy)  # pixel just right of / below the hub
    face = {}
    for y in range(int(cy - FACE_R) - 1, int(cy + FACE_R) + 2):
        for x in range(int(cx - FACE_R) - 1, int(cx + FACE_R) + 2):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            if math.hypot(dx, dy) > RIM_IN:
                continue
            c.set(x, y, "D1" if lit(dx, dy) > 0.5 else "D0" if math.hypot(dx, dy) > FACE_R - 0.4 else "D1")
            # the face plate: a rounded block, lit on the upper left
            if abs(dx) <= 5.6 and -5.6 <= dy <= 6.2 and math.hypot(dx, dy) <= FACE_R - 0.6:
                corner = abs(dx) > 4.6 and (dy < -4.6 or dy > 5.2)
                if corner:
                    continue
                l = lit(dx / 5.6, dy / 6.0)
                face[(x, y)] = "A2" if l > 0.35 else "A1" if l > -0.4 else "A0"
    # Brows: a heavy angry V, high on the outside and low over the nose; a dark carve under them.
    b = p["brow"]
    brow = [(-5, -5), (-4, -5), (-4, -4), (-3, -4), (-2, -4), (-2, -3), (-1, -3)]
    both = brow + [(-1 - dx, dy) for dx, dy in brow]
    # frowning pulls the inner ends down
    carved = {(ix + dx, iy + dy + (b if abs(dx + 0.5) < 3 else 0)) for dx, dy in both}
    for (x, y) in carved:
        if (x, y - 1) not in carved:
            face[(x, y - 1)] = "A3"
    for q in carved:
        face[q] = "D0"
    # Eyes: dark slits under the brows, an ember in each (closed: a dark line).
    glow = ["A1", "F1", "F2", "F3"][p["eyes"]]
    for ex in (-4, 2):
        y = iy - 2 + b
        if p["shut"]:
            face[(ix + ex, y)] = "A0"
            face[(ix + ex + 1, y)] = "A0"
            continue
        face[(ix + ex, y)] = glow if ex > 0 else "D0"
        face[(ix + ex + 1, y)] = "D0" if ex > 0 else glow
    # Nose.
    face[(ix - 1, iy)] = "A3"
    face[(ix, iy)] = "A1"
    face[(ix - 1, iy + 1)] = "A1"
    face[(ix, iy + 1)] = "A0"
    # Mouth: a grille of teeth; it opens (`mouth` 0..2) on its glowing throat (`glow` 0..3).
    top, bottom = iy + 2, iy + 4 + p["mouth"]
    throat = ["D0", "F1", "F2", "F3"][p["glow"]]
    for x in range(ix - 4, ix + 4):
        for y in range(top, bottom + 1):
            if y == top:
                col = "A3" if x % 2 == 0 else "A2"
            elif y == bottom:
                col = "A2" if x % 2 == 0 else "A1"
            else:
                col = throat if y > top + 1 or p["glow"] >= 2 else "D0"
                if p["glow"] == 3 and y == top + 1 and ix - 2 <= x < ix + 2:
                    col = "W"
            face[(x, y)] = col
        # teeth gaps
        if x % 2 and p["mouth"] == 0:
            face[(x, top)] = "A1"
    for q, col in face.items():
        if math.hypot(q[0] + 0.5 - cx, q[1] + 0.5 - cy) <= FACE_R:
            c.set(q[0], q[1], col)
    if p["hot"]:
        sub = Canvas(CELL)
        sub.px = {q: col for q, col in c.px.items() if math.hypot(q[0] + 0.5 - cx, q[1] + 0.5 - cy) <= FACE_R}
        for step in HOT_FACE[1:p["hot"] + 1]:
            sub.remap(step)
        c.over(sub)


## A jagged crack through the wheel, top to bottom, relative to the hub.
CRACK = [(1, -14), (1, -13), (0, -12), (0, -11), (1, -10), (1, -9), (2, -8), (1, -7), (0, -6),
         (0, -5), (-1, -4), (-1, -3), (0, -2), (1, -1), (1, 0), (0, 1), (0, 2), (-1, 3), (-1, 4),
         (0, 5), (1, 6), (1, 7), (0, 8), (0, 9), (-1, 10), (-1, 11), (0, 12), (0, 13)]


def crack_x(y):
    """Where the crack runs on row `y` (relative to the hub)."""
    for cx_, cy_ in CRACK:
        if cy_ == y:
            return cx_
    return 0


def draw_wheel(p):
    cx, cy = CX + p["dx"], CY + p["dy"]
    body = Canvas(CELL)
    draw_rim(body, p, cx, cy)
    draw_face(body, p, cx, cy)
    if p["crack"]:
        for k, (dx, dy) in enumerate(CRACK):
            if p["crack"] == 1 and not -9 <= dy <= 9:
                continue
            body.set(int(cx) + dx, int(cy) + dy, "O")
    if p["dull"]:
        body.remap(DULL)
    if p["split"]:
        # it falls apart in two halves, each rolling away a little and dropping
        s = p["split"]
        halves = [Canvas(CELL), Canvas(CELL)]
        for (x, y), col in body.px.items():
            if col == "O":
                continue
            right = x - int(cx) > crack_x(y - int(cy))
            halves[right].set(x, y, col)
        body = Canvas(CELL)
        for k, half in enumerate(halves):
            ang = math.radians((-1 if k == 0 else 1) * min(s * 22.0, 80.0))
            hx = cx + (-1 if k == 0 else 1) * (1.0 + 2.2 * s)
            moved = Canvas(CELL)
            for (x, y), col in half.px.items():
                rx, ry = x + 0.5 - cx, y + 0.5 - cy
                qx = rx * math.cos(ang) - ry * math.sin(ang)
                qy = rx * math.sin(ang) + ry * math.cos(ang)
                moved.set(math.floor(hx + qx), math.floor(cy + qy), col)
            # fill the pinholes a rotation leaves, then rest on the floor
            for (x, y) in list(moved.px):
                for nx, ny in ((x + 1, y), (x, y + 1)):
                    if (nx, ny) not in moved.px and (nx + 1, ny) in moved.px and (nx - 1, ny) in moved.px:
                        moved.px[(nx, ny)] = moved.px[(x, y)]
            drop = GROUND - max(y for _, y in moved.px)
            moved.px = {(x, y + drop): col for (x, y), col in moved.px.items()}
            moved.outline()
            body.over(moved)
    else:
        body.outline()
    if p["flash"]:
        body.remap(RED_FLASH)
    out = Canvas(CELL)
    trail = fire_trail(p, cx, cy)
    out.over(trail)
    out.over(body)
    add_dust(out, p["dust"])
    add_fx(out, p["fx"])
    return out


def fire_trail(p, cx, cy):
    """Streaks of fire left behind (to the left) as it launches; `trail` is their length."""
    c = Canvas(CELL)
    if not p["trail"]:
        return c
    rows = [(-10, 0.55), (-6, 0.85), (-2, 1.0), (2, 0.95), (6, 0.8), (10, 0.5)]
    for k, (dy, f) in enumerate(rows):
        y = int(cy) + dy
        edge = cx - math.sqrt(max(TOOTH_TIP ** 2 - (dy + 0.5) ** 2, 0.0)) + 2
        length = int(p["trail"] * f + ((k + p["phase"]) % 3) - 1)
        for j in range(length):
            x = int(edge) - j
            g = j / max(length, 1)
            col = "W" if g < 0.15 else "F3" if g < 0.35 else "F2" if g < 0.6 else "F1" if g < 0.85 else "F0"
            if g > 0.7 and (j + k + p["phase"]) % 3 == 0:
                continue  # its tail breaks into flecks
            c.set(x, y, col)
            if abs(dy) <= 6 and g < 0.5:
                c.set(x, y + 1, "F2" if g < 0.3 else "F1")
    c.outline("F0")
    return c


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
    """Sparks and chips: (x, y, color), one pixel each, outlined."""
    if not fx:
        return
    s = Canvas(CELL)
    for x, y, col in fx:
        s.set(x, y, col)
    s.outline("F0" if all(col.startswith("F") or col == "W" for _, _, col in fx) else "O", only_empty_of=c)
    c.over(s)


def lump(c, x, y, rx, ry, ramp):
    for yy in range(int(y - ry) - 1, int(y + ry) + 2):
        for xx in range(int(x - rx) - 1, int(x + rx) + 2):
            dx, dy = (xx + 0.5 - x) / rx, (yy + 0.5 - y) / ry
            if dx * dx + dy * dy > 1.0:
                continue
            l = lit(dx, dy)
            c.set(xx, yy, ramp[0] if l > 0.45 else ramp[1] if l > -0.2 else ramp[2])


def rubble(dust=()):
    """What is left: blocks of the rim, a couple of teeth and the face's broken plate."""
    c = Canvas(CELL)
    lump(c, 22.0, GROUND - 2.0, 4.5, 2.8, ("S3", "S2", "S1"))
    lump(c, 42.5, GROUND - 1.5, 4.0, 2.4, ("S3", "S2", "S1"))
    lump(c, 15.5, GROUND - 0.5, 1.6, 1.4, ("S4", "S2", "S1"))
    lump(c, 49.0, GROUND - 0.5, 1.5, 1.3, ("S4", "S2", "S1"))
    lump(c, 32.0, GROUND - 3.0, 4.6, 3.4, ("S3", "S2", "S1"))
    # the face's plate, cracked, its eyes out
    for x in range(29, 36):
        for y in range(GROUND - 5, GROUND - 1):
            c.set(x, y, "A2" if y == GROUND - 5 else "A1" if x < 33 else "A0")
    c.set(30, GROUND - 4, "D0")
    c.set(33, GROUND - 4, "D0")
    for x in range(30, 35, 2):
        c.set(x, GROUND - 2, "A3")
    c.set(32, GROUND - 5, "O")
    c.set(32, GROUND - 4, "O")
    c.outline()
    add_dust(c, dust)
    return c


# --- animations -----------------------------------------------------------------------------

def idle():
    eyes = [1, 1, 2, 2, 1, 1]
    return [pose(eyes=eyes[i], brow=1 if i == 3 else 0) for i in range(6)]


def walk():
    # The rim turns a tooth's width over the loop (the game also spins the whole wheel while it
    # rolls); the face keeps gritting its teeth.
    return [pose(turn=i * 36.0 / 8, eyes=1, mouth=0) for i in range(8)]


def attack():
    # The face heats red and the mouth opens on a glowing throat, snaps shut in a bite with sparks,
    # and opens hot again just before it rolls.
    return [
        pose(eyes=1),
        pose(eyes=2, brow=1),
        pose(eyes=2, brow=1, mouth=1, glow=1, hot=1),
        pose(eyes=3, brow=1, mouth=2, glow=2, hot=1, dx=-1),
        pose(eyes=3, brow=1, mouth=2, glow=3, hot=2, dx=-1),
        pose(eyes=3, brow=1, mouth=0, glow=2, hot=2, dx=1,
             fx=[(44, 40, "F3"), (46, 37, "F2"), (45, 44, "F2")]),
        pose(eyes=3, brow=1, mouth=1, glow=3, hot=1, fx=[(48, 41, "F1")]),
        pose(eyes=3, brow=1, mouth=2, glow=3, hot=1),
    ]


def special():
    # The launch: dust kicks up behind it, the rim blurs and streaks of fire stream out behind.
    return [
        pose(eyes=3, brow=1, mouth=1, glow=2, hot=1, dx=-1, turn=6, dust=[(14, 48, 2.6)]),
        pose(eyes=3, brow=1, mouth=1, glow=2, hot=1, turn=18, blur=True, dust=[(11, 46, 3.2), (17, 49, 2.0)]),
        pose(eyes=3, brow=1, mouth=1, glow=3, hot=1, dx=1, blur=True, trail=6, phase=0, dust=[(8, 44, 3.4, True)]),
        pose(eyes=3, brow=1, mouth=1, glow=3, hot=1, dx=1, blur=True, trail=11, phase=1),
        pose(eyes=3, brow=1, mouth=1, glow=3, hot=1, dx=2, blur=True, trail=15, phase=2),
        pose(eyes=3, brow=1, mouth=1, glow=3, hot=1, dx=2, blur=True, trail=17, phase=0),
        pose(eyes=3, brow=1, mouth=1, glow=3, hot=1, dx=2, blur=True, trail=18, phase=1),
    ]


def hurt():
    return [
        pose(flash=True, dx=-1),
        pose(dx=-2, turn=-9, shut=True, brow=1, mouth=1),
        pose(dx=-1, turn=-4, eyes=1),
        pose(eyes=1),
    ]


def death():
    # A crack runs through its face and rim, it splits in two halves that fall apart, and leaves
    # a heap of rubble in the dust.
    frames = [draw_wheel(p) for p in (
        pose(crack=1, eyes=0, shut=True, mouth=1),
        pose(crack=2, eyes=0, shut=True, mouth=1, dull=True, dx=1, dust=[(31, 22, 2.0)]),
        pose(crack=2, eyes=0, shut=True, mouth=1, dull=True, split=1,
             dust=[(32, 24, 3.0), (20, 47, 2.4), (44, 47, 2.4)], fx=[(30, 20, "S3"), (36, 18, "S2")]),
        pose(crack=2, eyes=0, shut=True, mouth=1, dull=True, split=2.5,
             dust=[(32, 20, 3.4, True), (14, 46, 3.0), (50, 46, 3.0)]),
        pose(crack=2, eyes=0, shut=True, mouth=1, dull=True, split=4,
             dust=[(12, 44, 3.0, True), (52, 44, 3.0, True)]),
    )]
    frames.append(rubble([(32, 40, 3.6), (20, 43, 2.6, True), (44, 43, 2.6, True)]))
    frames.append(rubble([(32, 37, 3.0, True)]))
    frames.append(rubble())
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
        strip([draw_wheel(p) for p in make()], os.path.join(OUT, "rueda_devoradora_%s.png" % name))
    strip(death(), os.path.join(OUT, "rueda_devoradora_death.png"))
