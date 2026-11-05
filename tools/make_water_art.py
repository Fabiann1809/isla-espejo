"""Draws the forest's water and wooden bridge pixel by pixel (light from the upper left).

The tileset's pond was a flat light-blue rectangle with a frame of lighter grass, and its bridge a
plain square of planks, so the river read as a patch of earth between two puddles. This draws:

  water.png  16 px tiles, one row per tile, one column per animation frame. The water is
             transparent outside its shore, so the room's own grass shows around it: rounded outer
             corners, a shore that wobbles a pixel here and there (two variants of each edge), an
             earth bank under the north shore (we look at the island from the south), a dark rim
             on the grass, foam that laps at the shore, shallow water that deepens towards the
             middle, and ripples and glints that come and go. Rows (keep in sync with WaterArt.ROWS):
                 0-8   nine-slice: top-left, top, top-right, left, middle, right, bottom-left,
                       bottom, bottom-right
                 9-12  inner corners, by the diagonal that is land: SE, SW, NE, NW
                 13-16 second variant of top, left, right, bottom
                 17-18 more middles
  bridge_*.png  pieces of a bridge that crosses the water from west to east (its boards run
             north-south), repeated by WaterArt to any length:
  water_lily.png  two lily pads (8x7 each), the second in flower, floating on open water
                 bridge_deck.png      32x32 boards (repeats both ways)
                 bridge_deck_end.png  2x16 dark edge of the deck's west end (flipped for the east)
                 bridge_rail.png      16x10 railing: a beam and one post per tile
                 bridge_newel.png     5x13 thick post at each end of a railing
                 bridge_side.png      16x8 the deck's south face and a pile into the water per tile
                 bridge_shadow.png    16x8 the shade the bridge casts on the water

    python tools/make_water_art.py
Writes into assets/tilesets/water/. Original art (no third-party source). Needs Pillow.
"""
import math
import os
import random

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "tilesets", "water")
T = 16
FRAMES = 6

# --- palette ---------------------------------------------------------------------------------------
FOAM = (206, 238, 232)
SHALLOW_1 = (116, 194, 204)
SHALLOW_2 = (84, 168, 190)
MID = (64, 142, 174)
DEEP = (52, 120, 158)
RIPPLE_ON = {SHALLOW_2: (112, 190, 206), MID: (92, 168, 196), DEEP: (78, 150, 184)}
GLINT = (236, 250, 246)
BANK_SHADE = (40, 96, 130)
BANK_LIP = (122, 98, 58)
BANK = (96, 70, 42)
BANK_DARK = (66, 48, 32)
BANK_STONE = (120, 112, 96)
RIM = (60, 88, 34)

WOOD_HI = (210, 164, 106)
WOOD_LT = (186, 138, 86)
WOOD_MD = (160, 114, 68)
WOOD_DK = (122, 84, 50)
WOOD_LINE = (72, 48, 30)
SHADOW = (16, 34, 52)

# --- water -----------------------------------------------------------------------------------------
MARGIN = 3.0      # grass between the tile's edge and the water (px)
CORNER = 5.0      # radius of an outer corner (px)
FACE = 3          # height of the earth bank under a north shore (px)
BANK_SHADOW = 2   # darker water under that bank (px)

# Tiles: (land sides, land diagonal cell or None, variant).
N, S, E, W = "N", "S", "E", "W"
TILES = [
    ({N, W}, None, 0), ({N}, None, 0), ({N, E}, None, 0),
    ({W}, None, 0), (set(), None, 0), ({E}, None, 0),
    ({S, W}, None, 0), ({S}, None, 0), ({S, E}, None, 0),
    (set(), (1, 1), 0), (set(), (-1, 1), 0), (set(), (1, -1), 0), (set(), (-1, -1), 0),
    ({N}, None, 1), ({W}, None, 1), ({E}, None, 1), ({S}, None, 1),
    (set(), None, 1), (set(), None, 2),
]


def wobble(t, variant):
    """How far a straight shore leans into the water at t (0..16 along the edge). Zero at both
    ends, so any two edge tiles meet without a step."""
    if variant == 0:
        return 0.0
    # A shallow bay (variant 1) or a little spit of grass (variant 2), a few pixels long.
    centre, depth = (6.0, -1.6) if variant == 1 else (10.0, 1.4)
    k = max(0.0, 1.0 - abs(t - centre) / 5.0)
    return depth * k * k * (3 - 2 * k)


