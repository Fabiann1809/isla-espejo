"""Draws the bridge worm's art (Gusano de los puentes, temple enemy, island 3) pixel by pixel.

The bestiary pack's worm, scaled from 128 px down to the game, came out blurred, so it is drawn at
the game's own pixel size instead, following the pack's design: a thick plum body of ring plates
with glowing lava seams between them and lava cracks across them, rising from a lava pool in an arch
to an orange head with a yellow eye, fangs and lava dripping from its jaw. The body is a tube along a
spline (its key points move frame by frame) and the head is drawn on its end, as in the pack's
sheet: idle (it sways), walk (it undulates), attack (from its reared stance it lunges forward with
its jaws wide, snaps them shut in a splash of lava and comes back up), special (it bursts out of the
ground: the floor cracks and bulges, breaks in flying rocks and a crown of lava, and the body rises
out of the hole to rear up roaring), hurt and death (it slumps and melts into the pool). It also
draws the pieces of its body that rise along its path (WormSegment) and the ripple that betrays it
under the ground.

How BridgeWorm shows them: special plays over the warning before it surfaces (the worm stays put
over its hole) and backwards, fast, when it dives; attack plays over the surge, the lunge being the
surge itself; idle while it rests out.

Writes into `assets/sprites/gusano_puentes/`:
    gusano_puentes_<animation>.png   64x64 cells, facing right, the pool's surface (its "feet") on
                                     row 54: idle, walk, attack, special, hurt, death
    gusano_puentes_segment.png       24x24 cells, one per body piece from the head to the tail (a
                                     hump of body out of the ground, ground on row 20)
    gusano_puentes_ripple.png        32x32 cells: 12 that loop (rings of lava spreading on the ground)

    python tools/make_gusano_puentes_art.py
Then tools/make_temple_enemy_frames.gd builds its SpriteFrames as for every temple enemy, and
tools/enemy_aseprite.lua keeps an editable `source/gusano_puentes.aseprite`
(extras="segment:1,ripple:12").
Needs Pillow.
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "gusano_puentes")
CELL = 64
SEGMENT_CELL = 24
RIPPLE_CELL = 32
## Surface of the lava pool the worm rises from (its "feet"); the pool's front lip goes below it.
GROUND = 54
## Ground row of a body piece: the Sprite2D is centered 8 px above the piece (segment_offset).
SEGMENT_GROUND = 20

PALETTE = {
    "O": (26, 10, 20),     # outline
    "L": (58, 22, 36),     # inner line (head against body)
    # body: plum rock plates
    "B0": (46, 20, 36),
    "B1": (74, 32, 52),
    "B2": (104, 46, 66),
    "B3": (136, 66, 86),
    "B4": (170, 100, 116),
    # head: molten orange
    "H0": (130, 40, 18),
    "H1": (186, 66, 22),
    "H2": (228, 102, 28),
    "H3": (248, 146, 44),
    "H4": (255, 196, 92),
    # lava
    "S0": (70, 18, 16),
    "S1": (128, 30, 18),
    "S2": (196, 62, 20),
    "S3": (240, 112, 28),
    "S4": (255, 170, 56),
    "Y": (255, 222, 104),
    "Y2": (255, 248, 206),
    "M": (64, 8, 12),      # inside the mouth
    "W": (255, 240, 230),  # hurt flash
    # the floor it breaks through: dark stone
    "G0": (40, 30, 34),
    "G1": (70, 56, 58),
    "G2": (104, 86, 84),
    "G3": (140, 120, 112),
}
## Death: each step cools the lava and dims the rock.
COOL_STEPS = [
    {"Y2": "Y", "Y": "S4", "S4": "S3", "S3": "S2", "H4": "H3", "H3": "H2"},
    {"Y": "S3", "S4": "S2", "S3": "S2", "S2": "S1", "H2": "H1", "H1": "H0", "B4": "B3", "B3": "B2"},
    {"S3": "S1", "S2": "S1", "S1": "S0", "H3": "H1", "H1": "H0", "H0": "B1", "B3": "B2", "B2": "B1"},
]

## Key points of the body's spine (x, y, radius), from the tail in the pool to the neck, and where
## the head's center goes, for a few poses that the animations blend.
REST = ([(8, 51, 5.0), (17, 49, 7.0), (25, 46, 8.0), (31, 36, 7.5), (35, 29, 7.0), (40, 26, 6.5)], (45, 24))
REAR = ([(8, 52, 4.0), (17, 50, 6.5), (24, 45, 7.5), (27, 35, 7.5), (29, 27, 7.0), (33, 21, 6.5)], (38, 18))
LUNGE = ([(8, 52, 4.0), (17, 50, 6.5), (26, 46, 7.5), (34, 39, 7.5), (41, 37, 7.0), (46, 39, 6.5)], (51, 39))
TALL = ([(10, 53, 4.5), (18, 50, 7.0), (24, 42, 7.5), (27, 31, 7.5), (31, 22, 7.0), (36, 17, 6.5)], (41, 14))
ARC = ([(8, 52, 4.5), (16, 48, 7.0), (24, 41, 7.5), (33, 37, 7.5), (41, 38, 7.0), (46, 42, 6.5)], (50, 43))
LYING = ([(6, 52, 3.5), (14, 50, 5.5), (22, 49, 6.0), (30, 49, 6.0), (38, 49, 5.5), (44, 49, 5.0)], (49, 48))
## Out of the hole it bursts from (special): the body rises straight out of the ground at HOLE_X,
## the cell's middle, where the worm's origin (its ripple and warning circle) is.
HOLE_X = 32
EMERGE = ([(HOLE_X, 62, 6.5), (HOLE_X, 54, 7.5), (HOLE_X + 1, 46, 7.5), (HOLE_X + 2, 38, 7.0), (HOLE_X + 3, 31, 6.8),
           (HOLE_X + 5, 26, 6.5)], (HOLE_X + 9, 22))
RISEN = ([(HOLE_X, 62, 6.5), (HOLE_X, 54, 7.5), (HOLE_X + 1, 44, 7.5), (HOLE_X + 2, 34, 7.2), (HOLE_X + 4, 25, 6.8),
          (HOLE_X + 7, 18, 6.5)], (HOLE_X + 12, 14))
## Reared over its hole, the head where REAR has it: the lunge (attack) starts from here.
RISEN_REAR = ([(HOLE_X, 62, 6.5), (HOLE_X, 54, 7.5), (HOLE_X, 45, 7.5), (HOLE_X + 1, 36, 7.2), (HOLE_X + 3, 28, 6.8),
               (HOLE_X + 8, 22, 6.5)], (HOLE_X + 14, 18))
## Length of one ring plate along the spine, and the lava crack across each plate (where across it).
PLATE = 7.0
CRACKS = [0.25, -0.35, 0.45, -0.1, 0.3, -0.45, 0.1]


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
            if (a[0] == b[0] or a[1] == b[1]) and (b[0] == c[0] or b[1] == c[1]) and                     a[0] != c[0] and a[1] != c[1]:
                out.pop(-2)
    return out


def drop_lone(canvas, keep=()):
    """No lone pixel sticking out of a shape (one or no neighbour)."""
    for (x, y) in list(canvas.px):
        if canvas.px[(x, y)] in keep:
            continue
        if sum(n in canvas.px for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))) <= 1:
            del canvas.px[(x, y)]


# --- the body -----------------------------------------------------------------------------------

def blend(a, b, f):
    """A pose between two key poses (spine points and head)."""
    pts = [(pa[0] + (pb[0] - pa[0]) * f, pa[1] + (pb[1] - pa[1]) * f, pa[2] + (pb[2] - pa[2]) * f)
           for pa, pb in zip(a[0], b[0])]
    head = (a[1][0] + (b[1][0] - a[1][0]) * f, a[1][1] + (b[1][1] - a[1][1]) * f)
    return pts, head


def spline(points, steps=24):
    """Catmull-Rom through the key points: samples (x, y, r) with their arc length."""
    pts = [points[0]] + list(points) + [points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for k in range(steps):
            t = k / steps
            t2, t3 = t * t, t * t * t
            v = [0.5 * (2 * p1[j] + (-p0[j] + p2[j]) * t + (2 * p0[j] - 5 * p1[j] + 4 * p2[j] - p3[j]) * t2
                        + (-p0[j] + 3 * p1[j] - 3 * p2[j] + p3[j]) * t3) for j in (0, 1)]
            out.append((v[0], v[1], p1[2] + (p2[2] - p1[2]) * t))
    out.append(points[-1])
    samples = []
    s = 0.0
    for i, (x, y, r) in enumerate(out):
        if i:
            s += math.hypot(x - out[i - 1][0], y - out[i - 1][1])
        samples.append((x, y, r, s))
    return samples


def tube(samples, size):
    """Every pixel inside the tube: its arc length, its surface normal and how far across it lies."""
    xs = [p[0] for p in samples]
    ys = [p[1] for p in samples]
    rmax = max(p[2] for p in samples) + 1
    hits = {}
    for y in range(int(min(ys) - rmax), int(max(ys) + rmax) + 1):
        for x in range(int(min(xs) - rmax), int(max(xs) + rmax) + 1):
            if not (0 <= x < size and 0 <= y < size):
                continue
            px_, py_ = x + 0.5, y + 0.5
            best, arg = 2.0, None
            for i, (sx, sy, r, s) in enumerate(samples):
                d = math.hypot(px_ - sx, py_ - sy) / r
                if d < best:
                    best, arg = d, i
            if best > 1.0:
                continue
            sx, sy, r, s = samples[arg]
            a, b = samples[max(arg - 1, 0)], samples[min(arg + 1, len(samples) - 1)]
            tx, ty = b[0] - a[0], b[1] - a[1]
            tl = math.hypot(tx, ty) or 1.0
            across = (tx * (py_ - sy) - ty * (px_ - sx)) / tl / r
            hits[(x, y)] = (s, (px_ - sx) / r, (py_ - sy) / r, across, r)
    return hits


def draw_body(points, glow=1, wave=0.0, ground=GROUND, pool=None):
    """The plated body along the spine. `glow` 0..2 brightens its seams; `wave` slides the plates
    (the undulation); pixels under the ground (or into the pool) are left out."""
    samples = spline(points)
    total = samples[-1][3]
    body = Canvas(CELL)
    seam = ["S2", "S3", "S4"][glow]
    seam_hot = ["S3", "S4", "Y"][glow]
    for (x, y), (s, nx, ny, across, r) in tube(samples, CELL).items():
        if y > ground or (pool is not None and y > ground - 1 and pool(x)):
            continue
        # Plates count from the neck; their seams bow toward the tail like rings seen from above.
        from_head = total - s + wave - 1.4 * (1.0 - across * across)
        plate = math.floor(from_head / PLATE)
        f = from_head / PLATE - plate
        l = lit(nx, ny) + 0.3 * (math.sin(math.pi * f) - 0.5)
        if f * PLATE < 1.0 and plate >= 0 and s > 3.0:
            c = seam if l < 0.1 else seam_hot
            if l < -0.55:
                c = "S1" if glow == 0 else "S2"
        elif plate in (1, 3) and f > 0.3 and abs((across - CRACKS[plate % len(CRACKS)]) * r) < 0.5 and l > -0.5:
            # a crack from the seam halfway across the plate
            c = seam if f > 0.45 else "B1"
        elif f * PLATE < 2.0 and l < 0.5:
            # the plate's edge just behind a seam sits in the shade of the one before it
            c = "B1" if l > -0.4 else "B0"
        else:
            c = "B4" if l > 0.72 else "B3" if l > 0.3 else "B2" if l > -0.2 else "B1" if l > -0.62 else "B0"
        body.set(x, y, c)
    drop_lone(body)
    return body


# --- the head -----------------------------------------------------------------------------------

def draw_head(hx, hy, mouth=0, blink=False, drip=0, glow=1):
    """The head facing right, centered on (hx, hy). `mouth` 0..3 opens the jaw, `drip` 0..3 is the
    lava dripping from it."""
    head = Canvas(CELL)
    hxi, hyi = int(round(hx)), int(round(hy))
    # a wide gape lifts the snout as well as dropping the jaw
    up = max(mouth - 1, 0)
    lip = hyi + 2 - up                  # row of the mouth's line
    jaw_top = hyi + 3 + mouth           # first row of the lower jaw
    # skull and upper snout
    for y in range(hyi - 7, lip + 1):
        for x in range(hxi - 8, hxi + 12):
            skull = in_ellipse(x, y, hxi + 0.5, hyi + 0.5, 7.0, 6.0)
            snout = in_ellipse(x, y, hxi + 5.5, hyi + 1.0 - up, 5.4, 3.4)
            if not (skull or snout):
                continue
            if skull:
                l = lit((x + 0.5 - hxi - 0.5) / 7.0, (y + 0.5 - hyi - 0.5) / 6.0)
            else:
                l = lit((x + 0.5 - hxi - 5.5) / 5.4, (y + 0.5 - hyi - 1.0 + up) / 3.4) - 0.1
            head.set(x, y, "H4" if l > 0.7 else "H3" if l > 0.3 else "H2" if l > -0.25 else "H1")
    drop_lone(head)
    # knobs on top of the skull
    for dx in (-3, 0):
        head.set(hxi + dx, hyi - 6, "H3")
    # lower jaw
    for y in range(jaw_top, jaw_top + 3):
        for x in range(hxi - 2, hxi + 10):
            if in_ellipse(x, y, hxi + 4.0 - mouth * 0.3, jaw_top + 0.6, 5.6 - mouth * 0.3, 2.1):
                head.set(x, y, "H2" if y == jaw_top else "H1")
    # throat between the jaws
    for y in range(lip + 1, jaw_top):
        for x in range(hxi - 1, hxi + 9 - (y - lip) // 2):
            head.set(x, y, "M")
    if mouth >= 2:
        mid = (lip + jaw_top) // 2
        head.set(hxi, mid, "S4" if glow else "S2")
        head.set(hxi + 1, mid, "S3" if glow else "S1")
        head.set(hxi, mid + 1, "S3" if glow else "S1")
    if mouth == 0:
        for x in range(hxi + 1, hxi + 10):
            if (x, lip) in head.px:
                head.set(x, lip, "O")
        head.set(hxi + 1, lip + 1, "O")
    # fangs: hanging from the upper jaw, one rising from the lower one when it gapes
    for fx in (hxi + 4, hxi + 7):
        head.set(fx, lip + 1, "Y2")
        if mouth >= 2:
            head.set(fx, lip + 2, "Y2")
    if mouth >= 2:
        head.set(hxi + 6, jaw_top - 1, "Y2")
    # nostril, brow and eye
    head.set(hxi + 8, hyi - 1, "H0")
    for x in range(hxi - 1, hxi + 3):
        head.set(x, hyi - 3, "H0")
    if blink:
        head.set(hxi, hyi - 1, "H0")
        head.set(hxi + 1, hyi - 1, "H0")
    else:
        head.set(hxi, hyi - 2, "Y2")
        head.set(hxi + 1, hyi - 2, "Y")
        head.set(hxi, hyi - 1, "Y")
        head.set(hxi + 1, hyi - 1, "O")
    # lava dripping off the jaw
    bottom = jaw_top + 2
    for dx, length in ((2, (1, 2, 3, 2)[drip]), (6, (2, 3, 1, 4)[drip])):
        for k in range(length):
            head.set(hxi + dx, bottom + k, "S3" if k < length - 1 else "S4")
        if length == 1 and drip == 2:
            head.set(hxi + dx, bottom + 3, "S4")   # a drop that broke off
    return head


def draw_worm(p):
    points, (hx, hy) = p["shape"]
    points = [(x + p["dx"][i] if i < len(p["dx"]) else x, y + p["dy"][i] if i < len(p["dy"]) else y, r)
              for i, (x, y, r) in enumerate(points)]
    hx, hy = hx + p["hdx"], hy + p["hdy"]
    # the neck reaches into the head
    points = points + [(hx - 3.0, hy + 0.5, points[-1][2] - 0.5)]
    if p["sink"]:
        points = [(x, y + p["sink"], r) for x, y, r in points]
        hy += p["sink"]
    pool_rx = p["pool"]
    pool_cx = p["pool_x"]
    in_pool = (lambda x: abs(x + 0.5 - pool_cx) < pool_rx - 1) if pool_rx else None
    worm = Canvas(CELL)
    if p["cracks"]:
        worm.over(ground_cracks(pool_cx, *p["cracks"]))
    if p["mound"]:
        worm.over(mound(pool_cx, p["mound"]))
    if pool_rx:
        worm.over(lava_pool(pool_cx, pool_rx, p["pool_cool"], p["phase"], back=True))
    if p["body"]:
        body = draw_body(points, glow=p["glow"], wave=p["wave"], pool=in_pool)
        head = draw_head(hx, hy, mouth=p["mouth"], blink=p["blink"], drip=p["drip"], glow=p["glow"])
    else:
        body, head = Canvas(CELL), Canvas(CELL)
    head.px = {(x, y): c for (x, y), c in head.px.items() if y <= GROUND}
    # where the head meets the body, a dark inner line instead of a second outline
    for (x, y), c in list(head.px.items()):
        if c.startswith("H") and any(n in body.px and n not in head.px
                                     for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))):
            head.px[(x, y)] = "L" if x < hx else "H0"
    body.over(head)
    for step in COOL_STEPS[:p["cool"]]:
        body.remap(step)
    worm.over(body)
    worm.outline()
    if pool_rx:
        front = lava_pool(pool_cx, pool_rx, p["pool_cool"], p["phase"], back=False)
        front.outline("S0", only_empty_of=worm)
        worm.over(front)
    if p["rim"]:
        worm.over(broken_rim(pool_cx, pool_rx, p["rim"], worm))
    if p["flash"]:
        worm.remap({c: "W" for c in PALETTE if c not in ("O", "L", "M")})
    if p["flames"]:
        back, front_fire = flames(p["flames"], p["phase"], pool_cx, pool_rx or 14)
        back.outline("S0")
        back.over(worm)
        worm = back
        front_fire.outline("S0", only_empty_of=worm)
        worm.over(front_fire)
    if p["splash"]:
        back, front_jets = splash(p["splash"], p["pool_x"], max(pool_rx, 6))
        back.outline("S0")
        back.over(worm)
        worm = back
        front_jets.outline("S0", only_empty_of=worm)
        worm.over(front_jets)
    add_fx(worm, p["fx"])
    add_rocks(worm, p["rocks"])
    return worm


def lava_pool(cx, rx, cool, phase, back):
    """The pool the worm rises from: its far half behind the body, its near lip in front of it."""
    c = Canvas(CELL)
    ry = 3.0
    for y in range(GROUND - 3, GROUND + 4):
        if back != (y < GROUND):
            continue
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if not in_ellipse(x, y, cx, GROUND + 0.5, rx, ry):
                continue
            q = math.hypot((x + 0.5 - cx) / rx, (y - GROUND) / ry)
            col = "S1" if q > 0.85 else "S2" if q > 0.62 else "S3" if q > 0.3 else "S4"
            if not back and y == GROUND and (x + phase * 3) % 7 == 0:
                col = "Y"
            if cool >= 2:
                col = ("S3" if cool == 2 else "S1") if (x * 5 + y * 3) % 11 == 0 else ("S1" if cool == 2 else "B1")
            c.set(x, y, col)
    if cool == 1:
        c.remap(COOL_STEPS[0])
    if back:
        c.outline("S0")
    return c


def flame_tongue(c, x, h, lean, ground=GROUND):
    """One tongue of fire rising from the ground, `h` px tall, white at its root, red at its tip."""
    for k in range(h):
        y = ground - k
        f = k / max(h, 1)
        if f < 0.35:
            cols = ("Y", "Y2", "Y")
        elif f < 0.65:
            cols = ("S4", "Y", "S4")
        else:
            cols = ("S3", "S4", "S3")
        width = 3 if f < 0.5 else 2 if f < 0.8 else 1
        xs = [x - 1, x, x + 1] if width == 3 else ([x, x + lean] if width == 2 else [x + lean])
        for i, xx in enumerate(xs):
            c.set(xx, y, cols[1] if width == 1 else cols[min(i + (3 - width), 2)])


FLAME_HEIGHTS = [1.0, 0.6, 0.85, 0.5, 0.95, 0.7]


def flames(height, shift, cx, rx):
    """The eruption: tongues of lava fire around the pool, tall behind the worm, short in front."""
    back, front = Canvas(CELL), Canvas(CELL)
    x0, x1 = int(cx - rx) + 3, int(cx + rx) - 1
    for i, x in enumerate(range(x0, x1, 4)):
        edge = 1.0 - abs(x - cx) / (rx + 2)
        h = int(round(height * FLAME_HEIGHTS[(i + shift) % len(FLAME_HEIGHTS)] * (0.5 + 0.5 * edge)))
        # the splash flies outward from where the body breaks the surface
        out = -1 if x < cx else 1
        if h >= 1:
            flame_tongue(back, x, h, out, GROUND - 1)
        hf = int(round(height * 0.45 * FLAME_HEIGHTS[(i + shift + 3) % len(FLAME_HEIGHTS)]))
        if hf >= 1 and (i + shift) % 2 == 0:
            flame_tongue(front, x + 2, hf, out, GROUND + 2)
    return back, front


## Directions of the cracks that run out from where it breaks the floor (seen flat: half as tall).
CRACK_RAYS = [(-1.0, 0.0, 1.0), (-0.6, -0.8, 0.7), (0.15, -1.0, 0.6), (0.75, -0.65, 0.8), (1.0, 0.1, 1.0),
              (0.55, 0.85, 0.55), (-0.5, 0.9, 0.6)]


def ground_cracks(cx, length, glow):
    """Glowing cracks spreading over the floor from (cx, GROUND): `length` px long, `glow` 0..2."""
    c = Canvas(CELL)
    hot, warm, cool = (("S3", "S2", "S1"), ("S4", "S3", "S2"), ("Y", "S4", "S3"))[glow]
    for i, (dx, dy, k) in enumerate(CRACK_RAYS):
        n = int(length * k)
        pts = []
        for t in range(n + 1):
            # each crack zigzags a little as it goes
            wob = 0.6 * math.sin(t * 1.3 + i * 2.1)
            pts.append((math.floor(cx + dx * t - dy * wob), math.floor(GROUND + 0.5 + (dy * t + dx * wob) * 0.5)))
        for j, (x, y) in enumerate(pixel_perfect(pts)):
            c.set(x, y, hot if j < n * 0.35 else warm if j < n * 0.7 else cool)
    for x in range(int(cx) - 1, int(cx) + 2):
        c.set(x, GROUND, hot)
    c.outline("S0")
    return c


def mound(cx, h):
    """The floor bulging over the worm: plates of stone pushed up, lava showing in their joints."""
    c = Canvas(CELL)
    rx = 6 + h
    for y in range(GROUND - h - 1, GROUND + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if not in_ellipse(x, y, cx, GROUND + 1.0, rx, h + 1.5):
                continue
            nx, ny = (x + 0.5 - cx) / rx, (y - GROUND - 1.0) / (h + 1.5)
            l = lit(nx, ny)
            col = "G3" if l > 0.6 else "G2" if l > 0.15 else "G1" if l > -0.3 else "G0"
            # joints between the plates: a cross of lava through the top
            if abs(x + 0.5 - cx - (y - GROUND) * 0.4) < 0.6 or (y == GROUND - h // 2 and abs(x + 0.5 - cx) < rx * 0.7):
                col = "Y" if abs(x + 0.5 - cx) < 2 else "S4"
            c.set(x, y, col)
    c.outline()
    return c


def broken_rim(cx, rx, size, worm):
    """Slabs of the broken floor tipped up around the hole, in front of the worm and the pool."""
    c = Canvas(CELL)
    for side in (-1, 1):
        x0 = int(cx + side * (rx - 1))
        for k in range(size):
            for j in range(3):
                x = x0 + side * j
                y = GROUND + 1 - k + (j if side > 0 else 2 - j) // 2
                c.set(x, y, "G2" if k == size - 1 else "G1" if j else "G3")
    c.outline(only_empty_of=worm)
    return c


## Jets of the splash on each side of the hole: (where across the hole, height, how far it bends out).
JETS = [(0.2, 1.0, 0.45), (0.5, 0.75, 0.8), (0.85, 0.55, 1.2), (1.1, 0.3, 1.6)]


def splash(height, cx, rx):
    """The lava thrown up as it breaks the floor: jets bending outward from the hole, white-hot at
    their root, a drop flying off each tip; the near ones (shorter) go in front of the body."""
    back, front = Canvas(CELL), Canvas(CELL)
    for side in (-1, 1):
        for i, (across, tall, bend) in enumerate(JETS):
            h = max(2, int(round(height * tall)))
            x0 = cx + side * rx * across
            near = i == 1
            target = front if near else back
            h = h * 2 // 3 if near else h
            base = GROUND + (2 if near else -1)
            tip = None
            for k in range(h):
                f = k / h
                x = int(round(x0 + side * bend * h * 0.35 * f * f))
                y = base - k
                cols = ("Y2", "Y") if f < 0.3 else ("Y", "S4") if f < 0.65 else ("S4", "S3")
                target.set(x, y, cols[0])
                if f < 0.75:
                    target.set(x + side, y, cols[1])
                tip = (x, y)
            if tip is not None and h >= 5:
                # the drop that breaks off the jet's tip
                dx, dy = tip[0] + side * 2, tip[1] - 2
                target.set(dx, dy, "Y")
                target.set(dx + side, dy, "S4")
                target.set(dx, dy - 1, "S4")
    return back, front


def add_rocks(canvas, rocks):
    """Chunks of the floor thrown up by the burst: (x, y, size) with size 2 or 3, lit top-left."""
    if not rocks:
        return
    c = Canvas(canvas.size)
    for x, y, size in rocks:
        for dy in range(size - (size == 3)):
            for dx in range(size):
                c.set(x + dx, y + dy, "G3" if dx == 0 and dy == 0 else "G2" if dx + dy < size else "G1")
        if size == 3:
            c.set(x + 1, y + 2, "G1")
    c.outline()
    canvas.over(c)


def add_fx(canvas, fx):
    """Lava drops and sparks: (x, y, size, color); size 1 is one pixel, 2 a 2x2 drop."""
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
    drops.outline(only_empty_of=canvas)
    canvas.over(drops)


def pose(**kw):
    p = dict(shape=REST, dx=(), dy=(), hdx=0, hdy=0, mouth=0, blink=False, drip=0, glow=1, wave=0.0,
             flash=False, cool=0, sink=0, pool=14, pool_x=17.0, pool_cool=0, flames=0, phase=0, fx=(),
             body=True, cracks=None, mound=0, rim=0, rocks=(), splash=0)
    p.update(kw)
    return p


# --- animations -----------------------------------------------------------------------------

def idle():
    # It sways from the pool up, the head bobbing a beat later; the lava drips off its jaw.
    sway = [0, 0.6, 1.0, 0.6, 0, -0.5]
    bob = [0, 0, -1, -1, 0, 0]
    frames = []
    for i in range(6):
        w = [0, 0, 0.2, 0.5, 0.8, 1.0]
        frames.append(pose(dx=[sway[i] * k for k in w], dy=[0, 0, 0, 0, bob[i] * 0.5, bob[i]],
                           hdx=round(sway[i]), hdy=bob[(i + 5) % 6], drip=i % 4, glow=2 if i in (2, 3) else 1,
                           blink=i == 4, phase=i))
    return frames


def walk():
    # It undulates: a wave runs up the body toward the head and the plates slide along it.
    frames = []
    for i in range(8):
        ph = i / 8 * math.tau
        dx = [0] + [0.9 * math.sin(ph - 1.1 * k) for k in range(1, 6)]
        dy = [0.6 * math.cos(ph)] + [1.1 * math.cos(ph - 1.1 * k) for k in range(1, 6)]
        frames.append(pose(dx=dx, dy=dy, hdx=round(dx[-1]), hdy=round(dy[-1]), wave=i * PLATE / 8,
                           drip=(i // 2) % 4, phase=i))
    return frames


def attack():
    # Played over the surge, from its reared stance (special's last frame): it lunges forward with
    # its jaws wide, snaps them shut in a splash of lava, then pulls back up to rest.
    mx = 58
    return [
        # the body pours out of the hole and lays itself forward along the lunge
        pose(shape=blend(RISEN_REAR, LUNGE, 0.35), pool=12, pool_x=27.0, mouth=3, drip=0, glow=2),
        pose(shape=blend(RISEN_REAR, LUNGE, 0.75), pool=13, pool_x=21.0, mouth=3, drip=1, glow=2),
        pose(shape=LUNGE, hdx=1, mouth=3, drip=2, glow=2),
        pose(shape=LUNGE, hdy=2, mouth=0, drip=0, glow=2,
             fx=[(mx - 3, GROUND - 4, 2, "Y"), (mx + 1, GROUND - 6, 2, "S4"), (mx - 7, GROUND - 5, 1, "Y"),
                 (mx + 3, GROUND - 2, 1, "S4")]),
        pose(shape=LUNGE, hdy=1, mouth=1, drip=1, glow=2,
             fx=[(mx - 4, GROUND - 10, 2, "S4"), (mx + 2, GROUND - 12, 2, "Y"), (mx - 8, GROUND - 7, 1, "S4"),
                 (mx + 4, GROUND - 5, 1, "S3")]),
        pose(shape=blend(LUNGE, REST, 0.4), mouth=1, drip=3,
             fx=[(mx - 3, GROUND - 8, 1, "S3"), (mx + 2, GROUND - 6, 2, "S3"), (mx - 7, GROUND - 2, 1, "S2")]),
        pose(shape=blend(LUNGE, REST, 0.75), drip=0, fx=[(mx + 1, GROUND - 2, 1, "S3")]),
        pose(drip=1),
    ]


def special():
    # Bursts out of the ground over the hole at HOLE_X: the floor cracks, bulges, breaks in rocks and
    # a crown of lava, the head shoots out of the hole and the body follows until it rears up roaring
    # (where the attack's lunge starts). Played backwards it dives back into the hole.
    hx = float(HOLE_X)
    h = HOLE_X
    return [
        pose(body=False, pool=0, pool_x=hx, cracks=(8, 0), fx=[(h + 3, GROUND - 3, 1, "S4")]),
        pose(body=False, pool=0, pool_x=hx, cracks=(9, 1), mound=3,
             fx=[(h - 2, GROUND - 7, 1, "Y"), (h + 5, GROUND - 6, 1, "S4")]),
        pose(body=False, pool=8, pool_x=hx, cracks=(11, 2), splash=12, glow=2, phase=0, rim=2,
             rocks=[(h - 10, GROUND - 7, 3), (h + 8, GROUND - 9, 2), (h - 4, GROUND - 13, 2), (h + 3, GROUND - 15, 2)],
             fx=[(h - 7, GROUND - 11, 1, "Y"), (h + 6, GROUND - 13, 1, "S4")]),
        pose(shape=EMERGE, sink=20, pool=10, pool_x=hx, cracks=(12, 2), splash=20, flames=6, glow=2, mouth=2, phase=1, rim=3,
             rocks=[(h - 15, GROUND - 12, 3), (h + 13, GROUND - 16, 2), (h - 8, GROUND - 22, 2), (h + 7, GROUND - 25, 2)],
             fx=[(h - 11, GROUND - 17, 2, "Y"), (h + 10, GROUND - 20, 1, "S4"), (h + 2, GROUND - 27, 1, "Y")]),
        pose(shape=EMERGE, sink=9, pool=11, pool_x=hx, cracks=(12, 2), splash=22, flames=8, glow=2, mouth=2, drip=1, phase=2,
             rim=3, rocks=[(h - 19, GROUND - 9, 3), (h + 17, GROUND - 12, 2), (h - 12, GROUND - 25, 2),
                           (h + 13, GROUND - 28, 2)],
             fx=[(h - 15, GROUND - 20, 2, "S4"), (h + 16, GROUND - 22, 1, "Y"), (h + 5, GROUND - 33, 1, "Y")]),
        pose(shape=blend(EMERGE, RISEN, 0.6), sink=3, pool=11, pool_x=hx, cracks=(11, 1), splash=12, flames=7, glow=2, mouth=3,
             drip=2, phase=3, rim=3,
             rocks=[(h - 21, GROUND - 2, 3), (h + 20, GROUND - 4, 2), (h - 16, GROUND - 17, 2), (h + 17, GROUND - 19, 2)],
             fx=[(h - 18, GROUND - 11, 2, "S4"), (h + 19, GROUND - 13, 1, "S4"), (6, 14, 1, "Y")]),
        pose(shape=RISEN, pool=11, pool_x=hx, cracks=(10, 1), flames=5, glow=2, mouth=3, drip=3, phase=4, rim=3,
             rocks=[(h - 21, GROUND - 1, 3), (h + 20, GROUND - 1, 2), (h - 18, GROUND - 8, 2), (h + 19, GROUND - 9, 2)],
             fx=[(h - 20, GROUND - 3, 1, "S3"), (h + 21, GROUND - 5, 1, "S3")]),
        pose(shape=RISEN_REAR, pool=11, pool_x=hx, cracks=(9, 0), flames=2, glow=2, mouth=3, drip=0, phase=5,
             rim=3, rocks=[(h - 21, GROUND - 1, 3), (h + 20, GROUND - 1, 2), (h - 19, GROUND - 1, 2),
                           (h + 18, GROUND - 2, 2)]),
    ]


def hurt():
    return [
        pose(flash=True, hdx=-1),
        pose(shape=blend(REST, REAR, 0.3), hdx=-3, hdy=2, dx=[0, 0, -0.5, -1, -1.5, -2], mouth=1, blink=True),
        pose(hdx=-1, hdy=1, mouth=1, drip=1),
        pose(drip=2),
    ]


def death():
    # It slumps forward onto the lava, sinks into its pool and the pool crusts over.
    return [draw_worm(p) for p in (
        pose(shape=blend(REST, ARC, 0.4), mouth=2, blink=True, drip=1),
        pose(shape=ARC, mouth=2, blink=True, drip=2, cool=1),
        pose(shape=blend(ARC, LYING, 0.6), mouth=1, blink=True, cool=1, pool=18, pool_x=24.0),
        pose(shape=LYING, mouth=1, blink=True, cool=2, pool=22, pool_x=27.0),
        pose(shape=LYING, blink=True, cool=2, sink=3, pool=24, pool_x=28.0, pool_cool=1),
        pose(shape=LYING, blink=True, cool=3, sink=6, pool=25, pool_x=28.0, pool_cool=1),
        pose(shape=LYING, blink=True, cool=3, sink=40, pool=25, pool_x=28.0, pool_cool=2),
        pose(shape=LYING, cool=3, sink=40, pool=24, pool_x=28.0, pool_cool=3),
    )]


# --- the body pieces and the ripple ---------------------------------------------------------------

def segment(scale, wave):
    """A hump of body out of the ground: it rises from a little lava hole and dives into another."""
    a, b, r = 5.2 * scale, 6.6 * scale, 4.6 * scale
    cx = SEGMENT_CELL / 2
    points = []
    for k in range(9):
        t = math.pi * (1 - k / 8)
        points.append((cx + a * math.cos(t), SEGMENT_GROUND + 1 - b * math.sin(t), r))
    piece = Canvas(SEGMENT_CELL)
    samples = spline(points, steps=8)
    total = samples[-1][3]
    for (x, y), (s, nx, ny, across, rr) in tube(samples, SEGMENT_CELL).items():
        if y > SEGMENT_GROUND:
            continue
        along = s + wave - 1.0 * (1.0 - across * across)
        plate = math.floor(along / PLATE)
        f = along / PLATE - plate
        l = lit(nx, ny) + 0.3 * (math.sin(math.pi * f) - 0.5)
        if f * PLATE < 1.0 and 0 < s < total:
            c = "S3" if l > 0.1 else "S2" if l > -0.55 else "S1"
        elif f * PLATE < 2.0 and l < 0.5:
            c = "B1" if l > -0.4 else "B0"
        else:
            c = "B4" if l > 0.72 else "B3" if l > 0.3 else "B2" if l > -0.2 else "B1" if l > -0.62 else "B0"
        piece.set(x, y, c)
    drop_lone(piece)
    piece.outline()
    # the lava holes at both ends, their near lip over the body
    holes = Canvas(SEGMENT_CELL)
    for hx in (cx - a, cx + a):
        for y in range(SEGMENT_GROUND - 1, SEGMENT_GROUND + 3):
            for x in range(int(hx - r) - 2, int(hx + r) + 3):
                if in_ellipse(x, y, hx, SEGMENT_GROUND + 0.5, r + 1.6, 1.8):
                    q = abs(x + 0.5 - hx) / (r + 1.6)
                    holes.set(x, y, "S4" if q < 0.3 and y >= SEGMENT_GROUND else "S3" if q < 0.65 else "S2")
    holes.outline("S0", only_empty_of=piece)
    for (x, y), c in holes.px.items():
        if y >= SEGMENT_GROUND or (x, y) not in piece.px:
            piece.px[(x, y)] = c
    return piece


def ripple(frame, frames=12):
    """The ground stirring over the burrowed worm: rings of lava that spread and darken as they go,
    around a cracked mound that glows (same rings, radius and timing as the code drew)."""
    c = Canvas(RIPPLE_CELL)
    cx, cy = RIPPLE_CELL / 2, RIPPLE_CELL / 2
    for i in range(3):
        p = (frame / frames + i / 3) % 1.0
        rx = 9.0 * (0.3 + p)
        ry = rx * 0.5
        col = "Y" if p < 0.2 else "S4" if p < 0.42 else "S3" if p < 0.64 else "S2" if p < 0.84 else "S1"
        if p < 0.12:
            continue  # still too small to read as a ring: the mound is enough
        n = 200
        ring = pixel_perfect([(math.floor(cx + rx * math.cos(k / n * math.tau)),
                               math.floor(cy + ry * math.sin(k / n * math.tau))) for k in range(n)])
        for k, (x, y) in enumerate(ring):
            # the far ring fades: past the middle only every other pixel stays
            if p > 0.64 and k % 2:
                continue
            c.set(x, y, col)
    # the mound: rock cracking open with lava under it
    for x, y, col in ((-2, 0, "B1"), (-1, 0, "B2"), (0, 0, "S3"), (1, 0, "B2"), (2, 0, "B1"),
                      (-1, -1, "B3"), (0, -1, "B2"), (1, -1, "S2"), (-1, 1, "B0"), (0, 1, "B1"), (1, 1, "B0")):
        c.set(int(cx) + x, int(cy) + y, col)
    c.set(int(cx), int(cy), "Y" if frame % 4 < 2 else "S4")
    return c


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
        strip([draw_worm(p) for p in make()], os.path.join(OUT, "gusano_puentes_%s.png" % name))
    strip(death(), os.path.join(OUT, "gusano_puentes_death.png"))
    # one piece per body segment, from the one behind the head to the tail (thinner)
    strip([segment(s, w) for s, w in ((1.0, 0.0), (0.9, 1.5), (0.8, 3.0), (0.7, 4.5))],
          os.path.join(OUT, "gusano_puentes_segment.png"))
    strip([ripple(i) for i in range(12)], os.path.join(OUT, "gusano_puentes_ripple.png"))
