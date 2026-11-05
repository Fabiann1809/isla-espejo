"""Draws the forest's dirt (paths and patches of bare earth) pixel by pixel.

The tileset's dirt patch drew paths as boxes with rounded corners and a dotted border. This dirt is
transparent outside its edge, so the grass below shows through. The edge wanders, frays into the
grass, has tufts of grass biting into it, a worn darker line just inside and a few blades of grass
that lean over it. Inside, the earth has specks, pebbles and a stone now and then.

  dirt.png  16 px tiles, one per row, the same rows as the water (WaterArt / AreaArt.ROWS):
                0-8   nine-slice, 9-12 inner corners (SE, SW, NE, NW), 13-16 other looks of the
                top, left, right and bottom edges, 17-18 more middles

    python tools/make_dirt_art.py
Writes into assets/tilesets/dirt/. Original art (no third-party source). Needs Pillow.
"""
import math
import os
import random

from PIL import Image

from make_water_art import TILES, T, shore_distance

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "tilesets", "dirt")

DIRT = (178, 130, 84)
DIRT_SHADE = (164, 117, 73)
DIRT_WORN = (150, 106, 64)
SPECK = (136, 95, 58)
PEBBLE = (208, 168, 120)
STONE = (150, 142, 126)
STONE_DK = (108, 100, 88)
GRASS = (124, 175, 37)
GRASS_DK = (98, 148, 32)

GAP = 3.0        # grass between the tile's edge and the dirt (px)
CORNER = 10.0    # radius of an outer corner (px)
FRAY = 0.8       # the outermost band of earth breaks up into the grass (px)
WORN = 1.8       # the darker band inside the edge ends here (px)


def bend(t, variant):
    """How far the edge leans into the earth at t (0..16 along it): every look wanders a little,
    and is back on the line at both ends so any two tiles meet."""
    window = math.sin(math.pi * t / T)
    if variant == 0:
        return 1.4 * window * math.sin(2 * math.pi * t / T)
    if variant == 1:
        return 2.4 * window ** 2
    return -2.0 * window ** 3 + 0.8 * window * math.sin(3 * math.pi * t / T)


def dirt_tile(sides, diagonal, variant, row):
    rng = random.Random(row * 104729 + 3)
    img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    px = img.load()
    dist = {(x, y): shore_distance(x + 0.5, y + 0.5, sides, diagonal, variant, bend, GAP, CORNER)
            for y in range(T) for x in range(T)}
    # Tufts of grass biting into the edge: the grass below shows through.
    edge = [(x, y) for (x, y), s in dist.items() if 0 < s < 1.0 and 4 <= x <= 11 and 4 <= y <= 11]
    rng.shuffle(edge)
    bites = [(x, y, rng.uniform(1.4, 2.4)) for x, y in edge[: rng.randint(0, 2)]]
    for (x, y), s in dist.items():
        if s <= 0 or any(math.hypot(x - bx, y - by) < r for bx, by, r in bites):
            continue
        if s < FRAY and rng.random() < 0.3:
            continue  # the last grains of earth among the grass
        if s < WORN:
            color = DIRT_WORN
        else:
            color = DIRT if rng.random() > 0.05 else DIRT_SHADE
            roll = rng.random()
            if roll < 0.012:
                color = SPECK
            elif roll < 0.02:
                color = PEBBLE
        px[x, y] = color + (255,)
    # A stone now and then, well inside the earth.
    if rng.random() < 0.08:
        for _ in range(20):
            x, y = rng.randint(3, 11), rng.randint(3, 12)
            if all(dist[x + dx, y + dy] > WORN + 1 for dx in (0, 1, 2) for dy in (0, 1)):
                px[x, y] = PEBBLE + (255,)
                px[x + 1, y] = STONE + (255,)
                px[x, y + 1] = STONE + (255,)
                px[x + 1, y + 1] = STONE_DK + (255,)
                break
    # Blades of grass leaning over the edge.
    edge = [(x, y) for (x, y), s in dist.items() if 0 < s < 1.2 and px[x, y][3]]
    rng.shuffle(edge)
    for x, y in edge[: rng.randint(0, 2)]:
        px[x, y] = GRASS + (255,)
        inward = [(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                  if (x + dx, y + dy) in dist and dist[x + dx, y + dy] > dist[x, y]]
        if inward:
            px[inward[0]] = GRASS_DK + (255,)
    return img


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    sheet = Image.new("RGBA", (T, T * len(TILES)), (0, 0, 0, 0))
    for row, (sides, diagonal, variant) in enumerate(TILES):
        sheet.paste(dirt_tile(sides, diagonal, variant, row), (0, row * T))
    sheet.save(os.path.join(OUT, "dirt.png"))
    print("dirt art written to", os.path.normpath(OUT))
