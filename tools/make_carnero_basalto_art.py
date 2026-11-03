"""Draws the Carnero de basalto's art (temple enemy, island 3) pixel by pixel.

The beasts pack's ram, scaled from 128 px down to the game, came out blurred, so it is drawn at the
game's own pixel size instead, following the pack's design: a hulking ram of grey-violet basalt
plates split by glowing lava seams, a lowered head with a thick gold horn curled around it and hooves
that glow like embers. It is built from a few parts (rump, chest, four legs, head, horn) that each
animation moves frame by frame: idle, walk, attack (paws the ground with its head down, then butts
forward in a puff of dust; frame 2 is the pose held while its lane is marked), special (the charge:
a gallop that loops, a trail of fire and dust behind it), hurt (its last frame, dazed, is held while
it is stunned) and death (it buckles, falls on its side and its seams go cold). It also draws the
lane it marks on the ground before a charge (BasaltRamData.lane_art).

Writes into `assets/sprites/carnero_basalto/`:
    carnero_basalto_<animation>.png   64x64 cells, facing right, hooves on row 44: idle, walk,
                                      attack, special, hurt, death
    carnero_basalto_lane.png          18x18 tiles of the charge lane, pointing right: start, middle,
                                      middle, end; first unlit (marked), then lit (filled), then hot

    python tools/make_carnero_basalto_art.py
Then tools/make_temple_enemy_frames.gd builds its SpriteFrames as for every temple enemy, and
tools/enemy_aseprite.lua keeps an editable `source/carnero_basalto.aseprite`.
Needs Pillow.
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "carnero_basalto")
CELL = 64
## Last row of the hooves; their outline goes on the row below.
GROUND = 44
LANE_TILE = 18
LANE_WIDTH = 18

PALETTE = {
    "O": (24, 14, 22),     # outline
    # basalt plates (grey-violet)
    "B0": (50, 30, 50),
    "B1": (80, 50, 78),
    "B2": (114, 76, 104),
    "B3": (152, 108, 132),
    "B4": (190, 148, 162),
    # lava seams and hooves
    "L0": (104, 30, 22),
    "L1": (186, 68, 24),
    "L2": (238, 128, 38),
    "L3": (255, 198, 78),
    "L4": (255, 242, 176),
    # gold horn
    "G0": (128, 64, 18),
    "G1": (218, 134, 28),
    "G2": (250, 184, 50),
    "G3": (255, 226, 122),
    # dust
    "D0": (112, 86, 66),
    "D1": (170, 136, 100),
    "D2": (220, 194, 150),
    "W": (255, 243, 236),  # hurt flash
}
## Death: each step cools the seams and dims the stone.
COOL_STEPS = [
    {"L4": "L3", "L3": "L2", "L2": "L1"},
    {"L3": "L1", "L2": "L1", "L1": "L0", "B4": "B3", "G3": "G2"},
    {"L1": "L0", "L0": "B1", "B4": "B3", "B3": "B2", "G3": "G1", "G2": "G1"},
]
## The charge: the seams run white-hot.
BLAZE = {"L0": "L1", "L1": "L2", "L2": "L3", "L3": "L4"}

## Rest pose (cell coordinates): the body's two masses, the legs, the long face and the horn.
RUMP = (22.0, 30.5, 7.5, 7.0)    # center x, center y, radius x, radius y
CHEST = (31.0, 28.5, 8.5, 8.5)
## The face hangs from the forehead down to the muzzle; the horn curls around a point behind it.
BROW = (40.0, 27.0)
MUZZLE = (43.0, 33.5)
FACE_R = 3.7
HORN_C = (38.5, 26.0)
## Legs, back to front: far hind, far fore, near hind, near fore (the far pair drawn darker).
LEG_X = [19, 32, 22, 35]
LEG_TOP = 35
## The basalt plates: one seed each (rest coordinates) and how much lighter or darker it is.
PLATES = [((17, 27), 0.1), ((20, 35), -0.1), ((25, 30), 0.0), ((24, 23), 0.15), ((30, 22), 0.2),
          ((36, 24), 0.05), ((31, 31), -0.05), ((37, 32), -0.15), ((28, 36), -0.2)]

class Canvas:
    def __init__(self, size, height=None):
        self.size = size
        self.height = height or size
        self.px = {}

    def set(self, x, y, c):
        if 0 <= x < self.size and 0 <= y < self.height:
            self.px[(x, y)] = c

    def over(self, other):
        self.px.update(other.px)

    def outline(self, color="O", only_empty_of=None):
        """A 1 px outline around everything drawn (4-neighbours: rounder than 8)."""
        ring = {}
        for (x, y) in self.px:
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if (nx, ny) in self.px or not (0 <= nx < self.size and 0 <= ny < self.height):
                    continue
                if only_empty_of is not None and (nx, ny) in only_empty_of.px:
                    continue
                ring[(nx, ny)] = color
        self.px.update(ring)

    def remap(self, mapping):
        self.px = {p: mapping.get(c, c) for p, c in self.px.items()}

    def shifted(self, dx, dy):
        c = Canvas(self.size, self.height)
        for (x, y), col in self.px.items():
            c.set(x + dx, y + dy, col)
        return c

    def image(self):
        img = Image.new("RGBA", (self.size, self.height), (0, 0, 0, 0))
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


def capsule(canvas, ax, ay, bx, by, r, shade):
    """A thick limb from (ax, ay) to (bx, by); `shade(l)` picks a color from how lit a pixel is."""
    vx, vy = bx - ax, by - ay
    vv = max(vx * vx + vy * vy, 0.001)
    for y in range(int(min(ay, by) - r) - 1, int(max(ay, by) + r) + 2):
        for x in range(int(min(ax, bx) - r) - 1, int(max(ax, bx) + r) + 2):
            px_, py_ = x + 0.5, y + 0.5
            t = max(0.0, min(1.0, ((px_ - ax) * vx + (py_ - ay) * vy) / vv))
            qx, qy = ax + vx * t, ay + vy * t
            d = math.hypot(px_ - qx, py_ - qy)
            if d > r:
                continue
            canvas.set(x, y, shade(lit((px_ - qx) / r, (py_ - qy) / r)))


# --- the ram -----------------------------------------------------------------------------------

def pose(**kw):
    p = dict(bdx=0, bdy=0, hdx=0, hdy=0, legs=((0, 0),) * 4, eye="open", flash=False, cool=0,
             blaze=False, fire=0, phase=0, lie=0, horn_dy=0, fx=(), dust=())
    p.update(kw)
    return p


def stone(l, bright=0.0):
    l += bright
    return "B4" if l > 0.72 else "B3" if l > 0.28 else "B2" if l > -0.25 else "B1" if l > -0.7 else "B0"


def draw_legs(p, far):
    """The far pair (far=True) or the near pair: thick legs ending in glowing hooves."""
    c = Canvas(CELL)
    for i in ((0, 1) if far else (2, 3)):
        fdx, lift = p["legs"][i]
        hx = LEG_X[i] + p["bdx"]
        hy = LEG_TOP + p["bdy"]
        fx_, fy = LEG_X[i] + fdx + p["bdx"] * 0.5, GROUND - lift
        if p["lie"]:
            # lying on its side the legs stick out stiffly in front of its belly
            fx_, fy = hx + 7 + (i % 2) * 2, hy + 2 - (i // 2) * 2 + (i % 2)
        dim = -0.5 if far else 0.0
        shade = lambda l, d=dim: min(stone(l, d), "B3")
        # thigh, then shank: hind knees bend back, fore knees forward
        kx = (hx + fx_) / 2 + (0.8 if i % 2 else -0.8)
        ky = (hy + fy) / 2
        capsule(c, hx, hy - 2, kx, ky, 2.4 if i % 2 else 2.7, shade)
        capsule(c, kx, ky, fx_ + 0.5, fy - 1.2, 1.7, shade)
        # hoof: two rows, an ember rim at the bottom
        hoof_y = int(round(fy))
        bx0 = int(round(fx_)) - 1
        if p["lie"]:
            for y in (hoof_y - 2, hoof_y - 1):
                c.set(bx0 + 3, y, "L1" if far else "L2")
            continue
        for x in range(bx0, bx0 + 3):
            c.set(x, hoof_y - 1, "L0" if far else "L1")
            c.set(x, hoof_y, "L1" if far else ("L3" if x == bx0 + 2 else "L2"))
    return c


def plate_of(x, y, ox, oy):
    best, best_d = 0, 1e9
    for k, ((sx, sy), _) in enumerate(PLATES):
        d = (x - sx - ox) ** 2 + ((y - sy - oy) * 1.2) ** 2
        if d < best_d:
            best, best_d = k, d
    return best


def draw_body(p):
    c = Canvas(CELL)
    bdx, bdy = p["bdx"], p["bdy"]
    squash = 2 if p["lie"] else 0
    plates = {}
    for (cx, cy, rx, ry) in (RUMP, CHEST):
        cx, cy, ry2 = cx + bdx, cy + bdy + squash / 2, ry - squash / 2
        for y in range(int(cy - ry2) - 1, int(cy + ry2) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                # a blocky superellipse: rock, not flesh
                if abs((x + 0.5 - cx) / rx) ** 2.6 + abs((y + 0.5 - cy) / ry2) ** 2.6 > 1.0:
                    continue
                k = plate_of(x, y, bdx, bdy)
                plates[(x, y)] = k
    # one light for the whole body, each plate a little lighter or darker
    x0 = min(x for x, _ in plates)
    x1 = max(x for x, _ in plates)
    y0 = min(y for _, y in plates)
    y1 = max(y for _, y in plates)
    mx, my, hx, hy = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2, (y1 - y0) / 2
    for (x, y), k in plates.items():
        c.set(x, y, stone(lit((x + 0.5 - mx) / hx, (y + 0.5 - my) / hy), PLATES[k][1]))
    # the cracks between plates glow; a plate's top edge catches the light, its bottom lip is dark
    seams = set()
    for (x, y), k in plates.items():
        for n in ((x + 1, y), (x, y + 1)):
            if n in plates and plates[n] != k:
                seams.add((x, y))
    for (x, y) in seams:
        below, above = (x, y + 1), (x, y - 1)
        if below in plates and below not in seams:
            c.px[below] = {"B0": "B1", "B1": "B2", "B2": "B3", "B3": "B4"}.get(c.px[below], c.px[below])
        if above in plates and above not in seams and c.px[above] != "B0":
            c.px[above] = "B1"
    for (x, y) in seams:
        # the seams near the rim are hairline dark cracks, the inner ones carry lava
        inner = all(n in plates for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
        hot = (x * 7 + y * 3 + p["phase"]) % 9 == 0
        c.px[(x, y)] = ("L2" if hot else "L1") if inner else "L0"
    # tail stub
    tx, ty = int(RUMP[0] - RUMP[2] + bdx), int(25 + bdy + squash)
    for dx, dy, col in ((-1, 0, "B3"), (-1, 1, "B2"), (-2, 1, "B1"), (0, 1, "B2")):
        c.set(tx + dx, ty + dy, col)
    return c


def draw_head(p):
    """The long face, its eye and the curled horn, moved by (hdx, hdy) on top of the body's offset."""
    c = Canvas(CELL)
    ox, oy = p["bdx"] + p["hdx"], p["bdy"] + p["hdy"]
    bx, by = BROW[0] + ox, BROW[1] + oy
    mx, my = MUZZLE[0] + ox, MUZZLE[1] + oy
    # neck: a thick wedge from the shoulders into the back of the head
    capsule(c, CHEST[0] + 4 + p["bdx"], 26 + p["bdy"], bx - 2, by + 2, 4.0, lambda l: stone(l, -0.15))
    # the face: forehead down to a blunt muzzle (a ram's Roman nose)
    capsule(c, bx, by, mx, my, FACE_R, lambda l: stone(l, 0.1))
    capsule(c, mx - 0.3, my, mx + 0.6, my + 0.9, 2.4, lambda l: stone(l, 0.2))
    ex, ey = int(bx + 2), int(by + 3)
    # nostril and mouth
    nx_, ny_ = int(mx + 1), int(my)
    c.set(nx_ + 1, ny_, "B0")
    c.set(nx_, ny_ + 2, "B1")
    c.set(nx_ + 1, ny_ + 2, "B1")
    # the horn: a thick gold spiral from the top of the head, back, down and forward to its tip
    horn = Canvas(CELL)
    ccx, ccy = HORN_C[0] + ox, HORN_C[1] + oy + p["horn_dy"]
    steps = 220
    ridge = {}
    for i in range(steps + 1):
        t = i / steps
        ang = math.radians(-50 - 330 * t)
        r = 6.4 - 3.8 * t
        x = ccx + r * math.cos(ang)
        y = ccy + r * math.sin(ang)
        thick = 2.3 if t < 0.35 else 1.9 if t < 0.65 else 1.4 if t < 0.85 else 0.9
        for yy in range(int(y - thick) - 1, int(y + thick) + 2):
            for xx in range(int(x - thick) - 1, int(x + thick) + 2):
                dx_, dy_ = xx + 0.5 - x, yy + 0.5 - y
                if dx_ * dx_ + dy_ * dy_ > thick * thick or (xx, yy) in horn.px:
                    continue
                # outside of the curl catches the light from the upper left, inside is in shade
                rx_, ry_ = xx + 0.5 - ccx, yy + 0.5 - ccy
                n = math.hypot(rx_, ry_) or 1.0
                l = lit(rx_ / n, ry_ / n)
                outer = n > r
                if outer:
                    col = "G3" if l > 0.8 else "G2" if l > -0.2 else "G1"
                else:
                    col = "G2" if l > 0.55 else "G1" if l > -0.4 else "G0"
                horn.set(xx, yy, col)
                ridge[(xx, yy)] = t
    # ridges across the horn every few pixels along it
    for (x, y), t in ridge.items():
        if int(t * 18) % 3 == 2 and horn.px[(x, y)] in ("G2", "G3") and t < 0.8:
            horn.px[(x, y)] = "G1"
    # where the horn lies on the head, a dark line under it so the curl reads
    for (x, y) in list(horn.px):
        for n in ((x, y + 1), (x + 1, y), (x - 1, y)):
            if n not in horn.px and n in c.px:
                c.px[n] = "B0"
    # the hollow of the curl is in deep shadow
    for y in range(int(ccy) - 4, int(ccy) + 5):
        for x in range(int(ccx) - 4, int(ccx) + 5):
            if (x, y) not in horn.px and (x, y) in c.px and math.hypot(x + 0.5 - ccx, y + 0.5 - ccy) < 3.6:
                c.px[(x, y)] = "B0"
    c.over(horn)
    # brow ridge over a glowing eye
    if p["eye"] == "open":
        c.set(ex + 1, ey, "L3")
        c.set(ex + 2, ey, "L2")
        c.set(ex + 1, ey - 1, "B0")
        c.set(ex + 2, ey - 1, "B0")
    elif p["eye"] == "shut":
        c.set(ex + 1, ey, "B0")
        c.set(ex + 2, ey, "B0")
    elif p["eye"] == "dizzy":
        c.set(ex + 1, ey - 1, "L1")
        c.set(ex + 2, ey, "L1")
        c.set(ex + 1, ey, "B0")
    return c


