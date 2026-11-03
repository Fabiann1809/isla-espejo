"""Draws the Salamandra de cristal's effects (temple enemy, island 3) pixel by pixel, and cleans its
death strip.

The salamander itself keeps the art scaled from the pack (tools/make_temple_enemy_art.py); what was
drawn in code gets pixel art here, in the pack's colors (crimson, lava orange, crystal yellow): the
hot crystal it lobs (a shard that spins in flight) and the patch it leaves where it lands
(GroundHazard.art: a splash of molten crystal with shards stuck in it, that glows and then crusts
over). The pack's death frames carry a white halo around the body; its stray light pixels are
removed (on the edge) or filled with their neighbours' color (inside).

Writes into `assets/sprites/salamandra_cristal/`:
    salamandra_cristal_crystal.png   12x12 cells: 4 that loop (the shard spinning)
    salamandra_cristal_patch.png     32x32 cells: 3 spawn, 4 burning (loop), 4 cooling
    salamandra_cristal_death.png     cleaned in place (running it again changes nothing)

    python tools/make_salamandra_cristal_art.py
tools/enemy_aseprite.lua keeps an editable `source/salamandra_cristal.aseprite`
(extras="crystal:12,patch:8:spawn=1-3;burn=4-7;cool=8-11").
Needs Pillow.
"""
import math
import os
from collections import Counter

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "salamandra_cristal")
CRYSTAL_CELL = 12
PATCH_CELL = 32

PALETTE = {
    "O": (30, 10, 14),     # outline
    # crimson and lava
    "R0": (70, 18, 20),
    "R1": (130, 30, 16),
    "R2": (196, 62, 10),
    "R3": (240, 110, 20),
    "R4": (250, 165, 30),
    # crystal
    "Y": (252, 210, 60),
    "Y2": (255, 246, 190),
    # cooled crust
    "C0": (46, 20, 36),
    "C1": (74, 32, 52),
    "C2": (104, 46, 66),
}
## The patch cooling: each step dims the lava and the crystals.
COOL_STEPS = [
    {"Y2": "Y", "Y": "R4", "R4": "R3", "R3": "R2"},
    {"Y": "R3", "R4": "R2", "R3": "R2", "R2": "R1", "R1": "C1"},
    {"R3": "R1", "R2": "R1", "R1": "C1", "R0": "C0"},
    {"R1": "C2", "C1": "C0", "R0": "C0", "R2": "C2"},
]


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


# --- the lobbed crystal ---------------------------------------------------------------------------

## Widths of the shard row by row from its tip, as it spins about its long axis: wide with its lit
## face, narrow, edge on, narrow with its dark face.
SPIN = [
    [1, 3, 3, 5, 5, 3, 3, 1],
    [1, 1, 3, 3, 3, 3, 1, 1],
    [1, 1, 1, 1, 1, 1, 1, 1],
    [1, 1, 3, 3, 3, 3, 1, 1],
]


