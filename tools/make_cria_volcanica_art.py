"""Draws the Cría volcánica's art (the Núcleo de cría's brood, temple, island 3) pixel by pixel.

The creature had no art of its own (it borrowed the salamander's, shrunk and tinted), so it is drawn
at the game's pixel size from the bugs that leave the hive in the pack's sheet: a small winged
insect of fire, a dark head and thorax, a striped abdomen of lava with a glowing tail, and two
pale wings; it hovers over its own shadow. Its animations: idle (hovers, wings beating, the tail
pulsing), walk (flies leaning forward), attack (backs off while its tail heats up, then darts and
bites with a spark), special (flares up in flames), hurt and death (its wings fold, it drops to the
floor and burns out into a pinch of ash).

Writes into `assets/sprites/cria_volcanica/`:
    cria_volcanica_<animation>.png   32x32 cells, facing right, shadow on row 26: idle, walk,
                                     attack, special, hurt, death

    python tools/make_cria_volcanica_art.py
Then tools/make_temple_enemy_frames.gd builds its SpriteFrames as for every temple enemy, and
tools/enemy_aseprite.lua keeps an editable `source/cria_volcanica.aseprite`. Needs Pillow.
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "cria_volcanica")
CELL = 32
## Last row of its shadow on the floor (it flies: the shadow stands for its feet).
GROUND = 26

PALETTE = {
    "O": (26, 12, 16),     # outline
    "SH": (30, 20, 30),    # shadow on the floor
    # chitin
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
    # wings
    "W1": (190, 134, 86),
    "W2": (236, 196, 136),
    "W3": (255, 238, 200),
    # ash
    "A1": (88, 78, 80),
    "A2": (128, 116, 112),
    "W": (255, 243, 224),  # hurt flash
}
LAVA = ["S0", "S1", "S2", "S3", "S4", "Y", "Y2"]
CHITIN = ["B0", "B1", "B2", "B3"]
## Death: each step cools the lava.
COOL_STEPS = [
    {"Y2": "Y", "Y": "S4", "S4": "S3", "S3": "S2"},
    {"Y": "S3", "S4": "S2", "S3": "S2", "S2": "S1", "B3": "B2", "W3": "W2"},
    {"S3": "S1", "S2": "S1", "S1": "S0", "B2": "B1", "W2": "W1"},
]
BLAZE = {"S0": "S1", "S1": "S2", "S2": "S3", "S3": "S4", "S4": "Y", "Y": "Y2", "B1": "B2", "B2": "B3"}

## Rest pose: abdomen, thorax and head (center x, center y, radius x, radius y).
ABDOMEN = (11.5, 16.5, 4.6, 3.3)
THORAX = (16.5, 15.0, 2.1, 2.3)
HEAD = (19.9, 14.2, 2.3, 2.3)
## Where the wings join the thorax, and each beat's angle (degrees, 0 = forward, -90 = up).
WING_ROOT = (16.0, 12.5)
WING_ANGLE = {"up": -95, "mid": -130, "down": -160, "fold": 165}


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


def seam(top, under):
    """Where a part lies over another, its edge becomes a dark seam instead of a second outline."""
    for (x, y) in list(top.px):
        if any(n in under.px and n not in top.px for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))):
            top.px[(x, y)] = "B0"


def blob(c, cx, cy, rx, ry, color_at):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if in_ellipse(x, y, cx, cy, rx, ry):
                c.set(x, y, color_at(x, y, lit((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)))


# --- the creature ----------------------------------------------------------------------------

def pose(**kw):
    p = dict(dx=0, dy=0, wing="up", glow=1, tilt=0, curl=0, bite=0, blaze=False, flash=False,
             cool=0, shadow=True, fx=())
    p.update(kw)
    return p


def wing(c, ax, ay, angle, length, width, colors):
    """A wing as a slim ellipse from its root, `colors` = (edge, fill, vein)."""
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
            # the leading edge (toward the light) is pale, a vein runs down the middle
            col = colors[0] if v < -width * 0.35 else colors[2] if abs(v) < 0.5 and u < length * 0.3 else colors[1]
            c.set(x, y, col)


def draw_bug(p):
    dx, dy = p["dx"], p["dy"]
    tilt = p["tilt"]
    glow = p["glow"]
    body = Canvas(CELL)
    # The far wing behind everything.
    wa = WING_ANGLE[p["wing"]]
    wx, wy = WING_ROOT[0] + dx, WING_ROOT[1] + dy
    back = Canvas(CELL)
    wing(back, wx - 1, wy + 1, wa - 14, 6.0, 1.7, ("W2", "W1", "W1"))
    # Abdomen: lava ringed with thin dark bands, the tail end glowing; curled under when it
    # gets ready to dart.
    ax, ay, arx, ary = ABDOMEN
    ax += dx + p["curl"] * 0.5
    ay += dy - tilt * 0.6 + p["curl"] * 0.8
    left = ax - arx

    def abdomen(x, y, l):
        k = int(x + 0.5 - left)
        if k < 2:
            return ramp(LAVA, glow + 3 + l)
        if k % 3 == 0:
            return ramp(CHITIN, 0.6 + l * 1.5)
        return ramp(LAVA, glow + 1.8 + l * 1.6)
    blob(body, ax, ay, arx, ary, abdomen)
    # Thorax and head, dark chitin lit from the upper left, each parted from the one behind by a
    # dark seam.
    tx, ty, trx, try_ = THORAX
    thorax = Canvas(CELL)
    blob(thorax, tx + dx, ty + dy, trx, try_, lambda x, y, l: ramp(CHITIN, 1.6 + l * 1.8))
    seam(thorax, body)
    body.over(thorax)
    hx, hy, hrx, hry = HEAD
    hx += dx + p["bite"] * 0.5
    hy += dy + tilt * 0.6
    head = Canvas(CELL)
    blob(head, hx, hy, hrx, hry, lambda x, y, l: ramp(CHITIN, 1.8 + l * 1.8))
    seam(head, body)
    body.over(head)
    hxi, hyi = int(hx), int(hy)
    # big glowing eye and the jaws
    body.set(hxi, hyi - 1, "Y2")
    body.set(hxi + 1, hyi - 1, "Y")
    body.set(hxi + 1, hyi, "S4")
    jaw = "Y" if p["bite"] else "S3"
    body.set(hxi + 2, hyi + 1, jaw)
    if p["bite"]:
        body.set(hxi + 3, hyi + 1, "S4")
    # feeler
    body.set(hxi, hyi - 3, "B1")
    body.set(hxi + 1, hyi - 4, "B1")
    # legs tucked under the thorax
    lx, ly = int(tx + dx), int(ty + dy) + 2
    body.set(lx - 1, ly + 1, "B0")
    body.set(lx - 2, ly + 2, "B0")
    body.set(lx + 1, ly + 1, "B0")
    body.set(lx + 2, ly + 2, "B0")
    front = Canvas(CELL)
    wing(front, wx, wy, wa, 7.0, 2.0, ("W3", "W2", "W1"))
    back.over(body)
    back.over(front)
    bug = back
    if p["blaze"]:
        bug.remap(BLAZE)
    for step in COOL_STEPS[:p["cool"]]:
        bug.remap(step)
    bug.outline("S2" if p["blaze"] else "O")
    if p["blaze"]:
        bug.outline()
    if p["flash"]:
        bug.remap({c: "W" for c in PALETTE if c not in ("O", "SH")})
    return finish(bug, p)


def finish(bug, p):
    if p["shadow"]:
        shadow = Canvas(CELL)
        blob(shadow, 15.0 + p["dx"] * 0.5, GROUND, 3.2, 1.0, lambda x, y, l: "SH")
        shadow.over(bug)
        bug = shadow
    add_fx(bug, p["fx"])
    return bug


def add_fx(canvas, fx):
    """Sparks and embers: (x, y, size, color); size 1 is one pixel, 2 a small flame."""
    if not fx:
        return
    sparks = Canvas(canvas.size)
    for x, y, size, col in fx:
        sparks.set(x, y, col)
        if size == 2:
            sparks.set(x, y + 1, "S3")
            sparks.set(x + 1, y + 1, "S4")
            sparks.set(x - 1, y + 1, "S3")
    sparks.outline(only_empty_of=canvas)
    canvas.over(sparks)


def ash(cool, embers=()):
    """What is left on the floor: a crumpled husk, then a pinch of ash."""
    c = Canvas(CELL)
    if cool < 2:
        # the husk: folded wings over a dark body, lava still in its bands
        blob(c, 15.5, GROUND - 1.5, 5.0, 2.0, lambda x, y, l: ramp(CHITIN, 1.5 + l * 1.5))
        for x in (12, 14, 16):
            c.set(x, GROUND - 1, "S3" if cool == 0 else "S2")
        blob(c, 17.5, GROUND - 3.0, 3.0, 1.2, lambda x, y, l: "W2" if l > 0 else "W1")
        c.set(20, GROUND - 2, "Y" if cool == 0 else "S3")
    else:
        blob(c, 15.5, GROUND - 0.5, 4.0, 1.5, lambda x, y, l: "A2" if l > 0.2 else "A1")
        if cool == 2:
            c.set(15, GROUND - 1, "S3")
    c.outline()
    add_fx(c, list(embers))
    return c


# --- animations -----------------------------------------------------------------------------

def idle():
    wings = ["up", "mid", "down", "up", "mid", "down"]
    bob = [0, -1, -1, 0, 1, 0]
    glow = [1, 2, 3, 3, 2, 1]
    return [pose(wing=wings[i], dy=bob[i], glow=glow[i]) for i in range(6)]


def walk():
    # Flies leaning forward, its wings beating faster.
    wings = ["up", "down", "mid", "up", "down", "mid"]
    bob = [0, 1, 0, -1, 0, 1]
    return [pose(wing=wings[i], dy=bob[i], tilt=1, glow=2, dx=1) for i in range(6)]


def attack():
    # Backs off while its tail heats up, then darts in and bites, about 3/4 of the way through
    # (attack_windup 0.35 s of 0.47 s).
    return [
        pose(wing="up", glow=1),
        pose(wing="down", dx=-1, glow=2, curl=1),
        pose(wing="up", dx=-2, dy=-1, glow=2, curl=1),
        pose(wing="down", dx=-3, dy=-1, glow=3, curl=2),
        pose(wing="mid", dx=-3, dy=-1, glow=3, curl=2, fx=[(6, 19, 1, "Y")]),
        pose(wing="down", dx=1, tilt=1, glow=3, curl=1),
        pose(wing="mid", dx=5, tilt=1, glow=3, bite=1, fx=[(28, 15, 1, "Y2"), (29, 13, 1, "Y"), (29, 17, 1, "S4"), (30, 15, 1, "Y")]),
        pose(wing="up", dx=3, glow=2, fx=[(28, 17, 1, "S3")]),
    ]


def special():
    # Flares up: it bursts into flame and embers fly off it.
    return [
        pose(wing="up", glow=3),
        pose(wing="down", glow=3, blaze=True, dy=-1, fx=[(10, 8, 1, "Y")]),
        pose(wing="up", glow=3, blaze=True, dy=-2, fx=[(8, 6, 2, "Y"), (23, 7, 1, "S4")]),
        pose(wing="down", glow=3, blaze=True, dy=-2, fx=[(6, 4, 1, "S4"), (25, 5, 2, "Y"), (14, 4, 1, "Y")]),
        pose(wing="up", glow=3, blaze=True, dy=-1, fx=[(4, 3, 1, "S3"), (27, 3, 1, "S4")]),
        pose(wing="mid", glow=2, fx=[(26, 2, 1, "S3")]),
    ]


def hurt():
    return [
        pose(flash=True, wing="down", dx=-1),
        pose(wing="down", dx=-2, dy=-1, glow=0, tilt=-1),
        pose(wing="up", dx=-1, glow=1),
        pose(wing="mid", glow=1),
    ]


def death():
    # Its wings fold, it drops to the floor in a burst of embers and burns out.
    frames = [
        draw_bug(pose(flash=True, wing="down")),
        draw_bug(pose(wing="fold", dy=2, tilt=1, glow=2, cool=1)),
        draw_bug(pose(wing="fold", dy=5, dx=1, tilt=1, glow=1, cool=1)),
    ]
    frames.append(ash(0, [(10, 18, 1, "Y"), (21, 17, 1, "Y"), (15, 15, 2, "Y")]))
    frames.append(ash(1, [(8, 14, 1, "S4"), (23, 12, 1, "S3")]))
    frames.append(ash(2, [(16, 10, 1, "S3")]))
    frames.append(ash(3))
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
        strip([draw_bug(p) for p in make()], os.path.join(OUT, "cria_volcanica_%s.png" % name))
    strip(death(), os.path.join(OUT, "cria_volcanica_death.png"))
