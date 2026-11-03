"""Draws the Vasija poseida's art (temple enemy, island 3) and its fire spirit pixel by pixel.

The pack's vase, scaled from 128 px down to the game, came out blurred, so it is drawn at the game's
own pixel size instead, following the pack's design: a round pot of brown-orange clay with a bronze
rim, a dark neck band, glowing lava stains on its belly and a gold rune with a flame on its front;
fire lives inside it. It is built from a few parts that each animation moves: the pot (which can
lean, rise and crack), its rim and the four crab legs it hides under itself. Animations, as in the
pack's sheet: idle (still, a faint glow; frame 0 is also every decoy vase), walk (scuttles on its
crab legs), attack (leans back, fills with fire and spits a fireball from its mouth), special (it
jumps on its legs, fire bursts from its mouth: the spirit leaving), hurt, and death (it bursts into
shards that settle around its rim).

The spirit it frees (espiritu_vasija) is the pack's fireball: a ball of fire trailing flames.

Writes into `assets/sprites/vasija_poseida/`:
    vasija_poseida_<animation>.png   64x64 cells, facing right, the foot's last row on row 50:
                                     idle, walk, attack, special, hurt, death
    vasija_poseida_spirit.png        32x32 cells, the ball's center on (18, 16): 4 flicker (loop),
                                     2 attack (gather, lunge), 1 hurt, 3 death

    python tools/make_vasija_poseida_art.py
Then tools/make_temple_enemy_frames.gd builds the vase's SpriteFrames as for every temple enemy,
tools/make_vasija_poseida.gd the spirit's, and tools/enemy_aseprite.lua keeps an editable
`source/vasija_poseida.aseprite` (extras="spirit:8:fly=1-4;attack=5-6;hurt=7-7;death=8-10").
Needs Pillow.
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "vasija_poseida")
CELL = 64
SPIRIT_CELL = 32
## Last row of the pot's foot; its outline goes on the row below.
GROUND = 50
CX = 32.0
## The pot's profile, in rows above GROUND: foot, belly (an ellipse), neck, rim.
FOOT_TOP = 1
BELLY_Y, BELLY_RX, BELLY_RY = 9.5, 13.0, 10.0
NECK = (19, 20)
NECK_R = 7.0
RIM_Y, RIM_RX, RIM_RY = 21.8, 8.5, 2.6

PALETTE = {
    "O": (26, 12, 10),      # outline
    # clay
    "C0": (60, 26, 14),
    "C1": (102, 46, 20),
    "C2": (150, 74, 30),
    "C3": (198, 108, 44),
    "C4": (234, 154, 76),
    # bronze rim, rune
    "G0": (120, 70, 24),
    "G1": (206, 146, 52),
    "G2": (252, 216, 130),
    # lava and fire
    "S0": (72, 14, 14),
    "S1": (130, 30, 20),
    "S2": (196, 62, 24),
    "S3": (240, 118, 32),
    "S4": (255, 176, 58),
    "Y": (255, 222, 108),
    "Y2": (255, 248, 204),
    # smoke
    "K1": (82, 70, 74),
    "K2": (122, 110, 108),
    "W": (255, 243, 230),   # hurt flash
}
## Hurt: everything jumps to its lightest tones.
FLASH = {"C0": "C2", "C1": "C3", "C2": "C4", "C3": "W", "C4": "W", "G0": "G2", "G1": "W", "G2": "W",
         "S0": "S2", "S1": "S3", "S2": "S4", "S3": "Y", "S4": "Y2", "Y": "W", "Y2": "W"}
## The stains brighten as the fire inside wakes up.
GLOW_UP = {"S1": "S2", "S2": "S3", "S3": "S4", "S4": "Y"}

## Lava stains on the belly: flame shapes licking up its sides (rows above GROUND, x from CX).
STAINS = [
    [(-8, 3), (-9, 6), (-8, 9), (-9, 12), (-8, 14)],
    [(-5, 2), (-5, 4), (-4, 6)],
    [(8, 3), (9, 6), (8, 9), (9, 12), (7, 14)],
    [(5, 2), (5, 4), (6, 6)],
]


class Canvas:
    def __init__(self, size):
        self.size = size
        self.px = {}

    def set(self, x, y, c):
        x, y = int(x), int(y)
        if 0 <= x < self.size and 0 <= y < self.size:
            self.px[(x, y)] = c

    def over(self, other):
        self.px.update(other.px)

    def shifted(self, dx, dy):
        c = Canvas(self.size)
        for (x, y), col in self.px.items():
            c.set(x + dx, y + dy, col)
        return c

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


def sphere_light(dx, dy, rx, ry):
    """Light on a round belly: (dx, dy) from its center (dy up), lit from the upper left front."""
    nx, ny = dx / rx, -dy / ry
    nz = math.sqrt(max(0.0, 1.0 - nx * nx - ny * ny))
    return max(0.0, -0.45 * nx - 0.5 * ny + 0.74 * nz)


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


def polyline(points):
    pts = []
    for (ax, ay), (bx, by) in zip(points, points[1:]):
        n = int(max(abs(bx - ax), abs(by - ay), 1))
        for i in range(n + 1):
            pts.append((round(ax + (bx - ax) * i / n), round(ay + (by - ay) * i / n)))
    return pixel_perfect(pts)


def capsule(c, a, b, r, shade):
    """A thick segment from a to b (radius r); `shade(l)` picks the color from the light."""
    ax, ay = a
    bx, by = b
    vx, vy = bx - ax, by - ay
    ll = vx * vx + vy * vy or 1.0
    for y in range(int(min(ay, by) - r) - 1, int(max(ay, by) + r) + 2):
        for x in range(int(min(ax, bx) - r) - 1, int(max(ax, bx) + r) + 2):
            px_, py_ = x + 0.5, y + 0.5
            t = max(0.0, min(1.0, ((px_ - ax) * vx + (py_ - ay) * vy) / ll))
            qx, qy = ax + vx * t, ay + vy * t
            d = math.hypot(px_ - qx, py_ - qy)
            if d <= r:
                c.set(x, y, shade(lit((px_ - qx) / max(r, 0.1), (py_ - qy) / max(r, 0.1))))


# --- the vase ----------------------------------------------------------------------------------

def pose(**kw):
    p = dict(lift=0, lean=0.0, dx=0, legs=0, step=0, dangle=False, glow=0, mouth=0, cracks=0,
             flash=False, squash=0, fx=(), fire=0, ball=None)
    p.update(kw)
    return p


def half_width(h):
    """Half the pot's width `h` rows above its foot."""
    if h <= FOOT_TOP:
        return 7.5
    if NECK[0] <= h <= NECK[1]:
        return NECK_R
    q = (h - BELLY_Y) / BELLY_RY
    if abs(q) >= 1.0:
        return 0.0
    return BELLY_RX * math.sqrt(1.0 - q * q)