def crystal(frame):
    """The hot shard it lobs, spinning in flight."""
    c = Canvas(CRYSTAL_CELL)
    cx, top = 6, 2
    lit_left = frame != 3
    rows = SPIN[frame]
    for k, w in enumerate(rows):
        y = top + k
        for x in range(cx - w // 2, cx + w // 2 + 1):
            if frame == 2:
                col = "Y2" if k < 4 else "Y"
            elif x == cx:
                col = "Y2" if k < 3 else "Y"          # the ridge between the faces
            elif (x < cx) == lit_left:
                col = "Y" if k < 5 else "R4"
            else:
                col = "R4" if k < 3 else "R3"
            if k == len(rows) - 1:
                col = "R3"
            c.set(x, y, col)
    c.outline()
    return c


# --- the patch it leaves ------------------------------------------------------------------------

## Crystal shards stuck in the patch: base (x, y) relative to the center, height, lean.
SHARDS = [(-6, 1, 4, -1), (-1, -3, 3, 0), (4, 0, 5, 1), (0, 4, 3, 0), (7, -3, 2, 1), (-8, -3, 2, -1)]


def shard(c, x, y, h, lean, glint):
    """A shard sticking up from the patch: 2 px wide, a lit left face, a darker right one and a
    point that leans a little."""
    for k in range(h):
        yy = y - k
        dx = lean if k >= h - 1 and h > 2 else 0
        if k < h - 1:
            c.set(x + dx, yy, "Y2" if glint and k >= h - 3 else "Y")
            c.set(x + dx + 1, yy, "R4" if k else "R3")
        else:
            c.set(x + dx, yy, "Y2" if glint else "Y")


def patch(scale, glow, shards=6, glints=(), cool=0, splash=False):
    c = Canvas(PATCH_CELL)
    cx, cy = 16.0, 17.0
    # about the hazard's radius (12 px), a little flattened like the ground it lies on
    rx, ry = 12.5 * scale, 9.5 * scale
    for y in range(PATCH_CELL):
        for x in range(PATCH_CELL):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            ang = math.atan2(dy, dx)
            # a splash: lobes all around its rim
            lobe = 1.0 + 0.07 * math.sin(5 * ang + 1.0) + 0.04 * math.sin(9 * ang + 0.3)
            q = math.hypot(dx, dy) / lobe
            if q > 1.0:
                continue
            c.set(x, y, "R1" if q > 0.8 else "R2" if q > 0.45 else "R3" if q > 0.2 else "R4")
    for (x, y) in glow:
        if (x, y) in c.px:
            c.set(x, y, "Y")
            if (x + 1, y) in c.px:
                c.set(x + 1, y, "R4")
    c.outline("R0")
    for i, (sx, sy, h, lean) in enumerate(SHARDS[:shards]):
        shard_c = Canvas(PATCH_CELL)
        shard(shard_c, int(cx) + int(sx * scale), int(cy) + int(sy * scale), max(1, int(round(h * scale))),
              lean, i in glints)
        # a dark rim even inside the patch, so the shards stand out of the molten splash
        shard_c.outline("R0")
        c.over(shard_c)
    for step in COOL_STEPS[:cool]:
        c.remap(step)
    if splash:
        for x, y in ((3, 13), (28, 12), (6, 25), (26, 25), (15, 5)):
            c.set(x, y, "R3")
    return c


def patch_strip():
    spots = [[(12, 18), (19, 16)], [(13, 19), (18, 17)], [(14, 18), (11, 16)], [(18, 18), (13, 15)]]
    frames = [
        patch(0.45, [(16, 17)], shards=3, glints=(1,), splash=True),
        patch(0.75, [(14, 18), (18, 16)], shards=5, glints=(2,)),
        patch(1.0, spots[0], glints=(0, 4)),
    ]
    for i in range(4):
        frames.append(patch(1.0, spots[i], glints=((i + 1) % 6, (i + 4) % 6)))
    for k in range(4):
        frames.append(patch(1.0 - 0.03 * k, [], cool=k + 1))
    return frames


# --- cleaning the pack's death frames -----------------------------------------------------------

def is_halo(rgba):
    # none of its other frames has a color this pale: only the halo does
    return rgba[3] > 0 and min(rgba[:3]) > 140


def clean_halo(path):
    """Stray white pixels of the pack's halo: gone on the silhouette's edge, filled inside."""
    img = Image.open(path).convert("RGBA")
    px = img.load()
    w, h = img.size
    cell = h
    changed = 0
    for _ in range(4):
        fixes = {}
        for y in range(h):
            for x in range(w):
                if not is_halo(px[x, y]):
                    continue
                around = []
                edge = False
                for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    # never look across into the next cell
                    if not (0 <= ny < h and 0 <= nx < w) or nx // cell != x // cell or px[nx, ny][3] == 0:
                        edge = True
                    elif not is_halo(px[nx, ny]):
                        around.append(px[nx, ny])
                if edge:
                    fixes[(x, y)] = (0, 0, 0, 0)
                elif around:
                    fixes[(x, y)] = Counter(around).most_common(1)[0][0]
        if not fixes:
            break
        for p, c in fixes.items():
            px[p] = c
        changed += len(fixes)
    img.save(path)
    print(os.path.relpath(path), "cleaned", changed, "pixels")


def strip(frames, path):
    cell = frames[0].size
    img = Image.new("RGBA", (cell * len(frames), cell), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        img.alpha_composite(f.image(), (i * cell, 0))
    img.save(path)
    print(os.path.relpath(path), len(frames), "frames")


if __name__ == "__main__":
    strip([crystal(i) for i in range(4)], os.path.join(OUT, "salamandra_cristal_crystal.png"))
    strip(patch_strip(), os.path.join(OUT, "salamandra_cristal_patch.png"))
    clean_halo(os.path.join(OUT, "salamandra_cristal_death.png"))
