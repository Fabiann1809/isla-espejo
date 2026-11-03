"""Draws the Ruinas de la Montaña tileset (16x16 tiles, own art) with Pillow, guided by the concept
sheet (dark blue-violet stone, black outline, cyan glow, orange fire). Usage from the repo root:
    python tools/make_ruins_tileset_art.py [--preview <folder>]
Writes assets/tilesets/ruins/ruins_sheet.png (16 columns) and assets/tilesets/ruins/ruins_tiles.json
(name -> [column, row], patterns as lists), which tools/make_tileset_ruins.gd turns into the tileset
profile. With --preview it also writes a labeled contact sheet, a sample room and GIFs of the animated
tiles to <folder> (not part of the game). Every tile is deterministic (fixed seeds)."""
import json
import math
import os
import random
import sys

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "tilesets", "ruins")
PREVIEW = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
T = 16
COLUMNS = 16

# --- palette (measured from the concept sheet, trimmed) ---------------------------------------------
def rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


OUTLINE = rgb("#050a1a")
ROCK_D = rgb("#131a30")
ROCK_1 = rgb("#212a44")
ROCK_2 = rgb("#2c3a53")
ROCK_3 = rgb("#3a4666")
ROCK_4 = rgb("#4e557a")
ROCK_HI = rgb("#7a82a6")
FLOOR_D = rgb("#2f3552")
FLOOR_1 = rgb("#434968")
FLOOR_2 = rgb("#525a7c")
FLOOR_3 = rgb("#626382")
FLOOR_HI = rgb("#7d7f9e")
JOINT = rgb("#262c46")
WATER_D = rgb("#12325a")
WATER_1 = rgb("#1c4571")
WATER_2 = rgb("#2a6a94")
WATER_3 = rgb("#3a8fb4")
GLOW = rgb("#6fe6ff")
GLOW_2 = rgb("#a8f4ff")
WOOD_D = rgb("#4a2a14")
WOOD_1 = rgb("#6e4020")
WOOD_2 = rgb("#9a5c2a")
WOOD_HI = rgb("#c88442")
MOSS_D = rgb("#14442f")
MOSS_1 = rgb("#1f6b4a")
MOSS_2 = rgb("#2fa070")
MOSS_HI = rgb("#72d49a")
FIRE_1 = rgb("#d4501a")
FIRE_2 = rgb("#ff8a1e")
FIRE_3 = rgb("#ffc43a")
FIRE_HI = rgb("#fff0a8")
CRY_D = rgb("#1a5aa8")
CRY_1 = rgb("#2f8fe0")
CRY_2 = rgb("#5cc8ff")
CRY_HI = rgb("#d8f6ff")
RED_D = rgb("#6a1220")
RED_1 = rgb("#9a1c2c")
RED_2 = rgb("#c42a38")
BONE = rgb("#c8c2b4")
GOLD_D = rgb("#8a4a10")
GOLD_1 = rgb("#d98a22")
GOLD_2 = rgb("#ffc850")
CLEAR = (0, 0, 0, 0)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


def shade(c, f):
    return tuple(max(0, min(255, int(c[i] * f))) for i in range(3)) + (255,)


def blank(w=T, h=T):
    return Image.new("RGBA", (w, h), CLEAR)


def put(img, x, y, c):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), c)


def over(base, top):
    base.alpha_composite(top)
    return base


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