def draw_pot(p):
    """The pot standing with its foot on GROUND (its own lean and lift are applied later)."""
    pot = Canvas(CELL)
    squash = p["squash"]
    for h in range(0, NECK[1] + 1):
        y = GROUND - h
        hh = h * (1.0 + squash * 0.05)
        r = half_width(hh) + (squash * 0.5 if FOOT_TOP < h < NECK[0] else 0)
        if r <= 0:
            continue
        for x in range(int(CX - r) - 1, int(CX + r) + 1):
            if abs(x + 0.5 - CX) > r:
                continue
            nx = (x + 0.5 - CX) / max(r, 1)
            if h <= FOOT_TOP:
                c = "C1" if h == 0 else "C2"
                if nx < -0.5 and h == FOOT_TOP:
                    c = "C3"
            elif NECK[0] <= h:
                c = "C1" if h == NECK[0] or nx > 0.5 else "C2" if nx > -0.2 else "C3"
            else:
                l = sphere_light(x + 0.5 - CX, BELLY_Y - h, BELLY_RX, BELLY_RY)
                c = "C4" if l > 0.8 else "C3" if l > 0.5 else "C2" if l > 0.22 else "C1" if l > 0.02 else "C0"
            pot.set(x, y, c)
    # a band of the neck's gold under the shoulder
    for x in range(int(CX - 9), int(CX + 9)):
        if (x, GROUND - 18) in pot.px:
            pot.set(x, GROUND - 18, "C1" if x > CX + 5 else "C2")
    # lava stains: flames licking up the belly, two pixels thick at their root
    lv = p["glow"]
    for k, stain in enumerate(STAINS):
        pts = polyline([(CX + dx, GROUND - dy) for dx, dy in stain])
        inward = 1 if stain[0][0] < 0 else -1
        for i, (x, y) in enumerate(pts):
            if (x, y) not in pot.px:
                continue
            f = i / max(len(pts) - 1, 1)
            core = ["S3", "S4", "Y"][min(lv, 2)] if f < 0.6 else ["S2", "S3", "S4"][min(lv, 2)]
            pot.set(x, y, core)
            if f < 0.55 and (x + inward, y) in pot.px:
                pot.set(x + inward, y, ["S2", "S3", "S3"][min(lv, 2)])
    # the rune: a gold diamond with a flame inside
    rx, ry = int(CX), GROUND - 9
    for dy in range(-4, 5):
        for dx in range(-3, 4):
            d = abs(dx) / 2.6 + abs(dy) / 4.2
            if d > 1.0:
                continue
            if d > 0.62:
                c = "G2" if dx <= 0 and dy < 0 else "G1" if dx <= 0 or dy < 0 else "G0"
            else:
                c = "C1"
            pot.set(rx + dx, ry + dy, c)
    flame = {0: [(0, -1, "S3"), (0, 0, "S4"), (0, 1, "S3")],
             1: [(0, -2, "S3"), (0, -1, "S4"), (0, 0, "Y"), (0, 1, "S4"), (-1, 1, "S3")],
             2: [(0, -2, "S4"), (0, -1, "Y"), (0, 0, "Y2"), (0, 1, "Y"), (-1, 1, "S4"), (1, 1, "S3")]}
    for dx, dy, c in flame[min(2, lv)]:
        pot.set(rx + dx, ry + dy, c)
    # the rim, seen from above, and the dark mouth with the fire inside
    for h in range(NECK[1] + 1, NECK[1] + 6):
        y = GROUND - h
        for x in range(int(CX - RIM_RX) - 1, int(CX + RIM_RX) + 2):
            cy = GROUND - RIM_Y
            if not in_ellipse(x, y, CX, cy, RIM_RX, RIM_RY):
                continue
            if in_ellipse(x, y, CX, cy + 0.3, RIM_RX - 2.6, RIM_RY - 1.0):
                c = ["C0", "S1", "S2", "S3"][p["mouth"]]
                if p["mouth"] >= 2 and abs(x + 0.5 - CX) < 2:
                    c = "S4" if p["mouth"] == 2 else "Y"
            else:
                l = lit((x + 0.5 - CX) / RIM_RX, (y + 0.5 - cy) / RIM_RY)
                c = "G2" if l > 0.45 else "G1" if l > -0.2 else "G0"
            pot.set(x, y, c)
    if p["cracks"]:
        add_cracks(pot, p["cracks"])
    return pot


