"""Draws the Templo del Eclipse terrain tileset (16x16 tiles, own pixel art) with Pillow, guided by
docs/referencias/templo_mapa.jpg: stone islands with three height levels floating over a sea of lava.
Usage from the repo root:
    python tools/make_temple_tileset_art.py [--preview <folder>]
Writes assets/tilesets/temple/temple_sheet.png (16 columns) and assets/tilesets/temple/temple_tiles.json
(name -> [column, row]; patterns and animations -> lists of [column, row]), which
tools/make_tileset_temple.gd turns into the tileset profile. With --preview it also writes a labeled
contact sheet, a sample 30x18 composition and GIFs of every animation to <folder> (not part of the
game). Every tile is deterministic (fixed seeds) and uses only the colours of tools/temple_palette.py.

Lava: the sea is a macro pattern of 8x8 tiles (a 128 px period) in three variants (`lava_m`,
`lava_m2`, `lava_m3`) that share their edges: dark cooled plates drifting on molten channels, hot
only along the cracks, pushed off any lattice by a warp and dimmed in regions by a slow cooling
field. `<variant>_<cx>_<cy>` (cx, cy in 0..7) is one animation of 8 frames per macro cell; paint
cell (x, y) of the map with `<variant>_<x mod 8>_<y mod 8>`, picking the variant per 8x8 block by any
rule (LavaBackdrop uses a world-space noise), and every frame is seamless. `lava_flow` is the same
lava folded into one self-seamless 16 px tile (8 frames) and `lava_a..d` are still variants of it;
`lava_bubble` (6 frames) is a bubble on that tile and `lava_bubble_over` the bubble alone, to lay
over the macro lava.

Floors: a level has its own tone so the eye reads the height: level 0 the darkest, dusty rose
(STONE_0), level 1 the rosy mid stone, level 2 the palest and warmest. `floor<L>_m_<cx>_<cy>` is a 4x4 macro plan of large
flagstones whose slabs cross the tile borders (paint cell (x, y) with cx = x mod 4, cy = y mod 4);
`floor<L>_a..f` are single seamless tiles, `floor<L>_moss_*`, `floor<L>_crack_*` their details.
`floor_*` (no level) is level 1.

Blob patterns (`lava_rim`, `ledge`) have 47 tiles, one per distinct 8-neighbour mask once a corner
only counts when both edges beside it are inside (bits N=1 NE=2 E=4 SE=8 S=16 SW=32 W=64 NW=128,
"inside" = the cell belongs to the area: lava for the rim, the high plateau for the ledge). Their
order is `BLOB_MASKS` (also written to the json, and mirrored by `TileArt.blob47_tile`): first the
nine-slice in reading order and the four inner corners (SE, SW, NE, NW), exactly as
`TileArt.blob_tile` expects (with `<name>_inner` holding those four), then the other 34 masks in
ascending order.
"""
import json
import math
import os
import random
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from temple_palette import *  # noqa: E402,F401,F403

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "tilesets", "temple")
PREVIEW = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
T = 16
COLUMNS = 16
MACRO = 4  # tiles per side of a macro pattern
MN = MACRO * T  # its period in pixels

# --- blob masks -------------------------------------------------------------------------------------
N, NE, E, SE, S, SW, W, NW = 1, 2, 4, 8, 16, 32, 64, 128
NEIGHBOURS = ((N, (0, -1)), (NE, (1, -1)), (E, (1, 0)), (SE, (1, 1)), (S, (0, 1)), (SW, (-1, 1)), (W, (-1, 0)), (NW, (-1, -1)))


def normalise_mask(m):
    """A corner only matters when both edges beside it are inside."""
    if not (m & N and m & E):
        m &= ~NE
    if not (m & E and m & S):
        m &= ~SE
    if not (m & S and m & W):
        m &= ~SW
    if not (m & W and m & N):
        m &= ~NW
    return m


NINE_SLICE = [E | SE | S, W | SW | S | SE | E, W | SW | S,
              N | NE | E | SE | S, 255, N | NW | W | SW | S,
              N | NE | E, W | NW | N | NE | E, N | NW | W]
INNER = [255 ^ SE, 255 ^ SW, 255 ^ NE, 255 ^ NW]
BLOB_MASKS = NINE_SLICE + INNER + sorted(m for m in {normalise_mask(i) for i in range(256)} if m not in NINE_SLICE + INNER)
assert len(BLOB_MASKS) == 47


# --- helpers ------------------------------------------------------------------------------------------
def alpha(c, a):
    return (c[0], c[1], c[2], a)


def blank(w=T, h=T):
    return Image.new("RGBA", (w, h), CLEAR)