def draw_ram(p):
    far = draw_legs(p, True)
    body = draw_body(p)
    head = draw_head(p)
    near = draw_legs(p, False)
    figure = Canvas(CELL)
    figure.over(far)
    figure.over(body)
    figure.over(near)
    figure.over(head)
    # a dark line where a near part lies over a far leg
    for (x, y), col in list(far.px.items()):
        if (x, y) in body.px or (x, y) in near.px:
            continue
        if any(n in near.px or n in body.px for n in ((x + 1, y), (x - 1, y), (x, y - 1))):
            if col not in ("L0", "L1", "L2"):
                figure.px[(x, y)] = "O"
    if p["lie"]:
        for (x, y) in list(near.px):
            for n in ((x, y - 1), (x - 1, y), (x, y + 1)):
                if n not in near.px and n in body.px:
                    figure.px[n] = "O"
    if p["blaze"]:
        figure.remap(BLAZE)
    for step in COOL_STEPS[:p["cool"]]:
        figure.remap(step)
    figure.outline()
    if p["flash"]:
        figure.remap({c: "W" for c in PALETTE if c != "O"})
    if p["fire"]:
        fire = fire_trail(p["fire"], p["phase"], p["bdx"], p["bdy"])
        fire.outline("L0", only_empty_of=figure)
        fire.over(figure)
        figure = fire
    add_dust(figure, p["dust"])
    add_fx(figure, p["fx"])
    return figure


