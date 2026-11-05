"""Draws the forest camp's campfire and the cut stump pixel by pixel (light from the upper left).

The tileset's campfire was a tiny blurred tile and the stump a small picture cut flat at its foot,
both looking pasted onto the ground. These stand on it: each has a soft shadow and a base (a ring of
stones for the fire, roots spreading into the ground for the stump).

Writes into assets/art_forest/camp/:
    campfire.png  24x24 cells side by side, one per frame (6, looping): a ring of stones with
                  embers and ash, two logs leaning into each other, a flame that licks up and
                  sparks that rise. Its foot (the ring's lowest stone) is on the last row but one.
    stump.png     20x16: a cut stump with growth rings on top, bark, a tuft of moss, roots and
                  its shadow to the lower right. Its foot is the middle of the last row but one.

    python tools/make_camp_art.py
Original art (no third-party source). Needs Pillow.
"""
import math
import os
import random

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "art_forest", "camp")

OUTLINE = (44, 30, 24)
SHADOW = (20, 26, 14, 90)
STONE_HI = (176, 172, 158)
STONE = (138, 134, 122)
STONE_DK = (96, 92, 84)
ASH = (74, 62, 56)
ASH_DK = (52, 42, 38)
EMBER = (255, 132, 44)
EMBER_DIM = (196, 72, 34)
LOG_HI = (150, 102, 62)
LOG = (118, 78, 46)
LOG_DK = (84, 54, 34)
LOG_END = (206, 162, 108)
FLAME_OUT = (226, 86, 38)
FLAME_MID = (248, 152, 46)
FLAME_IN = (255, 220, 112)
FLAME_CORE = (255, 246, 196)
SPARK = (255, 200, 90)

BARK_HI = (140, 98, 62)
BARK = (110, 74, 46)
BARK_DK = (78, 52, 34)
WOOD_HI = (224, 186, 128)
WOOD = (198, 156, 100)
RING = (164, 120, 74)
MOSS_HI = (132, 178, 64)
MOSS = (88, 138, 50)


def put(img, x, y, color):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), color if len(color) == 4 else color + (255,))


def ellipse(img, cx, cy, rx, ry, color):
    for y in range(img.height):
        for x in range(img.width):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                put(img, x, y, color)


def outline(img):
    """A 1 px dark outline around every opaque part (shadows, half transparent, are left out)."""
    solid = {(x, y) for y in range(img.height) for x in range(img.width) if img.getpixel((x, y))[3] == 255}
    for x, y in list(solid):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            p = (x + dx, y + dy)
            if p not in solid and 0 <= p[0] < img.width and 0 <= p[1] < img.height:
                img.putpixel(p, OUTLINE + (255,))


# --- campfire --------------------------------------------------------------------------------------
CELL = 24
FRAMES = 6
RING_CENTER = (12, 18.5)
RING_RADIUS = (8.5, 4.2)


def campfire_base():
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    ellipse(img, 12.5, 20.5, 11, 3.6, SHADOW)
    # Ash and embers inside the ring.
    ellipse(img, RING_CENTER[0], RING_CENTER[1], 6.5, 3.0, ASH)
    ellipse(img, RING_CENTER[0], RING_CENTER[1] + 0.6, 4.5, 1.8, ASH_DK)
    # Two logs leaning into each other, their cut ends towards us.
    for (x0, y0), (x1, y1) in (((6, 20), (13, 13)), ((18, 20), (11, 13))):
        steps = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(steps + 1):
            x = round(x0 + (x1 - x0) * i / steps)
            y = round(y0 + (y1 - y0) * i / steps)
            put(img, x, y, LOG_HI)
            put(img, x, y + 1, LOG)
            put(img, x + (1 if x1 > x0 else -1), y + 1, LOG_DK)
        put(img, x0, y0, LOG_END)
        put(img, x0, y0 + 1, LOG_HI)
    # The ring of stones, the near ones last so they overlap the far ones.
    stones = []
    for i in range(11):
        angle = math.tau * i / 11 + 0.2
        stones.append((RING_CENTER[0] + math.cos(angle) * RING_RADIUS[0], RING_CENTER[1] + math.sin(angle) * RING_RADIUS[1]))
    for sx, sy in sorted(stones, key=lambda s: s[1]):
        x, y = round(sx - 1), round(sy - 1)
        for dx, dy, color in ((0, 0, STONE_HI), (1, 0, STONE), (2, 0, STONE), (0, 1, STONE), (1, 1, STONE), (2, 1, STONE_DK)):
            put(img, x + dx, y + dy, color)
    outline(img)
    return img