## Cracks that run over the pot before it bursts (x from CX, rows above GROUND).
CRACKS = [
    [(-2, 19), (-3, 16), (-1, 14), (-3, 11)],
    [(4, 18), (6, 15), (5, 12), (7, 9)],
    [(-7, 13), (-9, 10), (-7, 7), (-8, 4)],
    [(2, 6), (4, 4), (3, 2)],
    [(-3, 5), (-5, 3)],
]


def add_cracks(pot, level):
    cols = {1: ("S2", "S3"), 2: ("S3", "Y"), 3: ("S4", "Y2")}[level]
    count = 2 if level == 1 else len(CRACKS)
    for crack in CRACKS[:count]:
        for i, (x, y) in enumerate(polyline([(CX + dx, GROUND - dy) for dx, dy in crack])):
            if (x, y) in pot.px:
                pot.set(x, y, cols[i % 2])


## Legs: hip (under the pot) and knee, relative to the pot's center bottom; the foot reaches GROUND.
LEGS = [  # (hip dx, hip dy, knee dx, knee dy, foot dx, front)
    (-8, -4, -15, -9, -20, False),
    (8, -4, 15, -9, 20, False),
    (-6, -2, -13, -6, -17, True),
    (6, -2, 13, -6, 17, True),
]


def draw_legs(p, base_y, front):
    """Crab legs: a thick upper segment up to a raised knee, a thin lower one down to a point."""
    c = Canvas(CELL)
    ext = p["legs"]
    for i, (hx, hy, kx, ky, fx, is_front) in enumerate(LEGS):
        if is_front != front:
            continue
        side = -1 if hx < 0 else 1
        # the walk alternates pairs: one lifts while the other plants
        swing = 0
        if p["step"]:
            phase = (p["step"] + (0 if (i % 2 == 0) == is_front else 2)) % 4
            swing = [0, 1, 0, -1][phase]
        hip = (CX + hx * ext, base_y + hy)
        knee = (CX + kx * ext + swing * side, base_y + ky * ext - (1 if swing > 0 else 0))
        if p["dangle"]:
            foot = (knee[0] + side * 1, knee[1] + 6)
        else:
            foot = (CX + fx * ext + swing * side * 2, GROUND + 0.5 - (2 if swing > 0 else 0))
        dark = not is_front
        capsule(c, hip, knee, 1.4, lambda l: ("C2" if l > 0 else "C1") if dark else ("C4" if l > 0.3 else "C3" if l > -0.3 else "C2"))
        capsule(c, knee, foot, 0.9, lambda l: "C1" if dark else ("C3" if l > 0 else "C2"))
        c.set(knee[0], knee[1] - 1, "C2" if dark else "S3")  # a glowing joint
    return c