# --- effects in the cell ------------------------------------------------------------------------

def dust_puff(c, cx, cy, r, stage):
    """A billowing puff of dust (three lumps): `stage` 0 dense, 1 thinning, 2 a few wisps."""
    lumps = ((cx, cy, r), (cx - r * 0.9, cy + r * 0.35, r * 0.7), (cx + r * 0.8, cy + r * 0.3, r * 0.75))
    for lx, ly, lr in lumps:
        for y in range(int(ly - lr) - 1, int(ly + lr) + 2):
            for x in range(int(lx - lr) - 1, int(lx + lr) + 2):
                dx, dy = (x + 0.5 - lx) / lr, (y + 0.5 - ly) / lr
                q = dx * dx + dy * dy
                if q > 1.0 or y > GROUND + 1:
                    continue
                if stage == 1 and q > 0.45 and (x + y) % 2 == 0:
                    continue
                if stage == 2 and (q > 0.55 or (x + y) % 2 == 0):
                    continue
                l = lit(dx, dy)
                col = "D2" if l > 0.3 else "D1" if l > -0.35 else "D0"
                if (x, y) not in c.px or col == "D2":
                    c.set(x, y, col)


def add_dust(canvas, puffs):
    """Puffs of dust kicked up from the ground: (x, y, radius, stage); they sit behind the ram."""
    if not puffs:
        return
    d = Canvas(canvas.size)
    for x, y, r, stage in puffs:
        dust_puff(d, x, y, r, stage)
    for k in list(d.px):
        if k in canvas.px:
            del d.px[k]
    canvas.over(d)