def shore_distance(px, py, sides, diagonal, variant, bend=wobble, gap=MARGIN, corner=CORNER):
    """Distance (px) from the point to the shore, positive in the water. The tile is the middle cell
    of a 3x3 block, its own square is 0..16; land lies beyond the given sides or in the diagonal cell.
    `bend`, `gap` and `corner` shape the shore (tools/make_dirt_art.py draws its paths with them)."""
    margin = {N: gap + bend(px, variant), S: gap - bend(px, variant),
              W: gap + bend(py, variant), E: gap - bend(py, variant)}
    edge = {N: py, S: T - py, W: px, E: T - px}
    d = {side: edge[side] - margin[side] for side in sides}
    best = min(d.values()) if d else 99.0
    for a, b in ((N, W), (N, E), (S, W), (S, E)):
        if a in d and b in d and d[a] < corner and d[b] < corner:
            best = min(best, corner - math.hypot(corner - d[a], corner - d[b]))
    if diagonal is not None:
        cx = T if diagonal[0] > 0 else 0
        cy = T if diagonal[1] > 0 else 0
        dx = max(0.0, (px - cx) * (-diagonal[0]))
        dy = max(0.0, (py - cy) * (-diagonal[1]))
        best = min(best, math.hypot(dx, dy) - gap)
    return min(best, 16.0)


def band(s, x, y):
    """Water color by distance from the shore, dithered where two bands meet."""
    for limit, color, next_color in ((2.0, SHALLOW_1, SHALLOW_2), (4.5, SHALLOW_2, MID), (8.5, MID, DEEP)):
        if s < limit:
            if s > limit - 0.7 and (x + y) % 2 == 0:
                return next_color
            return color
    return DEEP