def shear(c, lean, pivot_y):
    """Leans a picture: rows shift sideways in proportion to their height over `pivot_y`."""
    out = Canvas(CELL)
    for (x, y), col in c.px.items():
        out.set(x + round(lean * (pivot_y - y)), y, col)
    return out


def draw_vase(p):
    lift = p["lift"]
    pot = draw_pot(p)
    if p["lean"]:
        pot = shear(pot, p["lean"], GROUND)
    pot = pot.shifted(p["dx"], -lift)
    body = Canvas(CELL)
    if p["legs"]:
        body.over(draw_legs(p, GROUND - lift, front=False))
    if p["fire"]:
        body.over(fire_jet(p["fire"], p["dx"] + round(p["lean"] * RIM_Y), GROUND - lift - NECK[1] - 3))
    body.over(pot)
    if p["legs"]:
        legs = draw_legs(p, GROUND - lift, front=True)
        for xy, col in legs.px.items():
            if xy not in pot.px or xy[1] > GROUND - lift - 3:
                body.px[xy] = col
    body.outline()
    if p["flash"]:
        body.remap(FLASH)
    if p["ball"]:
        bx, by, size = p["ball"]
        ball = Canvas(CELL)
        fireball(ball, bx, by, size, 0)
        ball.outline("S0", only_empty_of=body)
        body.over(ball)
    add_fx(body, p["fx"])
    return body


def flame_tongue(c, x, base_y, h, lean):
    """One tongue of fire rising `h` px from base_y, white at its root, red at its tip."""
    for k in range(h):
        y = base_y - k
        f = k / max(h, 1)
        width = 2 if f < 0.45 else 1 if f < 0.8 else 0
        xc = x + round(lean * f * f * 3)
        for i in range(-width, width + 1):
            edge = abs(i) == width and width > 0
            col = ("Y2" if f < 0.3 else "Y" if f < 0.55 else "S4") if not edge else ("S4" if f < 0.4 else "S3")
            if f >= 0.8:
                col = "S3"
            c.set(xc + i, y, col)


