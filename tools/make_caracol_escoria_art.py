"""Draws the Caracol de escoria's art (temple enemy, island 3) pixel by pixel.

A cooled, faceted basalt shell carries a recessed lava spiral. The soft molten foot and two
independently flexing eyestalks contrast with the heavy shell. All shapes are drawn at native
resolution with a one-pixel outline and clustered upper-left highlights, using temple colors.
The six animations preserve the existing cell sizes, frame counts and ground alignment.

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

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "caracol_escoria")
CELL = 64
TRAIL_CELL = 24
## Last row of the lava pool it sits in; its outline goes on the row below.
GROUND = 53

# A compact subset of the scenery palette; aliases keep the cooling/effect helpers shared.
from temple_palette import (OUTLINE, STONE_COOL_D, STONE_COOL_1, STONE_COOL_2,
                            STONE_COOL_3, STONE_3, CRUST_1, LAVA_D, LAVA_1,
                            LAVA_3, LAVA_4, LAVA_HI, LAVA_CORE)
PALETTE = {k: c[:3] for k, c in {
    "O": OUTLINE, "L": STONE_COOL_D,
    "S0": CRUST_1, "S1": LAVA_D, "S2": LAVA_1, "S3": LAVA_3,
    "S4": LAVA_4, "Y": LAVA_HI, "Y2": LAVA_CORE,
    "B0": STONE_COOL_D, "B1": STONE_COOL_1, "B2": STONE_COOL_2,
    "B3": STONE_COOL_3, "B4": STONE_3,
    "R1": LAVA_D, "R2": LAVA_1, "R3": LAVA_3,
    "G0": LAVA_D, "G1": LAVA_4, "G2": LAVA_HI, "W": LAVA_CORE,
}.items()}
## Death: each step cools the lava and dims the slag.
COOL_STEPS = [
    {"Y2": "Y", "Y": "S4", "S4": "S3", "S3": "S2", "G2": "G1"},
    {"Y": "S3", "S4": "S2", "S3": "S2", "S2": "S1", "B4": "B3", "B3": "B2", "R3": "R2", "G1": "G0"},
    {"S3": "S1", "S2": "S1", "S1": "S0", "B3": "B2", "B2": "B1", "R3": "R2", "R2": "R1", "G0": "B1"},
]
## Rest pose (cell coordinates).
SHELL = (24.5, 37.5, 12.0)          # center x, center y, radius
HEAD = (44.0, 41.0, 6.0, 6.0)       # center x, center y, half width, half height
POOL = (30.5, 51.5, 19.0, 2.0)      # center x, center y, radius x, radius y
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


# --- the snail ---------------------------------------------------------------------------------

def pose(**kw):
    p = dict(sdx=0, sdy=0, squash=0, hdx=0, hdy=0, bdx=0, front=0, back=0, mouth=0, glob=0,
             blink=False, glow=1, phase=0, flash=False, cool=0, sink=0,
             head_in=0, pool=None, pool_ry=None, pool_glow=1, pool_cool=0, fire=0, slag=None, fx=())
    p.update(kw)
    return p


def polygon(canvas, points, color):
    mask = Image.new("1", (canvas.size, canvas.size))
    ImageDraw.Draw(mask).polygon([(round(x), round(y)) for x, y in points], fill=1)
    for y in range(canvas.size):
        for x in range(canvas.size):
            if mask.getpixel((x, y)):
                canvas.set(x, y, color)


def line(canvas, points, color):
    mask = Image.new("1", (canvas.size, canvas.size))
    ImageDraw.Draw(mask).line([(round(x), round(y)) for x, y in points], fill=1)
    for y in range(canvas.size):
        for x in range(canvas.size):
            if mask.getpixel((x, y)):
                canvas.set(x, y, color)


def draw_shell(p):
    """Fixed stone plates: only the light inside their fissures breathes."""
    shell = Canvas(CELL)
    cx, cy, r = SHELL
    cx += p["sdx"]
    cy += p["sdy"]
    sy = (r - p["squash"]) / r
    def pts(coords):
        return [(cx+x, cy+y*sy) for x,y in coords]
    polygon(shell, pts([(-12,-5),(-9,-10),(-4,-13),(3,-13),(9,-9),(13,-3),
                        (13,4),(9,10),(2,12),(-6,11),(-12,6),(-14,0)]), "B1")
    polygon(shell, pts([(-12,-5),(-9,-10),(-4,-13),(3,-13),(7,-10),(1,-8),
                        (-6,-7),(-10,-1),(-13,1)]), "B3")
    polygon(shell, pts([(-8,-5),(-3,-8),(5,-9),(10,-5),(8,1),(2,4),(-5,3),(-9,0)]), "B2")
    polygon(shell, pts([(8,-5),(12,-2),(12,4),(8,9),(2,11),(-4,10),(2,6),(7,2)]), "B0")
    line(shell, pts([(-10,-7),(-7,-10),(-3,-11),(1,-11)]), "B4")
    line(shell, pts([(-12,1),(-11,5),(-8,8)]), "B2")
    # A broad dark groove separates the spiral from the angular stone plates.
    spiral = []
    for i in range(181):
        t = i / 180 * math.tau * 1.65
        radius = 0.5 + i / 180 * 10.2
        spiral.append((round(cx - 1 + math.cos(t)*radius),
                       round(cy + math.sin(t)*radius*sy)))
    groove = Canvas(CELL)
    line(groove, spiral, "B0")
    groove.outline("B0")
    shell.over(groove)
    hot = ["S2", "S3", "S4", "Y"][p["glow"]]
    line(shell, spiral, hot)
    # Branching fissures meet the coil without moving the rock itself.
    for branch in [[(-7,-6),(-7,-9),(-5,-11)],[(8,1),(10,2),(11,5)],
                   [(-5,7),(-6,9),(-5,10)]]:
        line(shell, pts(branch), "S3" if p["glow"] > 1 else "S2")
    if p["glow"] >= 2:
        for x,y in spiral[35:65:4] + spiral[122:143:5]:
            shell.set(x,y,"Y" if p["glow"]==3 else "S4")
    return shell


def draw_head(p):
    """Rounded lava neck, with two staggered stalks that bend after the foot."""
    head = Canvas(CELL)
    hx = round(HEAD[0] + p["hdx"] - p["head_in"])
    hy = round(HEAD[1] + p["hdy"] + p["head_in"])
    polygon(head, [(hx-5,hy-2),(hx-3,hy-5),(hx+2,hy-5),(hx+5,hy-2),
                   (hx+6,hy+2),(hx+3,hy+5),(hx-7,hy+7)], "S2")
    polygon(head, [(hx-4,hy-2),(hx-2,hy-4),(hx+2,hy-4),(hx+4,hy-1),
                   (hx+3,hy+1),(hx-1,hy+2),(hx-4,hy+5)], "S3")
    line(head, [(hx-2,hy-3),(hx+1,hy-3),(hx+3,hy-1)], "S4")
    # Far stalk is shorter and darker. Near stalk lags a half beat behind it.
    for k, (dx, height) in enumerate([(-3,10),(3,12)]):
        bob = [0,-1,-1,0,1,1,0,0][(p["phase"]+k*2)%8]
        ex = hx+dx + (1 if bob<0 else 0)
        ey = hy-height+bob + p["head_in"]
        line(head, [(hx+dx-1,hy-3),(ex-1,ey+3),(ex,ey+1)], "S2")
        line(head, [(hx+dx,hy-3),(ex,ey+3),(ex+1,ey+1)], "S4" if k else "S3")
        polygon(head, [(ex-1,ey-1),(ex+1,ey-2),(ex+3,ey),(ex+2,ey+2),(ex,ey+2)], "S1")
        if not p["blink"]:
            head.set(ex+1,ey,"Y2")
            head.set(ex+2,ey,"O")
            head.set(ex+1,ey+1,"Y")
        else:
            line(head, [(ex,ey+1),(ex+2,ey+1)], "O")
    my = hy+2
    line(head, [(hx+2,my),(hx+5,my-1)], "S0")
    if p["mouth"]:
        polygon(head, [(hx+2,my-1),(hx+6,my-1),(hx+6,my+p["mouth"]),
                       (hx+3,my+p["mouth"])], "O")
        head.set(hx+4,my+p["mouth"],"S4")
    if p["glob"]:
        head.set(hx+6,my,"Y")
        head.set(hx+7,my,"S4")
    return head


def draw_body(p):
    """Muscular, rippling foot; a pointed tail anchors the silhouette."""
    body = Canvas(CELL)
    reach = p["front"]
    bx = p["bdx"]
    polygon(body, [(10+p["back"],49),(16,46),(24,45),(32+bx,43),
                   (38+bx,39),(44+bx,41),(48+reach,46),(51+reach,50),
                   (48+reach,52),(19,52)], "S2")
    polygon(body, [(12,49),(21,47),(31+bx,46),(39+bx,43),(44+bx,44),
                   (48+reach,48),(46+reach,50),(28,50),(19,51)], "S3")
    line(body, [(15,49),(23,48),(29+bx,48)], "S4")
    line(body, [(39+bx,45),(42+bx,46),(44+reach,48)], "S4")
    for x in range(21,48,6):
        y = 50 + ((x//6+p["phase"])%3==0)
        line(body, [(x,y),(x+2,y-1)], "S1")
    return body


def lava_pool(cx, cy, rx, ry, glow, phase, cool=0, tail=False):
    """The molten puddle it sits in: a bright rim where the lava swells, a dark underside, and
    hot streaks that crawl along it."""
    c = Canvas(CELL)
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            wob = 0.12 * math.sin(x * 0.65 + phase * math.tau / 8)
            if dx * dx + dy * dy > 1.0 + wob:
                continue
            # the swell of its surface: a few dips along the top so it never reads as a plank
            if dy < -0.45 and (x * 7 + phase) % 9 in (0, 4) and abs(dx) < 0.85:
                continue
            if dy < -0.45:
                col = "S4" if glow >= 1 else "S3"
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
    # Heat pulses inside a stationary spiral; the soft neck breathes and the stalks lag.
    glow = [1, 2, 3, 3, 2, 1]
    hdy = [0, -1, -1, 0, 1, 1]
    sq = [0, 0, 0, 1, 1, 0]
    return [pose(glow=glow[i], hdy=hdy[i], squash=sq[i], sdy=sq[i] / 2.0,
                 blink=i == 4, phase=[0,1,2,4,5,6][i]) for i in range(6)]


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
                           glow=2 if i % 4 < 2 else 1, phase=i))
    return frames


def attack():
    # Rears back while the spiral heats up and the lava gathers in its mouth, then lunges and spits
    # the ball forward (the hit lands three quarters through: windup 0.6 s, attack 0.2 s) and settles.
    mx, my = int(HEAD[0]) + 7, int(HEAD[1]) + 3
    return [
        pose(hdx=-1, glow=2),
        pose(hdx=-2, hdy=-1, sdx=-1, glow=2, mouth=1),
        pose(hdx=-3, hdy=-2, sdx=-1, glow=3, mouth=1, glob=1),
        pose(hdx=-3, hdy=-2, sdx=-2, glow=3, mouth=2, glob=2, phase=1),
        pose(hdx=-4, hdy=-2, sdx=-2, glow=3, mouth=2, glob=2, phase=2),
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
        pose(glow=3, head_in=2, sink=4, pool=24, pool_ry=3.6, pool_glow=2, phase=1, fire=3),
        pose(glow=3, head_in=3, sink=11, pool=26, pool_ry=4.0, pool_glow=2, phase=2, fire=7),
        pose(glow=3, head_in=3, sink=20, pool=27, pool_ry=4.2, pool_glow=2, phase=3, fire=12,
             fx=[(18, 30, 1, "Y"), (44, 28, 1, "S4")]),
        pose(glow=3, head_in=3, sink=27, pool=27, pool_ry=4.2, pool_glow=2, phase=4, fire=20,
             fx=[(14, 26, 1, "S4"), (36, 22, 1, "Y"), (50, 28, 1, "Y")]),
        pose(glow=3, head_in=3, sink=27, pool=27, pool_ry=4.0, pool_glow=2, phase=5, fire=14,
             fx=[(20, 20, 1, "S3"), (40, 18, 1, "S4"), (52, 24, 1, "S3")]),
        pose(glow=3, head_in=2, sink=12, pool=25, pool_ry=3.6, pool_glow=2, phase=6, fire=5,
             fx=[(26, 16, 1, "S3"), (46, 18, 1, "S3")]),
        pose(glow=2, head_in=1, sink=3, pool=21, pool_ry=3.0, phase=7, fire=2),
    ]


def hurt():
    return [
        pose(flash=True, hdx=-1),
        pose(hdx=-2, hdy=1, sdx=-1, squash=1, sdy=0.5, mouth=1, blink=True, glow=3),
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
            col = "S1" if q > 0.83 else "S3"
            if q < 0.78 and (math.sin(x*0.67+y*0.42) + math.cos(y*0.91-x*0.31)) > 0.35:
                col = "B1" if y < cy else "B0"
            elif q < 0.65 and (x+y*2)%7 in (0,1):
                col = "S4"
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
