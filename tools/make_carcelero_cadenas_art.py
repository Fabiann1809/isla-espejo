"""Draws the Carcelero de cadenas' chain throw (temple enemy, island 3) pixel by pixel.

Its body strips come from the bestiary pack (tools/make_temple_enemy_art.py); the chain it throws
to drag Nico was a plain grey line drawn in code. This draws it as pixel art in the pack's iron
grey: one tile of links (a round link seen flat, then one seen edge-on) that the chain's Line2D
repeats along its length, and the barbed hook at its tip with a gleam running over it.

Writes into `assets/sprites/carcelero_cadenas/`:
    carcelero_cadenas_chain.png   8x4: one tile of links, along +x (Line2D, tile mode)
    carcelero_cadenas_hook.png    12x12 cells, 4 frames (loop): the hook pointing +x, its tip on
                                  the cell's center row, where the chain's end is

    python tools/make_carcelero_cadenas_art.py
tools/make_carcelero_cadenas.gd puts both in its ChainJailerData (chain_art, hook_art);
tools/enemy_aseprite.lua keeps an editable `source/carcelero_cadenas_hook.aseprite` (extras="hook:8").
Needs Pillow.
"""
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "carcelero_cadenas")
HOOK_CELL = 12

PALETTE = {
    "O": (26, 20, 24),     # outline
    "I0": (52, 48, 56),    # iron in shadow, the links' holes
    "I1": (96, 92, 100),
    "I2": (150, 146, 148),
    "I3": (206, 202, 192),
    "G": (255, 250, 222),  # the gleam
    "H": (255, 196, 92),   # warm glint on the hook's edge (the temple's firelight)
}

## One tile of chain, left to right: a round link seen flat (its hole dark) and the next one seen
## edge-on, a short bar that runs into the following tile's round link.
CHAIN_TILE = [
    "_332____",
    "30012222",
    "20011111",
    "_110____",
]

## The hook pointing right: an eye for the chain, a shaft, and two claws curling back from the tip;
## symmetric top to bottom so it reads the same when the throw goes left (it is rotated, never
## flipped).
HOOK = [
    "____________",
    "____3332____",
    "___32__332__",
    "__2_____332_",
    "__________32",
    "_22______132",
    "200233333333",
    "_22______132",
    "__________32",
    "__2_____332_",
    "___32__332__",
    "____3332____",
]
## Where the gleam is in each frame (it runs from the eye to the tip and rests a frame).
GLEAM = [[(4, 6)], [(8, 6), (10, 3)], [(11, 6), (6, 1)], []]


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = {}

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[(x, y)] = c

    def outline(self, color="O"):
        """A 1 px outline around everything drawn (4-neighbours)."""
        ring = {}
        for (x, y) in self.px:
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if (nx, ny) not in self.px and 0 <= nx < self.w and 0 <= ny < self.h:
                    ring[(nx, ny)] = color
        self.px.update(ring)

    def image(self):
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for (x, y), c in self.px.items():
            img.putpixel((x, y), PALETTE[c] + (255,))
        return img


def from_rows(rows, w, h):
    c = Canvas(w, h)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row[:w]):
            if ch != "_":
                c.set(x, y, "I" + ch)
    return c


def chain():
    # No outline: the tile repeats edge to edge, and its dark hole and shadow row already part it
    # from the floor.
    return from_rows(CHAIN_TILE, 8, 4)


def hook():
    frames = []
    for gleam in GLEAM:
        c = from_rows(HOOK, HOOK_CELL, HOOK_CELL)
        c.outline()
        # the claws' points catch the torchlight
        c.set(2, 3, "H")
        c.set(2, 9, "H")
        for (x, y) in gleam:
            c.set(x, y, "G")
            if y != 6:
                c.set(x, 12 - y, "G")
        frames.append(c)
    return frames


def save(frames, path):
    w, h = frames[0].w, frames[0].h
    img = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        img.alpha_composite(f.image(), (i * w, 0))
    img.save(path)
    print(os.path.relpath(path), len(frames), "frames")


if __name__ == "__main__":
    save([chain()], os.path.join(OUT, "carcelero_cadenas_chain.png"))
    save(hook(), os.path.join(OUT, "carcelero_cadenas_hook.png"))