def add_fx(canvas, fx):
    """Sparks, embers and pebbles: (x, y, color), one pixel each, outlined unless on the figure."""
    if not fx:
        return
    drops = Canvas(canvas.size)
    for x, y, c in fx:
        drops.set(x, y, c)
    canvas.over(drops)


def fire_trail(power, phase, bdx, bdy):
    """Flames streaming back from the ram's body while it charges: three tapering tongues that
    wave, white-hot where they leave the stone."""
    c = Canvas(CELL)
    x0 = int(RUMP[0] - RUMP[2] + bdx) + 2
    for k, (y, size) in enumerate(((24 + bdy, 0.75), (29 + bdy, 1.0), (34 + bdy, 0.6))):
        length = int(round(power * size)) + [0, 2, 1, 3][(phase + k) % 4]
        for i in range(length):
            f = i / max(length, 1)
            wave = int(round(math.sin((i - phase * 2.5 + k * 2) * 0.55) * min(f * 3.0, 1.2)))
            half = 2 if f < 0.2 and k == 1 else 1 if f < 0.7 else 0
            for dy in range(-half, half + 1):
                col = "L4" if f < 0.25 else "L3" if f < 0.5 else "L2" if f < 0.78 else "L1"
                if dy != 0:
                    col = {"L4": "L3", "L3": "L2", "L2": "L1"}.get(col, col)
                c.set(x0 - i, y + dy + wave, col)
    # loose sparks behind
    for k in range(3):
        sx = x0 - power - 2 - ((phase * 3 + k * 5) % 7)
        sy = 22 + bdy + (k * 7 + phase * 2) % 14
        c.set(sx, sy, "L3" if k % 2 else "L2")
    return c


