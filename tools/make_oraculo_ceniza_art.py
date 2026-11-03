"""Draws the Oráculo de ceniza's art (temple enemy, island 3) pixel by pixel.

The bestiary pack's oracle, scaled down from its 128 px cells, came out blurred, so it is drawn at
the game's own pixel size instead, following the pack's design: a hunched seer in a red-orange robe
with wide sleeves and a gold-trimmed hem, an olive under-robe, a red hood around a pale bone mask,
and a staff crowned with a ball of fire. It is built from a few parts (robe, far sleeve, hood and
mask, near arm, staff and its fire) that each animation moves frame by frame: idle, walk, attack
(it thrusts the staff and a fireball flies off with its trail), special (a seal of fire spreads on
the floor around it, an eye of fire opens over it and shoots a long ray), hurt (a red flash) and
death (it folds into a heap that crumbles to ash around a skull). It also draws the fireball that
falls on Nico, the seal with the eye that marks where it will land, and the burst of the landing.

Writes into `assets/sprites/oraculo_ceniza/`:
    oraculo_ceniza_<animation>.png   64x64 cells, facing right, feet on row 50: idle, walk,
                                     attack, special, hurt, death
    oraculo_ceniza_ball.png          24x24 cells, 4 frames (loop): the falling fireball, its trail
                                     upward, the ball's center at (12, 17)
    oraculo_ceniza_seal.png          48x48 cells: 3 opening, 4 burning (loop); centered, ring
                                     radius 22 (the strike's radius)
    oraculo_ceniza_burst.png         64x64 cells, 6 frames: the landing, centered at (32, 40), its
                                     blast radius 22

    python tools/make_oraculo_ceniza_art.py
Then tools/make_temple_enemy_frames.gd builds its SpriteFrames as for every temple enemy, and
tools/enemy_aseprite.lua keeps an editable `source/oraculo_ceniza.aseprite`
(extras="ball:12,seal:10:open=1-3;burn=4-7,burst:20").
Needs Pillow.
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "oraculo_ceniza")
CELL = 64
## Last row of the feet; its outline goes on the row below.
GROUND = 50
## Center of the body, in cell columns.
CX = 29
## The staff's poses are written from its old length; it is held lower, its fire at the hood's
## height as in the pack (and the figure keeps the height it has in the game).
STAFF_DROP = 4

PALETTE = {
    "O": (24, 9, 12),      # outline
    "D": (46, 14, 18),     # hood's shadow, sleeve openings, eye sockets
    # robe and hood
    "R0": (78, 14, 20),
    "R1": (130, 24, 26),
    "R2": (180, 42, 32),
    "R3": (226, 88, 46),
    "T": (232, 170, 70),   # gold trim
    # under-robe
    "K0": (54, 46, 26),
    "K1": (92, 84, 44),
    "K2": (132, 122, 66),
    # bone mask, hand, skull
    "M0": (128, 104, 78),
    "M1": (204, 184, 140),
    "M2": (242, 230, 194),
    # staff
    "W0": (66, 36, 20),
    "W1": (116, 68, 32),
    "W2": (164, 108, 52),
    # fire
    "F2": (244, 124, 32),
    "F3": (255, 192, 64),
    "F4": (255, 244, 180),
    # ash
    "A0": (60, 52, 54),
    "A1": (102, 92, 88),
    "A2": (154, 144, 134),
}
## Hurt: the whole figure flashes red, as in the pack's sheet.
RED_FLASH = {"D": "R0", "R0": "R1", "R1": "R2", "R2": "R2", "R3": "R3", "T": "R3", "K0": "R0",
             "K1": "R1", "K2": "R2", "M0": "R2", "M1": "R3", "M2": "R3", "W0": "R0", "W1": "R1",
             "W2": "R2", "F2": "R3", "F3": "R3", "F4": "R3"}
## Death: the robe and the trim go grey as they turn to ash.
ASH_STEPS = [
    {"R3": "R2", "T": "R3", "F3": "F2", "F4": "F3", "K2": "K1"},
    {"R3": "A2", "R2": "R1", "R1": "A1", "R0": "A0", "T": "A2", "K2": "A1", "K1": "A1",
     "K0": "A0", "W2": "A1", "W1": "A0", "W0": "A0"},
    {"R2": "A1", "R1": "A1", "R0": "A0", "A2": "A1", "F2": "R1", "F3": "R2"},
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
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    return pixel_perfect([(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n))
                          for i in range(n + 1)])


def shade(l, ramp=("R3", "R2", "R1", "R0"), cuts=(0.5, 0.05, -0.45)):
    for c, cut in zip(ramp, cuts):
        if l > cut:
            return c
    return ramp[-1]


def blob(c, cx, cy, rx, ry, ramp=("R3", "R2", "R1", "R0"), cuts=(0.5, 0.05, -0.45)):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if in_ellipse(x, y, cx, cy, rx, ry):
                c.set(x, y, shade(lit((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry), ramp, cuts))


# --- the oracle --------------------------------------------------------------------------------

def pose(**kw):
    p = dict(bob=0, drop=0, lean=0, sway=0, feet=0, lift=0, base=(9, 0), top=(9, -25), hand=0.45,
             orb=2, phase=0, eye=True, flash=False, ash=0, fx=(), seal=0, seal_glow=1, flames=0,
             sigil=0, ray=0, trail=None)
    p.update(kw)
    return p


def draw_robe(c, p, ys):
    """The bell of the robe, hunched at the back, its hem swaying with the step."""
    bottom = GROUND - 1
    for y in range(ys, bottom + 1):
        t = (y - ys) / max(bottom - ys, 1)
        hump = 1.6 * math.sin(math.pi * min(t * 1.4, 1.0))
        shift = round(p["sway"] * t * t)
        left = round(CX - 4 - 5 * t ** 0.9 - hump) + shift
        right = round(CX + 3 + 4 * t ** 0.9) + shift
        mid, half = (left + right + 1) / 2, (right - left + 1) / 2
        for x in range(left, right + 1):
            u = (x + 0.5 - mid) / half
            # a hanging cloth: lit on its left, the right side (under the arm) in shadow
            c.set(x, y, shade(lit(u * 0.9, 0.1 - 0.35 * (1 - t) ** 3), cuts=(0.3, -0.15, -0.45)))
        # two folds down the skirt, a lit edge beside each
        if t > 0.35:
            for k in (0.3, 0.62):
                fx = round(left + (right - left) * k)
                c.set(fx, y, "R0" if t > 0.6 else "R1")
                c.set(fx - 1, y, "R3" if k < 0.5 else "R2")
        if y == bottom:
            for x in range(left, right + 1):
                c.set(x, y, "T" if (x + p["phase"]) % 5 else "R3")
    return left, right


def draw_oracle(p):
    body = Canvas(CELL)
    ys = GROUND - 16 + p["drop"] + p["bob"]
    # the far sleeve hangs at its back, its dark cuff open toward the floor
    sx, sy = CX - 9 + p["sway"] // 2, ys + 8 + p["drop"] // 3 - p["lift"]
    blob(body, sx, sy, 3.4, 4.6)
    for y in range(sy - 4, sy + 6):
        for x in range(sx - 5, sx + 3):
            if in_ellipse(x, y, sx - 1.6, sy + 2.2, 1.7, 2.3) and (x, y) in body.px:
                body.set(x, y, "D")
    # its cuff: a lit lip around the opening
    for (x, y) in list(body.px):
        if body.px[(x, y)] != "D" and (x + 1, y) in body.px and body.px[(x + 1, y)] == "D"                 and x < sx:
            body.set(x, y, "T")
    # feet peek out under the hem
    back_x, front_x = CX - 3 - p["feet"], CX + 3 + p["feet"]
    if p["drop"] < 6:
        for x in (back_x, back_x + 1):
            body.set(x, GROUND, "W0")
        for x in (front_x, front_x + 1, front_x + 2):
            body.set(x, GROUND, "W1" if x == front_x else "W0")
    draw_robe(body, p, ys)
    # the olive under-robe down its front, tied by a gold cord
    for y in range(ys + 4, GROUND - 1):
        t = (y - ys - 4) / max(GROUND - ys - 6, 1)
        x0 = CX + 1 + round(p["sway"] * t * t)
        x1 = x0 + 2 + (1 if t > 0.5 else 0)
        for x in range(x0, x1 + 1):
            body.set(x, y, "K2" if x == x0 else "K0" if x == x1 else "K1")
    cord = ys + 8
    for x in range(CX, CX + 5):
        body.set(x, cord, "T")
    body.set(CX + 2, cord + 1, "T")
    body.set(CX + 2, cord + 2, "R3")
    # hood: rounded, its peak drooping back, a dark opening around the mask
    hx, hy = CX + 1 + p["lean"], ys - 3
    blob(body, hx, hy, 5.2, 5.5)
    for x, y in ((hx - 4, hy - 5), (hx - 5, hy - 4), (hx - 6, hy - 3)):
        body.set(x, y, "R1" if y > hy - 5 else "R2")
    for y in range(hy - 6, hy + 7):
        for x in range(hx - 1, hx + 7):
            if in_ellipse(x, y, hx + 2.8, hy + 0.9, 3.0, 4.2) and (x, y) in body.px:
                body.set(x, y, "D")
    # the rim of the hood catches the light
    for y in range(hy - 5, hy + 2):
        for x in range(hx - 1, hx + 6):
            if (x, y) in body.px and body.px[(x, y)] != "D" and (x, y + 1) in body.px \
                    and body.px[(x, y + 1)] == "D" and (x - 1, y) in body.px:
                body.set(x, y, "R3")
    # the bone mask, a hooked nose and one dark eye
    mx, my = hx + 2, hy - 2
    mask = {(1, 0): "M2", (2, 0): "M2",
            (0, 1): "M2", (1, 1): "M2", (2, 1): "M1", (3, 1): "M1",
            (0, 2): "M2", (1, 2): "M1", (2, 2): "D", (3, 2): "M1",
            (0, 3): "M1", (1, 3): "M2", (2, 3): "M1", (3, 3): "M2", (4, 3): "M1",
            (0, 4): "M0", (1, 4): "M1", (2, 4): "M1", (3, 4): "M0", (4, 4): "M0",
            (1, 5): "M0", (2, 5): "M0"}
    for (dx, dy), col in mask.items():
        body.set(mx + dx, my + dy, col)
    if p["eye"]:
        body.set(mx + 2, my + 2, "F3")
    # near arm out to the staff, the staff and the bony hand that grips it
    bx, by = CX + p["base"][0], GROUND + p["base"][1]
    tx, ty = CX + p["top"][0], GROUND + p["top"][1] + STAFF_DROP + p["bob"] // 2
    staff = line(bx, by, tx, ty)
    for i, (x, y) in enumerate(staff):
        body.set(x, y, "W2" if i > len(staff) - 3 else "W1")
    body.set(tx - 1, ty - 1, "W2")
    body.set(tx + 1, ty - 1, "W1")
    hand_x = round(tx + (bx - tx) * p["hand"])
    hand_y = round(ty + (by - ty) * p["hand"])
    ax, ay = CX + 3 + p["lean"] // 2, ys + 3
    arm = Canvas(CELL)
    vx, vy = hand_x - 1 - ax, hand_y - ay
    for y in range(min(ay, hand_y) - 3, max(ay, hand_y) + 4):
        for x in range(min(ax, hand_x) - 3, max(ax, hand_x) + 3):
            px_, py_ = x + 0.5, y + 0.5
            t = max(0.0, min(1.0, ((px_ - ax) * vx + (py_ - ay) * vy) / max(vx * vx + vy * vy, 1)))
            qx, qy = ax + vx * t, ay + vy * t
            r = 2.0 + 0.7 * t
            if math.hypot(px_ - qx, py_ - qy) > r:
                continue
            arm.set(x, y, shade(lit((px_ - qx) / r, (py_ - qy) / r)))
    # the cuff at the wrist
    for (x, y) in list(arm.px):
        if abs(x - (hand_x - 2)) == 0:
            arm.set(x, y, "T")
    body.over(arm)
    for (x, y), col in (((hand_x - 1, hand_y), "M2"), ((hand_x, hand_y), "M1"),
                        ((hand_x - 1, hand_y + 1), "M1"), ((hand_x, hand_y + 1), "M0")):
        body.set(x, y, col)
    for step in ASH_STEPS[:p["ash"]]:
        body.remap(step)
    body.outline()
    if p["flash"]:
        body.remap(RED_FLASH)
    if p["orb"]:
        fire = Canvas(CELL)
        fire_ball(fire, tx, ty - 3, p["orb"], p["phase"])
        fire.outline("R0", only_empty_of=body)
        body.over(fire)
    return body


def fire_ball(c, x, y, size, phase, tongue=True):
    """The ball of fire on the staff: white core, a flickering tongue on top."""
    r = {1: 1.6, 2: 2.6, 3: 3.4, 4: 4.4}[size]
    for yy in range(int(y - r) - 1, int(y + r) + 2):
        for xx in range(int(x - r) - 1, int(x + r) + 2):
            d = math.hypot(xx + 0.5 - (x + 0.5), yy + 0.5 - (y + 0.5)) / r
            if d > 1.0:
                continue
            c.set(xx, yy, "F4" if d < 0.38 else "F3" if d < 0.75 else "F2")
    if not tongue:
        return
    lean = (-1, 0, 1, 0)[phase % 4]
    h = size + 1 + (phase % 2)
    top = int(y - r)
    for k in range(h):
        f = k / h
        col = "F3" if f < 0.4 else "F2"
        xx = x + (lean if f > 0.5 else 0)
        c.set(xx, top - k, col)
        if f < 0.35 and size > 1:
            c.set(xx - 1 if lean >= 0 else xx + 1, top - k, "F2")


# --- special: the seal on the floor, the eye and its ray -----------------------------------------

def floor_seal(r, glow, front):
    """The ring of fire on the floor around it, seen flat; `front` keeps only its nearer half."""
    c = Canvas(CELL)
    cx, cy = CX + 1.5, GROUND + 0.5
    ry = r * 0.34
    ring = "F3" if glow else "F2"
    for y in range(int(cy - ry) - 2, int(cy + ry) + 3):
        for x in range(int(cx - r) - 2, int(cx + r) + 3):
            if (y + 0.5 >= cy) != front:
                continue
            q = math.hypot((x + 0.5 - cx) / r, (y + 0.5 - cy) / ry)
            if 0.86 <= q <= 1.0:
                c.set(x, y, ring)
            elif r > 10 and 0.6 <= q <= 0.7 and (x + y) % 3 == 0:
                c.set(x, y, "F2")
    if glow > 1:
        for (x, y) in list(c.px):
            if c.px[(x, y)] == "F3" and (x * 7 + y) % 5 == 0:
                c.px[(x, y)] = "F4"
    return c


def flame_tongue(c, x, ground, h, lean):
    """One tongue of fire rising from the ring, white at its root, orange at its tip."""
    for k in range(h):
        f = k / max(h, 1)
        col = "F4" if f < 0.25 else "F3" if f < 0.6 else "F2"
        width = 2 if f < 0.45 else 1
        xx = x + (lean if f > 0.6 else 0)
        c.set(xx, ground - k, col)
        if width == 2:
            c.set(xx + 1, ground - k, "F3" if col == "F4" else "F2")


def seal_flames(r, height, phase, front):
    c = Canvas(CELL)
    cx, cy = CX + 1.5, GROUND + 0.5
    heights = (1.0, 0.6, 0.85, 0.5, 0.95, 0.7, 0.8)
    for i in range(9):
        a = math.pi * (i + 0.5) / 9 if front else math.pi + math.pi * (i + 0.5) / 9
        x = round(cx + r * math.cos(a))
        y = round(cy + r * 0.34 * math.sin(a))
        h = round(height * heights[(i + phase) % len(heights)] * (0.6 if front else 1.0))
        if h > 0:
            flame_tongue(c, x, y, h, 1 if (i + phase) % 2 else -1)
    return c


def eye_sigil(c, cx, cy, w, h, pupil=True):
    """An upright eye of fire: an almond outline, an iris ring and a white-hot pupil."""
    for x in range(cx - w, cx + w + 1):
        u = (x - cx) / w
        e = round(h * (1 - u * u) ** 0.8)
        c.set(x, cy - e, "F3")
        c.set(x, cy + e, "F3")
        if abs(u) < 0.95 and e >= 2:
            c.set(x, cy - e + 1, "F2")
            c.set(x, cy + e - 1, "F2")
    ir = max(1.5, h * 0.62)
    for y in range(int(cy - ir) - 1, int(cy + ir) + 2):
        for x in range(int(cx - ir) - 1, int(cx + ir) + 2):
            d = math.hypot(x - cx, y - cy) / ir
            if 0.7 <= d <= 1.05:
                c.set(x, y, "F2")
            elif d < 0.7 and pupil:
                c.set(x, y, "F4" if d < 0.45 else "F3")
    if pupil:
        # a dark slit, like a cat's: it reads as an eye even this small
        for dy in (-1, 0, 1):
            c.set(cx, cy + dy, "D")
    # its rays: short strokes past the corners and above and below
    for dx, dy in ((-w - 2, 0), (-w - 3, 0), (w + 2, 0), (w + 3, 0), (0, -h - 2), (0, h + 2)):
        c.set(cx + dx, cy + dy, "F2")


def ray(c, x0, y, length, thick):
    for x in range(x0, min(x0 + length, CELL)):
        c.set(x, y, "F4")
        if thick > 1:
            c.set(x, y - 1, "F3")
            c.set(x, y + 1, "F3" if x < x0 + length - 2 else "F2")
        if thick > 2:
            c.set(x, y - 2, "F2")
            c.set(x, y + 2, "F2")


def draw_frame(p):
    body = draw_oracle(p)
    out = Canvas(CELL)
    if p["seal"]:
        back = floor_seal(p["seal"], p["seal_glow"], False)
        if p["flames"]:
            back.over(seal_flames(p["seal"], p["flames"], p["phase"], False))
        back.outline("R0")
        out.over(back)
    out.over(body)
    if p["seal"]:
        front = floor_seal(p["seal"], p["seal_glow"], True)
        if p["flames"]:
            front.over(seal_flames(p["seal"], p["flames"], p["phase"] + 2, True))
        front.outline("R0", only_empty_of=body)
        out.over(front)
    if p["sigil"]:
        s = Canvas(CELL)
        w, h = {1: (5, 2), 2: (11, 5), 3: (13, 6)}[p["sigil"]]
        eye_sigil(s, CX + 3, GROUND - 15, w, h)
        s.outline("R0")
        out.over(s)
    if p["ray"]:
        r = Canvas(CELL)
        x0, y, length, thick = p["ray"]
        ray(r, x0, y, length, thick)
        r.outline("R0", only_empty_of=out)
        out.over(r)
    if p["trail"]:
        t = Canvas(CELL)
        x, y, length = p["trail"]
        flying_ball(t, x, y, length)
        t.outline("R0", only_empty_of=out)
        out.over(t)
    add_fx(out, p["fx"])
    return out


def flying_ball(c, x, y, length):
    """The fireball thrown forward: a round head and a tapering trail behind it."""
    for k in range(length):
        xx = x - 3 - k
        f = k / max(length, 1)
        c.set(xx, y, "F3" if f < 0.5 else "F2")
        if f < 0.55:
            c.set(xx, y - 1, "F2")
        if f < 0.3:
            c.set(xx, y + 1, "F2")
    # the flame of a flying ball streams back along its trail, not up
    fire_ball(c, x, y, 3, 1, tongue=False)


def add_fx(canvas, fx):
    """Sparks and embers: (x, y, color), one pixel each, outlined where they touch nothing."""
    if not fx:
        return
    sparks = Canvas(canvas.size)
    for x, y, col in fx:
        sparks.set(x, y, col)
    canvas.over(sparks)


# --- the heap it leaves --------------------------------------------------------------------------

SKULL = ["_222_",
         "22221",
         "2DD1D",
         "1DD1D",
         "_11D0",
         "_0101"]


def skull(c, x, y, cracked=False):
    for dy, row in enumerate(SKULL):
        for dx, ch in enumerate(row):
            if ch != "_":
                c.set(x + dx, y + dy, "D" if ch == "D" else "M" + ch)
    if cracked:
        c.set(x + 2, y, "M0")
        c.set(x + 2, y + 1, "M1")


def heap(rx, ry, ash, face=None, hood=True, staff=True, embers=0):
    """What is left of it: a mound of robe (its hood still on top, the mask or the bare skull at its
    front) that crumbles to grey ash, and the staff lying behind."""
    c = Canvas(CELL)
    cx = CX + 0.5
    if staff:
        for (x, y) in line(CX - 14, GROUND - 1, CX + 13, GROUND - 4):
            c.set(x, y, "W1")
        c.set(CX + 14, GROUND - 5, "W2")
    for y in range(GROUND - int(ry) - 1, GROUND + 1):
        for x in range(int(cx - rx) - 2, int(cx + rx) + 3):
            # a lumpy mound
            lump = 1.0 + 0.07 * math.sin(x * 1.3) + 0.05 * math.sin(x * 0.7 + 1.0)
            if not in_ellipse(x, y, cx, GROUND + 0.5, rx * lump, ry + 0.5):
                continue
            c.set(x, y, shade(lit((x + 0.5 - cx) / rx, (y + 0.5 - GROUND) / (ry + 0.5))))
    # folds of the fallen robe and its gold hem along the floor
    for k in (-0.45, 0.1, 0.5):
        x = round(cx + rx * k)
        for y in range(GROUND - int(ry * (1 - k * k)) + 2, GROUND):
            if (x, y) in c.px:
                c.set(x, y, "R0")
                c.set(x - 1, y, "R3")
    for x in range(int(cx - rx) + 1, int(cx + rx)):
        if (x, GROUND) in c.px and x % 4:
            c.set(x, GROUND, "T")
    hx, hy = round(cx + rx * 0.35), GROUND - int(ry) + 1
    if hood:
        blob(c, hx, hy, 4.2, 3.8)
        for y in range(hy - 4, hy + 4):
            for x in range(hx, hx + 6):
                if in_ellipse(x, y, hx + 2.2, hy + 0.6, 2.4, 3.0) and (x, y) in c.px:
                    c.set(x, y, "D")
    else:
        for x in range(int(cx) + 2, int(cx) + 5):
            c.set(x, GROUND - 1, "K1")
    for step in ASH_STEPS[:ash]:
        c.remap(step)
    if ash:
        # grey speckles: the cloth turning to ash
        for (x, y) in list(c.px):
            h = (x * 73856093 ^ y * 19349663) % 29
            if h < 3 + 3 * ash:
                c.px[(x, y)] = "A2" if h % 2 else "A1"
    if face == "mask":
        for (dx, dy), col in {(0, 0): "M2", (1, 0): "M2", (0, 1): "M2", (1, 1): "D", (2, 1): "M1",
                              (0, 2): "M1", (1, 2): "M1", (2, 2): "M1", (3, 2): "M0",
                              (1, 3): "M0"}.items():
            c.set(hx + 1 + dx, hy - 2 + dy, col)
    elif face == "skull":
        skull(c, hx, hy - 3)
    c.outline()
    for i in range(embers):
        x = int(cx - rx + 2 + (i * 7) % int(2 * rx - 3))
        y = GROUND - 1 - (i * 3) % max(int(ry) - 1, 1)
        if (x, y) in c.px and c.px[(x, y)] != "O":
            c.px[(x, y)] = "F3" if i % 2 else "F2"
    return c


# --- animations -----------------------------------------------------------------------------

def idle():
    bob = [0, 0, 1, 1, 1, 0]
    return [pose(bob=bob[i], phase=i) for i in range(6)]


def walk():
    # A hunched shuffle: the body dips on each step, the hem swings, the feet trade places and the
    # staff is planted ahead and dragged.
    bob = [0, 1, 1, 0, 1, 1, 0, 0]
    sway = [0, -1, -2, -1, 0, 1, 2, 1]
    feet = [0, 1, 1, 0, -1, -1, 0, 0]
    base = [9, 10, 10, 10, 9, 8, 8, 9]
    lift = [0, 0, 0, -1, -1, 0, 0, 0]
    return [pose(bob=bob[i], sway=sway[i], feet=feet[i], base=(base[i], lift[i]),
                 top=(9 + (base[i] - 9) // 2, -25 + lift[i]), phase=i) for i in range(8)]


def attack():
    # Played as the fireball leaves: it rears back gathering fire, thrusts the staff and the ball
    # flies off with its trail, then it settles.
    return [draw_frame(p) for p in (
        pose(lean=-1, base=(8, 0), top=(7, -26), orb=3, phase=0),
        pose(lean=-1, base=(7, 0), top=(5, -27), orb=4, phase=1, lift=1,
             fx=[(CX + 9, GROUND - 28, "F3"), (CX + 2, GROUND - 27, "F2")]),
        pose(lean=2, base=(8, 0), top=(15, -21), hand=0.5, orb=0, phase=2,
             trail=(CX + 20, GROUND - 20, 4)),
        pose(lean=2, base=(8, 0), top=(15, -21), hand=0.5, orb=1, phase=3,
             trail=(CX + 28, GROUND - 21, 9)),
        pose(lean=1, base=(8, 0), top=(13, -23), hand=0.5, orb=1, phase=0,
             fx=[(CX + 17, GROUND - 18, "F2"), (CX + 24, GROUND - 21, "F3"), (CX + 27, GROUND - 21, "F2"),
                 (CX + 30, GROUND - 22, "F2"), (CX + 32, GROUND - 20, "R3")]),
        pose(lean=1, base=(9, 0), top=(11, -24), orb=2, phase=1, fx=[(CX + 30, GROUND - 22, "F2")]),
        pose(phase=2),
    )]


def special():
    # The seal: a ring of fire spreads on the floor around it, flames rise from it, an eye of fire
    # opens over it and shoots a long ray toward its prey (where the mark will appear).
    staff_up = dict(base=(9, -2), top=(10, -28), hand=0.4)
    return [draw_frame(p) for p in (
        pose(orb=3, phase=0, seal=7, seal_glow=1, lift=1, **staff_up),
        pose(orb=3, phase=1, seal=13, seal_glow=1, lift=2, **staff_up),
        pose(orb=4, phase=2, seal=19, seal_glow=2, flames=5, lift=2, **staff_up),
        pose(orb=4, phase=3, seal=22, seal_glow=2, flames=9, lift=2, sigil=1, **staff_up),
        pose(orb=4, phase=0, seal=22, seal_glow=2, flames=11, lift=2, sigil=3, **staff_up),
        pose(orb=3, phase=1, seal=22, seal_glow=1, flames=6, lift=1, sigil=1, lean=1,
             ray=(CX + 14, GROUND - 27, 26, 3), **staff_up),
        pose(orb=2, phase=2, seal=22, seal_glow=0, flames=2, lean=1,
             ray=(CX + 13, GROUND - 27, 34, 1), **staff_up),
    )]


def hurt():
    return [
        pose(lean=-1, base=(8, 0), top=(7, -24), phase=0),
        pose(flash=True, lean=-2, drop=1, base=(8, 0), top=(6, -23), orb=1, eye=False, phase=1),
        pose(lean=-1, drop=1, base=(8, 0), top=(7, -24), orb=1, phase=2),
        pose(phase=3),
    ]


def death():
    # It reels, drops its staff and folds into a heap of robe that crumbles to ash around its skull.
    frames = [
        draw_frame(pose(lean=-2, drop=1, base=(8, 0), top=(5, -24), orb=1, eye=False, phase=0)),
        draw_frame(pose(lean=-1, drop=4, base=(10, 0), top=(20, -18), hand=0.7, orb=1,
                        eye=False, phase=1, ash=1)),
    ]
    frames.append(heap(10, 9, 0, face="mask"))
    frames.append(heap(11, 8, 1, face="skull", embers=4))
    frames.append(heap(12, 7, 2, face="skull", embers=6))
    frames.append(heap(13, 6, 3, face="skull", hood=False, embers=3))
    frames.append(heap(13, 5, 3, face="skull", hood=False))
    # embers rising off the ash in the middle frames
    for i, pts in ((3, [(CX - 3, GROUND - 12, "F2"), (CX + 7, GROUND - 14, "F3")]),
                   (4, [(CX - 5, GROUND - 15, "F2"), (CX + 9, GROUND - 18, "R3")])):
        add_fx(frames[i], pts)
    return frames


# --- effects --------------------------------------------------------------------------------

BALL_CELL = 24
SEAL_CELL = 48
BURST_CELL = 64


def ball():
    """The fireball falling on Nico: round head at (12, 17), its flames streaming up."""
    frames = []
    for i in range(4):
        c = Canvas(BALL_CELL)
        cx, cy = 12, 17
        # trail: three tongues streaming up, flickering
        for k, (dx, h) in enumerate(((-2, 9), (0, 13), (2, 8))):
            h = h + (1 if (i + k) % 2 else -1)
            for j in range(h):
                f = j / h
                x = cx + dx + (((i + j // 3 + k) % 3) - 1 if f > 0.5 else 0)
                c.set(x, cy - 3 - j, "F3" if f < 0.35 else "F2" if f < 0.75 else "R2")
                if f < 0.5:
                    c.set(x + 1, cy - 3 - j, "F2")
        r = 4.6
        for y in range(cy - 6, cy + 6):
            for x in range(cx - 6, cx + 6):
                d = math.hypot(x + 0.5 - (cx + 0.5), y + 0.5 - (cy + 0.5)) / r
                if d <= 1.0:
                    l = lit((x + 0.5 - cx - 0.5) / r, (y + 0.5 - cy - 0.5) / r)
                    c.set(x, y, "F4" if d < 0.4 or (d < 0.6 and l > 0.2) else "F3" if d < 0.8 else "F2")
        c.outline("R0")
        if i % 2:
            c.set(cx - 5, cy - 9, "F3")
        else:
            c.set(cx + 5, cy - 11, "F2")
        frames.append(c)
    return frames


def eye_ring(c, cx, cy, r, glow, eye_open, runes_phase):
    """The seal on the floor: a double ring of fire with rune marks between, an eye in the middle."""
    for y in range(SEAL_CELL):
        for x in range(SEAL_CELL):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if r - 1.5 <= d <= r:
                c.set(x, y, "F3" if glow else "F2")
            elif r - 2.5 <= d < r - 1.5:
                c.set(x, y, "R1")
            elif r > 12 and r - 7.0 <= d <= r - 6.0:
                c.set(x, y, "F2")
    # runes: short ticks between the rings, every eighth of a turn
    if r > 12:
        for k in range(8):
            a = k * math.tau / 8 + runes_phase * 0.12
            for t in (r - 3.5, r - 4.5):
                c.set(round(cx - 0.5 + t * math.cos(a)), round(cy - 0.5 + t * math.sin(a)),
                      "F4" if glow > 1 and k % 2 == 0 else "F3")
    if eye_open:
        w, h = round(min(r * 0.62, 10) * eye_open), max(1, round(min(r * 0.32, 5) * eye_open))
        e = Canvas(SEAL_CELL)
        for x in range(-w, w + 1):
            u = x / max(w, 1)
            yy = round(h * (1 - u * u) ** 0.8)
            e.set(int(cx) + x - 1 if x < 0 else int(cx) + x, int(cy) - yy, "F3")
            e.set(int(cx) + x - 1 if x < 0 else int(cx) + x, int(cy) + yy - 1, "F3")
        if h >= 3:
            for y in range(int(cy) - 3, int(cy) + 3):
                for x in range(int(cx) - 3, int(cx) + 3):
                    d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                    if d <= 2.9:
                        e.set(x, y, "F4" if d < 1.2 else "R2" if d < 2.0 else "F2")
        c.over(e)


def seal():
    """The mark on the floor where the fireball will fall: it opens (ring, runes, eye) and then
    burns, its runes turning and its eye flaring."""
    frames = []
    cx = cy = SEAL_CELL / 2
    for i, (r, eye) in enumerate(((10, 0), (17, 0.5), (22, 1.0))):
        c = Canvas(SEAL_CELL)
        eye_ring(c, cx, cy, r, 1, eye, i)
        c.outline("R0")
        frames.append(c)
    for i in range(4):
        c = Canvas(SEAL_CELL)
        eye_ring(c, cx, cy, 22, 2 if i % 2 == 0 else 1, 1.0, 3 + i)
        # small flames licking up from the rim, moving round from frame to frame
        for k in range(6):
            a = math.pi + math.pi * (k + 0.5 + i * 0.5) / 6
            x = round(cx - 0.5 + 21.5 * math.cos(a))
            y = round(cy - 0.5 + 21.5 * math.sin(a))
            h = (2, 3, 1, 3, 2, 1)[(k + i) % 6]
            for j in range(h):
                c.set(x, y - j - 1, "F3" if j < h - 1 else "F2")
        c.outline("R0")
        frames.append(c)
    return frames


def burst():
    """The landing: a white flash where the ball hits, a wave of fire that fills the seal's circle
    (radius 22, as the strike) with flames around its rim, then the floor cools to a scorched ring."""
    frames = []
    cx, cy = 32, 40
    heights = (1.0, 0.55, 0.8, 0.45, 0.9, 0.6, 0.75, 0.5, 0.95, 0.65, 0.7, 0.5)
    # (radius of the blast, rim flames height, floor stage)
    plan = ((9, 3, 0), (17, 7, 1), (22, 11, 2), (22, 8, 3), (22, 4, 4), (22, 0, 5))
    for i, (r, ring_h, stage) in enumerate(plan):
        c = Canvas(BURST_CELL)
        for y in range(cy - r - 1, cy + r + 2):
            for x in range(cx - r - 1, cx + r + 2):
                q = math.hypot(x + 0.5 - cx, y + 0.5 - cy) / r
                if q > 1.0:
                    continue
                # scatter without stripes
                h = (x * 73856093 ^ y * 19349663) % 7
                if stage == 0:
                    col = "F4" if q < 0.5 else "F3" if q < 0.8 else "F2"
                elif stage == 1:
                    col = "F3" if q < 0.3 else "F2" if q < 0.6 else "F3" if q < 0.85 else "F4"
                elif stage == 2:
                    if q < 0.55:
                        col = "F2" if h == 0 else "R1" if h < 3 else "R2"
                        c.set(x, y, col)
                        continue
                    col = "R2" if q < 0.7 else "F2" if q < 0.82 else "F3" if q < 0.93 else "F4"
                elif stage == 3:
                    if q < 0.8:
                        continue
                    col = "R2" if q < 0.88 else "F2"
                elif stage == 4:
                    if q < 0.86:
                        continue
                    col = "R2" if h < 2 else "R1"
                else:
                    if q < 0.9 or h < 2:
                        continue
                    col = "R1"
                c.set(x, y, col)
        # flames around the rim, taller at the back
        for k in range(12):
            a = math.tau * (k + 0.5) / 12
            x = round(cx + r * 0.93 * math.cos(a))
            y = round(cy + r * 0.93 * math.sin(a))
            h = round(ring_h * heights[(k + i) % len(heights)] * (1.0 if math.sin(a) < 0 else 0.6))
            if h > 0:
                flame_tongue(c, x, y, h, 1 if (k + i) % 2 else -1)
        c.outline("R0")
        if 1 <= i <= 3:
            for k in range(7):
                a = k * 0.9 + i
                c.set(round(cx + (10 + i * 4) * math.cos(a)), round(cy - 8 - (5 + i * 4) * abs(math.sin(a))),
                      "F3" if k % 2 else "F2")
        frames.append(c)
    return frames


def strip(frames, path):
    cell = frames[0].size
    img = Image.new("RGBA", (cell * len(frames), cell), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        img.alpha_composite(f.image(), (i * cell, 0))
    img.save(path)
    print(os.path.relpath(path), len(frames), "frames")


if __name__ == "__main__":
    for name, make in (("idle", idle), ("walk", walk), ("hurt", hurt)):
        strip([draw_frame(p) for p in make()], os.path.join(OUT, "oraculo_ceniza_%s.png" % name))
    strip(attack(), os.path.join(OUT, "oraculo_ceniza_attack.png"))
    strip(special(), os.path.join(OUT, "oraculo_ceniza_special.png"))
    strip(death(), os.path.join(OUT, "oraculo_ceniza_death.png"))
    strip(ball(), os.path.join(OUT, "oraculo_ceniza_ball.png"))
    strip(seal(), os.path.join(OUT, "oraculo_ceniza_seal.png"))
    strip(burst(), os.path.join(OUT, "oraculo_ceniza_burst.png"))