def flame(img, frame, rng):
    """A flame of three layers whose tip sways and leaps from frame to frame."""
    heights = [10, 12, 9, 11, 13, 10]
    sway = [0, 1, 1, 0, -1, -1]
    h = heights[frame]
    base_y = 18
    for layer, (color, width, shrink) in enumerate(((FLAME_OUT, 3.8, 0), (FLAME_MID, 2.8, 2), (FLAME_IN, 1.8, 4), (FLAME_CORE, 0.8, 6))):
        top = base_y - h + shrink
        for y in range(top, base_y + 1 - layer // 2):
            t = (y - top) / max(1, base_y - top)  # 0 at the tip, 1 at the base
            half = width * math.sqrt(t)
            cx = 12 + sway[frame] * (1 - t)
            for x in range(CELL):
                if abs(x + 0.5 - cx) <= half:
                    put(img, x, y, color)
    # A tongue of flame that breaks away now and then.
    if frame in (1, 4):
        put(img, 12 + sway[frame] * 2, base_y - h - 2, FLAME_MID)
        put(img, 12 + sway[frame] * 2, base_y - h - 3, FLAME_OUT)
    # Embers glowing among the logs.
    for x, y in ((9, 19), (14, 19), (12, 20), (16, 18)):
        put(img, x, y, EMBER if (x + y + frame) % 3 else EMBER_DIM)
    # Sparks rising and drifting.
    for i, (x0, phase) in enumerate(((10, 0), (14, 2), (12, 4))):
        age = (frame + phase) % FRAMES
        y = base_y - h - 1 - age * 2
        if 0 <= y < CELL and age < 5:
            put(img, x0 + (age // 2) * (1 if i % 2 else -1), y, SPARK)


def write_campfire():
    rng = random.Random(7)
    base = campfire_base()
    sheet = Image.new("RGBA", (CELL * FRAMES, CELL), (0, 0, 0, 0))
    for f in range(FRAMES):
        frame = base.copy()
        flame(frame, f, rng)
        # The near stones stay in front of the flame's foot.
        for y in range(19, CELL):
            for x in range(CELL):
                p = base.getpixel((x, y))
                if p[3] == 255 and p[:3] in (STONE_HI, STONE, STONE_DK, OUTLINE):
                    frame.putpixel((x, y), p)
        sheet.paste(frame, (f * CELL, 0))
    sheet.save(os.path.join(OUT, "campfire.png"))


# --- stump -----------------------------------------------------------------------------------------
def write_stump():
    img = Image.new("RGBA", (20, 16), (0, 0, 0, 0))
    ellipse(img, 11.5, 13.5, 9, 2.6, SHADOW)
    # The trunk flares into roots at its foot; bark in vertical strips, lit on the left.
    rows = {y: (5, 14) for y in range(4, 11)}
    rows.update({11: (4, 15), 12: (3, 16), 13: (2, 17)})
    for y, (x0, x1) in rows.items():
        for x in range(x0, x1 + 1):
            if y == 13 and x in (5, 9, 14):
                continue  # gaps between the roots
            color = BARK_HI if x < 7 else (BARK_DK if x > 12 else BARK)
            if y >= 12 and (x < 5 or x > 14):
                color = BARK if x < 5 else BARK_DK
            if (x * 3 + y) % 7 == 0 and 6 < x < 13 and y < 12:
                color = BARK_DK
            put(img, x, y, color)
    # The cut on top: pale wood with growth rings.
    ellipse(img, 10, 4.2, 5.4, 2.6, WOOD)
    ellipse(img, 9.6, 3.6, 3.6, 1.6, WOOD_HI)
    for x, y in ((7, 4), (8, 3), (10, 3), (12, 4), (11, 5), (9, 5)):
        put(img, x, y, RING)
    put(img, 10, 4, RING)
    # Moss at its foot, on the shaded side.
    for x, y, color in ((12, 12, MOSS), (13, 12, MOSS_HI), (13, 11, MOSS), (14, 12, MOSS), (11, 13, MOSS), (12, 13, MOSS_HI)):
        put(img, x, y, color)
    outline(img)
    img.save(os.path.join(OUT, "stump.png"))


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write_campfire()
    write_stump()
    print("camp art written to", os.path.normpath(OUT))