def water_tile(sides, diagonal, variant, row):
    rng = random.Random(row * 7919 + 13)
    frames = [Image.new("RGBA", (T, T), (0, 0, 0, 0)) for _ in range(FRAMES)]
    dist = {}
    for y in range(T):
        for x in range(T):
            dist[x, y] = shore_distance(x + 0.5, y + 0.5, sides, diagonal, variant)

    def is_water(x, y):
        if 0 <= x < T and 0 <= y < T:
            return dist[x, y] > 0
        return shore_distance(x + 0.5, y + 0.5, sides, diagonal, variant) > 0

    north_land = N in sides or (diagonal is not None and diagonal[1] < 0)
    # Ripple sites in open water, away from the tile's edges so tiles never cut one in half.
    sites = []
    for _ in range(40):
        if len(sites) == 3:
            break
        x, y = rng.randint(2, 11), rng.randint(2, 13)
        if all(dist.get((x + i, y), 0) > 6 for i in range(3)) and all(abs(y - sy) > 2 or abs(x - sx) > 4 for sx, sy, _ in sites):
            sites.append((x, y, rng.randrange(FRAMES)))
    glints = [(rng.randint(2, 13), rng.randint(2, 13), rng.randrange(FRAMES)) for _ in range(2)]

    for f, frame in enumerate(frames):
        px = frame.load()
        for y in range(T):
            for x in range(T):
                s = dist[x, y]
                if s <= 0:
                    # A dark rim on the grass all around the water.
                    if any(is_water(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                        px[x, y] = RIM + (255,)
                    continue
                if north_land and not is_water(x, y - FACE):
                    # The earth bank under a north shore: lit lip, earth, dark foot, a stone now and then.
                    depth = next(k for k in range(1, FACE + 1) if not is_water(x, y - k))
                    color = BANK_LIP if depth == 1 else (BANK if depth < FACE else BANK_DARK)
                    if depth == 2 and (x * 5 + row) % 11 == 0:
                        color = BANK_STONE
                    px[x, y] = color + (255,)
                    continue
                color = band(s, x, y)
                if north_land and not is_water(x, y - FACE - BANK_SHADOW):
                    color = BANK_SHADE
                # Foam laps at the shore: the line moves a pixel out and back.
                lap = 1.0 if (f // 2) % 3 != 1 else 1.8
                if s < lap and color != BANK_SHADE:
                    color = FOAM if (x + y + f) % 4 else SHALLOW_1
                px[x, y] = color + (255,)
        # Ripples: a short light dash that grows, holds and fades, each on its own phase.
        for sx, sy, phase in sites:
            age = (f - phase) % FRAMES
            length = (1, 3, 3, 2, 0, 0)[age]
            start = sx + (3 - length) // 2
            for i in range(length):
                base = px[start + i, sy][:3]
                if base in RIPPLE_ON:
                    px[start + i, sy] = RIPPLE_ON[base] + (255,)
        for gx, gy, phase in glints:
            if f == phase and dist[gx, gy] > 4 and px[gx, gy][:3] in (MID, DEEP, SHALLOW_2):
                px[gx, gy] = GLINT + (255,)
    return frames


def write_water():
    sheet = Image.new("RGBA", (T * FRAMES, T * len(TILES)), (0, 0, 0, 0))
    for row, (sides, diagonal, variant) in enumerate(TILES):
        for f, frame in enumerate(water_tile(sides, diagonal, variant, row)):
            sheet.paste(frame, (f * T, row * T))
    sheet.save(os.path.join(OUT, "water.png"))


# --- bridge ----------------------------------------------------------------------------------------
def write_lilies():
    """Two lily pads (8x7 each, side by side), the second with a flower."""
    pad = ["..oooo..",
           ".oLLggo.",
           "oLLgg.go",
           "oLggg.Go",
           "oggggGGo",
           ".oGGGGo.",
           "..oooo.."]
    colors = {"o": (40, 86, 42), "L": (132, 190, 80), "g": (92, 156, 62), "G": (66, 124, 50),
              "p": (238, 172, 204), "y": (252, 228, 120)}
    img = Image.new("RGBA", (16, 7), (0, 0, 0, 0))
    for n in range(2):
        for y, line in enumerate(pad):
            for x, ch in enumerate(line):
                if ch in colors:
                    img.putpixel((n * 8 + x, y), colors[ch] + (255,))
    for (x, y), ch in {(11, 2): "p", (12, 2): "p", (11, 3): "p", (12, 3): "y", (13, 3): "p", (12, 4): "p"}.items():
        img.putpixel((x, y), colors[ch] + (255,))
    img.save(os.path.join(OUT, "water_lily.png"))


def write_deck():
    """Boards of 3 px with a dark line between them, each with its own joints, over 32x32 px so the
    joints do not line up in a grid."""
    rng = random.Random(4)
    size = T * 2
    img = Image.new("RGBA", (size, size))
    px = img.load()
    for board in range(size // 4):
        x0 = board * 4
        # Now and then an older, darker board.
        lit, body = (WOOD_LT, WOOD_MD) if rng.random() < 0.3 else (WOOD_HI, WOOD_LT)
        for y in range(size):
            px[x0, y] = lit + (255,)
            px[x0 + 1, y] = body + (255,)
            px[x0 + 2, y] = body + (255,)
            px[x0 + 3, y] = WOOD_LINE + (255,)
            if rng.random() < 0.05:
                px[x0 + 1 + rng.randint(0, 1), y] = WOOD_MD + (255,)
        # Butt joints where two boards meet, each board at its own heights.
        first = rng.randint(2, 15)
        for joint in (first, first + rng.randint(11, 15)):
            for i in range(3):
                px[x0 + i, joint % size] = WOOD_LINE + (255,)
            px[x0, (joint + 1) % size] = WOOD_HI + (255,)
    img.save(os.path.join(OUT, "bridge_deck.png"))


def write_deck_end():
    img = Image.new("RGBA", (2, T))
    for y in range(T):
        img.putpixel((0, y), WOOD_LINE + (255,))
        img.putpixel((1, y), WOOD_DK + (255,))
    img.save(os.path.join(OUT, "bridge_deck_end.png"))


def write_rail():
    img = Image.new("RGBA", (T, 10), (0, 0, 0, 0))
    px = img.load()
    for x in range(T):
        px[x, 0] = WOOD_LINE + (255,)
        px[x, 1] = WOOD_HI + (255,)
        px[x, 2] = WOOD_LT + (255,)
        px[x, 3] = WOOD_DK + (255,)
        px[x, 4] = WOOD_LINE + (255,)
    for y in range(5, 10):
        px[6, y] = WOOD_LINE + (255,)
        px[7, y] = WOOD_LT + (255,)
        px[8, y] = WOOD_MD + (255,)
        px[9, y] = WOOD_LINE + (255,)
    px[7, 9] = WOOD_DK + (255,)
    px[8, 9] = WOOD_DK + (255,)
    img.save(os.path.join(OUT, "bridge_rail.png"))


def write_newel():
    img = Image.new("RGBA", (5, 13), (0, 0, 0, 0))
    px = img.load()
    for y in range(13):
        for x in range(5):
            edge = x in (0, 4) or y in (0, 12)
            px[x, y] = (WOOD_LINE if edge else (WOOD_HI if x == 1 else (WOOD_LT if x == 2 else WOOD_MD))) + (255,)
    for x in range(1, 4):
        px[x, 1] = WOOD_HI + (255,)
        px[x, 2] = WOOD_DK + (255,)
    img.save(os.path.join(OUT, "bridge_newel.png"))


def write_side():
    img = Image.new("RGBA", (T, 8), (0, 0, 0, 0))
    px = img.load()
    for x in range(T):
        px[x, 0] = WOOD_DK + (255,)
        px[x, 1] = WOOD_MD + (255,)
        px[x, 2] = WOOD_LINE + (255,)
    for y in range(3, 7):
        px[6, y] = WOOD_LINE + (255,)
        px[7, y] = WOOD_MD + (255,)
        px[8, y] = WOOD_DK + (255,)
        px[9, y] = WOOD_LINE + (255,)
    for x in (5, 10):
        px[x, 7] = FOAM + (255,)
    for x in (6, 7, 8, 9):
        px[x, 7] = SHALLOW_1 + (255,)
    img.save(os.path.join(OUT, "bridge_side.png"))


def write_shadow():
    img = Image.new("RGBA", (T, 8), (0, 0, 0, 0))
    for y in range(8):
        for x in range(T):
            if y < 5 or (x + y) % 2 == 0:
                img.putpixel((x, y), SHADOW + (140 if y < 5 else 80,))
    img.save(os.path.join(OUT, "bridge_shadow.png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write_water()
    write_lilies()
    write_deck()
    write_deck_end()
    write_rail()
    write_newel()
    write_side()
    write_shadow()
    print("water and bridge art written to", os.path.normpath(OUT))