def value_noise(rng, w, h, cell):
    gw, gh = w // cell + 2, h // cell + 2
    grid = [[rng.random() for _ in range(gw)] for _ in range(gh)]
    out = [[0.0] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            gx, gy = x / cell, y / cell
            x0, y0 = int(gx), int(gy)
            fx, fy = gx - x0, gy - y0
            fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
            top = grid[y0][x0] * (1 - fx) + grid[y0][x0 + 1] * fx
            bot = grid[y0 + 1][x0] * (1 - fx) + grid[y0 + 1][x0 + 1] * fx
            out[y][x] = top * (1 - fy) + bot * fy
    return out


# --- floors -------------------------------------------------------------------------------------------
def floor_tile(seed, tones=(FLOOR_1, FLOOR_2, FLOOR_3), joint=JOINT, wear=0.0, moss=0.0, crack=False,
               rune=False, dark=False):
    """Four slabs of 8x8 in two offset rows (tileable), a dark joint on the right and bottom of each."""
    rng = random.Random(seed)
    img = blank()
    noise = value_noise(rng, T, T, 4)
    slabs = [(0, 0), (8, 0), (-4, 8), (4, 8), (12, 8)]
    for sx, sy in slabs:
        base = rng.choice(tones)
        if dark:
            base = shade(base, 0.55)
        for yy in range(8):
            for xx in range(8):
                x, y = sx + xx, sy + yy
                if not (0 <= x < T and 0 <= y < T):
                    continue
                n = noise[y][x] - 0.5
                c = shade(base, 1.0 + n * 0.22 + rng.uniform(-0.04, 0.04))
                if xx == 7 or yy == 7:
                    c = joint if not dark else shade(joint, 0.6)
                elif yy == 0 or xx == 0:
                    c = shade(c, 1.12)
                img.putpixel((x, y), c)
    if wear:
        for _ in range(int(wear * 40)):
            put(img, rng.randrange(T), rng.randrange(T), shade(tones[0], 0.8))
    if crack:
        x, y = rng.randrange(3, 6), 1
        while y < 15:
            put(img, x, y, shade(joint, 0.7))
            x += rng.choice((-1, 0, 1))
            x = max(1, min(14, x))
            y += 1
    if moss:
        # clusters of moss growing from the joints: a short random walk, lit from above
        cells = set()
        for _ in range(max(1, int(moss * 9))):
            x, y = rng.randrange(1, 15), rng.randrange(1, 15)
            for _ in range(rng.randrange(5, 11)):
                cells.add((x, y))
                x = max(0, min(15, x + rng.choice((-1, 0, 1))))
                y = max(0, min(15, y + rng.choice((-1, 0, 0, 1))))
        for x, y in cells:
            c = MOSS_1
            if (x, y - 1) not in cells:
                c = MOSS_2
            elif (x, y + 1) not in cells:
                c = MOSS_D
            put(img, x, y, c)
    if rune:
        cx, cy = 7, 7
        for dx, dy in ((0, -3), (0, -2), (0, 2), (0, 3), (-3, 0), (3, 0), (-2, 0), (2, 0), (-1, -1), (1, 1),
                       (-1, 1), (1, -1)):
            put(img, cx + dx, cy + dy, GLOW)
        put(img, cx, cy, GLOW_2)
        for dx, dy in ((0, -4), (0, 4), (-4, 0), (4, 0)):
            put(img, cx + dx, cy + dy, mix(FLOOR_2, GLOW, 0.4))
    return img


def void_tile(seed):
    """Cave ground outside the rooms: almost black rock, a few faint cracks."""
    rng = random.Random(seed)
    img = blank()
    noise = value_noise(rng, T, T, 5)
    for y in range(T):
        for x in range(T):
            c = shade(ROCK_D, 0.55 + noise[y][x] * 0.7)
            img.putpixel((x, y), c)
    for _ in range(5):
        put(img, rng.randrange(T), rng.randrange(T), ROCK_1)
    return img


# --- 9-slice areas ------------------------------------------------------------------------------------
def make_area(inner_fn, outer_fn, inset=3, radius=5.0, rim=None):
    """A 48x48 picture of a rounded area drawn with `inner_fn(x, y)` over `outer_fn(x, y)` and its nine
    16x16 tiles (top-left, top, top-right, left, center, right, bottom-left, bottom, bottom-right)."""
    size = 3 * T
    img = Image.new("RGBA", (size, size))
    mask = [[False] * size for _ in range(size)]
    lo, hi = inset, size - inset
    for y in range(size):
        for x in range(size):
            cx = min(max(x + 0.5, lo + radius), hi - radius)
            cy = min(max(y + 0.5, lo + radius), hi - radius)
            mask[y][x] = lo <= x + 0.5 <= hi and lo <= y + 0.5 <= hi and \
                math.hypot(x + 0.5 - cx, y + 0.5 - cy) <= radius
    for y in range(size):
        for x in range(size):
            img.putpixel((x, y), inner_fn(x, y, mask) if mask[y][x] else outer_fn(x, y, mask))
    return img, mask


def slice9(img):
    tiles = []
    for r in range(3):
        for c in range(3):
            tiles.append(img.crop((c * T, r * T, c * T + T, r * T + T)))
    return tiles


def dist_to_edge(mask, x, y, inside):
    """Chebyshev-ish distance (1..4) to the nearest pixel of the other side."""
    size = len(mask)
    for d in range(1, 5):
        for dx in range(-d, d + 1):
            for dy in range(-d, d + 1):
                if max(abs(dx), abs(dy)) != d:
                    continue
                nx, ny = x + dx, y + dy
                if 0 <= nx < size and 0 <= ny < size and mask[ny][nx] != inside:
                    return d
    return 5


def water_painters(tiles, frame):
    """The two painters of water on stone over a `tiles` x `tiles` canvas: what the water looks like
    inside (a shore glow, a lighter band, deep water with a shimmer) and the stone around it with a
    soft glow on its edge. `frame` (0..2) moves the shimmer."""
    floor = floor_tile(11)
    floor_big = Image.new("RGBA", (tiles * T, tiles * T))
    for r in range(tiles):
        for c in range(tiles):
            floor_big.paste(floor, (c * T, r * T))
    noise = value_noise(random.Random(5), tiles * T + 6, tiles * T + 6, 4)

    def inner(x, y, mask):
        d = dist_to_edge(mask, x, y, True)
        n = noise[y + frame * 2][x + frame]
        if d == 1:
            return mix(WATER_3, GLOW, 0.75)
        if d == 2:
            return mix(WATER_2, WATER_3, 0.6)
        if d == 3:
            return WATER_2
        c = mix(WATER_D, WATER_1, 0.35 + 0.65 * n)
        if d >= 5 and n > 0.74:
            c = mix(c, WATER_2, 0.7)
        return c

    def outer(x, y, mask):
        base = floor_big.getpixel((x, y))
        d = dist_to_edge(mask, x, y, False)
        if d == 1:
            return mix(base[:3] + (255,), GLOW, 0.4)
        if d == 2:
            return mix(base[:3] + (255,), WATER_2, 0.2)
        return base

    return inner, outer


def water_area(frame, seed=7):
    """Water with a luminous shore on stone (3x3 tiles). `frame` (0..2) moves the shimmer."""
    inner, outer = water_painters(3, frame)
    img, mask = make_area(inner, outer)
    spark = random.Random(100 + frame)
    for _ in range(6):
        x, y = spark.randrange(8, 40), spark.randrange(8, 40)
        if mask[y][x] and dist_to_edge(mask, x, y, True) >= 4:
            img.putpixel((x, y), GLOW_2)
    return img


def water_inner_corners(inset=3, radius=5.0):
    """The four inner corners of an irregular river (SE, SW, NE, NW: the diagonal that is NOT water): the
    tile of a water cell whose diagonal neighbour is stone, with a rounded bite of stone in that corner."""
    size = 4 * T
    inner, outer = water_painters(4, 0)
    corner = 2 * T - inset
    mask = [[True] * size for _ in range(size)]
    for y in range(size):
        for x in range(size):
            px, py = x + 0.5, y + 0.5
            if px >= corner and py >= corner:
                cx, cy = max(px, corner + radius), max(py, corner + radius)
                if math.hypot(px - cx, py - cy) <= radius:
                    mask[y][x] = False
    img = Image.new("RGBA", (size, size))
    for y in range(size):
        for x in range(size):
            img.putpixel((x, y), inner(x, y, mask) if mask[y][x] else outer(x, y, mask))
    se = img.crop((T, T, 2 * T, 2 * T))
    return [se, se.transpose(Image.FLIP_LEFT_RIGHT), se.transpose(Image.FLIP_TOP_BOTTOM),
            se.transpose(Image.FLIP_LEFT_RIGHT).transpose(Image.FLIP_TOP_BOTTOM)]


def patch_area(inner_tones, outer_fn_seed, edge_light, joint, moss=0.0, seed=21):
    """A patch of one floor drawn over another, with a worn edge (used for paths and moss)."""
    inner_tile = floor_tile(seed, tones=inner_tones, joint=joint, moss=moss)
    outer_tile = floor_tile(outer_fn_seed, tones=(ROCK_2, ROCK_3, ROCK_2), joint=ROCK_D, dark=True)
    big_in = Image.new("RGBA", (3 * T, 3 * T))
    big_out = Image.new("RGBA", (3 * T, 3 * T))
    for r in range(3):
        for c in range(3):
            big_in.paste(inner_tile, (c * T, r * T))
            big_out.paste(outer_tile, (c * T, r * T))

    def inner(x, y, mask):
        d = dist_to_edge(mask, x, y, True)
        c = big_in.getpixel((x, y))
        return edge_light if d == 1 else c

    def outer(x, y, mask):
        c = big_out.getpixel((x, y))
        d = dist_to_edge(mask, x, y, False)
        return shade(c, 0.7) if d == 1 else c

    return make_area(inner, outer, inset=2, radius=6.0)[0]


def inner_corners(area_img, mask_fn=None):
    """Four tiles (SE, SW, NE, NW: the diagonal that is NOT the area) made from the area's center with
    a rounded notch cut by the outside look."""
    # outside tile = the area's top-left corner tile's outer part; build from the area's own center
    center = area_img.crop((T, T, 2 * T, 2 * T))
    corner = area_img.crop((0, 0, T, T))
    result = []
    for quadrant in ("SE", "SW", "NE", "NW"):
        tile = center.copy()
        px = tile.load()
        src = corner.load()
        for y in range(T):
            for x in range(T):
                qx = x >= T // 2
                qy = y >= T // 2
                inside = {"SE": qx and qy, "SW": (not qx) and qy, "NE": qx and (not qy), "NW": (not qx) and (not qy)}[quadrant]
                if inside:
                    # distance from the notch corner decides rounding
                    cx = T if quadrant in ("SE", "NE") else 0
                    cy = T if quadrant in ("SE", "SW") else 0
                    if math.hypot(x + 0.5 - cx, y + 0.5 - cy) <= 6.5:
                        sx = x if quadrant in ("NW", "SW") else T - 1 - x
                        sy = y if quadrant in ("NW", "NE") else T - 1 - y
                        px[x, y] = src[sx % T, sy % T]
        result.append(tile)
    return result


# --- rock columns, boulders, walls ----------------------------------------------------------------------
def rock_column(seed, height=32, moss=0.0, dark=False, lean=0):
    """A column of rock (the cliff 'pillars' of the concept sheet): a light rounded cap, a body of
    three or four vertical facets with cracks, a flared foot. 16 wide; `height` 32 gives a top tile
    and a base tile."""
    rng = random.Random(seed)
    img = blank(16, height)
    noise = value_noise(rng, 16, height, 3)
    cap_h = 10
    wide = 7.2 + rng.uniform(-0.3, 0.3)
    mask = {}
    for y in range(height):
        if y < cap_h:
            t = (cap_h - 1 - y) / (cap_h - 1)
            hw = wide * math.sqrt(max(0.0, 1.0 - t * t)) + 0.9
        else:
            hw = wide + (noise[y][3] - 0.5) * 1.0
        if y >= height - 3:
            hw += 0.7 * (y - (height - 4))
        cx = 8.0 + lean * (1.0 - y / height)
        for x in range(16):
            if abs(x + 0.5 - cx) <= hw:
                mask[(x, y)] = (x + 0.5 - cx) / hw
    cracks = {rng.randrange(3, 13) for _ in range(2)}
    for (x, y), u in mask.items():
        n = noise[y][x] - 0.5
        below = (x, y + 1) in mask
        if y < cap_h - 1 and below:
            # the flat top of the rock, lit from the upper left
            c = mix(ROCK_HI, FLOOR_HI, max(0.0, 0.5 - u * 0.5) * 0.6)
            c = shade(c, 1.0 + n * 0.16 - max(0.0, u) * 0.12)
            if y == cap_h - 2:
                c = shade(c, 0.78)
        else:
            facet = min(3, int((u + 1.0) * 2.0))
            c = (ROCK_HI, ROCK_4, ROCK_3, ROCK_2)[facet]
            c = shade(c, 1.0 + n * 0.30 - (y - cap_h) * 0.006)
            if x in cracks and (y + x) % 5 != 0:
                c = shade(c, 0.62)
            if y == cap_h - 1:
                c = shade(ROCK_3, 0.7)
            if rng.random() < 0.006:
                c = mix(c, GLOW, 0.5)
        if dark:
            c = shade(c, 0.55)
        img.putpixel((x, y), c)
    if moss:
        for y in range(max(cap_h, height - 10), height):
            for x in range(16):
                if (x, y) in mask and noise[y][(x + 5) % 16] > 1.0 - moss * (y - (height - 10)) / 9:
                    img.putpixel((x, y), rng.choice((MOSS_1, MOSS_2, MOSS_D)))
    return outline(img)


def stalagmite(seed, moss=False):
    rng = random.Random(seed)
    img = blank()
    noise = value_noise(rng, 16, 16, 4)
    for y in range(1, 15):
        hw = 1.2 + (y - 1) * 0.42
        for x in range(16):
            u = (x + 0.5 - 8.0) / hw
            if abs(u) <= 1.0:
                n = noise[y][x] - 0.5
                c = (ROCK_4, ROCK_3, ROCK_2, ROCK_1)[min(3, int((u + 1.0) * 2.0))]
                c = shade(c, 1.0 + n * 0.3)
                if rng.random() < 0.015:
                    c = mix(c, GLOW, 0.5)
                img.putpixel((x, y), c)
    if moss:
        for _ in range(14):
            x, y = rng.randrange(3, 13), rng.randrange(9, 14)
            if img.getpixel((x, y))[3]:
                img.putpixel((x, y), rng.choice((MOSS_1, MOSS_2)))
    return outline(img)


def boulder(seed, small=False, moss=False):
    rng = random.Random(seed)
    img = blank()
    noise = value_noise(rng, 16, 16, 3)
    cx, cy = 8.0, 9.5 if not small else 11.0
    rx, ry = (6.6, 5.6) if not small else (4.2, 3.2)
    for y in range(16):
        for x in range(16):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            d = math.hypot(dx, dy)
            if d <= 1.0:
                light = 1.0 - (dx * 0.5 + dy * 0.6)
                c = mix(ROCK_2, ROCK_HI, max(0.0, min(1.0, light * 0.55 + (noise[y][x] - 0.5) * 0.6)))
                if d > 0.82 and dy > 0:
                    c = shade(c, 0.7)
                img.putpixel((x, y), c)
    if moss:
        for _ in range(16):
            x, y = rng.randrange(3, 13), rng.randrange(6, 14)
            if img.getpixel((x, y))[3]:
                img.putpixel((x, y), rng.choice((MOSS_1, MOSS_2, MOSS_D)))
    return outline(img)


def wall_face(seed, moss=0.0, top_lip=False, side=None):
    """The dark stone face under a terrace: two rows of blocks. With `top_lip` the top 6 rows are the
    light edge of the platform. `side` ('l' or 'r') adds the platform's lateral edge."""
    rng = random.Random(seed)
    img = blank()
    noise = value_noise(rng, T, T, 4)
    top = 6 if top_lip else 0
    for y in range(T):
        for x in range(T):
            if y < top:
                c = mix(FLOOR_2, FLOOR_3, 0.5 + (noise[y][x] - 0.5))
                if y == 0:
                    c = FLOOR_HI
                if y == top - 1:
                    c = shade(FLOOR_1, 0.85)
                if x % 8 == 7:
                    c = JOINT
            else:
                row = (y - top) // 5
                off = 0 if row % 2 == 0 else 4
                bx = (x + off) % 8
                c = ROCK_2 if (row + (x + off) // 8) % 2 == 0 else ROCK_1
                c = shade(c, 1.0 + (noise[y][x] - 0.5) * 0.4 - (y - top) * 0.012)
                if (y - top) % 5 == 4 or bx == 7:
                    c = ROCK_D
                elif (y - top) % 5 == 0:
                    c = shade(c, 1.15)
            img.putpixel((x, y), c)
    if moss:
        for y in range(top, T):
            for x in range(T):
                if noise[y][(x + 6) % T] > 1.0 - moss and rng.random() < 0.7:
                    img.putpixel((x, y), rng.choice((MOSS_1, MOSS_D, MOSS_2)))
    if side:
        for y in range(T):
            xs = range(0, 3) if side == "l" else range(T - 3, T)
            for x in xs:
                edge = x == (0 if side == "l" else T - 1)
                img.putpixel((x, y), OUTLINE if edge else mix(ROCK_D, ROCK_1, 0.4))
    return img


def spike_trap(out):
    """A floor trap: a slab with four small holes, or the same slab with four iron spikes out."""
    img = floor_tile(9, tones=(FLOOR_1, FLOOR_2, FLOOR_2))
    d = ImageDraw.Draw(img)
    d.rectangle((1, 1, 14, 14), outline=JOINT)
    for cx, cy in ((4, 4), (11, 4), (4, 11), (11, 11)):
        if out:
            d.rectangle((cx - 1, cy - 2, cx, cy + 1), fill=rgb("#aab4cc"))
            d.point((cx - 1, cy - 2), fill=rgb("#eaf0ff"))
            d.point((cx, cy + 1), fill=ROCK_D)
        else:
            d.rectangle((cx - 1, cy - 1, cx, cy), fill=ROCK_D)
    return img


def terrace_top(seed=4):
    """The back edge of a platform seen from above: a dark rim, then a lighter stone lip."""
    img = floor_tile(seed, tones=(FLOOR_2, FLOOR_3, FLOOR_3), wear=0.3)
    for x in range(T):
        img.putpixel((x, 0), OUTLINE)
        img.putpixel((x, 1), ROCK_D)
        img.putpixel((x, 2), shade(FLOOR_1, 0.85))
    return img


def terrace_side(side, seed=3):
    """The lateral edge of a platform seen from above: a stone rim on the open side."""
    rng = random.Random(seed)
    img = blank()
    for y in range(T):
        for x in range(T):
            near = x if side == "l" else T - 1 - x
            if near < 2:
                img.putpixel((x, y), OUTLINE if near == 0 else shade(ROCK_D, 1.2))
            elif near < 5:
                c = FLOOR_3 if near == 2 else mix(FLOOR_2, FLOOR_1, (near - 3) / 2)
                if y % 8 == 7:
                    c = JOINT
                img.putpixel((x, y), shade(c, 1.0 + rng.uniform(-0.03, 0.03)))
    return img


# --- stairs and bridges -------------------------------------------------------------------------------------
def stairs_steps(wood=False):
    """Four steps, each with a bright edge, a tread and a dark riser, so a staircase reads at a glance
    against the flat floor around it."""
    img = blank()
    edge = rgb("#b4b8dc") if not wood else WOOD_HI
    tread = FLOOR_HI if not wood else WOOD_2
    mid = FLOOR_2 if not wood else WOOD_1
    riser = rgb("#171c30") if not wood else WOOD_D
    for i in range(4):
        y0 = i * 4
        rows = (edge, tread, mid, riser)
        for y in range(4):
            for x in range(T):
                c = rows[y]
                if y in (1, 2):
                    c = shade(c, 1.0 + ((x * 7 + i * 3) % 5 - 2) * 0.015)
                img.putpixel((x, y0 + y), shade(c, 1.0 - 0.07 * i))
    return img


def stairs_rail(side):
    """A stone parapet with a wooden post, on the side of a staircase."""
    img = blank()
    for y in range(T):
        for x in range(T):
            near = x if side == "l" else T - 1 - x
            if 5 <= near <= 15:
                if near == 15 or near == 5:
                    c = OUTLINE
                elif near < 8:
                    c = ROCK_HI if near == 6 else ROCK_4
                else:
                    c = ROCK_3 if near < 12 else ROCK_2
                if y % 8 == 7:
                    c = shade(c, 0.6)
                img.putpixel((x, y), c)
    for y in range(3, 14):
        for x in (7, 8):
            xx = x if side == "l" else T - 1 - x
            img.putpixel((xx, y), WOOD_2 if y > 4 else WOOD_HI)
    return img


def bridge_planks(horizontal=True, seed=2):
    rng = random.Random(seed)
    img = blank()
    for y in range(T):
        for x in range(T):
            k = x if horizontal else y
            base = (WOOD_2, WOOD_1, WOOD_2, WOOD_1)[(k // 4) % 4]
            if k % 4 == 3:
                c = WOOD_D
            elif k % 4 == 0:
                c = shade(base, 1.18)
            else:
                c = shade(base, 1.0 + rng.uniform(-0.07, 0.07))
            img.putpixel((x, y), c)
    return img


def bridge_rail(horizontal=True):
    """Stone parapet along a bridge (the low wall at its sides); horizontal = runs along x."""
    img = blank()
    for y in range(T):
        for x in range(T):
            k = y if horizontal else x
            if k < 2:
                c = OUTLINE
            elif k < 5:
                c = ROCK_HI if k == 2 else ROCK_4
            elif k < 9:
                c = ROCK_3
            elif k < 12:
                c = ROCK_2
            else:
                c = ROCK_D
            along = x if horizontal else y
            if along % 8 == 7 and k >= 2:
                c = shade(c, 0.6)
            img.putpixel((x, y), c)
    return img


# --- crystals, fire, banners --------------------------------------------------------------------------------
def crystal_big(pulse=0):
    """A glowing crystal on a stone pedestal, 16x32 (top tile, base tile)."""
    img = blank(16, 32)
    d = ImageDraw.Draw(img)
    for y in range(22, 31):
        for x in range(2, 14):
            img.putpixel((x, y), ROCK_3 if y < 24 else (ROCK_1 if y > 27 else (ROCK_2 if x > 4 else ROCK_3)))
    d.line((1, 27, 14, 27), fill=ROCK_4)
    outline(img)
    d = ImageDraw.Draw(img)
    c2 = mix(CRY_2, CRY_HI, 0.35 * pulse)
    d.polygon([(8, 2), (12, 9), (11, 22), (5, 22), (4, 9)], fill=CRY_1)
    d.polygon([(8, 2), (12, 9), (11, 22), (8, 22)], fill=CRY_D)
    d.polygon([(8, 2), (4, 9), (5, 22), (8, 22)], fill=c2)
    d.line((8, 3, 8, 21), fill=mix(CRY_2, CRY_HI, 0.5 + 0.3 * pulse))
    d.line((6, 8, 6, 18), fill=CRY_HI)
    d.polygon([(8, 2), (12, 9), (11, 22), (5, 22), (4, 9)], outline=OUTLINE)
    for p in ((7, 5), (6, 12), (7, 16)):
        img.putpixel(p, CRY_HI)
    return img


def crystal_small(variant, pulse=0):
    img = blank()
    d = ImageDraw.Draw(img)
    d.rectangle((3, 11, 12, 14), fill=ROCK_2)
    d.line((3, 11, 12, 11), fill=ROCK_4)
    outline(img)
    d = ImageDraw.Draw(img)
    pts = {0: [(8, 1), (11, 6), (10, 11), (6, 11), (5, 6)], 1: [(6, 3), (9, 7), (9, 11), (4, 11), (3, 7)]}[variant % 2]
    d.polygon(pts, fill=CRY_1)
    d.polygon([pts[0], pts[1], pts[2], (pts[0][0], 11)], fill=CRY_D)
    d.polygon([pts[0], pts[4], pts[3], (pts[0][0], 11)], fill=mix(CRY_2, CRY_HI, 0.3 * pulse))
    d.line((pts[0][0] - 1, pts[0][1] + 2, pts[0][0] - 1, 9), fill=CRY_HI)
    d.polygon(pts, outline=OUTLINE)
    return img


def flame(img, cx, base_y, h, frame, big=False):
    """A flame centered on cx, standing on base_y; `frame` 0..2 flickers."""
    sway = (0, 1, -1)[frame % 3]
    hh = h + (0, 1, 0)[frame % 3]
    for i in range(hh):
        w = max(0.0, (hh - i) * (0.55 if big else 0.4) * (1.0 if i < hh * 0.6 else 0.6))
        y = base_y - i
        shift = sway * (i / hh)
        for x in range(int(cx - w - 1), int(cx + w + 2)):
            dx = abs(x + 0.5 - (cx + shift))
            if dx <= w + 0.5:
                c = FIRE_HI if (dx < w * 0.35 and i < hh * 0.6) else (FIRE_3 if dx < w * 0.65 else FIRE_2)
                if i > hh * 0.78:
                    c = FIRE_1
                put(img, x, y, c)


def torch_stand(frame):
    img = blank()
    d = ImageDraw.Draw(img)
    d.rectangle((5, 12, 10, 15), fill=ROCK_2)
    d.rectangle((6, 8, 9, 12), fill=ROCK_3)
    d.line((6, 8, 6, 12), fill=ROCK_4)
    d.rectangle((6, 6, 9, 8), fill=WOOD_1)
    outline(img)
    flame(img, 7.5, 6, 6, frame)
    return img


def brazier(frame):
    img = blank()
    d = ImageDraw.Draw(img)
    d.polygon([(3, 9), (12, 9), (10, 13), (5, 13)], fill=ROCK_2)
    d.line((3, 9, 12, 9), fill=ROCK_4)
    d.rectangle((6, 13, 9, 15), fill=ROCK_1)
    d.rectangle((4, 14, 11, 15), fill=ROCK_2)
    outline(img)
    flame(img, 7.5, 9, 8, frame, big=True)
    return img


def banner(torn=False):
    img = blank(16, 32)
    d = ImageDraw.Draw(img)
    d.rectangle((2, 1, 13, 3), fill=WOOD_1)
    d.line((2, 1, 13, 1), fill=WOOD_HI)
    for x in (2, 13):
        d.rectangle((x - 1, 0, x, 4), fill=GOLD_1)
    for y in range(4, 30):
        tear = (y - 22) // 2 if (torn and y > 22) else 0
        for x in range(3, 13):
            if y > 25 and (x * 3 + y) % 5 < (y - 25):
                continue
            if torn and y > 22 and x < 5 + tear // 2:
                continue
            img.putpixel((x, y), RED_2 if x < 6 else (RED_1 if x < 10 else RED_D))
    for p in [(7, 11), (8, 11), (9, 11), (6, 12), (7, 12), (8, 12), (9, 12), (10, 12), (6, 13), (8, 13), (10, 13),
              (7, 14), (8, 14), (9, 14), (7, 15), (9, 15)]:
        img.putpixel(p, GOLD_2)
    for p in ((7, 13), (9, 13)):
        img.putpixel(p, RED_D)
    return outline(img)


def chest(opened=False):
    img = blank()
    d = ImageDraw.Draw(img)
    if not opened:
        d.rectangle((2, 6, 13, 14), fill=GOLD_1)
        d.rectangle((2, 6, 13, 8), fill=GOLD_2)
        d.line((2, 9, 13, 9), fill=GOLD_D)
        d.rectangle((7, 8, 8, 11), fill=OUTLINE)
        d.point((7, 9), fill=GOLD_2)
        for x in (3, 12):
            d.line((x, 6, x, 14), fill=GOLD_D)
    else:
        d.rectangle((2, 8, 13, 14), fill=GOLD_1)
        d.rectangle((3, 8, 12, 10), fill=ROCK_D)
        d.line((4, 9, 11, 9), fill=GLOW)
        d.rectangle((2, 2, 13, 6), fill=GOLD_2)
        d.line((2, 6, 13, 6), fill=GOLD_D)
        for x in (3, 12):
            d.line((x, 2, x, 14), fill=GOLD_D)
    return outline(img)


def crate():
    img = blank()
    d = ImageDraw.Draw(img)
    d.rectangle((2, 3, 13, 14), fill=WOOD_1)
    d.rectangle((2, 3, 13, 5), fill=WOOD_2)
    d.line((3, 5, 12, 13), fill=WOOD_D)
    d.line((12, 5, 3, 13), fill=WOOD_D)
    d.rectangle((2, 3, 13, 14), outline=WOOD_D)
    d.line((3, 4, 12, 4), fill=WOOD_HI)
    return outline(img)


def barrel():
    img = blank()
    d = ImageDraw.Draw(img)
    d.rectangle((3, 3, 12, 13), fill=WOOD_1)
    d.ellipse((3, 11, 12, 15), fill=WOOD_1)
    d.ellipse((3, 1, 12, 5), fill=WOOD_HI)
    d.ellipse((5, 2, 10, 4), fill=WOOD_D)
    d.line((3, 7, 12, 7), fill=GOLD_D)
    d.line((3, 11, 12, 11), fill=GOLD_D)
    d.line((5, 5, 5, 13), fill=WOOD_2)
    return outline(img)


# --- plants, mushrooms, small details ---------------------------------------------------------------------
def fern(seed, blue=False):
    rng = random.Random(seed)
    img = blank()
    cols = (MOSS_D, MOSS_1, MOSS_2, MOSS_HI) if not blue else (rgb("#123a5a"), rgb("#1f5f8a"), rgb("#3a9ac4"), rgb("#8ae0ff"))
    cx, base = 8.0, 14
    for i in range(7):
        ang = -math.pi / 2 + (i - 3) * 0.42 + rng.uniform(-0.08, 0.08)
        length = rng.uniform(5.0, 8.0)
        for s in range(int(length * 2)):
            t = s / 2.0
            x = cx + math.cos(ang) * t
            y = base + math.sin(ang) * t + (t * t) * 0.045
            put(img, int(x), int(y), cols[1] if t < length * 0.5 else cols[2])
            if s % 3 == 0:
                put(img, int(x) + (1 if ang > -math.pi / 2 else -1), int(y) + 1, cols[0])
        put(img, int(cx + math.cos(ang) * length), int(base + math.sin(ang) * length), cols[3])
    return outline(img)


def moss_clump(seed):
    rng = random.Random(seed)
    img = blank()
    for _ in range(46):
        put(img, int(8 + rng.gauss(0, 3.0)), int(11 + rng.gauss(0, 1.8)), rng.choice((MOSS_1, MOSS_2, MOSS_2, MOSS_D, MOSS_HI)))
    return img


def mushroom(kind):
    cols = {0: (rgb("#1f6a8a"), rgb("#3ac0d8"), rgb("#b8f4ff")),
            1: (rgb("#4a2a8a"), rgb("#8a5ad8"), rgb("#d8b8ff")),
            2: (rgb("#1f6b4a"), rgb("#3ad090"), rgb("#baffd8")),
            3: (rgb("#8a3a5a"), rgb("#d8689a"), rgb("#ffc8e0"))}[kind]
    img = blank()
    d = ImageDraw.Draw(img)
    d.rectangle((7, 10, 8, 13), fill=BONE)
    d.ellipse((4, 6, 11, 11), fill=cols[1])
    d.rectangle((4, 9, 11, 10), fill=cols[0])
    d.point((6, 7), fill=cols[2])
    d.point((8, 7), fill=cols[2])
    return outline(img)


def glow_flower(kind):
    cols = {0: (CRY_2, CRY_HI), 1: (rgb("#a68aff"), rgb("#efe4ff")), 2: (GLOW, GLOW_2)}[kind]
    img = blank()
    d = ImageDraw.Draw(img)
    d.line((8, 9, 8, 14), fill=MOSS_1)
    d.point((6, 12), fill=MOSS_2)
    d.point((10, 11), fill=MOSS_2)
    for p in ((8, 7), (6, 8), (10, 8), (7, 9), (9, 9)):
        d.point(p, fill=cols[0])
    d.point((8, 8), fill=cols[1])
    return img


def rubble(seed):
    rng = random.Random(seed)
    img = blank()
    for _ in range(5):
        cx, cy = rng.randrange(4, 12), rng.randrange(8, 13)
        r = rng.choice((1, 2, 2))
        for y in range(cy - r, cy + r + 1):
            for x in range(cx - r - 1, cx + r + 2):
                if (x - cx) ** 2 / (r + 1) ** 2 + (y - cy) ** 2 / r ** 2 <= 1:
                    put(img, x, y, ROCK_4 if y < cy else ROCK_2)
    return outline(img)


def pebbles(seed):
    rng = random.Random(seed)
    img = blank()
    for _ in range(7):
        put(img, rng.randrange(2, 14), rng.randrange(4, 14), rng.choice((ROCK_4, ROCK_3, ROCK_HI)))
    return img


def bones():
    img = blank()
    d = ImageDraw.Draw(img)
    d.ellipse((5, 5, 10, 10), fill=BONE)
    d.rectangle((6, 9, 9, 11), fill=BONE)
    d.point((6, 7), fill=OUTLINE)
    d.point((9, 7), fill=OUTLINE)
    d.line((2, 13, 7, 12), fill=BONE)
    d.line((9, 12, 14, 13), fill=BONE)
    return outline(img)


def pillar(broken=False):
    """A fluted stone column, 16x32 (top tile, base tile); `broken` returns a 16x16 stump."""
    height = 16 if broken else 32
    img = blank(16, height)
    d = ImageDraw.Draw(img)
    top = 4 if broken else 3
    d.rectangle((3, top, 12, top + 2), fill=ROCK_4)
    d.line((3, top, 12, top), fill=ROCK_HI)
    d.rectangle((5, top + 3, 10, height - 5), fill=ROCK_3)
    d.rectangle((9, top + 3, 10, height - 5), fill=ROCK_2)
    d.line((6, top + 3, 6, height - 5), fill=ROCK_4)
    d.rectangle((3, height - 4, 12, height - 2), fill=ROCK_4)
    d.line((3, height - 4, 12, height - 4), fill=ROCK_HI)
    d.rectangle((9, height - 3, 12, height - 2), fill=ROCK_2)
    return outline(img)


def stele(tall=True):
    """An arched stone tablet with a glowing rune."""
    h = 32 if tall else 16
    img = blank(16, h)
    d = ImageDraw.Draw(img)
    top = 3 if tall else 1
    d.rectangle((3, top + 3, 12, h - 3), fill=ROCK_2)
    d.ellipse((3, top, 12, top + 7), fill=ROCK_2)
    d.line((3, top + 4, 3, h - 3), fill=ROCK_4)
    d.rectangle((10, top + 4, 12, h - 3), fill=ROCK_1)
    mid = top + (h - top) // 2 - 1
    for p in [(7, mid - 4), (7, mid - 3), (7, mid - 2), (6, mid - 1), (8, mid - 1), (7, mid), (7, mid + 1), (6, mid + 2), (8, mid + 2)]:
        d.point(p, fill=GLOW)
    d.point((7, mid - 1), fill=GLOW_2)
    d.rectangle((2, h - 3, 13, h - 2), fill=ROCK_3)
    return outline(img)


# --- waterfall --------------------------------------------------------------------------------------------------
def waterfall_mid(frame):
    img = blank()
    for y in range(T):
        for x in range(T):
            base = mix(WATER_2, WATER_3, 0.35 + 0.35 * math.sin(x * 1.3))
            if (x + (y + frame * 4) // 3) % 5 == 0:
                base = GLOW
            if (y + frame * 5) % 9 == 0 and x % 3 != 1:
                base = GLOW_2
            if x < 2 or x > 13:
                base = mix(base, WATER_1, 0.55)
            img.putpixel((x, y), base)
    for y in range(T):
        img.putpixel((0, y), WATER_D)
        img.putpixel((15, y), WATER_D)
    return img


def waterfall_top():
    img = blank()
    for y in range(T):
        for x in range(T):
            if y < 5:
                c = ROCK_4 if y == 0 else (ROCK_3 if y < 3 else ROCK_1)
                if x < 3 or x > 12:
                    c = ROCK_2
                if y == 4:
                    c = ROCK_D
            else:
                c = mix(WATER_3, GLOW, 0.4) if y == 5 else WATER_2
            img.putpixel((x, y), c)
    return img


def waterfall_base(frame):
    img = waterfall_mid(frame)
    rng = random.Random(40 + frame)
    for y in range(9, T):
        k = (y - 8) / 7.0
        for x in range(T):
            if rng.random() < 0.28 * k:
                img.putpixel((x, y), GLOW_2 if rng.random() < 0.5 else GLOW)
            elif y > 12:
                img.putpixel((x, y), mix(img.getpixel((x, y))[:3] + (255,), WATER_1, 0.35))
    for x in range(T):
        img.putpixel((x, 15), mix(WATER_1, WATER_D, 0.5))
    return img


def rock_mass(seed, dark=False):
    """Top view of a dense mass of rock: the fill of thick walls and of the cave around the map."""
    rng = random.Random(seed)
    img = blank()
    for y in range(T):
        for x in range(T):
            img.putpixel((x, y), shade(ROCK_D, 0.8 + rng.uniform(-0.05, 0.1)))
    caps = [(rng.uniform(1, 15), rng.uniform(1, 15), rng.uniform(3.2, 5.2)) for _ in range(6)]
    caps.sort(key=lambda c: c[1])
    for cx, cy, r in caps:
        for y in range(T):
            for x in range(T):
                for ox in (-16, 0, 16):
                    for oy in (-16, 0, 16):
                        dx, dy = x + 0.5 - (cx + ox), y + 0.5 - (cy + oy)
                        d = math.hypot(dx, dy)
                        if d <= r:
                            light = 1.0 - (dx * 0.45 + dy * 0.55) / r * 0.5
                            c = mix(ROCK_3, ROCK_HI, max(0.0, min(1.0, light - 0.2)))
                            if d > r - 1.1:
                                c = shade(ROCK_1, 0.9)
                            img.putpixel((x, y), shade(c, 0.6) if dark else c)
    return img


def shore_stone(seed, moss=False):
    """A low rounded block: the row of stones that lines a river or the edge of a platform."""
    rng = random.Random(seed)
    img = blank()
    d = ImageDraw.Draw(img)
    w = rng.choice((12, 13, 14))
    x0 = (16 - w) // 2
    top = rng.choice((5, 6))
    d.rounded_rectangle((x0, top, x0 + w - 1, 14), radius=3, fill=ROCK_2)
    d.rounded_rectangle((x0, top, x0 + w - 1, top + 5), radius=3, fill=ROCK_4)
    d.line((x0 + 2, top + 1, x0 + w - 4, top + 1), fill=ROCK_HI)
    d.line((x0 + w - 3, top + 4, x0 + w - 2, 13), fill=ROCK_1)
    if moss:
        for _ in range(6):
            put(img, rng.randrange(x0 + 1, x0 + w - 1), rng.randrange(top + 1, 12), rng.choice((MOSS_1, MOSS_2)))
    return outline(img)


# --- area patches over the normal floor ----------------------------------------------------------------------
def tiled(tile):
    big = Image.new("RGBA", (3 * T, 3 * T))
    for r in range(3):
        for c in range(3):
            big.paste(tile, (c * T, r * T))
    return big


def patch_over(inner_tile, outer_tile, edge, inset=2, radius=6.0):
    """A rounded patch of `inner_tile` over `outer_tile`: the 48x48 picture (see slice9)."""
    big_in, big_out = tiled(inner_tile), tiled(outer_tile)

    def inner(x, y, mask):
        return edge if dist_to_edge(mask, x, y, True) == 1 else big_in.getpixel((x, y))

    def outer(x, y, mask):
        c = big_out.getpixel((x, y))
        return shade(c, 0.58) if dist_to_edge(mask, x, y, False) == 1 else c

    return make_area(inner, outer, inset=inset, radius=radius)[0]


def ceremonial_floor():
    """The lighter slabs of the exit's base: a patch with a cyan rune rim."""
    inner_tile = floor_tile(61, tones=(FLOOR_3, FLOOR_3, FLOOR_HI), joint=FLOOR_1)
    outer_tile = floor_tile(1)
    return patch_over(inner_tile, outer_tile, mix(FLOOR_3, GLOW, 0.55), inset=2, radius=5.0)


# --- the sheet ---------------------------------------------------------------------------------------------------
def build_tiles():
    """Returns (ordered list of (name, 16x16 image), patterns {role: [names]})."""
    tiles = []
    patterns = {}

    def add(name, img):
        assert img.size == (T, T), (name, img.size)
        tiles.append((name, img))

    def add_tall(name, img):
        add(name + "_top", img.crop((0, 0, T, T)))
        add(name + "_base", img.crop((0, T, T, 2 * T)))

    # floors
    add("floor_a", floor_tile(1))
    add("floor_b", floor_tile(2))
    add("floor_crack", floor_tile(3, crack=True))
    add("floor_moss", floor_tile(4, moss=0.4))
    add("floor_rune", floor_tile(5, rune=True))
    add("floor_worn", floor_tile(6, tones=(FLOOR_2, FLOOR_3, FLOOR_3), wear=0.4))
    add("void_a", void_tile(1))
    add("void_b", void_tile(2))

    # areas: water (animated centers), worn path, moss patch, ceremonial floor
    ponds = [water_area(f) for f in range(3)]
    names = []
    for i, tile in enumerate(slice9(ponds[0])):
        add("pond_%d" % i, tile)
        names.append("pond_%d" % i)
    patterns["pond"] = names
    add("pond_center_b", slice9(ponds[1])[4])
    add("pond_center_c", slice9(ponds[2])[4])
    names = []
    for i, tile in enumerate(water_inner_corners()):
        add("pond_inner_%d" % i, tile)
        names.append("pond_inner_%d" % i)
    patterns["pond_inner"] = names

    base_floor = floor_tile(1)
    path = patch_over(floor_tile(7, tones=(FLOOR_3, FLOOR_3, FLOOR_HI), wear=0.3), base_floor, FLOOR_HI)
    moss = patch_over(floor_tile(8, moss=0.55), base_floor, MOSS_1)
    cere = ceremonial_floor()
    for role, area in (("path_patch", path), ("moss_patch", moss), ("stone_floor", cere)):
        names = []
        for i, tile in enumerate(slice9(area)):
            add("%s_%d" % (role, i), tile)
            names.append("%s_%d" % (role, i))
        patterns[role] = names
    for role, area in (("path_patch_inner", path), ("moss_patch_inner", moss)):
        names = []
        for i, tile in enumerate(inner_corners(area)):
            add("%s_%d" % (role, i), tile)
            names.append("%s_%d" % (role, i))
        patterns[role] = names

    # rock columns, stalagmites, boulders, rubble
    for i, (seed, moss_a, lean) in enumerate(((11, 0.0, 0), (12, 0.5, 0), (13, 0.0, 1), (14, 0.3, -1))):
        add_tall("column_rock_%s" % "abcd"[i], rock_column(seed, moss=moss_a, lean=lean))
    for i, seed in enumerate((21, 22)):
        add_tall("column_dark_%s" % "ab"[i], rock_column(seed, dark=True))
    for i, seed in enumerate((15, 16)):
        big = rock_column(seed, height=48, moss=0.2 * i)
        add("column_tall_%s_top" % "ab"[i], big.crop((0, 0, T, T)))
        add("column_tall_%s_mid" % "ab"[i], big.crop((0, T, T, 2 * T)))
        add("column_tall_%s_base" % "ab"[i], big.crop((0, 2 * T, T, 3 * T)))
    for i in range(2):
        add("rock_mass_%s" % "ab"[i], rock_mass(30 + i))
    add("rock_mass_dark", rock_mass(33, dark=True))
    for i in range(3):
        add("shore_stone_%s" % "abc"[i], shore_stone(40 + i, moss=i == 2))
    add("stalagmite_a", stalagmite(1))
    add("stalagmite_b", stalagmite(2, moss=True))
    add("boulder_a", boulder(1))
    add("boulder_b", boulder(2, moss=True))
    add("boulder_small", boulder(3, small=True))
    add("boulder_small_moss", boulder(4, small=True, moss=True))
    add("rubble_a", rubble(1))
    add("rubble_b", rubble(2))
    add("pebbles", pebbles(1))
    add("bones", bones())

    # terrace walls, stairs, bridges
    add("wall_face", wall_face(1))
    add("wall_face_moss", wall_face(2, moss=0.34))
    add("wall_lip", wall_face(3, top_lip=True))
    add("wall_lip_moss", wall_face(4, moss=0.3, top_lip=True))
    add("wall_side_l", wall_face(5, side="l"))
    add("wall_side_r", wall_face(6, side="r"))
    add("terrace_side_l", terrace_side("l"))
    add("terrace_side_r", terrace_side("r"))
    steps = stairs_steps()
    add("stairs_steps", steps)
    add("stairs_steps_wood", stairs_steps(wood=True))
    add("stairs_steps_h", steps.rotate(-90))
    add("stairs_rail_l", stairs_rail("l"))
    add("stairs_rail_r", stairs_rail("r"))
    add("stairs_rail_t", stairs_rail("l").rotate(-90))
    add("stairs_rail_b", stairs_rail("r").rotate(-90))
    add("bridge_planks_h", bridge_planks(True))
    add("bridge_planks_v", bridge_planks(False))
    add("bridge_rail_h", bridge_rail(True))
    add("bridge_rail_v", bridge_rail(False))

    # crystals, fire, banners, chests, props
    add_tall("crystal", crystal_big(0))
    add("crystal_top_b", crystal_big(1).crop((0, 0, T, T)))
    for i in range(2):
        add("crystal_small_%s" % "ab"[i], crystal_small(i))
        add("crystal_small_%s2" % "ab"[i], crystal_small(i, 1))
    for f in range(3):
        add("torch_%s" % "abc"[f], torch_stand(f))
    for f in range(3):
        add("brazier_%s" % "abc"[f], brazier(f))
    add_tall("banner_a", banner())
    add_tall("banner_b", banner(torn=True))
    add("chest_closed", chest())
    add("chest_open", chest(True))
    add("crate", crate())
    add("barrel", barrel())
    add_tall("pillar", pillar())
    add("pillar_broken", pillar(True))
    add_tall("stele", stele())
    add("stele_small", stele(False))
    add("fern_a", fern(1))
    add("fern_b", fern(2))
    add("fern_blue", fern(3, blue=True))
    add("moss_clump_a", moss_clump(1))
    add("moss_clump_b", moss_clump(2))
    for k in range(4):
        add("mushroom_%d" % k, mushroom(k))
    for k in range(3):
        add("glow_flower_%d" % k, glow_flower(k))

    # waterfall
    add("waterfall_top", waterfall_top())
    for f in range(3):
        add("waterfall_mid_%s" % "abc"[f], waterfall_mid(f))
    for f in range(3):
        add("waterfall_base_%s" % "abc"[f], waterfall_base(f))
    add("terrace_top", terrace_top())
    add("spike_trap_off", spike_trap(False))
    add("spike_trap_on", spike_trap(True))
    return tiles, patterns


def write_sheet(tiles, patterns):
    rows = (len(tiles) + COLUMNS - 1) // COLUMNS
    sheet = Image.new("RGBA", (COLUMNS * T, rows * T), CLEAR)
    coords = {}
    for i, (name, img) in enumerate(tiles):
        c, r = i % COLUMNS, i // COLUMNS
        sheet.paste(img, (c * T, r * T))
        coords[name] = [c, r]
    os.makedirs(OUT, exist_ok=True)
    sheet.save(os.path.join(OUT, "ruins_sheet.png"))
    data = {"tile_size": T, "columns": COLUMNS, "tiles": coords,
            "patterns": {role: [coords[n] for n in names] for role, names in patterns.items()}}
    with open(os.path.join(OUT, "ruins_tiles.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1)
    return sheet, coords


# --- preview (not part of the game) ----------------------------------------------------------------------------
def contact_sheet(tiles, scale=5):
    cell_w, cell_h = T * scale + 6, T * scale + 14
    cols = 12
    rows = (len(tiles) + cols - 1) // cols
    img = Image.new("RGBA", (cols * cell_w, rows * cell_h), (24, 26, 40, 255))
    d = ImageDraw.Draw(img)
    for i, (name, tile) in enumerate(tiles):
        c, r = i % cols, i // cols
        big = tile.resize((T * scale, T * scale), Image.NEAREST)
        bg = Image.new("RGBA", big.size, (60, 62, 78, 255))
        bg.alpha_composite(big)
        img.paste(bg, (c * cell_w + 3, r * cell_h + 2))
        d.text((c * cell_w + 3, r * cell_h + T * scale + 3), name[:17], fill=(190, 200, 230, 255))
    return img


def sample_room(coords, sheet, frame=0, scale=4):
    """A 34x20 tile cave built only from the sheet, to judge the set as a whole."""
    W, H = 34, 20
    room = Image.new("RGBA", (W * T, H * T), (0, 0, 0, 255))

    def tile(name):
        c, r = coords[name]
        return sheet.crop((c * T, r * T, c * T + T, r * T + T))

    def put_tile(name, x, y):
        room.alpha_composite(tile(name), (x * T, y * T))

    rng = random.Random(9)
    for y in range(H):
        for x in range(W):
            put_tile("void_a" if (x + y) % 3 else "void_b", x, y)
    # the room floor
    for y in range(3, H - 2):
        for x in range(2, W - 2):
            put_tile(rng.choice(("floor_a", "floor_a", "floor_a", "floor_b", "floor_crack", "floor_moss")), x, y)
    # path of worn stones
    for x in range(2, W - 2):
        for y in (11, 12):
            put_tile("floor_worn", x, y)
    # pond with a bridge
    pond_x, pond_y, pw, ph = 20, 4, 8, 6
    for j in range(ph):
        for i in range(pw):
            k = (0 if j == 0 else 2 if j == ph - 1 else 1) * 3 + (0 if i == 0 else 2 if i == pw - 1 else 1)
            name = "pond_%d" % k
            if k == 4:
                name = ("pond_4", "pond_center_b", "pond_center_c")[(frame + (i + j) % 2) % 3]
            put_tile(name, pond_x + i, pond_y + j)
    # waterfall into the pond from the top wall
    put_tile("waterfall_top", 23, 1)
    put_tile("waterfall_mid_" + "abc"[frame], 23, 2)
    put_tile("waterfall_mid_" + "abc"[frame], 23, 3)
    put_tile("waterfall_base_" + "abc"[frame], 23, 4)
    for i in range(pw + 2):
        put_tile("bridge_planks_h", pond_x - 1 + i, pond_y + 3)
        put_tile("bridge_rail_h", pond_x - 1 + i, pond_y + 2)
        put_tile("bridge_rail_h", pond_x - 1 + i, pond_y + 4)
    # a terrace with stairs on the left
    for x in range(4, 12):
        put_tile("wall_lip", x, 5)
        put_tile("wall_face", x, 6)
        for y in range(3, 5):
            put_tile("floor_worn", x, y)
    put_tile("wall_side_l", 4, 6)
    put_tile("wall_side_r", 11, 6)
    for y in (5, 6):
        put_tile("stairs_steps", 7, y)
        put_tile("stairs_rail_l", 6, y)
        put_tile("stairs_rail_r", 8, y)
    # border of rock columns (draw back to front)
    cols = ["column_rock_a", "column_rock_b", "column_rock_c", "column_rock_d"]
    for x in range(0, W):
        n = cols[(x * 7) % 4]
        put_tile(n + "_top", x, 0)
        put_tile(n + "_base", x, 1)
    for x in range(0, W):
        n = cols[(x * 5 + 1) % 4]
        put_tile(n + "_top", x, H - 3)
        put_tile(n + "_base", x, H - 2)
    for y in range(2, H - 3):
        for x in (0, 1, W - 2, W - 1):
            n = cols[(y * 3 + x) % 4]
            put_tile(n + "_top", x, y - 1)
            put_tile(n + "_base", x, y)
    # decoration
    for x in (13, 17):
        put_tile("pillar_top", x, 5)
        put_tile("pillar_base", x, 6)
    put_tile("crystal_top" if frame % 2 == 0 else "crystal_top_b", 15, 7)
    put_tile("crystal_base", 15, 8)
    put_tile("crystal_small_a" if frame != 1 else "crystal_small_a2", 5, 9)
    put_tile("crystal_small_b" if frame != 2 else "crystal_small_b2", 28, 14)
    put_tile("torch_" + "abc"[frame], 3, 14)
    put_tile("brazier_" + "abc"[frame], 30, 5)
    put_tile("banner_a_top", 12, 1)
    put_tile("banner_a_base", 12, 2)
    put_tile("banner_b_top", 18, 1)
    put_tile("banner_b_base", 18, 2)
    put_tile("chest_closed", 10, 15)
    put_tile("chest_open", 26, 16)
    put_tile("crate", 8, 15)
    put_tile("barrel", 9, 14)
    put_tile("stele_top", 15, 13)
    put_tile("stele_base", 15, 14)
    put_tile("stele_small", 22, 15)
    put_tile("floor_rune", 14, 15)
    for name, (x, y) in (("fern_a", (3, 4)), ("fern_blue", (30, 15)), ("mushroom_0", (14, 4)), ("mushroom_1", (3, 11)),
                         ("mushroom_2", (29, 8)), ("glow_flower_0", (12, 16)), ("glow_flower_2", (24, 12)),
                         ("moss_clump_a", (7, 15)), ("rubble_a", (19, 15)), ("bones", (4, 8)),
                         ("boulder_a", (31, 11)), ("stalagmite_a", (13, 10)), ("pebbles", (20, 13)),
                         ("boulder_small", (17, 11)), ("pillar_broken", (6, 12))):
        put_tile(name, x, y)
    return room.resize((W * T * scale, H * T * scale), Image.NEAREST)


def sample_map(coords, sheet, frame=0, scale=3):
    """A 48x34 tile map built only from the sheet, laid out like the concept map: platforms at two
    heights, a river with a bridge, a staircase through a cliff and an alcove with its own stairs."""
    W, H = 48, 34
    img = Image.new("RGBA", (W * T, H * T), (0, 0, 0, 255))
    rng = random.Random(5)

    def tile(name):
        c, r = coords[name]
        return sheet.crop((c * T, r * T, c * T + T, r * T + T))

    def blit(name, x, y):
        img.alpha_composite(tile(name), (x * T, y * T))

    def inside(rect, x, y):
        return rect[0] <= x < rect[2] and rect[1] <= y < rect[3]

    for y in range(H):
        for x in range(W):
            blit(rng.choice(("rock_mass_a", "rock_mass_b", "rock_mass_dark")), x, y)

    S = (18, 18, 38, 31)        # start platform (low)
    L = (3, 13, 14, 31)         # west platform (low)
    HI = (24, 5, 45, 16)        # high platform; its south edge is a cliff
    A = (5, 6, 11, 11)          # alcove (mini room), high
    RIVER = (14, 13, 18, 31)
    areas = [S, L, HI, A]
    for rect in areas:
        for y in range(rect[1], rect[3]):
            for x in range(rect[0], rect[2]):
                name = rng.choice(("floor_a", "floor_a", "floor_a", "floor_b", "floor_crack", "floor_moss"))
                if rect is A:
                    name = "floor_worn"
                blit(name, x, y)
    # the cliff under the high platform and the alcove
    for x in range(HI[0], HI[2]):
        blit("wall_lip", x, 16)
        blit("wall_face_moss" if x % 7 == 0 else "wall_face", x, 17)
    for x in range(A[0], A[2]):
        blit("wall_lip", x, 11)
        blit("wall_face", x, 12)
    # paths of worn stone
    for x in range(20, 36):
        blit("floor_worn", x, 24)
    # river with its waterfall
    for j in range(RIVER[3] - RIVER[1]):
        for i in range(RIVER[2] - RIVER[0]):
            k = (0 if j == 0 else 2 if j == RIVER[3] - RIVER[1] - 1 else 1) * 3 + (0 if i == 0 else 2 if i == RIVER[2] - RIVER[0] - 1 else 1)
            name = "pond_%d" % k
            if k == 4:
                name = ("pond_4", "pond_center_b", "pond_center_c")[(frame + (i + j) % 2) % 3]
            blit(name, RIVER[0] + i, RIVER[1] + j)
    for x in (15, 16):
        blit("waterfall_top", x, 10)
        blit("waterfall_mid_" + "abc"[frame], x, 11)
        blit("waterfall_base_" + "abc"[frame], x, 12)
    # bridge across the river and shore stones along both banks
    for x in range(13, 19):
        blit("bridge_rail_h", x, 24)
        blit("bridge_planks_h", x, 25)
        blit("bridge_rail_h", x, 26)
    for y in range(14, 31):
        if 23 <= y <= 27:
            continue
        blit("shore_stone_" + "abc"[y % 3], 13, y)
        blit("shore_stone_" + "abc"[(y + 1) % 3], 18, y)
    # stairs: south to the high platform, and up into the alcove
    for y in (16, 17):
        blit("stairs_steps", 30, y)
        blit("stairs_steps", 31, y)
        blit("stairs_rail_l", 29, y)
        blit("stairs_rail_r", 32, y)
    for y in (11, 12):
        blit("stairs_steps", 7, y)
        blit("stairs_steps", 8, y)
        blit("stairs_rail_l", 6, y)
        blit("stairs_rail_r", 9, y)

    # rocks around every platform: clusters of columns two deep, staggered, never in the openings
    openings = [(29, 15, 33, 19), (6, 10, 10, 14), (13, 23, 19, 28), RIVER]
    sprites = []
    names = ["column_rock_a", "column_rock_b", "column_rock_c", "column_rock_d"]
    tall = ["column_tall_a", "column_tall_b"]
    for rect, open_south in ((S, False), (L, False), (HI, True), (A, True)):
        x0, y0, x1, y1 = rect
        for y in range(y0 - 2, y1 + 2):
            for x in range(x0 - 2, x1 + 2):
                if inside(rect, x, y):
                    continue
                near = min(max(x0 - x, x - (x1 - 1), 0) if y0 <= y < y1 else 99,
                           max(y0 - y, y - (y1 - 1), 0) if x0 <= x < x1 else 99)
                corner = max(max(x0 - x, x - (x1 - 1), 0), max(y0 - y, y - (y1 - 1), 0))
                if corner > 2 or inside((x0 - 2, y0 - 2, x1 + 2, y1 + 2), x, y) is False:
                    continue
                if open_south and y >= y1 - 0 and y <= y1 + 1:
                    continue
                if any(inside(o, x, y) for o in openings) or any(inside(a, x, y) for a in areas if a is not rect):
                    continue
                if rect is S and y < y0 and inside((24, 5, 45, 18), x, y):
                    continue
                if corner == 2 and rng.random() < 0.3:
                    continue
                px = x * T + rng.choice((-6, -3, 0, 3, 6))
                base = (y + 1) * T + rng.choice((-4, 0, 0, 4)) + (-3 if corner == 2 else 0)
                kind = rng.choice(names + names + tall) if corner == 2 and rng.random() < 0.6 else rng.choice(names)
                sprites.append((base, px, kind))
    sprites.sort()
    for base, px, kind in sprites:
        if kind.startswith("column_tall"):
            for part, off in (("top", 48), ("mid", 32), ("base", 16)):
                img.alpha_composite(tile("%s_%s" % (kind, part)), (px, base - off))
        else:
            img.alpha_composite(tile(kind + "_top"), (px, base - 32))
            img.alpha_composite(tile(kind + "_base"), (px, base - 16))

    # decoration: lights, crystals, banners, chests, props, plants
    def put_tall(name, x, y):
        blit(name + "_top", x, y - 1)
        blit(name + "_base", x, y)

    put_tall("crystal", 7, 8)
    blit("chest_closed", 9, 8)
    blit("crate", 5, 7)
    blit("crate", 5, 8)
    blit("torch_" + "abc"[frame], 10, 7)
    blit("brazier_" + "abc"[frame], 22, 22)
    blit("torch_" + "abc"[(frame + 1) % 3], 28, 19)
    blit("torch_" + "abc"[(frame + 2) % 3], 33, 19)
    put_tall("banner_a", 30, 5)
    put_tall("banner_b", 40, 5)
    put_tall("pillar", 27, 9)
    put_tall("pillar", 41, 9)
    blit("brazier_" + "abc"[frame], 33, 8)
    blit("chest_closed", 43, 8)
    put_tall("crystal", 35, 10)
    blit("floor_rune", 28, 27)
    put_tall("stele", 36, 27)
    blit("chest_closed", 20, 28)
    blit("crystal_small_a" if frame != 1 else "crystal_small_a2", 6, 17)
    blit("crystal_small_b" if frame != 2 else "crystal_small_b2", 11, 27)
    for name, (x, y) in (("fern_a", (4, 22)), ("fern_blue", (3, 28)), ("mushroom_0", (12, 20)), ("mushroom_1", (22, 26)),
                         ("mushroom_2", (36, 22)), ("glow_flower_0", (9, 19)), ("glow_flower_2", (32, 28)),
                         ("moss_clump_a", (20, 25)), ("rubble_a", (35, 20)), ("bones", (5, 14)),
                         ("boulder_a", (37, 12)), ("stalagmite_a", (25, 12)), ("boulder_small", (9, 24)),
                         ("pillar_broken", (7, 15)), ("barrel", (26, 11)), ("crate", (26, 10))):
        blit(name, x, y)
    return img.resize((W * T * scale, H * T * scale), Image.NEAREST)


def main():
    tiles, patterns = build_tiles()
    sheet, coords = write_sheet(tiles, patterns)
    print("%d tiles, sheet %dx%d" % (len(tiles), sheet.width, sheet.height))
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        contact_sheet(tiles).save(os.path.join(PREVIEW, "ruinas_hoja.png"))
        sample_map(coords, sheet, 0).save(os.path.join(PREVIEW, "ruinas_mapa.png"))
        frames = [sample_map(coords, sheet, f, scale=2) for f in range(3)]
        frames[0].save(os.path.join(PREVIEW, "ruinas_mapa.gif"), save_all=True, append_images=frames[1:], duration=170, loop=0)


if __name__ == "__main__":
    main()