# --- animations -----------------------------------------------------------------------------

def idle():
    # Slow breathing: the chest rises, the head nods a pixel, the seams pulse.
    bdy = [0, 0, -1, -1, 0, 0]
    hdy = [0, 0, 0, 1, 1, 0]
    return [pose(bdy=bdy[i], hdy=hdy[i], blaze=i in (2, 3), eye="shut" if i == 4 else "open")
            for i in range(6)]


def walk():
    # A heavy four-beat walk: diagonal pairs swing together, the body bobs on each plant.
    cycle = [(-3, 0), (-1, 1), (1, 2), (3, 1), (3, 0), (1, 0), (-1, 0), (-3, 0)]
    frames = []
    for i in range(8):
        a = cycle[i]
        b = cycle[(i + 4) % 8]
        legs = (b, a, a, b)
        frames.append(pose(legs=legs, bdy=-1 if i % 4 in (1, 2) else 0, hdy=1 if i % 4 == 3 else 0))
    return frames


def attack():
    # Head down, it paws the ground (frame 2 is held while the lane is marked), then butts forward
    # in a burst of dust and settles back.
    windup = dict(hdy=2, hdx=1, bdy=1, bdx=-1)
    return [
        pose(hdy=1, legs=((0, 0), (0, 0), (0, 0), (1, 2))),
        pose(hdy=2, bdy=1, legs=((0, 0), (0, 0), (0, 0), (-2, 1)), dust=[(36, 44, 2, 1)]),
        pose(**windup, legs=((-1, 0), (1, 0), (-1, 0), (1, 0)), blaze=True,
             dust=[(13, 43, 2.5, 0)], fx=[(11, 40, "D1"), (9, 42, "D0")]),
        pose(bdx=2, hdx=3, hdy=1, legs=((-3, 0), (3, 0), (-2, 0), (4, 1)), blaze=True,
             dust=[(12, 42, 3, 0), (19, 44, 2, 0)]),
        pose(bdx=4, hdx=5, hdy=0, legs=((-2, 0), (5, 0), (-1, 0), (6, 0)), blaze=True,
             dust=[(10, 41, 3.5, 1), (17, 43, 2.5, 0)],
             fx=[(54, 30, "L3"), (55, 34, "L2"), (53, 26, "D2")]),
        pose(bdx=3, hdx=4, hdy=1, legs=((-1, 0), (4, 0), (0, 0), (5, 0)),
             dust=[(9, 40, 3.5, 2), (15, 42, 3, 1)]),
        pose(bdx=1, hdx=1, legs=((0, 0), (2, 0), (0, 0), (2, 0)), dust=[(12, 41, 3, 2)]),
        pose(),
    ]


