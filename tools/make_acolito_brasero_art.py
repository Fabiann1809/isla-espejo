"""Draws the Acólito del brasero's flame (temple enemy, island 3) pixel by pixel.

Its body strips come from the bestiary pack (tools/make_temple_enemy_art.py); each flame of its fan
was the plants' generic orb tinted orange. This draws its own: a ball of fire in the colors of the
pack's fireball (white-hot core, yellow, orange, a dark red rim) whose tongues lick upward and
flicker. Fire rises whatever way the flame flies, so the art needs no turning.

Writes into `assets/sprites/acolito_brasero/`:
    acolito_brasero_orb.png   16x16 cells, 4 frames (loop): the ball's center at (8, 9)

    python tools/make_acolito_brasero_art.py
scenes/enemies/acolito_brasero_orb.tscn (inherits orb.tscn) plays it, and
tools/enemy_aseprite.lua keeps an editable `source/acolito_brasero_orb.aseprite` (extras="orb:8").
Needs Pillow.
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "acolito_brasero")
CELL = 16
CENTER = (8, 9)

PALETTE = {
    "O": (74, 16, 12),     # outline: dark ember red
    "F0": (176, 44, 22),
    "F1": (228, 92, 28),
    "F2": (250, 150, 40),
    "F3": (255, 210, 84),
    "F4": (255, 248, 200),
}

## Tongues of fire on top of the ball, per frame: (x offset, height, lean of the tip).
TONGUES = [
    [(-2, 3, -1), (0, 5, 0), (2, 3, 1)],
    [(-2, 2, 0), (0, 4, 1), (2, 4, 0)],
    [(-2, 4, -1), (0, 6, -1), (2, 2, 0)],
    [(-2, 3, 0), (0, 4, 0), (2, 3, 1)],
]


class Canvas:
    def __init__(self, size):
        self.size = size
        self.px = {}

    def set(self, x, y, c):
        if 0 <= x < self.size and 0 <= y < self.size:
            self.px[(x, y)] = c

    def outline(self, color="O"):
        """A 1 px outline around everything drawn (4-neighbours: rounder than 8)."""
        ring = {}
        for (x, y) in self.px:
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if (nx, ny) not in self.px and 0 <= nx < self.size and 0 <= ny < self.size:
                    ring[(nx, ny)] = color
        self.px.update(ring)

    def image(self):
        img = Image.new("RGBA", (self.size, self.size), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            img.putpixel((x, y), PALETTE[c] + (255,))
        return img


def flame(i):
    c = Canvas(CELL)
    cx, cy = CENTER
    r = 3.6
    for y in range(cy - 5, cy + 5):
        for x in range(cx - 5, cx + 5):
            # light from the upper left: the core sits a little up and left of the center
            d = math.hypot(x + 0.5 - (cx + 0.2), y + 0.5 - (cy + 0.3)) / r
            core = math.hypot(x + 0.5 - (cx - 0.3), y + 0.5 - (cy - 0.2)) / r
            if d > 1.0:
                continue
            c.set(x, y, "F4" if core < 0.38 else "F3" if core < 0.7 else "F2" if d < 0.88 else "F1")
    top = cy - 3
    for dx, h, lean in TONGUES[i]:
        for k in range(h):
            f = k / h
            x = cx + dx + (lean if f > 0.5 else 0)
            col = "F3" if f < 0.3 else "F2" if f < 0.65 else "F1"
            c.set(x, top - k, col)
            if f < 0.3 and dx == 0:
                c.set(x - 1, top - k, "F2")
    # the bottom of the ball is darker, burning against the air below
    for x in range(cx - 2, cx + 3):
        if (x, cy + 3) in c.px:
            c.set(x, cy + 3, "F0" if x != cx else "F1")
    c.outline()
    # a spark breaking off
    spark = [(cx + 5, cy - 6), (cx - 5, cy - 4), (cx + 4, cy - 8), None][i]
    if spark:
        c.set(*spark, "F2")
    return c


if __name__ == "__main__":
    frames = [flame(i) for i in range(4)]
    img = Image.new("RGBA", (CELL * len(frames), CELL), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        img.alpha_composite(f.image(), (i * CELL, 0))
    path = os.path.join(OUT, "acolito_brasero_orb.png")
    img.save(path)
    print(os.path.relpath(path), len(frames), "frames")
