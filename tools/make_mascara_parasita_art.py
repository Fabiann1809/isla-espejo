"""Draws the Máscara parásita's art (temple enemy, island 3) pixel by pixel.

The bestiary pack's mask, scaled from 128 px down to the game, came out blurred, so it is drawn at
the game's own pixel size instead, following the pack's design: a carnival mask, ivory on its lit
side and gold on the other, with dark eye holes, a red gem on the brow, a mane of magenta hair and
red-pink tentacles trailing behind it. It floats: there are no feet, its lowest tentacle tip rests
on row 50 in the first idle frame (where the game puts its shadow) and the mask bobs above it. It
is built from a few parts (hair, tentacles, mask plate) that each animation moves frame by frame,
as in the pack's sheet: idle (floats up and down; also while it rides a host), walk (floats along,
its tentacles streaming; also its flight from Nico), attack (rears back, its eyes flare and it
lunges with a purple trail), special (the leap to a host, wrapped in purple energy; it loops),
hurt and death (it cracks and crumbles into purple dust).

Writes into `assets/sprites/mascara_parasita/`:
    mascara_parasita_<animation>.png   64x64 cells, facing right, its base on row 50: idle, walk,
                                       attack, special, hurt, death

    python tools/make_mascara_parasita_art.py
Then tools/make_temple_enemy_frames.gd builds its SpriteFrames as for every temple enemy, and
tools/enemy_aseprite.lua keeps an editable `source/mascara_parasita.aseprite`.
Needs Pillow.
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "mascara_parasita")
CELL = 64
## Lowest row of its tentacles in the first idle frame (its "feet": the shadow goes under it).
BASE = 50
## Rest place of the mask plate's center.
MASK = (34.0, 44.0)

PALETTE = {
    "O": (28, 10, 26),      # outline
    "K": (22, 6, 22),       # eye holes and mouth
    "E": (255, 110, 220),   # the glint in its eyes
    # ivory side of the mask
    "I1": (176, 150, 150),
    "I2": (226, 212, 200),
    "I3": (252, 246, 232),
    # gold side and ornaments
    "G0": (118, 70, 22),
    "G1": (196, 140, 40),
    "G2": (240, 198, 74),
    "G3": (255, 238, 160),
    # magenta hair
    "H0": (64, 18, 64),
    "H1": (118, 30, 116),
    "H2": (176, 54, 170),
    "H3": (226, 112, 216),
    # tentacles
    "R0": (86, 12, 30),
    "R1": (148, 26, 48),
    "R2": (204, 56, 74),
    "R3": (242, 122, 132),
    # purple energy
    "M0": (70, 22, 120),
    "M1": (136, 52, 222),
    "M2": (190, 112, 255),
    "M3": (232, 196, 255),
    "M4": (255, 248, 255),
    "W": (255, 243, 248),   # hurt flash
}
HAIR = ("H0", "H1", "H2", "H3", "H3")
## Death: the colours drain toward the purple of its dust.
DRAIN = {"I3": "I2", "I2": "I1", "G3": "G2", "G2": "G1", "R3": "R2", "R2": "R1", "H3": "H2", "E": "K"}


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


def ramp_of(l, ramp, th=(0.62, 0.22, -0.3, -0.75)):
    for t, c in zip(th, reversed(ramp)):
        if l > t:
            return c
    return ramp[0]


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


def hashed(x, y, seed=0):
    x, y = int(x), int(y)
    return ((x * 73856093) ^ (y * 19349663) ^ (seed * 83492791)) % 97


# --- the mask ----------------------------------------------------------------------------------

def pose(**kw):
    p = dict(dx=0, dy=0, wave=0.0, stream=0.0, curl=0.0, eyes=1, mouth=0, flash=False, crack=0,
             split=0, drain=0, aura=False, fx=())
    p.update(kw)
    return p


## Tentacles: root (relative to the mask's center), rest direction (radians, 0 = right, pi/2 =
## down), length and wave offset. Drawn back to front.
TENTACLES = [
    ((-7, -3), 3.05, 7, 0.0),
    ((-7, 1), 2.85, 8, 1.7),
    ((-5, 3), 2.65, 7, 3.1),
]


def draw_tentacles(c, p, mx, my):
    """Red-pink tentacles streaming behind and below, waving; thick at the root, curled at the tip."""
    for k, ((rx, ry), angle, length, off) in enumerate(TENTACLES):
        # streaming turns them toward the back (left), curling bends their tips up
        a = angle + p["stream"] * (math.pi - angle) * 0.7
        x, y = mx + rx, my + ry
        pts = []
        for t in range(length):
            bend = 0.6 * math.sin(p["wave"] + off + t * 0.7) + p["curl"] * t / length
            a_t = a + bend * (t / length)
            x += math.cos(a_t)
            y += math.sin(a_t)
            # its tips never hang below the mask's chin (the shadow sits there)
            pts.append((math.floor(x), min(math.floor(y), int(my) + 6)))
        pts = pixel_perfect(pts)
        back = k in (0, 2)
        for i, (px_, py_) in enumerate(pts):
            f = i / max(len(pts) - 1, 1)
            if f < 0.7:
                # two pixels thick: a lit upper edge over a shaded underside
                c.set(px_, py_ - 1, "R2" if back else "R3")
                c.set(px_, py_, "R0" if back else "R1")
            else:
                c.set(px_, py_, "R1" if back else "R2")


def draw_hair(c, p, mx, my):
    """A mane of magenta hair over the top and back of the mask, with a few locks."""
    hx, hy, rx, ry = mx - 2.5, my - 2.5, 6.5, 6.1
    for y in range(int(hy - ry) - 1, int(hy + ry) + 2):
        for x in range(int(hx - rx) - 1, int(hx + rx) + 2):
            if not in_ellipse(x, y, hx, hy, rx, ry):
                continue
            c.set(x, y, ramp_of(lit((x + 0.5 - hx) / rx, (y + 0.5 - hy) / ry), HAIR,
                                (0.75, 0.75, 0.25, -0.45)))
    # locks: darker grooves curving back
    for (dx, dy) in ((-4, -3), (-3, -2), (-5, 0), (-4, 1), (-1, -5), (-2, -4), (-6, 2)):
        c.set(int(hx) + dx, int(hy) + dy, "H1")
    # tufts sticking out at the back
    for (dx, dy, col) in ((-7, -1, "H2"), (-7, 2, "H1"), (-6, -4, "H2"), (-8, 0, "H1")):
        c.set(int(hx) + dx, int(hy) + dy, col)


def draw_plate(c, p, mx, my):
    """The mask itself: ivory on its lit side, gold on the other, eye holes, brow gem, mouth."""
    rx, ry = 4.8, 6.6
    plate = {}
    for y in range(int(my - ry) - 1, int(my + ry) + 2):
        for x in range(int(mx - rx) - 1, int(mx + rx) + 2):
            if not in_ellipse(x, y, mx, my, rx, ry):
                continue
            nx, ny = (x + 0.5 - mx) / rx, (y + 0.5 - my) / ry
            l = lit(nx, ny)
            # the split between the two halves wavers down the face
            split = mx + 0.5 + (1 if (y - int(my)) in (-2, -1, 3, 4) else 0)
            if x + 0.5 < split:
                col = "I3" if l > 0.45 else "I2" if l > -0.25 else "I1"
            else:
                col = "G3" if l > 0.55 else "G2" if l > -0.05 else "G1" if l > -0.55 else "G0"
            plate[(x, y)] = col
    ix, iy = int(mx), int(my)
    # brow and eyes: the near eye (right) is bigger
    for (dx, dy) in ((-3, -2), (-2, -2), (1, -2), (2, -2), (3, -2)):
        if (ix + dx, iy + dy) in plate:
            plate[(ix + dx, iy + dy)] = "G0" if dx > 0 else "I1"
    for (dx, dy) in ((-3, -1), (-2, -1), (-2, 0), (1, -1), (2, -1), (3, -1), (1, 0), (2, 0), (3, 0)):
        plate[(ix + dx, iy + dy)] = "K"
    if p["eyes"]:
        plate[(ix - 2, iy - 1)] = "E"
        plate[(ix + 2, iy - 1)] = "E"
        if p["eyes"] > 1:
            plate[(ix + 2, iy - 1)] = "M4"
            plate[(ix + 3, iy - 1)] = "E"
            plate[(ix - 3, iy - 1)] = "E"
    # gem on the brow, gold rim
    plate[(ix, iy - 4)] = "R2"
    plate[(ix, iy - 3)] = "R1"
    plate[(ix - 1, iy - 4)] = "G2"
    plate[(ix + 1, iy - 4)] = "G1"
    # cheek ornament on the gold side
    plate[(ix + 3, iy + 2)] = "G0"
    plate[(ix + 2, iy + 3)] = "G0"
    # mouth: a slit, open when it bites
    for dx in range(-1, 2):
        plate[(ix + dx, iy + 4)] = "K"
    if p["mouth"]:
        for dx in range(-1, 2):
            plate[(ix + dx, iy + 5)] = "K"
        plate[(ix, iy + 4)] = "R1"
    if p["crack"]:
        # a crack running down from the brow
        for (dx, dy) in ((0, -5), (0, -4), (1, -3), (0, -2), (0, -1), (-1, 0), (0, 1), (1, 2),
                         (1, 3), (0, 4), (0, 5), (1, 6))[:6 + p["crack"] * 4]:
            plate[(ix + dx, iy + dy)] = "K"
    for (x, y), col in plate.items():
        if p["split"] and x + 0.5 >= mx + 0.5:
            # the broken mask's halves fall apart
            c.set(x + p["split"], y + p["split"], col)
        elif p["split"]:
            c.set(x - p["split"] // 2, y + p["split"] + 1, col)
        else:
            c.set(x, y, col)


def draw_mask(p):
    mx, my = MASK[0] + p["dx"], MASK[1] + p["dy"]
    body = Canvas(CELL)
    draw_tentacles(body, p, mx, my)
    draw_hair(body, p, mx, my)
    draw_plate(body, p, mx, my)
    for _ in range(p["drain"]):
        body.remap(DRAIN)
    body.outline("M1" if p["aura"] else "O")
    if p["aura"]:
        # a ring of energy just outside its dark outline
        body.outline("O")
    if p["flash"]:
        body.remap({c: "W" for c in PALETTE if c not in ("O", "K")})
    add_fx(body, p["fx"])
    return body


def add_fx(canvas, fx):
    """Motes and sparks: (x, y, kind, color); kind 1 is a pixel, 2 a 2x2 mote, 3 a 4-point sparkle."""
    if not fx:
        return
    motes = Canvas(canvas.size)
    for x, y, kind, c in fx:
        if kind == 1:
            motes.set(x, y, c)
        elif kind == 2:
            motes.set(x, y, "M4" if c == "M3" else "M3")
            motes.set(x + 1, y, c)
            motes.set(x, y + 1, c)
            motes.set(x + 1, y + 1, "M1")
        else:
            motes.set(x, y, "M4")
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                motes.set(x + dx, y + dy, c)
    motes.outline("M0", only_empty_of=canvas)
    canvas.over(motes)


# --- energy trails and dust --------------------------------------------------------------------

def trail(head_x, cy, length, half, phase, frayed=False):
    """A streak of purple energy behind the mask, like a flame blown back: as wide as the mask
    where it leaves it, tapering to ragged tips; white-hot along its middle."""
    c = Canvas(CELL)
    head_x = int(head_x)
    for t in range(length):
        x = head_x - t
        f = t / max(length - 1, 1)
        h = half * (1.0 - f) ** 0.7
        wobble = 0.8 * math.sin(t * 0.9 + phase * 1.7)
        top = round(cy - h + wobble * f)
        bottom = round(cy + h * 0.85 + wobble * f)
        for y in range(top, bottom + 1):
            d = abs(y + 0.5 - (cy + wobble * f)) / max(h, 0.5)
            col = "M4" if d < 0.22 and f < 0.5 else "M3" if d < 0.5 and f < 0.75 else "M2" if d < 0.85 else "M1"
            if frayed and f > 0.35 and hashed(x, y, phase) % 3 == 0:
                continue
            c.set(x, y, col)
    # loose sparks blown off its tips
    for k in range(2):
        c.set(head_x - length - 1 - 2 * k - phase % 2, round(cy - half * 0.7 + k * half * 1.3), "M2")
    c.outline("M0")
    return c


def with_trail(p, streak):
    mask = draw_mask(p)
    streak.over(mask)
    return streak


def dust(c, cx, cy, rx, ry, seed, thin=0):
    """A puff of purple dust; `thin` 0..2 breaks it into grains."""
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if not in_ellipse(x, y, cx, cy, rx, ry):
                continue
            if thin and hashed(x, y, seed) % (5 - thin) == 0:
                continue
            l = lit((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
            c.set(x, y, "M3" if l > 0.55 else "M2" if l > 0.0 else "M1" if l > -0.5 else "M0")


# --- animations -------------------------------------------------------------------------------

def idle():
    # Floats up and down; its tentacles sway a beat behind.
    dy = [0, -1, -2, -2, -1, 0]
    return [draw_mask(pose(dy=dy[i], wave=i * math.tau / 6)) for i in range(6)]


def walk():
    # Floats along: leaning in, tentacles streaming back, a quicker bob.
    dy = [-1, -2, -2, -1, -1, -2, -2, -1]
    return [draw_mask(pose(dx=1, dy=dy[i], wave=i * math.tau / 8, stream=0.45)) for i in range(8)]


def attack():
    # Rears back while its eyes flare and energy gathers around it, then lunges forward with a
    # purple trail (the bite lands at about 75% of the strip) and drifts back.
    my = MASK[1]
    return [
        draw_mask(pose(dx=-1, dy=-1, wave=0.5, curl=0.6)),
        draw_mask(pose(dx=-2, dy=-2, wave=1.0, curl=1.0, eyes=2, mouth=1)),
        draw_mask(pose(dx=-3, dy=-2, wave=1.5, curl=1.2, eyes=2, mouth=1, aura=True,
                       fx=[(23, 33, 1, "M2"), (40, 31, 1, "M3"), (26, 48, 1, "M2")])),
        draw_mask(pose(dx=-3, dy=-1, wave=2.0, curl=1.2, eyes=2, mouth=1, aura=True,
                       fx=[(24, 31, 3, "M2"), (41, 34, 1, "M3"), (22, 46, 1, "M2")])),
        with_trail(pose(dx=1, dy=-1, wave=2.5, stream=0.8, eyes=2, mouth=1),
                   trail(MASK[0] - 3, my - 2, 14, 4.5, 0)),
        with_trail(pose(dx=7, dy=0, wave=3.0, stream=1.0, eyes=2, mouth=1),
                   trail(MASK[0] + 3, my - 1, 28, 6.0, 1)),
        with_trail(pose(dx=4, dy=-1, wave=3.5, stream=0.6, eyes=1),
                   trail(MASK[0] - 1, my - 2, 18, 4.0, 2, frayed=True)),
    ]


def special():
    # The leap to a host: it flies wrapped in purple energy, the trail flickering (it loops).
    my = MASK[1]
    frames = []
    for i in range(6):
        streak = trail(MASK[0] + 1, my - 1.5, 24 + (i % 3) * 2, 6.0 - (i % 2) * 0.5, i)
        frames.append(with_trail(pose(dx=3, dy=-1 - (i % 2), wave=i * math.tau / 6, stream=1.0, eyes=2,
                                      aura=True), streak))
    return frames


def hurt():
    return [draw_mask(p) for p in (
        pose(flash=True, dx=-1),
        pose(dx=-3, dy=1, eyes=0, mouth=1, curl=-0.6, wave=1.0),
        pose(dx=-2, dy=0, wave=2.0, curl=-0.3),
        pose(dx=-1, wave=3.0),
    )]


def death():
    # It cracks, sags, breaks in two and crumbles into purple dust that settles and fades.
    frames = [
        draw_mask(pose(flash=True, dx=-1)),
        draw_mask(pose(dx=-2, dy=2, eyes=0, mouth=1, crack=1, curl=-0.8, drain=1)),
        draw_mask(pose(dx=-2, dy=5, eyes=0, crack=2, split=1, curl=-1.0, drain=2,
                       fx=[(26, 40, 1, "M2"), (39, 42, 1, "M3")])),
    ]
    puffs = [
        [(29, 50, 6, 2.5), (38, 50, 4, 2), (33, 48, 3, 2)],
        [(28, 49, 6, 2.5), (38, 49, 5, 2.5), (33, 45, 3, 2)],
        [(25, 50, 4, 1.5), (40, 50, 4, 1.5)],
    ]
    for k, group in enumerate(puffs):
        f = Canvas(CELL)
        for i, (x, y, rx, ry) in enumerate(group):
            dust(f, x, y, rx, ry, seed=k * 5 + i, thin=min(k, 2))
        f.outline("M0")
        if k < 2:
            # shards of the broken mask tumbling into the dust
            shards = Canvas(CELL)
            for (x, y, a, b) in [[(27, 44, "I3", "I2"), (36, 45, "G2", "G1"), (32, 41, "G3", "G1")],
                                 [(25, 47, "I2", "I1"), (39, 47, "G1", "G0")]][k]:
                shards.set(x, y, a)
                shards.set(x + 1, y, b)
                shards.set(x, y + 1, b)
            shards.outline()
            f.over(shards)
        add_fx(f, [(31 - k, 38 - k * 3, 1, "M2"), (38 + k, 41 - k * 2, 1, "M3")] if k < 2 else [])
        frames.append(f)
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
                       ("hurt", hurt), ("death", death)):
        strip(make(), os.path.join(OUT, "mascara_parasita_%s.png" % name))