def fire_jet(height, dx, rim_y):
    """Flames bursting up out of the mouth: a tall middle tongue and two shorter ones leaning out."""
    c = Canvas(CELL)
    flame_tongue(c, CX + dx, rim_y, height, 0.4)
    flame_tongue(c, CX + dx - 3, rim_y + 1, max(2, height * 2 // 3), -1)
    flame_tongue(c, CX + dx + 3, rim_y + 1, max(2, height // 2), 1)
    c.outline("S0")
    return c


def fireball(c, x, y, size, phase):
    """A ball of fire heading right with flames trailing behind it. size 1: small (the vase's
    spit), 2: the spirit."""
    r = 2.6 if size == 1 else 5.2
    tail = 6 if size == 1 else 11
    # the trailing flame: a tapering tail whose lobes waver with the phase
    for i in range(1, tail + 1):
        f = i / tail
        yc = y + math.sin(i * 0.7 + phase * 1.6) * f * (0.8 if size == 2 else 0.5)
        half = r * 0.95 * (1.0 - f) ** 0.7 * (0.8 + 0.2 * math.sin(i * 1.4 + phase * 2.1))
        for yy in range(int(yc - half) - 1, int(yc + half) + 2):
            d = abs(yy + 0.5 - yc)
            if d > half + 0.3:
                continue
            q = d / max(half, 0.5)
            col = "Y" if f < 0.2 and q < 0.4 else "S4" if f < 0.5 and q < 0.6 else "S3" if q < 0.8 and f < 0.75 else "S2" if f < 0.9 else "S1"
            c.set(x - r * 0.4 - i, yy, col)
    for yy in range(int(y - r) - 1, int(y + r) + 2):
        for xx in range(int(x - r) - 1, int(x + r) + 2):
            if not in_ellipse(xx, yy, x, y, r, r * 0.92):
                continue
            q = math.hypot(xx + 0.5 - (x + r * 0.25), yy + 0.5 - (y - r * 0.15)) / r
            c.set(xx, yy, "Y2" if q < 0.32 else "Y" if q < 0.6 else "S4" if q < 0.85 else "S3")


def add_fx(canvas, fx):
    """Sparks and drops: (x, y, size, color); size 1 is one pixel, 2 a 2x2 drop."""
    if not fx:
        return
    drops = Canvas(canvas.size)
    for x, y, size, c in fx:
        if size == 1:
            drops.set(x, y, c)
        else:
            drops.set(x, y, "Y2" if c == "Y" else "Y")
            drops.set(x + 1, y, c)
            drops.set(x, y + 1, c)
            drops.set(x + 1, y + 1, "S3")
    drops.outline("S0", only_empty_of=canvas)
    canvas.over(drops)


# --- animations --------------------------------------------------------------------------------

def idle():
    # Frame 0 is the still vase every decoy shows; then the fire inside glows a little.
    glow = [0, 0, 1, 1, 0, 0]
    mouth = [0, 0, 1, 1, 1, 0]
    return [pose(glow=glow[i], mouth=mouth[i]) for i in range(6)]


def walk():
    # It rises on its crab legs and scuttles, bobbing.
    return [pose(legs=1.0, lift=4 + (1 if i % 2 else 0), step=i + 1, glow=1, mouth=1) for i in range(6)]


def attack():
    # Legs out, it leans back while fire fills its mouth, then leans forward and spits a fireball.
    mouth_x = CX + 3
    return [
        pose(legs=0.7, lift=2, glow=1, mouth=1),
        pose(legs=1.0, lift=3, lean=-0.1, glow=1, mouth=2),
        pose(legs=1.0, lift=2, lean=-0.18, glow=2, mouth=3, squash=1),
        pose(legs=1.0, lift=2, lean=-0.18, glow=2, mouth=3, squash=1, fx=[(CX - 1, GROUND - 31, 1, "Y")]),
        pose(legs=1.0, lift=4, lean=0.2, glow=2, mouth=3, ball=(mouth_x + 9, GROUND - 28, 1),
             fx=[(mouth_x + 4, GROUND - 26, 1, "Y2"), (mouth_x + 3, GROUND - 29, 1, "S4")]),
        pose(legs=1.0, lift=4, lean=0.14, glow=1, mouth=2, ball=(mouth_x + 18, GROUND - 26, 1),
             fx=[(mouth_x + 8, GROUND - 27, 1, "S3")]),
        pose(legs=1.0, lift=3, lean=0.05, glow=1, mouth=1),
        pose(legs=0.7, lift=2, glow=0, mouth=1),
    ]


def special():
    # Rocking, it springs up on its legs and fire bursts from its mouth (the spirit leaving),
    # lands and cracks all over.
    return [
        pose(glow=1, mouth=1, dx=1, cracks=0),
        pose(legs=0.7, lift=1, glow=2, mouth=2, squash=1),
        pose(legs=1.0, lift=8, glow=2, mouth=3, dangle=True, fire=4),
        pose(legs=1.0, lift=11, glow=2, mouth=3, dangle=True, fire=12,
             fx=[(CX - 7, GROUND - 46, 1, "Y"), (CX + 6, GROUND - 48, 1, "S4")]),
        pose(legs=1.0, lift=7, glow=1, mouth=3, dangle=True, fire=7, cracks=1,
             fx=[(CX + 4, GROUND - 44, 1, "S3"), (CX - 6, GROUND - 40, 1, "S4")]),
        pose(legs=0.8, lift=1, glow=1, mouth=2, squash=1, cracks=2),
        pose(legs=0.5, lift=0, glow=2, mouth=2, cracks=3),
    ]


def hurt():
    return [
        pose(flash=True),
        pose(lean=-0.12, dx=-1, glow=1, mouth=1),
        pose(lean=-0.06, glow=1),
        pose(),
    ]


# --- death: the pot bursts into shards ----------------------------------------------------------

## Where the pot breaks (seeds of its shards, x from CX, rows above GROUND) and where each shard
## lands: (dx, dy) by the last frame.
SHARDS = [
    ((0, 19), (0, 14)),     # the rim and neck drop onto the pile
    ((-8, 13), (-6, 10)),
    ((8, 13), (7, 10)),
    ((-10, 9), (-8, 5)),
    ((10, 9), (9, 6)),
    ((-4, 8), (-2, 5)),
    ((4, 8), (3, 4)),
    ((-6, 2), (-5, 0)),
    ((6, 2), (6, 0)),
    ((0, 3), (0, 0)),
]


def shard_pieces(cool):
    """The pot cut into shards around SHARDS' seeds; the broken edges show its dark (or still
    burning) inside."""
    pot = draw_pot(pose(cracks=0, glow=2 if cool == 0 else 1 if cool == 1 else 0))
    pieces = [Canvas(CELL) for _ in SHARDS]
    for (x, y), col in pot.px.items():
        h = GROUND - y
        best = min(range(len(SHARDS)), key=lambda i: (x - CX - SHARDS[i][0][0]) ** 2 + (h - SHARDS[i][0][1]) ** 2)
        pieces[best].set(x, y, col)
    inside = ["S2", "S1", "C0", "C0"][cool]
    for piece in pieces:
        # blunt the thin wedges between seeds: they read as spikes, not shards
        for _ in range(2):
            for xy in [xy for xy in piece.px if sum(n in piece.px for n in (
                    (xy[0] + 1, xy[1]), (xy[0] - 1, xy[1]), (xy[0], xy[1] + 1), (xy[0], xy[1] - 1))) <= 1]:
                del piece.px[xy]
        cut = [xy for xy in piece.px if any(n in pot.px and n not in piece.px for n in
                                             ((xy[0] + 1, xy[1]), (xy[0] - 1, xy[1]), (xy[0], xy[1] + 1), (xy[0], xy[1] - 1)))]
        for xy in cut:
            piece.px[xy] = inside
    return pieces


def settled(pieces):
    """Where each shard comes to rest: it slides out by its landing dx and drops until it lies on
    the ground or on the shards under it."""
    placed = set()
    rest = [None] * len(pieces)
    order = sorted(range(len(pieces)), key=lambda i: SHARDS[i][0][1])
    for i in order:
        piece = pieces[i]
        if not piece.px:
            rest[i] = (0, 0)
            continue
        dx = SHARDS[i][1][0]
        lowest = max(y for _, y in piece.px)
        dy = 0
        while lowest + dy < GROUND:
            nxt = [(x + dx, y + dy + 1) for x, y in piece.px]
            if sum(p in placed for p in nxt) > len(nxt) * 0.12:
                break
            dy += 1
        rest[i] = (dx, dy)
        placed.update((x + dx, y + dy) for x, y in piece.px)
    return rest


def shards(t, cool):
    """The shards flying from the pot (t 0) to their resting place (t 1), with a hop."""
    pieces = shard_pieces(cool)
    rest = settled(shard_pieces(0))
    out = Canvas(CELL)
    for i, piece in enumerate(pieces):
        if not piece.px:
            continue
        hop = 4.0 * t * (1.0 - t) * (3 if i else 0)
        moved = piece.shifted(round(rest[i][0] * t), round(rest[i][1] * t - hop))
        out.over(moved)
    return out


def death():
    frames = []
    first = draw_vase(pose(cracks=3, glow=2, mouth=3, squash=1))
    frames.append(first)
    for t, cool, fx in ((0.35, 0, [(CX - 12, GROUND - 26, 1, "Y"), (CX + 13, GROUND - 24, 1, "S4"), (CX + 2, GROUND - 32, 1, "Y")]),
                        (0.7, 1, [(CX - 16, GROUND - 14, 1, "S3"), (CX + 17, GROUND - 12, 1, "S4")]),
                        (1.0, 2, []), (1.0, 3, []), (1.0, 3, [])):
        c = shards(t, cool)
        c.outline()
        add_fx(c, fx)
        frames.append(c)
    # a little smoke over the cold shards in the last frame
    smoke = Canvas(CELL)
    for x, y, col in ((CX - 2, GROUND - 14, "K2"), (CX - 1, GROUND - 14, "K2"), (CX - 1, GROUND - 15, "K1"),
                      (CX + 1, GROUND - 17, "K1"), (CX + 2, GROUND - 18, "K1")):
        smoke.set(x, y, col)
    frames[-1].over(smoke)
    return frames


# --- the spirit -----------------------------------------------------------------------------------

SPIRIT_X, SPIRIT_Y = 18, 16


def spirit(phase=0, squash=0, stretch=0, flash=False, burst=0):
    c = Canvas(SPIRIT_CELL)
    x = SPIRIT_X + stretch * 2 - squash
    if burst == 0:
        fireball(c, x, SPIRIT_Y, 2, phase)
        if squash:
            # gathering: the ball swells up and down, its core white-hot
            for dy in (-6, 6):
                for dx in (-1, 0, 1):
                    c.set(x + dx, SPIRIT_Y + dy * 0.92, "S3")
            c.set(x + 1, SPIRIT_Y - 1, "Y2")
        if stretch:
            # lunging: a streak ahead of the ball and a long thin trail
            for i in range(4):
                c.set(x + 6 + i // 2, SPIRIT_Y - 1 + i % 2, "Y" if i < 2 else "S4")
            for i in range(6):
                c.set(x - 14 - i, SPIRIT_Y + (i % 3) - 1, "S2" if i < 3 else "S1")
    elif burst == 1:
        # it bursts: a ring of flame with a hollow, smoky heart
        for yy in range(SPIRIT_Y - 8, SPIRIT_Y + 9):
            for xx in range(x - 9, x + 9):
                d = math.hypot(xx + 0.5 - x, (yy + 0.5 - SPIRIT_Y) * 1.1)
                if 5.0 < d <= 7.6:
                    c.set(xx, yy, "Y" if d < 6.0 else "S4" if d < 6.9 else "S3")
                elif d <= 2.0:
                    c.set(xx, yy, "K2" if yy < SPIRIT_Y else "K1")
    elif burst == 2:
        for dx, dy, col in ((-7, -5, "S4"), (8, -4, "Y"), (-9, 3, "S3"), (6, 6, "S4"), (0, -9, "S3"),
                            (10, 1, "S3")):
            c.set(x + dx, SPIRIT_Y + dy, col)
        for yy in range(SPIRIT_Y - 4, SPIRIT_Y + 4):
            for xx in range(x - 4, x + 5):
                if in_ellipse(xx, yy, x + 0.5, SPIRIT_Y, 4.2, 3.6):
                    c.set(xx, yy, "K2" if yy < SPIRIT_Y - 1 and xx < x + 2 else "K1")
    else:
        for dx, dy, col in ((-2, -8, "K1"), (-1, -8, "K1"), (0, -9, "K2"), (3, -6, "K1"), (-4, -4, "S3"),
                            (6, -2, "S2")):
            c.set(x + dx, SPIRIT_Y + dy, col)
    if burst < 3:
        c.outline("S0")
    if flash:
        c.remap({k: "W" for k in ("S4", "Y", "Y2", "S3")} | {"S2": "Y", "S1": "S4", "S0": "S3"})
    return c


def spirit_frames():
    return [spirit(phase=i) for i in range(4)] + [
        spirit(phase=0, squash=1),
        spirit(phase=1, stretch=1),
        spirit(phase=2, flash=True),
        spirit(burst=1),
        spirit(burst=2),
        spirit(burst=3),
    ]


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
        strip([draw_vase(p) for p in make()], os.path.join(OUT, "vasija_poseida_%s.png" % name))
    strip(death(), os.path.join(OUT, "vasija_poseida_death.png"))
    strip(spirit_frames(), os.path.join(OUT, "vasija_poseida_spirit.png"))