def special():
    # The charge, looped while it rushes: a gallop with its head low and the seams white-hot,
    # flames and dust streaming behind it.
    gallop = [
        ((-4, 1), (2, 0), (-3, 0), (4, 2)),
        ((-2, 2), (4, 1), (-1, 1), (5, 3)),
        ((1, 3), (3, 3), (2, 2), (3, 4)),
        ((3, 1), (-1, 2), (4, 0), (0, 3)),
        ((1, 0), (-3, 1), (2, 0), (-2, 1)),
        ((-2, 0), (-1, 0), (-1, 0), (1, 0)),
    ]
    bob = [0, -1, -2, -1, 0, 1]
    frames = []
    for i in range(6):
        frames.append(pose(legs=gallop[i], bdx=2, hdx=3, hdy=2 + (1 if bob[i] > 0 else 0), bdy=bob[i],
                           blaze=True, fire=11 + (i % 3), phase=i,
                           dust=[(8 - (i % 3), 41 + (i % 2), 3, i % 2), (15, 44, 2, (i + 1) % 3)]))
    return frames


def hurt():
    # Flinches, then reels with its eyes swimming; the last frame is held while it is stunned.
    return [
        pose(flash=True, bdx=-1, hdx=-1),
        pose(bdx=-2, hdx=-2, hdy=-1, bdy=-1, eye="shut", legs=((-1, 1), (0, 0), (-1, 0), (0, 1))),
        pose(bdx=-1, hdx=-1, hdy=2, eye="dizzy"),
        pose(hdy=3, bdy=1, eye="dizzy", horn_dy=0, legs=((-1, 0), (1, 0), (-1, 0), (1, 0))),
    ]


def death():
    # It buckles at the knees, falls on its side and its lava goes cold.
    lie = dict(hdy=1, hdx=2, bdy=6, eye="shut", lie=1)
    return [
        pose(flash=True, hdy=1),
        pose(hdy=2, bdy=1, eye="shut", legs=((0, 0), (2, 0), (0, 0), (3, 0))),
        pose(hdy=3, hdx=1, bdy=2, eye="shut", cool=1, legs=((-1, 0), (4, 0), (-1, 0), (5, 0))),
        pose(hdy=3, hdx=2, bdy=4, eye="shut", cool=1, legs=((-3, 0), (6, 0), (-2, 0), (7, 0)),
             dust=[(44, 43, 2.5, 0)]),
        pose(**lie, cool=2, dust=[(12, 42, 3.5, 0), (49, 42, 3.5, 0)]),
        pose(**lie, cool=2, dust=[(10, 41, 4, 1), (51, 41, 4, 1)]),
        pose(**lie, cool=3, dust=[(9, 40, 4, 2), (52, 40, 3.5, 2)]),
        pose(**lie, cool=3),
    ]


