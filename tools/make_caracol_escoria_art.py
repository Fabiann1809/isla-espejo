"""Draws the Caracol de escoria's art (temple enemy, island 3) pixel by pixel.

The bestiary pack's snail, scaled from 128 px down to the game, came out blurred (area averaging
smears its outline and its spiral), so this snail is drawn at the game's own pixel size instead,
following the pack's sheet: a big round red-hot shell with a thin bright yellow spiral glowing on it
(what reads first), a solid block of mauve slag for a head with a horn swept back, a sunken yellow
eye and heavy gold jaw plates, a squat
body, all of it sitting in a puddle of lava. It is built from a few parts (pool, shell, body, head)
that each animation moves frame by frame, as in the pack's sheet: idle, move, attack (spits a ball
of lava), special (the shell sinks into the ground and a ring of fire bursts from the pool at ground
level), hurt and death (it melts down into a crust of slag). It also draws the lava patch of its
burning trail (GroundHazard.art).

Writes into `assets/sprites/caracol_escoria/`:
    caracol_escoria_<animation>.png   64x64 cells, facing right, feet (the pool's last row) on
                                      row 53: idle, walk, attack, special, hurt, death
    caracol_escoria_trail.png         24x24 cells: 3 spawn, 4 burning (loop), 4 cooling

    python tools/make_caracol_escoria_art.py
Then tools/make_temple_enemy_frames.gd builds its SpriteFrames as for every temple enemy, and
tools/enemy_aseprite.lua keeps an editable `source/caracol_escoria.aseprite`
(extras="trail:8:spawn=1-3;burn=4-7;cool=8-11").
Needs Pillow.
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "caracol_escoria")
CELL = 64
TRAIL_CELL = 24
## Last row of the lava pool it sits in; its outline goes on the row below.
GROUND = 53

PALETTE = {
    "O": (26, 10, 14),     # outline
    "L": (66, 14, 18),     # inner line (shell against head and body)
    # shell and lava
    "S0": (62, 10, 14),
    "S1": (122, 18, 18),
    "S2": (196, 34, 12),
    "S3": (240, 70, 10),
    "S4": (247, 124, 20),
    "Y": (252, 188, 44),
    "Y2": (255, 240, 140),
    # head: mauve slag
    "B0": (50, 24, 34),
    "B1": (88, 46, 60),
    "B2": (134, 84, 96),
    "B3": (176, 128, 132),
    "B4": (214, 174, 170),
    # body: darker, redder slag
    "R1": (78, 22, 32),
    "R2": (122, 42, 52),
    "R3": (164, 74, 80),
    # gold jaw and horn tips
    "G0": (112, 64, 14),
    "G1": (196, 136, 28),
    "G2": (246, 208, 92),
    "W": (255, 243, 224),  # hurt flash
}
## Death: each step cools the lava and dims the slag.
COOL_STEPS = [
    {"Y2": "Y", "Y": "S4", "S4": "S3", "S3": "S2", "G2": "G1"},
    {"Y": "S3", "S4": "S2", "S3": "S2", "S2": "S1", "B4": "B3", "B3": "B2", "R3": "R2", "G1": "G0"},
    {"S3": "S1", "S2": "S1", "S1": "S0", "B3": "B2", "B2": "B1", "R3": "R2", "R2": "R1", "G0": "B1"},
]
## The special and the hurt: the shell turns white-hot.
BLAZE = {"S0": "S1", "S1": "S2", "S2": "S3", "S3": "S4", "S4": "Y", "Y": "Y2"}

## Rest pose (cell coordinates).
SHELL = (24.5, 37.5, 12.0)          # center x, center y, radius
## The spiral's eye sits low and back in the shell, as in the pack.
SPIRAL_EYE = (-1.2, 1.0)
SPIRAL_PITCH = 3.8                  # px between the turns of its line
HEAD = (43.0, 32.5, 6.0, 7.0)       # center x, center y, half width, half height
BODY = (39.5, 45.0, 7.5, 8.0)       # center x, center y, radius x, radius y
POOL = (29.5, 51.5, 19.0, 2.6)      # center x, center y, radius x, radius y
## Lava ball (spit): 5x5, relative to its top-left corner.
BALL = {(1, 0): "Y2", (2, 0): "Y", (3, 0): "S4",
        (0, 1): "Y2", (1, 1): "Y2", (2, 1): "Y", (3, 1): "Y", (4, 1): "S4",
        (0, 2): "Y", (1, 2): "Y", (2, 2): "Y", (3, 2): "S4", (4, 2): "S3",
        (0, 3): "S4", (1, 3): "Y", (2, 3): "S4", (3, 3): "S3", (4, 3): "S2",
        (1, 4): "S3", (2, 4): "S3", (3, 4): "S2"}


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

    def shifted(self, dx, dy, clip_below=None):
        c = Canvas(self.size)
        for (x, y), col in self.px.items():
            if clip_below is None or y + dy <= clip_below:
                c.set(x + dx, y + dy, col)
        return c

    def lone_pixels_off(self):
        """No single pixel sticking out of a rim."""
        for (x, y) in list(self.px):
            if sum(n in self.px for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))) <= 1:
                del self.px[(x, y)]

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


# --- the snail ---------------------------------------------------------------------------------

def pose(**kw):
    p = dict(sdx=0, sdy=0, squash=0, hdx=0, hdy=0, bdx=0, front=0, back=0, mouth=0, glob=0,
             blink=False, glow=1, spin=0.0, blaze=False, phase=0, flash=False, cool=0, sink=0,
             head_in=0, pool=None, pool_ry=None, pool_glow=1, pool_cool=0, fire=0, slag=None, fx=())
    p.update(kw)
    return p


def draw_shell(p):
    """The round shell: dark, saturated red-hot stone shaded for volume (darker low and right),
    with one thin bright spiral line glowing on it from its pale eye out to the rim (Archimedean,
    so its turns keep one spacing and read as a spiral, not rings)."""
    cx, cy, r = SHELL
    cx += p["sdx"]
    cy += p["sdy"]
    ry = r - p["squash"]
    ecx, ecy = cx + SPIRAL_EYE[0], cy + SPIRAL_EYE[1] * ry / r
    shell = Canvas(CELL)
    glow = p["glow"]
    line_lit = ["S4", "Y", "Y", "Y2"][glow]
    line_dark = ["S3", "S4", "Y", "Y"][glow]
    core = ["Y", "Y2", "Y2", "Y2"][glow]
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            if not in_ellipse(x, y, cx, cy, r, ry):
                continue
            nx, ny = (x + 0.5 - cx) / r, (y + 0.5 - cy) / ry
            l = lit(nx, ny)
            q = math.hypot(nx, ny)
            base = "S3" if l > 0.75 else "S2" if l > -0.2 else "S1"
            if q > 0.84 and l < 0.2:
                base = "S1" if l > -0.4 else "S0"
            dx, dy = x + 0.5 - ecx, (y + 0.5 - ecy) * r / ry
            d = math.hypot(dx, dy)
            ang = (math.atan2(dy, dx) + p["spin"]) % math.tau
            ph = (d - SPIRAL_PITCH * ang / math.tau) % SPIRAL_PITCH
            col = base
            if d < 1.0:
                col = core
            elif d < 2.0:
                # the spiral's eye glows a little around it
                col = line_lit if l > -0.3 else line_dark
            elif ph < 0.85 + 0.6 * d / r and q < 0.92:
                # the line widens as it winds out, so it reads as a spiral and not as rings
                col = line_lit if l > -0.15 else line_dark
            shell.set(x, y, col)
    shell.lone_pixels_off()
    if p["blaze"]:
        shell.remap(BLAZE)
    return shell


def draw_head(p):
    """A solid block of slag, wider at the jaw: one horn sweeping back over the shell with a gold
    tip, a dark brow over a sunken yellow eye, and heavy gold plates on the jaw."""
    hx, hy, hw, hh = HEAD
    hx += p["hdx"]
    hy += p["hdy"] + p["head_in"]
    hxi, hyi = int(hx), int(hy)
    head = Canvas(CELL)
    top = int(hy - hh)
    bottom = int(hy + hh)
    # The horn first, so the head's outline closes over its root: it rises from the back of the
    # crown and curls back over the shell.
    for (dx, dy, c) in ((-1, 0, "B3"), (-2, 0, "B2"), (-2, -1, "B4"), (-3, -1, "B3"), (-4, -1, "B2"),
                        (-3, 0, "B1"), (-4, -2, "B4"), (-5, -2, "B3"), (-5, -1, "B1"), (-6, -2, "G1"),
                        (-6, -1, "G0"), (-7, -2, "G2"), (-7, -1, "G1"), (-8, -1, "G2"), (-8, 0, "G1"),
                        (-9, 0, "G0"), (-9, 1, "G1")):
        head.set(hxi + dx, top + dy, c)
    for y in range(top, bottom + 1):
        t = (y - top) / max(1, bottom - top)
        left = hx - hw + 0.5 - 1.5 * t       # its back swells toward the jaw
        right = hx + hw - 0.5 + 0.8 * t
        for x in range(int(left) - 1, int(right) + 2):
            if not (left <= x + 0.5 <= right + 1):
                continue
            # round off the crown's corners
            if y == top and (x + 0.5 < left + 1.5 or x + 0.5 > right - 0.5):
                continue
            nx = (x + 0.5 - (left + right + 1) / 2) / ((right + 1 - left) / 2)
            ny = (y + 0.5 - hy) / hh
            l = lit(nx, ny)
            head.set(x, y, "B4" if l > 0.65 else "B3" if l > 0.15 else "B2" if l > -0.45 else "B1")
    # cracks of the slag on the crown and the cheek
    for (dx, dy) in ((-2, -5), (-1, -4), (-1, -3), (-4, 1), (-4, 2)):
        head.set(hxi + dx, hyi + dy, "B1")
    # A heavy brow, then the eye sunk under it.
    ex, ey = hxi, hyi - 2
    for x in range(ex - 2, ex + 4):
        head.set(x, ey - 1, "B0")
    head.set(ex - 1, ey, "B1")
    head.set(ex + 2, ey, "B1")
    if p["blink"]:
        head.set(ex, ey + 1, "B0")
        head.set(ex + 1, ey + 1, "B0")
    else:
        head.set(ex, ey, "Y2")
        head.set(ex + 1, ey, "Y")
        head.set(ex, ey + 1, "G1")
        head.set(ex + 1, ey + 1, "G0")
    # The snout's nostril.
    head.set(hxi + 5, hyi, "B1")
    # Mouth (a dark slit that opens) over a heavy gold jaw jutting past the face, bolted on by a
    # gold plate at its hinge.
    m = hyi + 3
    gap = p["mouth"]
    for dy in range(gap + 1):
        for x in range(hxi - 1, hxi + 8):
            if (x, m + dy) in head.px or dy > 0:
                head.set(x, m + dy, "O")
    if gap:
        head.set(hxi + 1, m + 1, "S2")
        head.set(hxi + 2, m + gap, "S3")
    jy = m + gap + 1
    for x in range(hxi - 2, hxi + 9):
        head.set(x, jy, "G2" if x % 2 == 0 else "G1")
        if x < hxi + 8:
            head.set(x, jy + 1, "G1")
        if hxi - 2 < x < hxi + 7:
            head.set(x, jy + 2, "G0")
    for (dx, dy, c) in ((-4, -1, "G2"), (-3, -1, "G1"), (-4, 0, "G1"), (-3, 0, "G1"), (-4, 1, "G0"),
                        (-3, 1, "G0")):
        head.set(hxi + dx, m + dy, c)
    if p["glob"] == 1:
        head.set(hxi + 6, m + 1, "S4")
        head.set(hxi + 7, m + 1, "Y")
    elif p["glob"] == 2:
        for dx, dy, c in ((5, 1, "Y"), (6, 1, "Y2"), (7, 1, "Y"), (8, 1, "S4"), (6, 0, "S4"), (6, 2, "S4")):
            head.set(hxi + dx, m + dy, c)
    return head


def draw_body(p):
    """The squat body under the head, spreading forward into the pool."""
    bx, by, brx, bry = BODY
    bx += p["bdx"]
    body = Canvas(CELL)
    for y in range(int(by - bry) - 1, GROUND + 1):
        for x in range(int(bx - brx) - 1, int(bx + brx) + 3 + p["front"]):
            # a rounded hump that widens at the foot
            w = brx + max(0.0, (y + 0.5 - by)) * 0.4 + (p["front"] if y > by else 0)
            nx, ny = (x + 0.5 - bx) / w, (y + 0.5 - by) / bry
            if nx * nx + min(ny, 0.0) ** 2 > 1.0:
                continue
            l = lit(nx, ny)
            body.set(x, y, "R3" if l > 0.45 else "R2" if l > -0.25 else "R1")
    # lava showing through cracks of its skin
    for (dx, dy, c) in ((-3, 2, "S3"), (-2, 3, "S4"), (2, 1, "S2"), (3, 2, "S3")):
        body.set(int(bx) + dx, int(by) + dy, c)
    return body


def lava_pool(cx, cy, rx, ry, glow, phase, cool=0, tail=False):
    """The molten puddle it sits in: a bright rim where the lava swells, a dark underside, and
    hot streaks that crawl along it."""
    c = Canvas(CELL)
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            wob = 0.07 * math.sin(x * 0.9 + phase * 1.7)
            if dx * dx + dy * dy > 1.0 + wob:
                continue
            # the swell of its surface: a few dips along the top so it never reads as a plank
            if dy < -0.45 and (x * 7 + phase) % 9 in (0, 4) and abs(dx) < 0.85:
                continue
            if dy < -0.45:
                col = "Y" if glow >= 1 else "S4"
            elif dy < 0.1:
                col = "S4" if glow >= 1 else "S3"
            elif dy < 0.6:
                col = "S3" if abs(dx) < 0.8 else "S2"
            else:
                col = "S1"
            c.set(x, y, col)
    # hot streaks
    for k in range(4):
        sx = int(cx - rx * 0.75 + ((k * 11 + phase * 3) % int(rx * 1.5)))
        sy = int(cy - ry * 0.2)
        for d in range(2 + k % 2):
            if (sx + d, sy) in c.px:
                c.set(sx + d, sy, "Y2" if glow >= 2 or d == 0 else "Y")
    c.lone_pixels_off()
    if tail:
        # the lava curls up at its back end, like the tip of a tail
        tx = int(cx - rx) + 1
        for (dx, dy, col) in ((0, -1, "S4"), (-1, -2, "Y"), (-1, -3, "S4"), (0, -4, "S3"), (1, -4, "S2")):
            c.set(tx + dx, int(cy) + dy, col)
    if cool == 1:
        c.remap(COOL_STEPS[0])
    elif cool >= 2:
        crust, crack = ("S1", "S3") if cool == 2 else ("B1", "S1")
        for q in c.px:
            c.px[q] = crust
        for k in range(5):
            sx = int(cx - rx * 0.7 + k * rx * 0.35)
            for d in range(2):
                if (sx + d, int(cy)) in c.px:
                    c.set(sx + d, int(cy) - (d + k) % 2, crack)
    return c


def fire_ring(height, shift, cx=31.0, half=26):
    """Flames bursting from the pool at ground level: a row of tongues, the tallest in the middle,
    with the far ones (behind) taller than the near ones (in front)."""
    back, front = Canvas(CELL), Canvas(CELL)
    for i, x in enumerate(range(int(cx) - half, int(cx) + half + 1, 3)):
        edge = 1.0 - (abs(x - cx) / (half + 2)) ** 2
        jit = [1.0, 0.6, 0.85, 0.5, 0.95, 0.7][(i + shift) % 6]
        h = int(round(height * edge * jit))
        if h >= 2:
            flame_tongue(back, x, GROUND - 3, h, 1 if (i + shift) % 2 else -1)
        # only a few short tongues lick over the near rim, so the pool stays readable
        hf = int(round(height * 0.3 * edge * [0.0, 1.0, 0.0, 0.0, 0.8, 0.0][(i + shift) % 6]))
        if hf >= 2:
            flame_tongue(front, x + 1, GROUND - 1, hf, -1 if (i + shift) % 2 else 1)
    return back, front


def flame_tongue(c, x, base, h, lean):
    """One tongue of fire `h` px tall, white-yellow at its root, red at its tip."""
    for k in range(h):
        y = base - k
        f = k / max(h, 1)
        cols = ("Y", "Y2", "Y") if f < 0.35 else ("S4", "Y", "S4") if f < 0.65 else ("S3", "S4", "S3")
        width = 3 if f < 0.45 else 2 if f < 0.8 else 1
        xs = [x - 1, x, x + 1] if width == 3 else ([x, x + lean] if width == 2 else [x + lean])
        for i, xx in enumerate(xs):
            c.set(xx, y, cols[1] if width == 1 else cols[min(i + (3 - width), 2)])


def slag_heap(w, h, cool, phase):
    """What is left when it melts: a lumpy crust of slag on a cooling pool, lava in its cracks."""
    c = Canvas(CELL)
    cx = 30.5
    for y in range(GROUND - h, GROUND + 1):
        for x in range(int(cx - w) - 1, int(cx + w) + 2):
            # a slumped dome, the shell's hump still showing at its back, with a few lumps
            nxx = (x + 0.5 - cx) / w
            lump = h * (0.88 + 0.12 * math.sin((x - cx) * 0.8 + 1.2)) * (1.0 + 0.25 * math.exp(-((nxx + 0.3) / 0.3) ** 2))
            top = GROUND - lump * math.sqrt(max(0.0, 1.0 - nxx ** 2)) / 1.25
            if y + 0.5 < top or abs(x + 0.5 - cx) > w:
                continue
            nx = (x + 0.5 - cx) / w
            l = -0.55 * nx + (0.8 if y < top + 1.2 else -0.2 if y < GROUND - 1 else -0.8)
            col = "R3" if l > 0.7 else "R2" if l > 0.0 else "R1" if l > -0.7 else "B0"
            if cool >= 3:
                col = {"R3": "B2", "R2": "B1", "R1": "B0"}.get(col, col)
            c.set(x, y, col)
    hot = ["S4", "S3", "S2", "S1"][cool]
    for k, (dx, dy) in enumerate(((-6, -1), (-5, -1), (-1, -2), (0, -1), (4, -1), (5, -2), (8, -1))):
        q = (int(cx) + dx, GROUND + dy)
        if q in c.px and (k + phase) % 3 != 2:
            c.set(*q, hot)
    c.lone_pixels_off()
    return c


def draw_snail(p):
    if p["slag"] is not None:
        w, h = p["slag"]
        out = lava_pool(30.5, GROUND - 1.5, w + 4, 2.4, 0, p["phase"], p["pool_cool"])
        heap = slag_heap(w, h, min(p["cool"], 3), p["phase"])
        out.over(heap)
        out.outline()
        add_fx(out, p["fx"])
        return out
    shell = draw_shell(p)
    body = draw_body(p)
    head = draw_head(p)
    fig = Canvas(CELL)
    fig.over(shell)
    # where the shell meets the head and body, a dark inner line instead of a second outline
    front = Canvas(CELL)
    front.over(body)
    front.over(head)
    for (x, y) in list(fig.px):
        if (x, y) in front.px:
            continue
        if any(n in front.px for n in ((x + 1, y), (x, y - 1), (x, y + 1))):
            fig.px[(x, y)] = "L"
    fig.over(front)
    for step in COOL_STEPS[:p["cool"]]:
        fig.remap(step)
    if p["sink"]:
        fig = fig.shifted(0, p["sink"], clip_below=GROUND - 2)
    pcx, pcy, prx, pry = POOL
    if p["pool"] is not None:
        prx = p["pool"]
    if p["pool_ry"] is not None:
        pcy, pry = GROUND + 0.5 - p["pool_ry"], p["pool_ry"]
    pool = lava_pool(pcx + (p["front"] - p["back"]) / 2.0, pcy, prx + (p["front"] + p["back"]) / 2.0,
                     pry, p["pool_glow"], p["phase"], p["pool_cool"], tail=p["pool"] is None)
    for step in COOL_STEPS[:max(0, p["cool"] - 1)]:
        pool.remap(step)
    # the pool covers the bottom of the shell and body: they sit in it
    fig.over(pool)
    fig.outline()
    if p["flash"]:
        fig.remap({c: "W" for c in PALETTE if c not in ("O", "L")})
    if p["fire"]:
        back, front_fire = fire_ring(p["fire"], p["phase"])
        back.outline("S0")
        back.over(fig)
        fig = back
        front_fire.outline("S0", only_empty_of=fig)
        fig.over(front_fire)
    add_fx(fig, p["fx"])
    return fig


def add_fx(canvas, fx):
    """Lava drops, sparks and the spat ball: (x, y, size, color); size 1 is one pixel, 2 a 2x2 drop,
    4 the 5x5 lava ball (its color unused)."""
    if not fx:
        return
    drops = Canvas(canvas.size)
    for x, y, size, c in fx:
        if size == 1:
            drops.set(x, y, c)
        elif size == 4:
            for (dx, dy), col in BALL.items():
                drops.set(x + dx, y + dy, col)
        else:
            drops.set(x, y, "Y2" if c == "Y" else "Y")
            drops.set(x + 1, y, c)
            drops.set(x, y + 1, c)
            drops.set(x + 1, y + 1, "S3")
    drops.outline(only_empty_of=canvas)
    canvas.over(drops)


# --- animations -----------------------------------------------------------------------------

def idle():
    # It breathes: the spiral's light swells and turns a little, the head nods.
    glow = [1, 2, 3, 3, 2, 1]
    hdy = [0, 0, 1, 1, 0, 0]
    sq = [0, 0, 0, 1, 1, 0]
    return [pose(glow=glow[i], hdy=hdy[i], squash=sq[i], sdy=sq[i] / 2.0, spin=-i * 0.18,
                 blink=i == 4, phase=i) for i in range(6)]


def walk():
    # The foot reaches out under the head while the shell waits, then the shell rides forward and
    # bobs; the pool stretches with it.
    reach = [0, 1, 2, 2, 1, 0, 0, 0]
    catch = [0, 0, 0, 1, 2, 2, 1, 0]
    frames = []
    for i in range(8):
        e, t = reach[i], catch[i]
        frames.append(pose(front=e, back=-t, bdx=e // 2, hdx=e - (1 if t == 2 else 0),
                           hdy=1 if t == 2 else 0, sdx=t - 1 if t else 0, sdy=-1 if t == 1 else 0,
                           glow=2 if i % 4 < 2 else 1, spin=-i * 0.25, phase=i))
    return frames


def attack():
    # Rears back while the spiral heats up and the lava gathers in its mouth, then lunges and spits
    # the ball forward (the hit lands three quarters through: windup 0.6 s, attack 0.2 s) and settles.
    mx, my = int(HEAD[0]) + 7, int(HEAD[1]) + 3
    return [
        pose(hdx=-1, glow=2),
        pose(hdx=-2, hdy=-1, sdx=-1, glow=2, mouth=1),
        pose(hdx=-3, hdy=-2, sdx=-1, glow=3, mouth=1, glob=1, spin=-0.4),
        pose(hdx=-3, hdy=-2, sdx=-2, glow=3, mouth=2, glob=2, spin=-0.8, phase=1),
        pose(hdx=-4, hdy=-2, sdx=-2, glow=3, mouth=2, glob=2, blaze=True, spin=-1.2, phase=2),
        pose(hdx=2, front=1, bdx=1, glow=3, mouth=2, phase=3,
             fx=[(mx + 2, my - 3, 4, "Y"), (mx, my - 1, 1, "S4"), (mx - 1, my + 1, 1, "Y")]),
        pose(hdx=1, front=1, glow=2, mouth=1, phase=4,
             fx=[(mx + 8, my - 2, 4, "Y"), (mx + 5, my - 1, 1, "Y"), (mx + 3, my, 1, "S3")]),
        pose(glow=1, phase=5, fx=[(mx + 11, my + 1, 2, "S4"), (mx + 8, my + 3, 1, "S3")]),
    ]


def special():
    # The head draws in, the shell blazes and sinks into the widening pool; a ring of fire bursts
    # from it at ground level, then dies down as the shell rises again.
    return [
        pose(glow=3, head_in=1, pool=21, pool_ry=3.0),
        pose(glow=3, blaze=True, head_in=2, sink=4, pool=24, pool_ry=3.6, pool_glow=2, phase=1, fire=3),
        pose(glow=3, blaze=True, head_in=3, sink=11, pool=26, pool_ry=4.0, pool_glow=2, phase=2, fire=7),
        pose(glow=3, blaze=True, head_in=3, sink=20, pool=27, pool_ry=4.2, pool_glow=2, phase=3, fire=12,
             fx=[(18, 30, 1, "Y"), (44, 28, 1, "S4")]),
        pose(glow=3, blaze=True, head_in=3, sink=27, pool=27, pool_ry=4.2, pool_glow=2, phase=4, fire=20,
             fx=[(14, 26, 1, "S4"), (36, 22, 1, "Y"), (50, 28, 1, "Y")]),
        pose(glow=3, blaze=True, head_in=3, sink=27, pool=27, pool_ry=4.0, pool_glow=2, phase=5, fire=14,
             fx=[(20, 20, 1, "S3"), (40, 18, 1, "S4"), (52, 24, 1, "S3")]),
        pose(glow=3, head_in=2, sink=12, pool=25, pool_ry=3.6, pool_glow=2, phase=6, fire=5,
             fx=[(26, 16, 1, "S3"), (46, 18, 1, "S3")]),
        pose(glow=2, head_in=1, sink=3, pool=21, pool_ry=3.0, phase=7, fire=2),
    ]


def hurt():
    return [
        pose(flash=True, hdx=-1),
        pose(hdx=-2, hdy=1, sdx=-1, squash=1, sdy=0.5, mouth=1, blink=True, glow=3, blaze=True),
        pose(hdx=-1, glow=2),
        pose(glow=1),
    ]


def death():
    # The light goes out of its spiral, it slumps and melts down into a crust of slag.
    return [draw_snail(p) for p in (
        pose(glow=0, hdy=1, mouth=1),
        pose(glow=0, hdy=2, hdx=-1, mouth=1, blink=True, cool=1, squash=1, sdy=0.5),
        pose(glow=0, hdy=3, hdx=-1, mouth=1, blink=True, cool=1, squash=2, sdy=1, sink=2, pool=23),
        pose(glow=0, hdy=4, hdx=-2, blink=True, cool=2, squash=3, sdy=1.5, sink=5, pool=24),
        pose(glow=0, hdy=4, hdx=-2, blink=True, cool=2, squash=4, sdy=2, sink=9, pool=25, pool_cool=1),
        pose(slag=(16, 11), cool=1, pool_cool=1, phase=1,
             fx=[(22, 38, 1, "S4"), (40, 40, 1, "S3")]),
        pose(slag=(18, 7), cool=2, pool_cool=2, phase=2, fx=[(30, 40, 1, "S3")]),
        pose(slag=(19, 4), cool=3, pool_cool=3, phase=3),
    )]


# --- the burning trail ----------------------------------------------------------------------

## Cracks of the crust that closes over a cooling patch, relative to its center.
CRUST_CRACKS = [
    [(-6, -1), (-5, -1), (-4, 0), (-3, 0), (-2, 1)],
    [(1, -3), (2, -2), (3, -2), (4, -1)],
    [(0, 2), (1, 3), (2, 3), (3, 3)],
    [(-3, -3), (-2, -2)],
    [(5, 1), (6, 1), (7, 2)],
]


def puddle(scale, glow, bubbles=(), cool=0, splash=False):
    c = Canvas(TRAIL_CELL)
    cx, cy = 12.0, 12.0
    # about the burn's radius (9 px), and taller than the 14 px between patches so a trail going
    # up or down stays joined
    rx, ry = 10.0 * scale, 8.0 * scale
    for y in range(TRAIL_CELL):
        for x in range(TRAIL_CELL):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            ang = math.atan2(dy, dx)
            lobe = 1.0 + 0.05 * math.sin(3 * ang + 2.0) + 0.035 * math.sin(5 * ang + 0.7)
            q = math.hypot(dx, dy) / lobe
            if q > 1.0:
                continue
            col = "S1" if q > 0.82 else "S2" if q > 0.58 else "S3" if q > 0.3 else "S4"
            c.set(x, y, col)
    # hot spots drift around the core
    for (x, y) in glow:
        if (x, y) in c.px:
            c.set(x, y, "Y")
            if (x + 1, y) in c.px:
                c.set(x + 1, y, "S4")
    for (x, y, stage) in bubbles:
        if stage == 0:
            c.set(x, y, "Y")
        elif stage == 1:
            for px_ in ((x, y), (x + 1, y), (x, y - 1), (x + 1, y - 1)):
                c.set(*px_, "Y2" if px_[1] == y - 1 else "Y")
        elif stage == 2:
            for px_ in ((x - 1, y), (x + 2, y), (x, y - 2), (x + 1, y + 1)):
                c.set(*px_, "Y2")
    if cool == 1:
        c.remap(COOL_STEPS[0])
    elif cool >= 2:
        # the crust closes over it, molten cracks show through and go out one by one
        crust = {2: "S1", 3: "B1", 4: "B0"}[cool]
        crack = {2: "S3", 3: "S2", 4: "S1"}[cool]
        for p in c.px:
            c.px[p] = crust
        for k, pts in enumerate(CRUST_CRACKS):
            if cool == 4 and k % 2:
                continue
            for dx, dy in pts:
                if (int(cx) + dx, int(cy) + dy) in c.px:
                    c.set(int(cx) + dx, int(cy) + dy, crack)
        if cool == 2:
            c.set(int(cx), int(cy), "Y")
    c.outline("S0" if cool < 3 else "B0")
    if splash:
        for x, y in ((3, 10), (21, 9), (6, 18), (18, 19)):
            c.set(x, y, "S3")
    return c


def trail():
    spots = [[(10, 12), (14, 14)], [(11, 13), (13, 12)], [(12, 14), (9, 13)], [(13, 13), (11, 11)]]
    frames = [
        puddle(0.45, [(12, 13)], splash=True),
        puddle(0.75, [(11, 13), (13, 12)]),
        puddle(1.0, spots[0]),
    ]
    bub = [[(8, 13, 0), (15, 12, 2)], [(8, 13, 1)], [(8, 13, 2), (15, 13, 0)], [(15, 13, 1)]]
    for i in range(4):
        frames.append(puddle(1.0, spots[i], bub[i]))
    frames.append(puddle(1.0, spots[0], cool=1))
    frames.append(puddle(1.0, [], cool=2))
    frames.append(puddle(0.95, [], cool=3))
    frames.append(puddle(0.9, [], cool=4))
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
        strip([draw_snail(p) for p in make()], os.path.join(OUT, "caracol_escoria_%s.png" % name))
    strip(death(), os.path.join(OUT, "caracol_escoria_death.png"))
    strip(trail(), os.path.join(OUT, "caracol_escoria_trail.png"))
