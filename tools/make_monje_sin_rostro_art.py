"""Draws the Monje sin rostro's effects (temple enemy, island 3) pixel by pixel.

The monk itself keeps the team's art, scaled from the pack by tools/make_temple_enemy_art.py (a
redrawn monk read worse than the pack's). What was drawn in code or borrowed gets its own pixel art
here: its comet-like projectile (it was the plants' orb tinted violet) and the glowing symbols it
leaves on the floor to teleport between.

Writes into `assets/sprites/monje_sin_rostro/`:
    monje_sin_rostro_orb.png           24x24 cells, 4 frames (loop), flying right, its head on the
                                       cell's center (scenes/enemies/monje_sin_rostro_orb.tscn)
    monje_sin_rostro_symbol.png        32x32 cells: 4 resting (a slow pulse), 4 warned (it is
                                       coming back there); the ring's center 5 px under the cell's
                                       center, where the monk's feet stand

    python tools/make_monje_sin_rostro_art.py
tools/enemy_aseprite.lua keeps an editable copy of each (extras="orb:12,symbol:8:rest=1-4;warned=5-8").
Needs Pillow.
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "monje_sin_rostro")
ORB_CELL = 24
SYMBOL_CELL = 32

PALETTE = {
    # purple magic
    "M0": (70, 22, 120),
    "M1": (136, 52, 222),
    "M2": (190, 112, 255),
    "M3": (232, 196, 255),
    "M4": (255, 248, 255),
    # the warned symbol turns pink
    "X1": (214, 70, 196),
    "X2": (255, 140, 232),
}
## The symbol's warning: its violet turns pink.
TO_WARN = {"M0": "X1", "M1": "X1", "M2": "X2", "M3": "X2"}


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


def line(x0, y0, x1, y1):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    return pixel_perfect([(round(x0 + (x1 - x0) * i / n), round(y0 + (y1 - y0) * i / n)) for i in range(n + 1)])


# --- the projectile and the floor symbols -----------------------------------------------------

def orb_frame(i):
    """The comet: a white-hot head on the cell's center and a violet tail streaming behind it."""
    c = Canvas(ORB_CELL)
    hx, hy = 12, 12
    # the tail: five flickering tongues, longest in the middle, thinning to sparks
    lengths = [(10, 7, 8, 4, 5), (11, 8, 6, 5, 3), (10, 6, 7, 3, 4), (9, 7, 8, 4, 5)][i]
    for dy, length in zip((0, -1, 1, -2, 2), lengths):
        for t in range(length):
            x = hx - 2 - t
            y = hy + dy
            f = t / length
            col = "M4" if dy == 0 and t < 3 else "M3" if f < 0.3 and abs(dy) < 2 else \
                "M2" if f < 0.6 else "M1" if f < 0.9 else "M0"
            c.set(x, y, col)
    for (x, y, col) in [[(1, 11, "M1"), (4, 8, "M2"), (6, 16, "M1")], [(2, 15, "M1"), (5, 9, "M2")],
                        [(0, 12, "M1"), (3, 9, "M1"), (5, 15, "M2")], [(1, 14, "M2"), (4, 16, "M1")]][i]:
        c.set(x, y, col)
    # the head, a little bigger than its hitbox, white at the core
    for y in range(hy - 4, hy + 5):
        for x in range(hx - 4, hx + 5):
            q = math.hypot(x - hx, y - hy)
            if q > 3.6:
                continue
            c.set(x, y, "M4" if q < 1.6 else "M3" if q < 2.6 else "M2")
    c.set(hx + 1, hy - 1, "M4")
    c.outline("M0")
    return c


def symbol_frame(level, warned, phase):
    """A ring of light on the floor with a band of runes and a triangle rune: `level` 0..2 its
    glow; warned, it is bigger, turns pink and sheds sparks upward."""
    c = Canvas(SYMBOL_CELL)
    cx, cy = 16.0, 21.0
    rx, ry = (12.0, 8.5) if warned else (10.5, 7.0)
    ring = ["M1", "M2", "M3"][level]
    rim = ["M0", "M1", "M2"][level]
    for y in range(SYMBOL_CELL):
        for x in range(SYMBOL_CELL):
            q = math.hypot((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
            ang = math.atan2((y + 0.5 - cy) / ry, (x + 0.5 - cx) / rx)
            if 0.86 <= q <= 1.0:
                # the far side of the ring is dimmer than the near one
                c.set(x, y, ring if y + 0.5 > cy - ry * 0.35 else rim)
            elif 0.66 <= q <= 0.76 and int((ang + math.pi) / math.tau * 14 + phase * 0.5) % 2 == 0:
                c.set(x, y, rim)
    corners = [(cx + math.sin(a) * rx * 0.5, cy - math.cos(a) * ry * 0.52)
               for a in (0.0, math.tau / 3, 2 * math.tau / 3)]
    for k in range(3):
        (x0, y0), (x1, y1) = corners[k], corners[(k + 1) % 3]
        for (x, y) in line(math.floor(x0), math.floor(y0), math.floor(x1), math.floor(y1)):
            c.set(x, y, ring)
    c.set(int(cx), int(cy), "M4" if level == 2 or warned else ring)
    if warned:
        for (x, y, col) in [[(6, 12, "M3"), (25, 10, "M2"), (16, 6, "M3")],
                            [(6, 9, "M2"), (25, 7, "M3"), (14, 4, "M2"), (20, 11, "M3")],
                            [(7, 6, "M1"), (24, 4, "M2"), (10, 10, "M3"), (21, 8, "M2")],
                            [(9, 7, "M2"), (22, 5, "M1"), (16, 9, "M3")]][phase]:
            c.set(x, y, col)
        c.remap(TO_WARN)
    return c


def orb():
    return [orb_frame(i) for i in range(4)]


def symbol():
    rest = [symbol_frame(level, False, 0) for level in (0, 1, 2, 1)]
    warned = [symbol_frame(level, True, i) for i, level in enumerate((2, 1, 2, 2))]
    return rest + warned


def strip(frames, path):
    cell = frames[0].size
    img = Image.new("RGBA", (cell * len(frames), cell), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        img.alpha_composite(f.image(), (i * cell, 0))
    img.save(path)
    print(os.path.relpath(path), len(frames), "frames")


if __name__ == "__main__":
    for name, make in (("orb", orb), ("symbol", symbol)):
        strip(make(), os.path.join(OUT, "monje_sin_rostro_%s.png" % name))