# --- the charge lane --------------------------------------------------------------------------

def lane_tile(kind, state, variant=0):
    """One 18x18 tile of the lane, pointing right. kind: start, mid, end; state: 0 marked (dark
    scorch and dim chevron), 1 filled (glowing), 2 hot (the filled tiles flicker to it)."""
    c = Canvas(LANE_TILE, LANE_WIDTH)
    edge = ["L0", "L1", "L2"][state]
    edge_hi = ["L1", "L2", "L3"][state]
    chev = ["L1", "L2", "L3"][state]
    chev_hi = ["L2", "L3", "L4"][state]
    # dashed borders along both edges, with an outline outside
    for x in range(LANE_TILE):
        on = (x + variant * 3) % 6 < 4
        if kind == "start" and x < 3:
            on = False
        if kind == "end" and x > 12:
            on = False
        if on:
            c.set(x, 1, edge_hi)
            c.set(x, LANE_WIDTH - 2, edge)
            c.set(x, 0, "O")
            c.set(x, LANE_WIDTH - 1, "O")
            c.set(x, 2, "L0" if state == 0 else edge)
            c.set(x, LANE_WIDTH - 3, "O" if state == 0 else "L0")
    # scorched hoof marks along the middle (the filled lane cracks open with lava)
    mid = LANE_WIDTH // 2
    if kind == "start":
        for y in range(3, LANE_WIDTH - 3):
            c.set(1, y, "O")
            c.set(2, y, edge_hi if 5 <= y <= LANE_WIDTH - 6 else edge)
        for (x, y) in ((4, mid - 4), (5, mid - 4), (4, mid + 3), (5, mid + 3), (7, mid - 3), (7, mid + 2)):
            c.set(x, y, "O" if state == 0 else "L1")
    # a chevron pointing the way
    if kind in ("mid", "start"):
        ox = 7 if kind == "mid" else 10
        for k in range(5):
            for y in (mid - 1 - k, mid + k):
                x = ox + 4 - k
                c.set(x, y, chev_hi if k < 2 else chev)
                c.set(x - 1, y, chev)
                c.set(x - 2, y, "O")
    if kind == "mid" and state > 0:
        for (x, y) in ((1, mid + 3 - variant), (2, mid + 3 - variant), (3, mid + 4 - variant),
                       (13, mid - 4 + variant), (14, mid - 3 + variant)):
            c.set(x, y, "L1" if state == 1 else "L2")
    # the end: a wide arrowhead and the mark where it stops
    if kind == "end":
        for k in range(8):
            for y in (mid - 1 - k, mid + k):
                x = 15 - k
                if 0 <= y < LANE_WIDTH:
                    c.set(x, y, chev_hi if k < 3 else chev)
                    c.set(x - 1, y, chev)
                    c.set(x - 2, y, "O")
                    c.set(x + 1, y, "O")
        c.set(16, mid - 1, "O")
        c.set(16, mid, "O")
    return c


def lane():
    tiles = []
    for state in range(3):
        tiles += [lane_tile("start", state), lane_tile("mid", state, 0), lane_tile("mid", state, 1),
                  lane_tile("end", state)]
    return tiles


def strip(frames, path):
    w, h = frames[0].size, frames[0].height
    img = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        img.alpha_composite(f.image(), (i * w, 0))
    img.save(path)
    print(os.path.relpath(path), len(frames), "frames")


if __name__ == "__main__":
    for name, make in (("idle", idle), ("walk", walk), ("attack", attack), ("special", special),
                       ("hurt", hurt), ("death", death)):
        strip([draw_ram(p) for p in make()], os.path.join(OUT, "carnero_basalto_%s.png" % name))
    strip(lane(), os.path.join(OUT, "carnero_basalto_lane.png"))