def put(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def get(img, x, y):
    if 0 <= x < img.width and 0 <= y < img.height:
        return img.getpixel((x, y))
    return CLEAR


def over(base, top, pos=(0, 0)):
    base.alpha_composite(top, pos)
    return base


def fill(img, x0, y0, x1, y1, c):
    for y in range(y0, y1):
        for x in range(x0, x1):
            put(img, x, y, c)


def outline(img, color=OUTLINE):
    """1 px outline around the opaque pixels (drawn into the transparent ring, inside the canvas)."""
    px = img.load()
    ring = []
    for y in range(img.height):
        for x in range(img.width):
            if px[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < img.width and 0 <= ny < img.height and px[nx, ny][3] > 0:
                        ring.append((x, y))
                        break
    for x, y in ring:
        px[x, y] = color
    return img


def smooth(t):
    return t * t * (3 - 2 * t)


def noise_grids(rng, n=T, cell=4, octaves=2, border_of=None):
    """The lattices of a periodic value noise: [(cell, grid), ...], one per octave. With `border_of`
    (the lattices of another noise of the same n, cell and octaves) the first row and column of
    every lattice are copied from it, so the two fields agree along their edges: tiles of one can
    stand next to tiles of the other without a seam (see LavaField)."""
    grids = []
    c, octave = cell, 0
    while octaves > 0 and c >= 1:
        g = max(1, n // c)
        grid = [[rng.random() for _ in range(g)] for _ in range(g)]
        if border_of is not None:
            other = border_of[octave][1]
            grid[0] = list(other[0])
            for y in range(g):
                grid[y][0] = other[y][0]
        grids.append((c, grid))
        c //= 2
        octaves -= 1
        octave += 1
    return grids


def noise_field(n, grids):
    """The periodic value noise of `grids` (see noise_grids), n x n, 0..1."""
    out = [[0.0] * n for _ in range(n)]
    amp, total = 1.0, 0.0
    for c, grid in grids:
        g = len(grid)
        for y in range(n):
            for x in range(n):
                gx, gy = x / c, y / c
                x0, y0 = int(gx) % g, int(gy) % g
                fx, fy = smooth(gx - int(gx)), smooth(gy - int(gy))
                x1, y1 = (x0 + 1) % g, (y0 + 1) % g
                top = grid[y0][x0] * (1 - fx) + grid[y0][x1] * fx
                bot = grid[y1][x0] * (1 - fx) + grid[y1][x1] * fx
                out[y][x] += (top * (1 - fy) + bot * fy) * amp
        total += amp
        amp *= 0.5
    return [[v / total for v in row] for row in out]


def periodic_noise(rng, n=T, cell=4, octaves=2):
    """Value noise that wraps at `n` (a tile of it is seamless with itself), 0..1."""
    return noise_field(n, noise_grids(rng, n, cell, octaves))


def sample_wrapped(field, x, y):
    """Bilinear sample of a periodic field at a fractional position."""
    n = len(field)
    x0, y0 = math.floor(x), math.floor(y)
    fx, fy = x - x0, y - y0
    x0, y0 = x0 % n, y0 % n
    x1, y1 = (x0 + 1) % n, (y0 + 1) % n
    top = field[y0][x0] * (1 - fx) + field[y0][x1] * fx
    bot = field[y1][x0] * (1 - fx) + field[y1][x1] * fx
    return top * (1 - fy) + bot * fy


def ridged(field):
    """Bright along the 0.5 contour of a field: a web of channels between plates."""
    return [[1.0 - 2.0 * abs(v - 0.5) for v in row] for row in field]


def band(v, steps):
    """`steps` = [(threshold, colour), ...] ascending; the colour of the first threshold v is under."""
    for threshold, colour in steps:
        if v < threshold:
            return colour
    return steps[-1][1]


def quantile_steps(values, shares):
    """Thresholds so that each (colour, share) of `shares` covers that share of `values`."""
    ordered = sorted(values)
    steps, acc = [], 0.0
    for colour, share in shares[:-1]:
        acc += share
        steps.append((ordered[min(len(ordered) - 1, int(acc * len(ordered)))], colour))
    steps.append((9.0, shares[-1][0]))
    return steps


def cut(img, name_fn, size=MACRO):
    """The 16 px tiles of a macro image, (name, tile) in reading order."""
    tiles = []
    for cy in range(size):
        for cx in range(size):
            tiles.append((name_fn(cx, cy), img.crop((cx * T, cy * T, cx * T + T, cy * T + T))))
    return tiles


# --- floors -------------------------------------------------------------------------------------------
## The stone of each height level: slab tones (mid, dark, pale) with the lit bevel, the shade and the
## joint of each, from the dark grey ground to the pale warm top.
LEVEL_TONES = {
    0: {"tones": [(STONE_0, STONE_2, STONE_1)] * 7 + [(STONE_1, STONE_0, STONE_D)] * 2 + [(STONE_2, STONE_3, STONE_1)],
        "joint": STONE_D, "outer_shade": STONE_D, "pit": (STONE_D, STONE_2), "crack": (STONE_D, STONE_3),
        "moss": (MOSS_D, MOSS_1, MOSS_2)},
    1: {"tones": [(STONE_3, STONE_4, STONE_1)] * 7 + [(STONE_2, STONE_3, STONE_1)] * 2 + [(STONE_4, STONE_HI, STONE_2)],
        "joint": JOINT, "outer_shade": STONE_1, "pit": (STONE_2, STONE_4), "crack": (STONE_D, STONE_4),
        "moss": (MOSS_D, MOSS_1, MOSS_2)},
    2: {"tones": [(STONE_4, STONE_HI, STONE_2)] * 7 + [(STONE_3, STONE_4, STONE_2)] * 2 + [(STONE_HI, STONE_HI, STONE_3)],
        "joint": STONE_1, "outer_shade": STONE_2, "pit": (STONE_3, STONE_HI), "crack": (STONE_1, STONE_HI),
        "moss": (MOSS_1, MOSS_2, MOSS_HI)},
}


def draw_slab(img, rng, x0, y0, x1, y1, tone, level, outer_shade=False):
    """One flagstone from (x0, y0) inclusive to (x1, y1) exclusive, with its joint on the top and
    left, a lit bevel inside it, a shade on the bottom and right and a soft corner."""
    base, lit, shade = tone
    joint = LEVEL_TONES[level]["joint"]
    if outer_shade:
        shade = LEVEL_TONES[level]["outer_shade"]
    for y in range(y0, y1):
        for x in range(x0, x1):
            if x == x0 or y == y0:
                c = joint
            elif y == y1 - 1 or x == x1 - 1:
                c = shade
            elif y == y0 + 1 or x == x0 + 1:
                c = lit
            else:
                c = base
            put(img, x % img.width, y % img.height, c)
    for cx, cy in ((x1 - 1, y0 + 1), (x0 + 1, y1 - 1), (x1 - 1, y1 - 1)):
        put(img, cx % img.width, cy % img.height, joint)
    put(img, (x0 + 1) % img.width, (y0 + 1) % img.height, base)
    if rng.random() < 0.3 and x1 - x0 > 6 and y1 - y0 > 6:  # a pit of wear
        dark, pale = LEVEL_TONES[level]["pit"]
        px, py = rng.randrange(x0 + 3, x1 - 3), rng.randrange(y0 + 3, y1 - 3)
        put(img, px, py, dark)
        put(img, px + 1, py + 1, pale)


def slab_layout(kind, rng):
    """Rows of slabs inside one tile: (y0, y1, [(x0, x1), ...]); x0/y0 hold the joint."""
    if kind == "2x2":
        return [(0, 8, [(0, 8), (8, 16)]), (8, 16, [(0, 8), (8, 16)])]
    if kind == "3x2":
        return [(0, 8, [(0, 6), (6, 11), (11, 16)]), (8, 16, [(0, 6), (6, 11), (11, 16)])]
    if kind == "brick":
        return [(0, 8, [(0, 8), (8, 16)]), (8, 16, [(0, 4), (4, 12), (12, 16)])]
    if kind == "brick3":
        return [(0, 8, [(0, 6), (6, 11), (11, 16)]), (8, 16, [(0, 3), (3, 9), (9, 16)])]
    if kind == "tall":
        return [(0, 16, [(0, 8), (8, 16)])]
    if kind == "wide":
        return [(0, 8, [(0, 16)]), (8, 16, [(0, 16)])]
    raise ValueError(kind)


def floor_tile(seed, kind="2x2", level=1, moss=0.0, crack=False, rune=None, glow=None):
    """A self-seamless flagstone tile: joints on its top and left, the shade of every slab on its
    bottom and right, so any two floors of a level meet without a seam."""
    rng = random.Random(seed)
    img = blank()
    tones = LEVEL_TONES[level]["tones"]
    for y0, y1, cols in slab_layout(kind, rng):
        for x0, x1 in cols:
            draw_slab(img, rng, x0, y0, x1, y1, rng.choice(tones), level, outer_shade=True)
    if moss > 0.0:
        moss_over(img, rng, moss, LEVEL_TONES[level]["moss"])
    if crack:
        crack_over(img, rng, LEVEL_TONES[level]["crack"])
    if rune is not None:
        rune_over(img, rune, glow, LEVEL_TONES[level]["crack"][0])
    return img


def floor_macro(seed, level):
    """A 64x64 plan of large flagstones (12 to 24 px) in staggered rows, periodic, so cut into 16
    tiles it paints a floor with no 16 px grid in it."""
    rng = random.Random(seed)
    img = blank(MN, MN)
    heights = rng.choice([[12, 20, 16, 16], [16, 12, 20, 16], [20, 16, 12, 16], [16, 20, 12, 16]])
    tones = LEVEL_TONES[level]["tones"]
    y = 0
    for h in heights:
        widths = rng.choice([[16, 24, 12, 12], [20, 12, 16, 16], [12, 20, 20, 12], [24, 16, 12, 12], [16, 16, 20, 12]])
        offset = rng.randrange(0, MN)
        x = offset
        for w in widths:
            draw_slab(img, rng, x, y, x + w, y + h, rng.choice(tones), level)
            x += w
        y += h
    moss = LEVEL_TONES[level]["moss"]
    for _ in range(3):  # a touch of moss in a joint
        mx, my = rng.randrange(MN), rng.randrange(MN)
        for i in range(rng.randrange(2, 4)):
            put(img, (mx + i) % MN, my, moss[1])
            if rng.random() < 0.5:
                put(img, (mx + i) % MN, (my + 1) % MN, moss[0])
    return img


def moss_overlay(seed, amount, moss):
    """Moss alone, transparent elsewhere, to lay over any floor (the macro plans included)."""
    img = blank()
    moss_over(img, random.Random(seed), amount, moss)
    return img


def crack_overlay(seed, level):
    """A crack alone, in the level's colours, to lay over any floor."""
    img = blank()
    crack_over(img, random.Random(seed), LEVEL_TONES[level]["crack"])
    return img


def moss_over(img, rng, amount, moss):
    """Moss creeping along the joints and into the slabs' corners."""
    spots = int(4 + amount * 12)
    for _ in range(spots):
        x, y = rng.randrange(1, 15), rng.randrange(1, 15)
        length = rng.randrange(2, 6)
        along_x = rng.random() < 0.5
        for i in range(length):
            px, py = (x + i, y) if along_x else (x, y + i)
            if not (1 <= px <= 14 and 1 <= py <= 14):
                break
            put(img, px, py, moss[1] if rng.random() < 0.7 else moss[2])
            if rng.random() < 0.4:
                put(img, px + (0 if along_x else 1), py + (1 if along_x else 0), moss[0])
            if rng.random() < 0.2:
                put(img, px, py - 1, moss[2])


def crack_over(img, rng, colours):
    """A crack across the slabs: a dark line with a lit edge under it."""
    dark, pale = colours
    x, y = rng.randrange(2, 6), rng.randrange(1, 4)
    for _ in range(rng.randrange(9, 14)):
        put(img, x, y, dark)
        if rng.random() < 0.6:
            put(img, x + 1, y + 1, pale)
        step = rng.random()
        if step < 0.45:
            y += 1
        elif step < 0.8:
            x += 1
        else:
            x += 1
            y += 1
        if rng.random() < 0.3:
            put(img, x - 1, y, dark)
        if not (1 <= x <= 14 and 1 <= y <= 14):
            break


RUNES = {
    "a": ["..###..", ".#...#.", "#..#..#", "#.###.#", "#..#..#", ".#...#.", "..###.."],
    "b": ["...#...", "..###..", ".#.#.#.", "#..#..#", ".#.#.#.", "..###..", "...#..."],
    "c": ["#######", "#.....#", "#.###.#", "#.#.#.#", "#.###.#", "#.....#", "#######"],
    "d": ["#.....#", ".#...#.", "..#.#..", "...#...", "..#.#..", ".#...#.", "#.....#"],
}


def rune_over(img, rune, glow=None, groove=STONE_D):
    """A carved glyph in the middle of the tile: a dark groove with its fill (bronze, or a glow frame)."""
    fill_colour = glow if glow is not None else BRONZE_1
    ox, oy = 4, 4
    cells = [(ox + x, oy + y) for y, row in enumerate(RUNES[rune]) for x, ch in enumerate(row) if ch == "#"]
    for x, y in cells:  # the groove's shadow, down and right of the glyph
        if (x + 1, y + 1) not in cells:
            put(img, x + 1, y + 1, groove)
    for x, y in cells:
        put(img, x, y, fill_colour)
    if glow == RUNE_GLOW:  # at the peak of the pulse, a halo of gold specks
        for x, y in cells:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if (nx, ny) not in cells and (nx + ny) % 2 == 0:
                    put(img, nx, ny, GOLD_HI)


# --- lava ---------------------------------------------------------------------------------------------
## Share of the surface each tone takes, from the cooled plates to the white-hot knots of the channels.
LAVA_SHARES = [(CRUST_1, 0.27), (LAVA_D, 0.18), (LAVA_1, 0.16), (LAVA_2, 0.14), (LAVA_3, 0.13),
               (LAVA_4, 0.07), (LAVA_HI, 0.038), (LAVA_CORE, 0.012)]
FLOW_FRAMES = 8


## How far (px) the plates' noise is pushed about by the warp (0 at the field's edges, so variants
## that share their edges still meet), and how much the slow cooling field dims whole regions.
WARP_PX = 9.0
WARP_FADE_PX = 10.0
COOL_SWING = 0.5


class LavaField:
    """A periodic lava field of `n` px: plates (ridged noise, pushed about by a warp so they never
    sit on a lattice, dimmed by a slow cooling field so some regions are mostly crust and others
    mostly channel) with cracks on them, molten channels between them whose shimmer drifts 2 px per
    frame (a seamless loop of 8 frames). A field made with `variant_of` another shares its edges
    (noise_grids' border copy; the warp fades out at the edges), so tiles cut from either can stand
    side by side with no seam: the sea mixes the variants by a world-space noise and never repeats."""

    def __init__(self, n, seed=11, variant_of=None):
        rng = random.Random(seed)
        self.n = n
        ref = variant_of
        border = (lambda name: getattr(ref, name) if ref is not None else None)
        self.plate_grids = noise_grids(rng, n, max(4, n // 4), 3, border("plate_grids"))
        self.warp_grids = [noise_grids(rng, n, max(4, n // 8), 2, border("warp_grids")[i] if ref else None) for i in range(2)]
        self.cool_grids = noise_grids(rng, n, max(4, n // 2), 1, border("cool_grids"))
        self.crack_grids = noise_grids(rng, n, max(4, n // 8), 2, border("crack_grids"))
        self.speck_grids = noise_grids(rng, n, max(2, n // 16), 2, border("speck_grids"))
        self.flow = ref.flow if ref is not None else periodic_noise(rng, n=T, cell=8, octaves=2)
        base = noise_field(n, self.plate_grids)
        warp_x, warp_y = (noise_field(n, g) for g in self.warp_grids)
        cool = noise_field(n, self.cool_grids)
        self.plates = [[0.0] * n for _ in range(n)]
        for y in range(n):
            for x in range(n):
                edge = min(x + 0.5, n - x - 0.5, y + 0.5, n - y - 0.5)
                amp = WARP_PX * smooth(min(1.0, edge / WARP_FADE_PX)) if n > 2 * WARP_FADE_PX else 0.0
                v = sample_wrapped(base, x + (warp_x[y][x] - 0.5) * 2 * amp, y + (warp_y[y][x] - 0.5) * 2 * amp)
                self.plates[y][x] = (1.0 - 2.0 * abs(v - 0.5)) * (1.0 - COOL_SWING / 2 + COOL_SWING * cool[y][x])
        self.cracks = ridged(noise_field(n, self.crack_grids))
        self.speck = noise_field(n, self.speck_grids)
        if ref is not None:
            self.steps, self.plate_level = ref.steps, ref.plate_level
        else:
            self.steps = quantile_steps([self.value(x, y, 0) for y in range(n) for x in range(n)], LAVA_SHARES)
            self.plate_level = self.steps[0][0]

    def value(self, x, y, frame):
        shimmer = self.flow[(y - 2 * frame) % T][(x - 2 * frame) % T] - 0.5
        pulse = 0.02 * math.sin(2 * math.pi * frame / FLOW_FRAMES)
        return self.plates[y][x] * 0.8 + shimmer * 0.3 + pulse

    def colour(self, x, y, frame, detail=0.0):
        v = self.value(x, y, frame) + detail
        c = band(v, self.steps)
        if v < self.plate_level:  # a cooled plate: specks of darker crust and dim cracks
            crack = self.cracks[y][x]
            if crack > 0.95:
                c = LAVA_2 if crack > 0.985 else LAVA_1
            elif crack > 0.9:
                c = LAVA_D
            elif self.speck[y][x] < 0.38:
                c = CRUST_D
        return c

    def frame(self, k, detail_field=None):
        img = blank(self.n, self.n)
        for y in range(self.n):
            for x in range(self.n):
                detail = 0.0
                if detail_field is not None:
                    w = min(x, self.n - 1 - x, y, self.n - 1 - y)
                    detail = (detail_field[y][x] - 0.5) * 0.2 * (0.0 if w < 2 else 1.0)
                put(img, x, y, self.colour(x, y, k, detail))
        return img


## The sea: LAVA_MACRO tiles per side (a 128 px period) in LAVA_VARIANTS variants that share their
## edges, each cut into `<variant>_<cx>_<cy>` animations of FLOW_FRAMES frames.
LAVA_MACRO = 8
LAVA_MN = LAVA_MACRO * T
LAVA_VARIANTS = ["lava_m", "lava_m2", "lava_m3"]
LAVA_FIELDS = [LavaField(LAVA_MN, 11)]
for _i, _seed in enumerate((23, 37)):
    LAVA_FIELDS.append(LavaField(LAVA_MN, _seed, variant_of=LAVA_FIELDS[0]))
LAVA_SMALL = LavaField(T, 12)


def lava_base_tiles():
    """lava_a..d: the small lava with a windowed detail of their own, so their borders are all equal."""
    tiles = []
    for i in range(4):
        rng = random.Random(100 + i)
        tiles.append(LAVA_SMALL.frame(0, periodic_noise(rng, cell=4, octaves=2)))
    return tiles


def bubble_frames(background):
    """A bubble swells on the lava and pops: 6 frames over `background` (None = the bubble alone)."""
    result = []
    cx, cy = 8, 8
    for k in range(6):
        img = background.copy() if background is not None else blank()
        if k < 4:
            r = [1.4, 2.4, 3.4, 4.0][k]
            for y in range(T):
                for x in range(T):
                    d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                    if d < r:
                        light = math.hypot(x + 0.5 - (cx - r * 0.4), y + 0.5 - (cy - r * 0.4))
                        if light < r * 0.45:
                            c = LAVA_CORE if k >= 2 else LAVA_HI
                        elif d > r - 1.0 and (x + 0.5 > cx or y + 0.5 > cy):
                            c = LAVA_2
                        elif d > r - 1.0:
                            c = LAVA_HI
                        else:
                            c = LAVA_4
                        put(img, x, y, c)
            if k == 3:  # taut: a darker sag in the middle
                put(img, cx, cy, LAVA_3)
                put(img, cx, cy + 1, LAVA_3)
        elif k == 4:  # pop: a ring of splashes
            for a in range(10):
                ang = a / 10.0 * 2 * math.pi
                put(img, int(round(cx + 4.3 * math.cos(ang))), int(round(cy + 4.3 * math.sin(ang))), LAVA_CORE if a % 2 == 0 else LAVA_HI)
                put(img, int(round(cx + 6.2 * math.cos(ang))), int(round(cy + 6.2 * math.sin(ang))), LAVA_HI if a % 3 == 0 else LAVA_4)
            for dx, dy in ((0, 0), (-1, 0), (0, -1), (1, 0), (0, 1)):
                put(img, cx + dx, cy + dy, LAVA_2)
        else:  # the ring dies
            for a in range(6):
                ang = a / 6.0 * 2 * math.pi + 0.3
                put(img, int(round(cx + 5.5 * math.cos(ang))), int(round(cy + 5.5 * math.sin(ang))), LAVA_HI)
            put(img, cx, cy, LAVA_1)
            put(img, cx - 1, cy, LAVA_2)
            put(img, cx, cy - 1, LAVA_2)
        result.append(img)
    return result


# --- blob areas (rim, ledge) ------------------------------------------------------------------------
def blob_context(mask):
    """The 3x3 cells around a tile of the area: True = inside."""
    inside = {(0, 0): True}
    for bit, (dx, dy) in NEIGHBOURS:
        inside[(dx, dy)] = bool(mask & bit)
    return inside


def nearest_outside(inside, x, y):
    """(distance, dx, dy) from pixel (x, y) of the centre tile to the nearest outside cell, dx/dy
    being where that cell lies (-1, 0, 1); distance 99 when every cell is inside."""
    best = (99.0, 0, 0)
    px, py = x + 0.5, y + 0.5
    for (cx, cy), is_in in inside.items():
        if is_in:
            continue
        x0, y0 = cx * T, cy * T
        dx = max(x0 - px, 0.0, px - (x0 + T))
        dy = max(y0 - py, 0.0, py - (y0 + T))
        d = math.hypot(dx, dy)
        if d < best[0]:
            best = (d, cx, cy)
    return best


def distance_to_outside(inside, x, y):
    return nearest_outside(inside, x, y)[0]


RIM_RNG = random.Random(31)
RIM_WIDTH = periodic_noise(RIM_RNG, cell=4, octaves=2)
RIM_SPECK = periodic_noise(RIM_RNG, cell=2, octaves=1)
RIM_CRACK = ridged(periodic_noise(random.Random(77), cell=4, octaves=2))
## Above this the crack web is a 1 px line; above the second, its hottest knots.
CRACK_LEVEL = 0.9
CRACK_HOT = 0.965
GLOW_REACH = 8.0


def rim_tile(mask):
    """Cooled crust on a lava cell where it touches the floor (or a cliff's foot): a dark contact
    line, a crust of plates split by dim cracks, a melting edge, then a hot glow fading into the
    open lava (dithered, so the lava's animation shows through it)."""
    inside = blob_context(mask)
    img = blank()
    for y in range(T):
        for x in range(T):
            d = distance_to_outside(inside, x, y)
            width = 4.5 + RIM_WIDTH[y][x] * 3.0
            if d >= width + GLOW_REACH:
                continue
            if d < 1.0:
                c = CRUST_D
            elif d >= width:
                heat = 1.0 - (d - width) / GLOW_REACH
                checker = (x + y) % 2 == 0
                if heat > 0.7:
                    c = LAVA_4 if RIM_SPECK[y][x] > 0.75 else LAVA_3
                elif heat > 0.4:
                    c = LAVA_3 if checker else LAVA_2
                elif heat > 0.2 and checker:
                    c = LAVA_2
                elif heat > 0.0 and checker and RIM_SPECK[y][x] > 0.5:
                    c = LAVA_1
                else:
                    continue
            elif d >= width - 1.2:
                c = LAVA_1 if RIM_SPECK[y][x] > 0.55 else LAVA_D
            elif RIM_CRACK[y][x] > CRACK_LEVEL and d > 1.5:
                c = LAVA_2 if RIM_CRACK[y][x] > CRACK_HOT else LAVA_1
            else:
                c = CRUST_D if RIM_SPECK[y][x] < 0.3 else CRUST_1
            put(img, x, y, c)
    return img


def rim_glow_frames():
    """The cracks of the crust pulsing: an overlay for any rim tile (over the open lava it hides)."""
    colours = [(LAVA_2, LAVA_3), (LAVA_3, LAVA_4), (LAVA_4, LAVA_HI), (LAVA_3, LAVA_4)]
    result = []
    for k in range(4):
        img = blank()
        for y in range(T):
            for x in range(T):
                v = RIM_CRACK[y][x]
                if v > CRACK_LEVEL:
                    put(img, x, y, colours[k][1] if v > CRACK_HOT else colours[k][0])
        result.append(img)
    return result


LEDGE_NOISE = periodic_noise(random.Random(45), cell=2, octaves=1)


def ledge_tile(mask):
    """The 2 px lip of a raised block on the high cell: lit on the sides that face the light (north
    and west), a dark outline with a lit line inside it where the block drops away south or east."""
    inside = blob_context(mask)
    img = blank()
    for y in range(T):
        for x in range(T):
            d, ox, oy = nearest_outside(inside, x, y)
            if d >= 2.0:
                continue
            shadow_side = oy > 0 or (oy == 0 and ox > 0)
            if d < 1.0:
                c = OUTLINE if shadow_side else STONE_HI
            else:
                c = STONE_HI if shadow_side else STONE_4
                if LEDGE_NOISE[y][x] > 0.9:
                    c = STONE_4 if shadow_side else STONE_3
            put(img, x, y, c)
    return img


# --- cliff faces ----------------------------------------------------------------------------------------
FACE_NOISE = periodic_noise(random.Random(52), n=48, cell=3, octaves=2)
COURSE = 8  # px per course of carved blocks
BLOCK = 12  # px per block along a course


def cliff_face(side, top, bottom, course0=0, lit_frame=None, moss_seed=None, x_offset=0):
    """A row of a cliff face: courses of carved blocks 8 px high and 12 px wide, staggered, with
    deep joints (a dark line and its shadow). `top`: the dark line under the plateau; `bottom`: the
    dark band where the face meets the lower floor; `lit_frame`: the foot standing in lava, lit from
    below over its last 8 px (4 flicker frames). `side` is 'l', 'm' or 'r' (the ends are outlined)."""
    img = blank()
    for y in range(T):
        course = course0 + y // COURSE
        row = y % COURSE
        joint_offset = (course % 2) * (BLOCK // 2) + x_offset
        for x in range(T):
            n = FACE_NOISE[(y + course0 * COURSE) % 48][(x + x_offset) % 48]
            along = (x + joint_offset) % BLOCK
            if row == 0:
                c = CLIFF_D
            elif row == 1:
                c = CLIFF_3 if n > 0.15 else CLIFF_2
            elif row == COURSE - 1:
                c = CLIFF_1
            else:
                c = CLIFF_2 if n > 0.1 else CLIFF_1
                if n > 0.85:
                    c = CLIFF_3
            if row != 0:
                if along == 0:
                    c = CLIFF_D
                elif along == 1:
                    c = CLIFF_1 if row != 1 else CLIFF_2
                elif along == BLOCK - 1 and row not in (1, COURSE - 1):
                    c = CLIFF_3 if n > 0.4 else CLIFF_2
            # a carved notch in the middle of some blocks
            block_id = ((x + joint_offset) // BLOCK + course * 7 + x_offset) % 5
            if block_id in (1, 3) and row in (3, 4) and along in (5, 6):
                c = CLIFF_1 if (row == 3) == (along == 5) else CLIFF_D
            put(img, x, y, c)
    if top:
        for x in range(T):
            put(img, x, 0, OUTLINE)
            put(img, x, 1, CLIFF_D if FACE_NOISE[1][(x + x_offset) % 48] > 0.5 else CLIFF_1)
    if bottom:
        for x in range(T):
            put(img, x, 13, CLIFF_1 if FACE_NOISE[13][(x + x_offset) % 48] > 0.35 else CLIFF_D)
            put(img, x, 14, CLIFF_D)
            put(img, x, 15, OUTLINE)
    if lit_frame is not None:
        underlight(img, lit_frame, x_offset)
    if side == "l":
        for y in range(T):
            put(img, 0, y, OUTLINE)
            if get(img, 1, y)[:3] not in (LAVA_1[:3], LAVA_2[:3], LAVA_3[:3], LAVA_D[:3]):
                put(img, 1, y, CLIFF_D)
    elif side == "r":
        for y in range(T):
            put(img, 15, y, OUTLINE)
            if get(img, 14, y)[:3] not in (LAVA_1[:3], LAVA_2[:3], LAVA_3[:3], LAVA_D[:3]):
                put(img, 14, y, CLIFF_D)
    if moss_seed is not None:
        vines_hang(img, moss_seed, from_top=top)
    return img


def underlight(img, frame, x_offset):
    """The lava's light climbing the foot of a face: lapping lava on the last row, then an orange
    glow fading upward over 6 to 8 px, higher or lower per column as it flickers."""
    wobble = [[2, 1, 0, 1], [1, 0, 1, 2], [0, 1, 2, 1], [1, 2, 1, 0]][frame]
    for x in range(T):
        n = FACE_NOISE[(x + x_offset) % 48][(frame * 11 + 3) % 48]
        reach = 6 + wobble[(x + x_offset) % 4] + (1 if n > 0.7 else 0)
        put(img, x, 15, LAVA_3 if n > 0.6 or frame % 2 == 0 and n > 0.4 else LAVA_2)
        put(img, x, 14, LAVA_2 if n > 0.5 else LAVA_1)
        for i in range(2, reach):
            y = 15 - i
            heat = 1.0 - (i - 2) / float(reach - 2)
            current = get(img, x, y)[:3]
            dark = current in (CLIFF_D[:3], OUTLINE[:3], CLIFF_1[:3])
            if heat > 0.75:
                c = LAVA_D if dark else LAVA_1
            elif heat > 0.5:
                c = LAVA_D if dark else (LAVA_1 if (x + y) % 2 == 0 else CLIFF_LAVA_LIT)
            elif heat > 0.25:
                c = CLIFF_1 if dark else (CLIFF_3 if (x + y) % 2 == 0 else CLIFF_LAVA_LIT)
            else:
                c = CLIFF_1 if dark else (CLIFF_3 if (x + y) % 2 == 0 else CLIFF_2)
            put(img, x, y, c)
        if n > 0.9:
            put(img, x, 15 - reach, LAVA_2)


def vines_hang(img, seed, from_top=True):
    """Vines dripping down the face from its lip, with leaves and a bright tip, and moss on the edge."""
    rng = random.Random(seed)
    start = 1 if from_top else 0
    for x in range(1, 15):
        if rng.random() < 0.5:
            put(img, x, start, MOSS_1 if rng.random() < 0.6 else MOSS_2)
            if rng.random() < 0.3:
                put(img, x, start + 1, MOSS_D)
    for _ in range(rng.randrange(2, 4)):
        x = rng.randrange(2, 14)
        length = rng.randrange(5, 13) if from_top else rng.randrange(2, 6)
        sway = 0
        for y in range(start, min(T - 2, start + length)):
            if rng.random() < 0.2:
                sway = max(-1, min(1, sway + rng.choice((-1, 1))))
            px = x + sway
            put(img, px, y, MOSS_1 if rng.random() < 0.65 else MOSS_D)
            if rng.random() < 0.3:
                put(img, px + rng.choice((-1, 1)), y, MOSS_2)
        put(img, x + sway, min(T - 2, start + length), MOSS_HI if rng.random() < 0.6 else MOSS_2)


# --- shadows, stairs, bridges ---------------------------------------------------------------------------
def shadow_tile(a):
    img = blank()
    fill(img, 0, 0, T, T, alpha(OUTLINE, a))
    return img


def stairs_steps(up=True):
    """Four steps of 4 px climbing north (or east when `up` is False): lit tread, dark riser."""
    img = blank()
    rng = random.Random(8)
    for i in range(4):
        for j in range(4):
            tone = [STONE_4, STONE_3, STONE_2, JOINT][j]
            if j == 1 and rng.random() < 0.2:
                tone = STONE_2
            for k in range(T):
                if up:
                    put(img, k, i * 4 + j, tone)
                else:
                    put(img, 15 - (i * 4 + j), k, tone)
    for k in range(T):
        if up:
            put(img, k, 0, STONE_HI if k % 5 else STONE_4)
        else:
            put(img, 15, k, STONE_HI if k % 5 else STONE_4)
    return img


def parapet_vertical(x0, x1):
    """A stone balustrade running north-south between x0 and x1: top face, dark sides, blocks."""
    img = blank()
    for y in range(T):
        for x in range(x0, x1):
            c = STONE_3
            if x == x0:
                c = STONE_4
            if x == x1 - 1:
                c = STONE_1
            if y % 5 == 4:
                c = JOINT
            put(img, x, y, c)
        put(img, x0 - 1, y, OUTLINE)
        put(img, x1, y, OUTLINE)
    return img


def parapet_horizontal(y0, y1, merlons=True):
    """A stone parapet running west-east: its top face (rows y0..y0+2), then its front face."""
    img = blank()
    for x in range(T):
        for y in range(y0, y1):
            c = STONE_3 if y < y0 + 3 else STONE_2
            if y == y0:
                c = STONE_4
            if y == y0 + 3:
                c = STONE_1
            if y >= y0 + 3 and (x + 2) % 6 == 0:
                c = JOINT
            if y == y1 - 1:
                c = JOINT
            put(img, x, y, c)
        put(img, x, y0 - 1, OUTLINE)
        put(img, x, y1, OUTLINE)
    if merlons:
        for x in (3, 4, 11, 12):
            for y in range(y0 - 1, y0 + 2):
                put(img, x, y, CLEAR)
            put(img, x, y0 + 2, OUTLINE)
            put(img, x - 1 if x in (3, 11) else x + 1, y0 - 1, OUTLINE)
    return img


def stone_post():
    img = blank()
    fill(img, 3, 2, 13, 8, STONE_4)
    fill(img, 3, 8, 13, 14, STONE_2)
    for x in range(3, 13):
        put(img, x, 2, STONE_HI)
        put(img, x, 7, STONE_3)
        put(img, x, 13, STONE_1)
    put(img, 7, 10, JOINT)
    put(img, 8, 10, JOINT)
    return outline(img)


def stone_deck(horizontal=True):
    """Flagstones of a bridge: two courses of narrow slabs across the walking direction."""
    img = floor_tile(90 if horizontal else 91, "3x2", level=1)
    if not horizontal:
        img = img.transpose(Image.TRANSPOSE)
    return img


def wood_deck(horizontal=True):
    """Planks across the walking direction, with their nails."""
    img = blank()
    rng = random.Random(17)
    for x in range(T):
        plank = x // 4
        for y in range(T):
            c = BRONZE_1
            if x % 4 == 0:
                c = BRONZE_D
            elif x % 4 == 1:
                c = BRONZE_2
            if rng.random() < 0.08:
                c = BRONZE_D if c == BRONZE_1 else c
            put(img, x, y, c)
        if x % 4 == 2:
            put(img, x, 2 + (plank % 2), OUTLINE)
            put(img, x, 13 - (plank % 2), OUTLINE)
    for x in range(T):
        put(img, x, 0, BRONZE_D)
        put(img, x, 15, OUTLINE)
    if not horizontal:
        img = img.transpose(Image.TRANSPOSE)
    return img


def rope_rail(horizontal=True, sag_top=True):
    """Two ropes sagging between posts along a wooden bridge's edge."""
    img = blank()
    for x in range(T):
        sag = int(round(1.5 - 1.5 * math.cos((x + 0.5) / T * 2 * math.pi)))
        for base in (5, 9):
            y = base + sag
            put(img, x, y, BRONZE_2 if x % 3 else GOLD_HI)
            put(img, x, y + 1, BRONZE_D)
    if not sag_top:
        img = img.transpose(Image.FLIP_TOP_BOTTOM)
    if not horizontal:
        img = img.transpose(Image.TRANSPOSE)
    return img


def rope_post():
    img = blank()
    fill(img, 6, 1, 10, 14, BRONZE_1)
    for y in range(1, 14):
        put(img, 6, y, BRONZE_2)
        put(img, 9, y, BRONZE_D)
    fill(img, 6, 1, 10, 3, BRONZE_2)
    for x in range(5, 11):
        put(img, x, 4, GOLD_HI if x % 2 else BRONZE_2)
        put(img, x, 8, GOLD_HI if x % 2 else BRONZE_2)
    return outline(img)


# --- small props the roles need --------------------------------------------------------------------------
def column(seed, moss=False):
    """A carved stone pillar, two tiles tall (top, base)."""
    rng = random.Random(seed)
    img = blank(T, 2 * T)
    fill(img, 4, 1, 12, 31, STONE_2)
    for y in range(1, 31):
        put(img, 4, y, STONE_4)
        put(img, 5, y, STONE_3)
        put(img, 11, y, STONE_1)
    fill(img, 3, 1, 13, 4, STONE_3)
    fill(img, 3, 1, 13, 2, STONE_HI)
    fill(img, 3, 27, 13, 31, STONE_3)
    fill(img, 3, 30, 13, 31, STONE_1)
    for y in (9, 10, 11, 17, 18, 19):
        for x in range(5, 11):
            put(img, x, y, BRONZE_1 if (x + y) % 2 else GOLD_HI if y in (10, 18) else BRONZE_D)
    for y in range(5, 27, 3):
        put(img, 7 + (y % 2), y, JOINT)
    if moss:
        for _ in range(8):
            x, y = rng.randrange(3, 12), rng.randrange(2, 29)
            put(img, x, y, MOSS_1 if rng.random() < 0.7 else MOSS_2)
            put(img, x, y + 1, MOSS_D)
    return outline(img)


def boulder(seed, small=False):
    """A dark lava rock, cooled, with a few warm cracks."""
    rng = random.Random(seed)
    img = blank()
    w, h = (10, 8) if small else (14, 12)
    cx, cy = 8, 9
    for y in range(T):
        for x in range(T):
            if ((x + 0.5 - cx) / (w / 2)) ** 2 + ((y + 0.5 - cy) / (h / 2)) ** 2 <= 1.0:
                top_left = ((x + 0.5 - cx + 2) / (w / 2)) ** 2 + ((y + 0.5 - cy + 2) / (h / 2)) ** 2
                c = STONE_1 if top_left > 0.9 else STONE_2
                if top_left < 0.35:
                    c = STONE_3
                if rng.random() < 0.08:
                    c = STONE_D
                put(img, x, y, c)
    for _ in range(2 if small else 3):
        x, y = rng.randrange(cx - 3, cx + 3), rng.randrange(cy - 2, cy + 3)
        put(img, x, y, LAVA_1)
        put(img, x + 1, y, LAVA_2)
    return outline(img)


def rocks_heap(seed):
    img = blank()
    rng = random.Random(seed)
    lighter = {STONE_1: STONE_2, STONE_2: STONE_3, STONE_3: STONE_4}
    darker = {STONE_1: STONE_D, STONE_2: STONE_1, STONE_3: STONE_2}
    for (x, y, w, h, tone) in ((1, 8, 7, 6, STONE_2), (7, 6, 8, 8, STONE_3), (4, 3, 7, 6, STONE_2), (10, 9, 5, 5, STONE_1)):
        fill(img, x, y, x + w, y + h, tone)
        for k in range(x, x + w):
            put(img, k, y, lighter[tone])
            put(img, k, y + h - 1, darker[tone])
        put(img, x, y, JOINT)
        put(img, x + w - 1, y + h - 1, JOINT)
    for _ in range(4):
        x, y = rng.randrange(2, 14), rng.randrange(4, 13)
        put(img, x, y, MOSS_1)
    return outline(img)


def flame(img, cx, base_y, height, frame, colours):
    for y in range(height):
        half = max(1, int((height - y) / height * 2.6 + 0.5)) - (1 if y < 2 else 0)
        sway = int(round(math.sin((frame / 3.0 + y / 6.0) * 2 * math.pi) * 0.8)) if y > height // 2 else 0
        for x in range(cx - half + sway, cx + half + 1 + sway):
            t = (height - y) / float(height)
            c = colours[0] if t > 0.75 else colours[1] if t > 0.45 else colours[2]
            if abs(x - cx - sway) == half and half > 0:
                c = colours[2] if t > 0.4 else colours[3]
            put(img, x, base_y - y, c)
    if frame % 2 == 0:
        put(img, cx + 2 * (frame % 3) - 2, base_y - height - 1 - frame % 2, colours[1])


def brazier(frame):
    img = blank()
    fill(img, 4, 9, 12, 14, BRONZE_1)
    for x in range(4, 12):
        put(img, x, 9, BRONZE_2)
        put(img, x, 13, BRONZE_D)
    fill(img, 6, 14, 10, 15, BRONZE_D)
    put(img, 3, 10, BRONZE_2)
    put(img, 12, 10, BRONZE_2)
    outline(img)
    flame(img, 8, 8, 6 + (frame % 2), frame, (FIRE_HI, FIRE_2, FIRE_1, FIRE_D))
    return img


def torch(frame):
    img = blank()
    fill(img, 7, 7, 9, 15, BRONZE_1)
    put(img, 7, 7, BRONZE_2)
    fill(img, 6, 6, 10, 8, BRONZE_D)
    outline(img)
    flame(img, 8, 5, 5 + (frame % 2), frame, (FIRE_HI, FIRE_2, FIRE_1, FIRE_D))
    return img


def crate():
    img = blank()
    fill(img, 3, 4, 13, 14, BRONZE_1)
    for k in range(3, 13):
        put(img, k, 4, BRONZE_2)
        put(img, k, 13, BRONZE_D)
        put(img, 3, k + 1, BRONZE_2)
        put(img, 12, k + 1, BRONZE_D)
    for k in range(10):
        put(img, 3 + k, 4 + k, BRONZE_D)
        put(img, 12 - k, 4 + k, BRONZE_D)
    return outline(img)


def chest(opened=False):
    img = blank()
    fill(img, 2, 6, 14, 14, BRONZE_1)
    fill(img, 2, 6, 14, 9, BANNER_1 if not opened else BRONZE_D)
    for x in range(2, 14):
        put(img, x, 13, BRONZE_D)
        put(img, x, 9, GOLD_HI if x % 3 else BRONZE_2)
    put(img, 7, 10, GOLD_HI)
    put(img, 8, 10, GOLD_HI)
    if opened:
        fill(img, 2, 3, 14, 6, BANNER_1)
        for x in range(2, 14):
            put(img, x, 3, BANNER_2)
        for x in range(3, 13, 2):
            put(img, x, 7, GOLD_HI)
    return outline(img)


def stele():
    img = blank()
    fill(img, 4, 1, 12, 15, STONE_3)
    for y in range(1, 15):
        put(img, 4, y, STONE_4)
        put(img, 11, y, STONE_1)
    for y, row in enumerate(RUNES["b"]):
        for x, ch in enumerate(row):
            if ch == "#" and 0 < x < 6:
                put(img, 5 + x, 4 + y, BRONZE_2 if (x + y) % 2 else GOLD_HI)
    return outline(img)


def rubble(seed, mossy=False):
    img = blank()
    rng = random.Random(seed)
    for _ in range(6):
        x, y, w = rng.randrange(1, 12), rng.randrange(4, 13), rng.randrange(2, 5)
        fill(img, x, y, x + w, y + 2, STONE_2)
        for k in range(x, x + w):
            put(img, k, y, STONE_3)
            put(img, k, y + 2, STONE_D)
        if mossy and rng.random() < 0.6:
            put(img, x + 1, y - 1, MOSS_1)
    return img


def pebbles(seed):
    img = blank()
    rng = random.Random(seed)
    for _ in range(7):
        x, y = rng.randrange(1, 15), rng.randrange(2, 14)
        put(img, x, y, STONE_3)
        put(img, x + 1, y, STONE_1)
        put(img, x, y + 1, STONE_1)
    return img


def embers(seed, warm=True):
    img = blank()
    rng = random.Random(seed)
    for _ in range(5):
        x, y = rng.randrange(1, 14), rng.randrange(2, 14)
        put(img, x, y, LAVA_HI if warm else LAVA_3)
        put(img, x + 1, y, LAVA_2)
        put(img, x, y + 1, CRUST_1)
        put(img, x + 1, y + 1, CRUST_D)
    return img


def ash(seed):
    img = blank()
    rng = random.Random(seed)
    for _ in range(9):
        x, y = rng.randrange(1, 15), rng.randrange(1, 15)
        put(img, x, y, ASH if rng.random() < 0.5 else SMOKE_2)
        if rng.random() < 0.5:
            put(img, x + 1, y, SMOKE_1)
    return img


def patch_tiles(mask_list, inner_colours, seed):
    """A nine-slice (plus inner corners) of a patch on the floor: moss or ash with a rounded edge."""
    rng = random.Random(seed)
    noise = periodic_noise(rng, cell=4, octaves=2)
    result = []
    for mask in mask_list:
        inside = blob_context(mask)
        img = floor_tile(seed + mask, "2x2", level=1)
        for y in range(T):
            for x in range(T):
                d = distance_to_outside(inside, x, y)
                edge = 2.5 + noise[y][x] * 3.0
                if d >= edge:
                    v = noise[(y * 3) % T][(x * 5) % T]
                    put(img, x, y, inner_colours[0] if v < 0.35 else inner_colours[1] if v < 0.8 else inner_colours[2])
                elif d >= edge - 1.0 and noise[y][x] > 0.3:
                    put(img, x, y, inner_colours[0])
        result.append(img)
    return result


# --- the sheet ----------------------------------------------------------------------------------------------
def build_tiles():
    """Returns (ordered list of (name, image), patterns {name: [names]}, animations {name: [names]},
    aliases {name: name})."""
    tiles = []
    patterns = {}
    animations = {}
    aliases = {}

    def add(name, img):
        assert img.size == (T, T), (name, img.size)
        tiles.append((name, img))

    def add_frames(name, frames):
        # Animated tiles are consecutive cells of one row.
        while (len(tiles) % COLUMNS) + len(frames) > COLUMNS:
            add("_pad_%d" % len(tiles), blank())
        names = []
        for i, img in enumerate(frames):
            frame_name = "%s_f%d" % (name, i)
            add(frame_name, img)
            names.append(frame_name)
        animations[name] = names
        return names

    def add_tall(name, img):
        add(name + "_top", img.crop((0, 0, T, T)))
        add(name + "_base", img.crop((0, T, T, 2 * T)))

    # floors: level 1 under the plain names, then every level under its own
    kinds = ["2x2", "2x2", "3x2", "brick", "brick3", "tall"]
    for i, (letter, kind) in enumerate(zip("abcdef", kinds)):
        add("floor_" + letter, floor_tile(1 + i, kind, level=1))
        aliases["floor1_" + letter] = "floor_" + letter
    add("floor_moss_a", floor_tile(7, "2x2", level=1, moss=0.4))
    add("floor_moss_b", floor_tile(8, "brick", level=1, moss=0.7))
    add("floor_crack_a", floor_tile(9, "2x2", level=1, crack=True))
    add("floor_crack_b", floor_tile(10, "3x2", level=1, crack=True))
    for detail in ("moss_a", "moss_b", "crack_a", "crack_b"):
        aliases["floor1_" + detail] = "floor_" + detail
    for rune in "abcd":
        add("floor_rune_" + rune, floor_tile(11, "2x2", level=1, rune=rune))
        aliases["floor1_rune_" + rune] = "floor_rune_" + rune
    add_frames("floor_rune_glow", [floor_tile(11, "2x2", level=1, rune="a", glow=g) for g in (BRONZE_2, GOLD_HI, RUNE_GLOW, GOLD_HI)])
    for level in (0, 2):
        for i, (letter, kind) in enumerate(zip("abcdef", kinds)):
            add("floor%d_%s" % (level, letter), floor_tile(1 + i + 20 * level, kind, level=level))
        add("floor%d_moss_a" % level, floor_tile(7 + 20 * level, "2x2", level=level, moss=0.4))
        add("floor%d_moss_b" % level, floor_tile(8 + 20 * level, "brick", level=level, moss=0.7))
        add("floor%d_crack_a" % level, floor_tile(9 + 20 * level, "2x2", level=level, crack=True))
        add("floor%d_crack_b" % level, floor_tile(10 + 20 * level, "3x2", level=level, crack=True))
    for rune in "abcd":
        add("floor2_rune_" + rune, floor_tile(51, "2x2", level=2, rune=rune))
    add_frames("floor2_rune_glow", [floor_tile(51, "2x2", level=2, rune="a", glow=g) for g in (BRONZE_2, GOLD_HI, RUNE_GLOW, GOLD_HI)])
    for level in (0, 1, 2):
        for name, img in cut(floor_macro(80 + level, level), lambda cx, cy, level=level: "floor%d_m_%d_%d" % (level, cx, cy)):
            add(name, img)
    # details as overlays, so they lie on the macro plans without breaking their slabs
    add("moss_over_a", moss_overlay(13, 0.4, LEVEL_TONES[1]["moss"]))
    add("moss_over_b", moss_overlay(14, 0.7, LEVEL_TONES[1]["moss"]))
    add("moss_over_c", moss_overlay(15, 0.5, LEVEL_TONES[2]["moss"]))
    for level in (0, 1, 2):
        add("floor%d_crack_over_a" % level, crack_overlay(16 + level, level))
        add("floor%d_crack_over_b" % level, crack_overlay(19 + level, level))

    # lava: the macro sea (LAVA_MACRO² animations per variant), the folded small tile and its stills and bubbles
    for variant, field in zip(LAVA_VARIANTS, LAVA_FIELDS):
        macro_frames = [field.frame(k) for k in range(FLOW_FRAMES)]
        for cy in range(LAVA_MACRO):
            for cx in range(LAVA_MACRO):
                add_frames("%s_%d_%d" % (variant, cx, cy), [f.crop((cx * T, cy * T, cx * T + T, cy * T + T)) for f in macro_frames])
    small = lava_base_tiles()
    for name, img in zip("abcd", small):
        add("lava_" + name, img)
    add_frames("lava_flow", [LAVA_SMALL.frame(k) for k in range(FLOW_FRAMES)])
    add_frames("lava_bubble", bubble_frames(small[0]))
    add_frames("lava_bubble_over", bubble_frames(None))

    # blobs: rim (lava side) and ledge (plateau side)
    rim_names = []
    for i, mask in enumerate(BLOB_MASKS):
        add("lava_rim_%d" % i, rim_tile(mask))
        rim_names.append("lava_rim_%d" % i)
    patterns["lava_rim"] = rim_names
    patterns["lava_rim_inner"] = rim_names[9:13]
    add_frames("lava_rim_glow", rim_glow_frames())
    ledge_names = []
    for i, mask in enumerate(BLOB_MASKS):
        add("ledge_%d" % i, ledge_tile(mask))
        ledge_names.append("ledge_%d" % i)
    patterns["ledge"] = ledge_names
    patterns["ledge_inner"] = ledge_names[9:13]

    # cliff faces
    for side in "lmr":
        offset = {"l": 0, "m": 5, "r": 3}[side]
        add("cliff_face_" + side, cliff_face(side, True, True, 0, x_offset=offset))
        add("cliff_face2_top_" + side, cliff_face(side, True, False, 0, x_offset=offset))
        add("cliff_face2_bot_" + side, cliff_face(side, False, True, 2, x_offset=offset))
        add("cliff_face_mid_" + side, cliff_face(side, False, False, 2, x_offset=offset))
        add("cliff_moss_" + side, cliff_face(side, True, True, 0, moss_seed=20 + offset, x_offset=offset))
        add("cliff_moss2_top_" + side, cliff_face(side, True, False, 0, moss_seed=30 + offset, x_offset=offset))
        add("cliff_moss2_bot_" + side, cliff_face(side, False, True, 2, moss_seed=40 + offset, x_offset=offset))
    for side in "lmr":
        offset = {"l": 0, "m": 5, "r": 3}[side]
        add_frames("cliff_foot_lava_" + side, [cliff_face(side, False, False, 2, lit_frame=k, x_offset=offset) for k in range(4)])

    # shadows: 40 % then 20 %
    add("shadow_s_1", shadow_tile(102))
    add("shadow_s_2", shadow_tile(51))

    # stairs
    add("stairs_up_steps", stairs_steps(True))
    add("stairs_up_rail_l", parapet_vertical(7, 13))
    add("stairs_up_rail_r", parapet_vertical(3, 9))
    add("stairs_side_steps", stairs_steps(False))
    add("stairs_side_rail_t", parapet_horizontal(7, 14, merlons=False))
    add("stairs_side_rail_b", parapet_horizontal(2, 9, merlons=False))

    # bridges
    add("bridge_stone_deck_h", stone_deck(True))
    add("bridge_stone_deck_v", stone_deck(False))
    add("bridge_stone_rail_n", parapet_horizontal(7, 14))
    add("bridge_stone_rail_s", parapet_horizontal(2, 9))
    add("bridge_stone_rail_e", parapet_vertical(2, 8))
    add("bridge_stone_rail_w", parapet_vertical(8, 14))
    add("bridge_stone_post", stone_post())
    add("bridge_wood_deck_h", wood_deck(True))
    add("bridge_wood_deck_v", wood_deck(False))
    add("bridge_wood_rail_n", rope_rail(True, True))
    add("bridge_wood_rail_s", rope_rail(True, False))
    add("bridge_wood_rail_e", rope_rail(False, False))
    add("bridge_wood_rail_w", rope_rail(False, True))
    add("bridge_rope_post", rope_post())

    # areas the game's roles ask for: a lava pond (opaque), moss and ash patches, a slab floor
    pond_names, pond_inner = [], []
    for i in range(13):
        img = over(small[i % 4].copy(), rim_tile(BLOB_MASKS[i]))
        add("lava_pond_%d" % i, img)
        (pond_names if i < 9 else pond_inner).append("lava_pond_%d" % i)
    patterns["pond"] = pond_names
    patterns["pond_inner"] = pond_inner
    for name, colours, seed in (("moss_patch", (MOSS_D, MOSS_1, MOSS_2), 61), ("ash_patch", (SMOKE_1, SMOKE_2, ASH), 62)):
        imgs = patch_tiles(BLOB_MASKS[:13], colours, seed)
        names = []
        for i, img in enumerate(imgs):
            add("%s_%d" % (name, i), img)
            names.append("%s_%d" % (name, i))
        patterns[name] = names[:9]
        patterns[name + "_inner"] = names[9:]
    slab_names = []
    for i in range(9):
        img = over(floor_tile(70 + i, "2x2", level=2), ledge_tile(BLOB_MASKS[i]))
        add("slab_floor_%d" % i, img)
        slab_names.append("slab_floor_%d" % i)
    patterns["slab_floor"] = slab_names

    # small props for the roles (trees, bushes, fires...)
    add_tall("column", column(1))
    add_tall("column_moss", column(2, moss=True))
    add("boulder_a", boulder(3))
    add("boulder_b", boulder(4))
    add("boulder_small", boulder(5, small=True))
    add("rocks_heap", rocks_heap(6))
    add_frames("brazier", [brazier(k) for k in range(3)])
    add_frames("torch", [torch(k) for k in range(3)])
    add("crate", crate())
    add("chest_closed", chest(False))
    add("chest_open", chest(True))
    add("stele", stele())
    add("rubble_a", rubble(7))
    add("rubble_b", rubble(8, mossy=True))
    add("pebbles", pebbles(9))
    add("ember_a", embers(10))
    add("ember_b", embers(11, warm=False))
    add("ash_a", ash(12))
    return tiles, patterns, animations, aliases


def write_sheet(tiles, patterns, animations, aliases):
    rows = (len(tiles) + COLUMNS - 1) // COLUMNS
    sheet = Image.new("RGBA", (COLUMNS * T, rows * T), CLEAR)
    coords = {}
    for i, (name, img) in enumerate(tiles):
        c, r = i % COLUMNS, i // COLUMNS
        sheet.paste(img, (c * T, r * T))
        if not name.startswith("_pad_"):
            coords[name] = [c, r]
    for alias, name in aliases.items():
        coords[alias] = coords[name]
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, "temple_sheet.png"))
    data = {"tile_size": T, "columns": COLUMNS, "tiles": coords,
            "patterns": {name: [coords[n] for n in names] for name, names in patterns.items()},
            "animations": {name: [coords[n] for n in names] for name, names in animations.items()},
            "blob_masks": BLOB_MASKS}
    with open(os.path.join(OUT, "temple_tiles.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1)
    return sheet, coords


# --- preview (not part of the game) ----------------------------------------------------------------------------
def contact_sheet(tiles, scale=4):
    cell_w, cell_h = T * scale + 6, T * scale + 14
    cols = 16
    rows = (len(tiles) + cols - 1) // cols
    img = Image.new("RGBA", (cols * cell_w, rows * cell_h), (24, 20, 26, 255))
    d = ImageDraw.Draw(img)
    for i, (name, tile) in enumerate(tiles):
        c, r = i % cols, i // cols
        big = tile.resize((T * scale, T * scale), Image.NEAREST)
        bg = Image.new("RGBA", big.size, (70, 60, 66, 255))
        bg.alpha_composite(big)
        img.paste(bg, (c * cell_w + 3, r * cell_h + 2))
        d.text((c * cell_w + 3, r * cell_h + T * scale + 3), name[:13], fill=(220, 200, 190, 255))
    return img


SAMPLE = [
    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
    "~~~000000000000~~~~~~~~~~~~~~~",
    "~~00000000000000~~~~~~1111111~",
    "~~00001111110000~~~~~01111111~",
    "~~00001111110000~~~~~01122211~",
    "~~00001111110000~~~~~01122211~",
    "~~00001111110000bbbbb01122211~",
    "~~0000000s000000~~~~~01111111~",
    "~~00000000000000~~~~~01111111~",
    "~~~0000000000000~~~~~~1111111~",
    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
    "~~~~~~~~0000000~~~~~~~~~~~~~~~",
    "~~~~~~~00000000www0000000~~~~~",
    "~~~~~~~00000000~~~~0000000~~~~",
    "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~",
]


def sample_map(coords, sheet, frame=0, scale=3):
    """A 30x18 composition drawn only from the sheet, in the layer order the game uses: lava, faces,
    floors, rims, ledges, shadows, stairs and bridges."""
    W, H = len(SAMPLE[0]), len(SAMPLE)
    img = Image.new("RGBA", (W * T, H * T), (0, 0, 0, 255))
    rng = random.Random(3)

    def tile(name):
        c, r = coords[name]
        return sheet.crop((c * T, r * T, c * T + T, r * T + T))

    def blit(name, x, y):
        img.alpha_composite(tile(name), (x * T, y * T))

    def height(x, y):
        if not (0 <= x < W and 0 <= y < H):
            return -1
        ch = SAMPLE[y][x]
        if ch in "~bw":
            return -1
        if ch == "s":
            return 0
        return int(ch)

    # cells covered by a face: (x, y) -> (tile base name, side, ends on a floor, owner height)
    faces = {}
    for y in range(H):
        for x in range(W):
            h = height(x, y)
            below = height(x, y + 1)
            if h < 0 or below >= h:
                continue
            drop = h - below
            same = lambda nx: height(nx, y) == h and height(nx, y + 1) == below  # noqa: E731
            side = "m" if same(x - 1) and same(x + 1) else "l" if same(x + 1) else "r" if same(x - 1) else "m"
            mossy = rng.random() < 0.25
            for row in range(drop):
                into_lava = below < 0 and row == drop - 1
                if drop == 1:
                    kind = "foot" if into_lava else ("cliff_moss_" if mossy else "cliff_face_")
                elif row == 0:
                    kind = "cliff_moss2_top_" if mossy else "cliff_face2_top_"
                elif row == drop - 1:
                    kind = "foot" if into_lava else ("cliff_moss2_bot_" if mossy else "cliff_face2_bot_")
                else:
                    kind = "cliff_face_mid_"
                faces[(x, y + 1 + row)] = (kind, side, row == drop - 1 and not into_lava, h)
    bubbles = {}
    for y in range(H):
        for x in range(W):
            if height(x, y) < 0 and (x, y) not in faces and rng.random() < 0.04:
                bubbles[(x, y)] = rng.randrange(6)
    # 1. lava: the macro sea, with bubbles laid over it
    for y in range(H):
        for x in range(W):
            variant = LAVA_VARIANTS[(x // LAVA_MACRO + 2 * (y // LAVA_MACRO)) % len(LAVA_VARIANTS)]
            blit("%s_%d_%d_f%d" % (variant, x % LAVA_MACRO, y % LAVA_MACRO, frame % FLOW_FRAMES), x, y)
            if (x, y) in bubbles:
                blit("lava_bubble_over_f%d" % ((frame + bubbles[(x, y)]) % 6), x, y)
    # 2. faces
    for (x, y), (kind, side, _, _) in faces.items():
        if kind == "foot":
            blit("cliff_foot_lava_%s_f%d" % (side, (frame + (x * 3 + y)) % 4), x, y)
        else:
            blit(kind + side, x, y)
    # 3. floors by level: the macro plan, with a few details
    floors = {}
    for y in range(H):
        for x in range(W):
            h = height(x, y)
            if h < 0 or (x, y) in faces or SAMPLE[y][x] == "s":
                continue
            name = "floor%d_m_%d_%d" % (h, x % MACRO, y % MACRO)
            roll = rng.random()
            detail = None
            if roll < 0.05:
                detail = "moss_over_" + ("c" if h == 2 else rng.choice("ab"))
            elif roll < 0.08:
                detail = "floor%d_crack_over_%s" % (h, rng.choice("ab"))
            floors[(x, y)] = (name, detail)
    floors[(24, 6)] = ("rune", None)
    for (x, y), (name, detail) in floors.items():
        if name == "rune":
            blit("floor2_rune_glow_f%d" % (frame % 4), x, y)
        else:
            blit(name, x, y)
        if detail is not None:
            blit(detail, x, y)
    # 4. rims on the lava cells around every island and face foot (the bridges' cells are lava too)

    def is_lava(nx, ny):
        return height(nx, ny) < 0 and (nx, ny) not in faces

    for y in range(H):
        for x in range(W):
            if not is_lava(x, y) or SAMPLE[y][x] in "bw":
                continue
            mask = 0
            for bit, (dx, dy) in NEIGHBOURS:
                if is_lava(x + dx, y + dy):
                    mask |= bit
            mask = normalise_mask(mask)
            if mask == 255:
                continue
            blit("lava_rim_%d" % BLOB_MASKS.index(mask), x, y)
            blit("lava_rim_glow_f%d" % ((frame + x + 2 * y) % 4), x, y)
    # 5. ledges on the high side of every change: a neighbour is "inside" when it stands at my level
    # or higher, or is the face of a plateau rising above me (never the face that drops from my level)
    for y in range(H):
        for x in range(W):
            h = height(x, y)
            if h < 0 or (x, y) in faces:
                continue
            mask = 0
            for bit, (dx, dy) in NEIGHBOURS:
                nx, ny = x + dx, y + dy
                if (nx, ny) in faces:
                    if faces[(nx, ny)][3] > h:
                        mask |= bit
                elif height(nx, ny) >= h:
                    mask |= bit
            mask = normalise_mask(mask)
            if mask == 255:
                continue
            blit("ledge_%d" % BLOB_MASKS.index(mask), x, y)
    # 6. shadows south of a face that ends on a floor
    for (x, y), (kind, side, on_floor, _) in faces.items():
        if on_floor:
            for i, name in ((1, "shadow_s_1"), (2, "shadow_s_2")):
                if height(x, y + i) >= 0 and (x, y + i) not in faces:
                    blit(name, x, y + i)
    # 7. stairs and bridges
    for y in range(H):
        for x in range(W):
            if SAMPLE[y][x] == "s":
                blit("stairs_up_steps", x, y)
                blit("stairs_up_rail_l", x - 1, y)
                blit("stairs_up_rail_r", x + 1, y)
            elif SAMPLE[y][x] == "b":
                blit("bridge_stone_deck_h", x, y)
                blit("bridge_stone_rail_n", x, y - 1)
                blit("bridge_stone_rail_s", x, y + 1)
            elif SAMPLE[y][x] == "w":
                blit("bridge_wood_deck_h", x, y)
                blit("bridge_wood_rail_n", x, y - 1)
                blit("bridge_wood_rail_s", x, y + 1)
    blit("bridge_stone_post", 15, 6)
    blit("bridge_stone_post", 15, 8)
    blit("bridge_rope_post", 14, 14)
    blit("bridge_rope_post", 14, 16)
    blit("brazier_f%d" % (frame % 3), 4, 4)
    blit("brazier_f%d" % ((frame + 1) % 3), 11, 4)
    blit("column_top", 22, 3)
    blit("column_base", 22, 4)
    blit("boulder_a", 12, 9)
    blit("rubble_b", 3, 8)
    blit("torch_f%d" % (frame % 3), 9, 15)
    return img.resize((W * T * scale, H * T * scale), Image.NEAREST)


def animation_gifs(coords, sheet, animations, folder, scale=6):
    for name, names in animations.items():
        if name.startswith("lava_m") and name != "lava_m_0_0":
            continue
        frames = []
        for frame_name in names:
            c, r = coords[frame_name]
            tile = sheet.crop((c * T, r * T, c * T + T, r * T + T))
            bg = Image.new("RGBA", (T, T), (70, 60, 66, 255))
            bg.alpha_composite(tile)
            frames.append(bg.resize((T * scale, T * scale), Image.NEAREST).convert("P", palette=Image.ADAPTIVE))
        frames[0].save(os.path.join(folder, "anim_%s.gif" % name), save_all=True, append_images=frames[1:],
                       duration=140, loop=0)
    # the three lava macros side by side (their shared edges meet), looping
    frames = []
    for k in range(FLOW_FRAMES):
        row = Image.new("RGBA", (LAVA_MN * len(LAVA_FIELDS), LAVA_MN), CLEAR)
        for i, field in enumerate(LAVA_FIELDS):
            row.paste(field.frame(k), (i * LAVA_MN, 0))
        frames.append(row.resize((row.width * 2, row.height * 2), Image.NEAREST).convert("P", palette=Image.ADAPTIVE))
    frames[0].save(os.path.join(folder, "anim_lava_macro.gif"), save_all=True, append_images=frames[1:], duration=160, loop=0)


def main():
    tiles, patterns, animations, aliases = build_tiles()
    sheet, coords = write_sheet(tiles, patterns, animations, aliases)
    print("%d tiles, sheet %dx%d, %d patterns, %d animations" % (len(coords), sheet.width, sheet.height, len(patterns), len(animations)))
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        contact_sheet([t for t in tiles if not t[0].startswith("_pad_")]).save(os.path.join(PREVIEW, "templo_hoja.png"))
        sample_map(coords, sheet, 0).save(os.path.join(PREVIEW, "templo_mapa.png"))
        frames = [sample_map(coords, sheet, f, scale=2).convert("P", palette=Image.ADAPTIVE) for f in range(24)]
        frames[0].save(os.path.join(PREVIEW, "templo_mapa.gif"), save_all=True, append_images=frames[1:], duration=150, loop=0)
        animation_gifs(coords, sheet, animations, PREVIEW)


if __name__ == "__main__":
    main()
