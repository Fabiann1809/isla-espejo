"""Draws the Manos del abismo's art (temple enemy, island 3) pixel by pixel.

The pack's hand, scaled from 128 px down to the game, came out blurred, so it is drawn at the game's
own pixel size instead, following the pack's design: a hand of dark red molten stone with glowing
lava in its cracks and joints and clawed fingers, coming out of a splash of lava. It is built from
parts that each animation moves: the forearm, the palm, four fingers of two joints and a thumb
(each pose says how far they curl and spread and how much the hand leans), and the splash at its
base. Animations, as in the pack's sheet: idle (it flexes its fingers), walk (it leans and slides
through the lava), attack (it opens wide, lunges and clenches: no splash, the arm the game draws
joins its wrist), special (it emerges from a pool; the game plays it backwards when it sinks), hurt,
and death (it clenches and sinks into the lava, which crusts over).

It also draws what the game used to draw with shapes (scripts/enemies/manos_abismo.gd): the warning
circle of its grab, the molten pool its arm comes out of and the arm itself.

Writes into `assets/sprites/manos_abismo/`:
    manos_abismo_<animation>.png   64x64 cells, facing right, the splash's last row on row 52:
                                   idle, walk, attack, special, hurt, death
    manos_abismo_warning.png       32x32 cells, 8 frames spread over the warning: a ring of radius 14
                                   (the grab's `warning_radius`) whose cracks glow toward its center
    manos_abismo_pool.png          32x32 cells, 6 frames looping at 5 fps: the pool (radius 11,
                                   squashed to half its height as the game drew it)
    manos_abismo_arm.png           16x9: one tile of the arm, repeated along its Line2D (9 px wide:
                                   the old arm plus its glowing edge)

    python tools/make_manos_abismo_art.py
Then tools/make_temple_enemy_frames.gd builds its SpriteFrames as for every temple enemy, and
tools/enemy_aseprite.lua keeps an editable `source/manos_abismo.aseprite`
(extras="warning:10,pool:5").
Needs Pillow.
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "manos_abismo")
CELL = 64
FX_CELL = 32
## Last row of the lava splash the hand comes out of; its outline goes on the row below.
GROUND = 52
CX = 31.0
## The arm the game draws meets the hand here (hand_offset (0, -10) with the feet 6 px below the
## origin): the wrist of the attack frames sits on it.
ARM_JOINT = (32, GROUND - 16)

PALETTE = {
    "O": (24, 8, 8),        # outline
    # molten stone
    "R0": (44, 14, 14),
    "R1": (80, 24, 20),
    "R2": (134, 42, 28),
    "R3": (178, 68, 38),
    "R4": (220, 110, 60),
    # lava
    "S0": (70, 12, 10),
    "S1": (138, 32, 16),
    "S2": (204, 70, 22),
    "S3": (244, 128, 30),
    "S4": (255, 186, 60),
    "Y": (255, 226, 112),
    "Y2": (255, 250, 206),
    # crust (cooled lava)
    "K0": (42, 26, 24),
    "K1": (70, 44, 38),
    "W": (255, 240, 226),   # hurt flash
}
FLASH = {"R0": "R2", "R1": "R3", "R2": "R4", "R3": "W", "R4": "W", "S1": "S3", "S2": "S4", "S3": "Y",
         "S4": "Y2", "Y": "W", "Y2": "W"}
## Death: the lava cools and the stone darkens.
COOL_STEPS = [
    {"Y2": "Y", "Y": "S4", "S4": "S3", "R4": "R3"},
    {"Y": "S3", "S4": "S2", "S3": "S2", "R3": "R2"},
    {"S3": "S1", "S2": "S1", "S1": "K1", "Y": "S2", "R2": "R1"},
]

## Fingers, index to little: knuckle on the palm (from its center), angle from straight up (deg,
## + leans forward), length of the two joints.
FINGERS = [
    ((3.5, -3.5), 22, (4.0, 3.4)),
    ((1.2, -5.0), 7, (4.4, 3.8)),
    ((-1.4, -5.0), -7, (4.4, 3.4)),
    ((-3.8, -3.6), -22, (3.4, 3.0)),
]
THUMB = ((4.8, 0.5), 70, (3.0, 2.8))


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

    def image(self, w=None, h=None):
        img = Image.new("RGBA", (w or self.size, h or self.size), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            if x < img.width and y < img.height:
                img.putpixel((x, y), PALETTE[c] + (255,))
        return img


def in_ellipse(x, y, cx, cy, rx, ry):
    return ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0


def lit(nx, ny):
    """How much a surface with normal (nx, ny) faces the light (upper left)."""
    return -0.55 * nx - 0.8 * ny


def rock(l):
    return "R4" if l > 0.6 else "R3" if l > 0.2 else "R2" if l > -0.3 else "R1"


def capsule(c, a, b, ra, rb, shade=rock):
    """A thick segment from a (radius ra) to b (radius rb), shaded by its light."""
    ax, ay = a
    bx, by = b
    vx, vy = bx - ax, by - ay
    ll = vx * vx + vy * vy or 1.0
    r = max(ra, rb)
    for y in range(int(min(ay, by) - r) - 1, int(max(ay, by) + r) + 2):
        for x in range(int(min(ax, bx) - r) - 1, int(max(ax, bx) + r) + 2):
            px_, py_ = x + 0.5, y + 0.5
            t = max(0.0, min(1.0, ((px_ - ax) * vx + (py_ - ay) * vy) / ll))
            qx, qy = ax + vx * t, ay + vy * t
            rr = ra + (rb - ra) * t
            d = math.hypot(px_ - qx, py_ - qy)
            if d <= rr:
                c.set(x, y, shade(lit((px_ - qx) / max(rr, 0.1), (py_ - qy) / max(rr, 0.1))))


def rotate(p, center, deg):
    a = math.radians(deg)
    dx, dy = p[0] - center[0], p[1] - center[1]
    return (center[0] + dx * math.cos(a) - dy * math.sin(a), center[1] + dx * math.sin(a) + dy * math.cos(a))


def pixel_perfect(pts):
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


# --- the hand ----------------------------------------------------------------------------------

def pose(**kw):
    p = dict(curl=0.4, spread=1.0, tilt=0.0, sink=0, arm=True, splash=1, pool=17.0, phase=0,
             glow=1, flash=False, cool=0, fx=(), dx=0, dy=0, trail=False)
    p.update(kw)
    return p


def draw_hand(p):
    """Forearm, palm, fingers and thumb, standing out of the ground (before sinking)."""
    c = Canvas(CELL)
    base = (CX - 1, GROUND + 1)
    wrist = (CX + 0.5, GROUND - 10)
    palm = (CX + 1.5, GROUND - 16)
    if not p["arm"]:
        # attack: only a stump of forearm under the wrist, where the game's arm joins it
        wrist = (ARM_JOINT[0], ARM_JOINT[1] + 1)
        palm = (wrist[0] + 1, wrist[1] - 5)
        base = (wrist[0] - 2.5, wrist[1] + 5)
    tilt = p["tilt"]
    rot = lambda q: rotate(q, wrist, tilt)
    palm = rot(palm)
    # forearm: thick at the ground, a lava seam along it
    capsule(c, base, wrist, 4.6, 3.6)
    seam = polyline([(round(base[0] + 1), round(base[1] - 2)), (round(wrist[0] + 1), round(wrist[1] + 2))])
    glow = ["S2", "S3", "S4"][min(p["glow"], 2)]
    for i, (x, y) in enumerate(seam):
        if (x, y) in c.px and i % 6 < 4:
            c.set(x, y, glow if i % 6 in (1, 2) else "S2")
    # palm
    for y in range(int(palm[1]) - 7, int(palm[1]) + 8):
        for x in range(int(palm[0]) - 7, int(palm[0]) + 8):
            if in_ellipse(x, y, palm[0], palm[1], 5.6, 5.4):
                c.set(x, y, rock(lit((x + 0.5 - palm[0]) / 5.6, (y + 0.5 - palm[1]) / 5.4)))
    # cracks from the wrist toward the knuckles
    for kx in (-2, 3):
        for i, (x, y) in enumerate(polyline([(round(palm[0]), round(palm[1] + 3)), (round(palm[0] + kx), round(palm[1] - 3))])):
            if (x, y) in c.px and i < 5:
                c.set(x, y, "S2" if i in (0, 4) else glow)
    # a glowing line across the palm
    for x in range(int(palm[0]) - 3, int(palm[0]) + 3):
        c.set(x, int(palm[1]) + (1 if x < palm[0] - 1 else 0), "S2" if x % 2 else glow)
    # fingers: two joints, curling forward and down; glowing knuckles
    curl, spread = p["curl"], p["spread"]
    tips = []
    for (kx, ky), angle, (l1, l2) in FINGERS + [THUMB]:
        is_thumb = angle == THUMB[1]
        k = (palm[0] + kx * spread ** 0.5, palm[1] + ky)
        k = rotate(k, palm, 0)
        a1 = angle * spread + tilt + curl * (25 if not is_thumb else 10)
        a2 = a1 + curl * (75 if not is_thumb else 40)
        j = (k[0] + l1 * math.sin(math.radians(a1)), k[1] - l1 * math.cos(math.radians(a1)))
        t = (j[0] + l2 * math.sin(math.radians(a2)), j[1] - l2 * math.cos(math.radians(a2)))
        capsule(c, k, j, 1.7, 1.5)
        capsule(c, j, t, 1.5, 0.9)
        c.set(round(j[0] - 0.5), round(j[1] - 0.5), "S3" if p["glow"] else "S2")
        tips.append(t)
    for (x, y) in tips:
        # claw tips: pale and sharp
        c.set(round(x - 0.5), round(y - 0.5), "R4")
    return c


def splash(p, under):
    """The lava splash at its base: a puddle and tongues of lava leaping around the forearm."""
    back, front = Canvas(CELL), Canvas(CELL)
    rx = p["pool"]
    if rx <= 0:
        return back, front
    ry = max(2.0, rx * 0.24)
    for y in range(int(GROUND - ry) - 1, GROUND + 2):
        for x in range(int(CX - rx) - 1, int(CX + rx) + 2):
            if not in_ellipse(x, y, CX + 0.5, GROUND - ry + 1.5, rx, ry):
                continue
            q = math.hypot((x + 0.5 - CX - 0.5) / rx, (y - GROUND + ry - 1.5) / ry)
            col = "S1" if q > 0.85 else "S2" if q > 0.62 else "S3" if q > 0.3 else "S4"
            (back if y < GROUND - ry + 1 else front).set(x, y, col)
    level = p["splash"]
    if level:
        ph = p["phase"]
        heights = [3, 5, 2, 4, 6, 3, 4]
        xs = [-15, -10, -5, 5, 10, 15, -2]
        for i, x in enumerate(xs):
            h = int(round(heights[(i + ph) % len(heights)] * level * 0.8))
            if h < 1:
                continue
            lean = -1 if x < 0 else 1
            target = front if i % 2 else back
            for k in range(h):
                f = k / max(h, 1)
                xx = CX + x + (lean if f > 0.6 else 0)
                col = "Y" if f < 0.3 else "S4" if f < 0.6 else "S3"
                target.set(xx, GROUND - 1 - k, col)
                if f < 0.4:
                    target.set(xx + lean, GROUND - 1 - k, "S3")
            if level >= 2:
                target.set(CX + x + lean * 2, GROUND - h - 2 - (i % 2), "S4")
    return back, front


def draw_abyss_hand(p):
    hand = draw_hand(p)
    if p["arm"]:
        # the forearm comes out of the lava: nothing of it shows under the splash's surface
        hand.px = {xy: c for xy, c in hand.px.items() if xy[1] <= GROUND - 2}
    if p["sink"]:
        hand = hand.shifted(0, p["sink"])
        hand.px = {xy: c for xy, c in hand.px.items() if xy[1] <= GROUND - 2}
    for step in COOL_STEPS[:p["cool"]]:
        hand.remap(step)
    hand = hand.shifted(p["dx"], p["dy"])
    if p["arm"]:
        back, front = splash(p, hand)
        for step in COOL_STEPS[:p["cool"]]:
            back.remap(step)
            front.remap(step)
        back.over(hand)
        back.over(front)
        hand = back
    else:
        # lava drips from the stump
        for x, y, col in ((ARM_JOINT[0] - 3, ARM_JOINT[1] + 8, "S3"), (ARM_JOINT[0] - 1, ARM_JOINT[1] + 9, "S4")):
            hand.set(x + p["dx"], y + p["dy"] + (p["phase"] % 2), col)
    if p["trail"]:
        # sliding: a smear of lava left behind
        for x in range(int(CX - 22), int(CX - 12)):
            hand.set(x, GROUND, "S2" if x % 3 else "S3")
            if x > CX - 18:
                hand.set(x, GROUND - 1, "S3")
    hand.outline()
    if p["flash"]:
        hand.remap(FLASH)
    add_fx(hand, p["fx"])
    return hand


def add_fx(canvas, fx):
    """Lava drops: (x, y, size, color); size 1 is one pixel, 2 a 2x2 drop."""
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


def arc_drops(x0, y0, x1, y1, n, hot=True):
    """Drops along an arc of lava flung from (x0, y0) to (x1, y1)."""
    out = []
    for i in range(n):
        t = i / max(n - 1, 1)
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t - math.sin(t * math.pi) * 5
        out.append((round(x), round(y), 2 if i == n - 1 else 1, "Y" if hot and i == n - 1 else "S4" if i % 2 else "S3"))
    return out


# --- animations --------------------------------------------------------------------------------

def idle():
    curl = [0.3, 0.45, 0.65, 0.75, 0.6, 0.4]
    return [pose(curl=curl[i], phase=i, glow=1 + (i in (2, 3)), tilt=[0, 0, 2, 3, 2, 0][i]) for i in range(6)]


def walk():
    # it leans forward and slides through the lava, leaving a smear
    return [pose(tilt=24 + (i % 2) * 4, curl=0.5 + 0.1 * (i % 3), dx=(i % 2), phase=i, trail=True,
                 pool=11.0, splash=1) for i in range(6)]


def attack():
    # coils, opens wide, lunges and clenches: the last frame is the grip it holds
    j = ARM_JOINT
    return [
        pose(arm=False, tilt=-18, curl=0.5),
        pose(arm=False, tilt=6, curl=0.0, spread=1.35),
        pose(arm=False, tilt=28, curl=0.0, spread=1.4, fx=arc_drops(j[0] - 8, j[1] + 4, j[0] - 16, j[1] + 10, 3)),
        pose(arm=False, tilt=34, curl=0.75, spread=1.1, fx=arc_drops(j[0] + 10, j[1] - 14, j[0] + 18, j[1] - 6, 3)),
        pose(arm=False, tilt=30, curl=1.35, spread=0.85, fx=arc_drops(j[0] + 12, j[1] - 10, j[0] + 20, j[1] - 2, 4)
             + [(j[0] - 10, j[1] - 12, 1, "S4")]),
        pose(arm=False, tilt=24, curl=1.4, spread=0.8, fx=[(j[0] + 21, j[1] + 2, 1, "S3")]),
        pose(arm=False, tilt=20, curl=1.35, spread=0.8),
    ]


def special():
    # a pool spreads, the fingers break its surface and the hand rises in a burst of lava
    return [
        pose(sink=40, pool=6.0, splash=0, phase=0),
        pose(sink=40, pool=10.0, splash=1, phase=1),
        pose(sink=20, pool=17.0, splash=1, curl=0.8, phase=2),
        pose(sink=12, pool=18.0, splash=2, curl=0.6, phase=3, fx=[(CX - 13, GROUND - 14, 1, "S4"), (CX + 14, GROUND - 12, 1, "Y")]),
        pose(sink=6, pool=18.0, splash=2, curl=0.3, phase=4, fx=[(CX - 15, GROUND - 18, 2, "S4"), (CX + 16, GROUND - 16, 1, "S3")]),
        pose(sink=2, pool=18.0, splash=2, curl=0.0, spread=1.3, phase=5, fx=[(CX - 16, GROUND - 10, 1, "S3")]),
        pose(sink=0, pool=17.0, splash=1, curl=0.1, spread=1.2, phase=6),
        pose(sink=0, pool=17.0, splash=1, curl=0.35, phase=0),
    ]


def hurt():
    return [
        pose(flash=True, curl=0.6),
        pose(tilt=-14, curl=0.9, dx=-1, glow=2),
        pose(tilt=-6, curl=0.7),
        pose(curl=0.5),
    ]


def death():
    # it clenches and sinks into the lava, which crusts over
    return [
        pose(curl=1.2, spread=0.85, glow=2, splash=2),
        pose(curl=1.4, spread=0.8, sink=5, cool=1, splash=1),
        pose(curl=1.4, spread=0.8, sink=13, cool=1, splash=1, pool=18.0),
        pose(curl=1.4, spread=0.8, sink=22, cool=2, splash=0, pool=18.0),
        pose(sink=40, cool=2, splash=0, pool=17.0, fx=[(CX + 2, GROUND - 4, 1, "S3")]),
        pose(sink=40, cool=3, splash=0, pool=12.0),
    ]


# --- effects the game used to draw with shapes -------------------------------------------------

WARN_RADIUS = 14.0
## Cracks from the ring toward the center (angle in degrees), the order they light up in.
WARN_CRACKS = [20, 140, 260, 80, 200, 320]


def warning(k, n):
    """Warning frame k of n: a dark ring with an orange rim whose cracks creep to the center and
    glow brighter until the hand bursts out."""
    c = Canvas(FX_CELL)
    cx = cy = FX_CELL / 2.0
    f = k / max(n - 1, 1)
    rim = "S2" if f < 0.3 else "S3" if f < 0.7 else "S4"
    for y in range(FX_CELL):
        for x in range(FX_CELL):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if WARN_RADIUS - 1.2 < d <= WARN_RADIUS:
                # the rim pulses around the ring: a brighter arc runs along it
                ang = (math.degrees(math.atan2(y + 0.5 - cy, x + 0.5 - cx)) + 360) % 360
                hot = abs(((ang - k * 45) + 180) % 360 - 180) < 40
                c.set(x, y, "Y" if hot and f > 0.5 else "S4" if hot else rim)
            elif WARN_RADIUS - 2.2 < d <= WARN_RADIUS - 1.2:
                c.set(x, y, "S0")
            elif WARN_RADIUS < d <= WARN_RADIUS + 1.0:
                c.set(x, y, "O")  # a dark edge so it reads on bright floors too
    # cracks creep inward one after another
    for i, ang in enumerate(WARN_CRACKS):
        start = i / len(WARN_CRACKS) * 0.5
        grow = max(0.0, min(1.0, (f - start) / 0.5))
        if grow <= 0:
            continue
        a = math.radians(ang)
        r0, r1 = WARN_RADIUS - 2.0, (WARN_RADIUS - 2.0) * (1.0 - grow * 0.75)
        pts = []
        steps = 16
        for s in range(steps + 1):
            r = r0 + (r1 - r0) * s / steps
            wob = math.sin(s * 1.7 + i) * 0.9
            pts.append((round(cx - 0.5 + math.cos(a) * r - math.sin(a) * wob),
                        round(cy - 0.5 + math.sin(a) * r + math.cos(a) * wob)))
        for j, (x, y) in enumerate(pixel_perfect(pts)):
            c.set(x, y, "S4" if j == len(pts) - 1 and f > 0.6 else "S3" if f > 0.5 else "S2")
    if f >= 0.55:
        # the center bubbles: something is coming
        r = 1.5 + 2.5 * (f - 0.55) / 0.45
        for y in range(FX_CELL):
            for x in range(FX_CELL):
                if in_ellipse(x, y, cx, cy, r, r):
                    q = math.hypot(x + 0.5 - cx, y + 0.5 - cy) / r
                    c.set(x, y, "Y2" if q < 0.35 and f > 0.8 else "Y" if q < 0.6 else "S4")
    return c


def pool_frame(k, n):
    """The molten pool at the arm's root (radius 11, half as tall): a crusted rim, a glow that
    pulses and bubbles that pop."""
    c = Canvas(FX_CELL)
    cx, cy, rx, ry = FX_CELL / 2.0, FX_CELL / 2.0, 11.0, 5.5
    pulse = 0.5 + 0.5 * math.sin(k / n * math.tau)
    for y in range(FX_CELL):
        for x in range(FX_CELL):
            if not in_ellipse(x, y, cx, cy, rx, ry):
                continue
            q = math.hypot((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
            if q > 0.86:
                col = "K0" if y < cy else "K1"
            elif q > 0.72:
                col = "S3" if pulse > 0.5 else "S2"
            elif q > 0.45:
                col = "S1" if (x + y + k) % 5 else "S2"
            else:
                col = "S2" if q > 0.25 else ("S3" if pulse > 0.3 else "S2")
            c.set(x, y, col)
    bubbles = [((-5, 0), 0), ((4, 1), 2), ((0, -2), 4)]
    for (bx, by), born in bubbles:
        age = (k - born) % n
        x, y = int(cx) + bx, int(cy) + by
        if age == 0:
            c.set(x, y, "S4")
        elif age == 1:
            for px_ in ((x, y), (x + 1, y), (x, y - 1), (x + 1, y - 1)):
                c.set(*px_, "Y" if px_[1] == y - 1 else "S4")
        elif age == 2:
            for px_ in ((x - 1, y), (x + 2, y), (x, y - 2), (x + 1, y + 1)):
                c.set(*px_, "S4")
    c.outline("O")
    return c


def arm_tile():
    """One 16 px tile of the arm, across its 9 px width: a glowing edge on both sides around dark
    molten stone with a lava seam that breaks now and then."""
    c = Canvas(16)
    rows = ["O", "S3", "R3", "R2", "R2", "R1", "R1", "S2", "O"]
    for y, col in enumerate(rows):
        for x in range(16):
            c.set(x, y, col)
    # knobbly stone and a broken seam
    for x in (2, 3, 9, 10, 11):
        c.set(x, 2, "R4")
    for x in (5, 13):
        c.set(x, 6, "R0")
    for x in range(16):
        if x % 8 not in (6, 7):
            c.set(x, 4, "S2" if x % 3 else "S3")
    c.set(1, 4, "S4")
    c.set(9, 4, "S4")
    return c


def strip(frames, path, w=None, h=None):
    cell = frames[0].size if w is None else w
    height = cell if h is None else h
    img = Image.new("RGBA", (cell * len(frames), height), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        img.alpha_composite(f.image(cell, height), (i * cell, 0))
    img.save(path)
    print(os.path.relpath(path), len(frames), "frames")


if __name__ == "__main__":
    for name, make in (("idle", idle), ("walk", walk), ("attack", attack), ("special", special),
                       ("hurt", hurt), ("death", death)):
        strip([draw_abyss_hand(p) for p in make()], os.path.join(OUT, "manos_abismo_%s.png" % name))
    strip([warning(k, 8) for k in range(8)], os.path.join(OUT, "manos_abismo_warning.png"))
    strip([pool_frame(k, 6) for k in range(6)], os.path.join(OUT, "manos_abismo_pool.png"))
    strip([arm_tile()], os.path.join(OUT, "manos_abismo_arm.png"), 16, 9)
