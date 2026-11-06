"""Draws the props of the Templo del Eclipse (island 3) pixel by pixel, at game scale.

Every piece is original art drawn here (nothing is copied or resampled from the reference zip, whose
pictures are blurred and at another scale): Nico is 32 px tall, a carved pillar is 16x56, the guardian
statue 32x48, the face gate 80x64. The palette is tools/temple_palette.py only, outlines are 1 px
OUTLINE and the light comes from the upper left. Everything is animated: fire and lava with 6-8 frames,
stone pieces with 4 frames of subtle life (rune glints, moss sway, ember flecks rising, dust).

Writes into assets/sprites/temple_props/:
    <name>.png     a horizontal strip, one cell per frame
    props.json     name -> {cell: [w, h], frames: n, fps: f, foot: [x, y], footprint: [w, h]}
                   (`foot` is the pixel of the cell that stands on the prop's origin; the geyser also
                   lists its `phases` and the lava fall its stackable `loop_rows`)

    python tools/make_temple_props_art.py
    python tools/make_temple_props_art.py --preview tmp_preview/temple_props
        also writes a contact sheet (every prop at 1x and 3x on the temple's stone and lava) and one
        GIF per prop.
Needs Pillow.
"""
import json
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from temple_palette import *  # noqa: E402,F401,F403

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites", "temple_props")

FIRE = (FIRE_D, FIRE_1, FIRE_2, FIRE_HI)
LAVA_RAMP = (LAVA_D, LAVA_1, LAVA_2, LAVA_3, LAVA_4, LAVA_HI, LAVA_CORE)


# --- canvas -----------------------------------------------------------------------------------------
class Canvas:
    """A small RGBA cell with the helpers the props need. Colours are palette tuples."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), CLEAR)
        self.px = self.img.load()

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y]
        return CLEAR

    def rect(self, x, y, w, h, c):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.put(xx, yy, c)

    def hline(self, x0, x1, y, c):
        for x in range(min(x0, x1), max(x0, x1) + 1):
            self.put(x, y, c)

    def vline(self, x, y0, y1, c):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            self.put(x, y, c)

    def ellipse(self, cx, cy, rx, ry, c):
        for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
                if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                    self.put(x, y, c)

    def ascii(self, rows, key, x0=0, y0=0):
        """Paints `rows` (strings) with `key` (char -> colour); ' ' and '.' leave the pixel alone."""
        for dy, row in enumerate(rows):
            for dx, ch in enumerate(row):
                if ch in (" ", "."):
                    continue
                self.put(x0 + dx, y0 + dy, key[ch])

    def outline(self, color=OUTLINE, skip=()):
        """A 1 px outline around every opaque pixel (4-connected), never over a colour in `skip`."""
        solid = {(x, y) for y in range(self.h) for x in range(self.w) if self.px[x, y][3] == 255}
        for x, y in list(solid):
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                p = (x + dx, y + dy)
                if p not in solid and 0 <= p[0] < self.w and 0 <= p[1] < self.h:
                    self.px[p] = color

    def copy(self):
        other = Canvas(self.w, self.h)
        other.img = self.img.copy()
        other.px = other.img.load()
        return other


def shade_x(x, x0, x1, ramp):
    """Colour of a vertical face lit from the left: `ramp` from light (left) to dark (right)."""
    t = (x - x0) / max(1, x1 - x0)
    return ramp[min(len(ramp) - 1, int(t * len(ramp)))]


def stone_block(c, x, y, w, h, ramp=(STONE_4, STONE_3, STONE_3, STONE_2), top=STONE_HI, joint=JOINT):
    """A masonry block: lit top row and left edge, darker toward the right, a joint line under it."""
    for yy in range(y, y + h):
        for xx in range(x, x + w):
            c.put(xx, yy, shade_x(xx, x, x + w - 1, ramp))
    c.hline(x, x + w - 1, y, top)
    c.vline(x, y, y + h - 1, ramp[0] if h > 1 else top)
    c.hline(x, x + w - 1, y + h - 1, joint)
    c.vline(x + w - 1, y + 1, y + h - 2, STONE_1)


def flame(c, cx, base_y, height, half_w, frame, n, colours=FIRE, sway_amp=1):
    """A tongue of fire of four layers whose tip sways and leaps; frame-driven, no outline."""
    leap = [0, 1, -1, 2, 0, 1, -2, 1][frame % 8]
    sway = round(sway_amp * math.sin(math.tau * frame / n))
    h = max(3, height + leap)
    for layer, (color, width, shrink) in enumerate(zip(colours, (half_w, half_w * 0.72, half_w * 0.45, half_w * 0.2), (0, 2, 4, 6))):
        top = base_y - h + shrink
        if top >= base_y:
            continue
        for y in range(top, base_y + 1 - (layer + 1) // 2):
            t = (y - top) / max(1, base_y - top)
            half = width * math.sqrt(max(0.05, t))
            x_c = cx + sway * (1 - t) + 0.5
            for x in range(int(cx - half_w - 3), int(cx + half_w + 4)):
                if abs(x + 0.5 - x_c) <= half:
                    c.put(x, y, color)
    # A tongue that breaks loose now and then, and a spark.
    if frame % 4 == 1:
        c.put(cx + sway * 2, base_y - h - 2, colours[1])
        c.put(cx + sway * 2, base_y - h - 3, colours[0])
    if frame % 3 == 2:
        c.put(cx - sway + 2, base_y - h - 4, colours[3])


def embers(c, spots, frame, n, rise=2, colours=(LAVA_HI, LAVA_4, LAVA_3)):
    """Flecks that rise from `spots` ((x, y, phase)...) and fade out, one pixel each."""
    for x, y, phase in spots:
        age = (frame + phase) % n
        if age >= n - 1:
            continue
        yy = y - age * rise
        xx = x + (age // 2) % 2 * (1 if phase % 2 else -1)
        c.put(xx, yy, colours[min(len(colours) - 1, age * len(colours) // n)])


def smoke(c, x, y, frame, n, phase=0):
    """A puff of smoke that rises, widens and thins."""
    age = (frame + phase) % n
    yy = y - age * 3
    drift = (age + 1) // 2
    if age < n // 2:
        c.hline(x + drift - 1, x + drift + 1, yy, SMOKE_2)
        c.put(x + drift, yy - 1, ASH)
        c.put(x + drift - 1, yy + 1, SMOKE_1)
        c.put(x + drift + 1, yy + 1, SMOKE_1)
        c.put(x + drift + 2, yy, SMOKE_1)
    else:
        c.hline(x + drift - 1, x + drift + 2, yy, SMOKE_1)
        c.put(x + drift, yy - 1, SMOKE_2)
        c.put(x + drift + 3, yy - 1, SMOKE_1)
        c.put(x + drift - 2, yy + 1, SMOKE_D)


def moss(c, spots, frame, n, sway=True):
    """Tufts of moss, their tips swaying one pixel."""
    s = [0, 1, 1, 0, 0, -1, -1, 0][frame % 8] if sway else 0
    for x, y in spots:
        c.put(x, y, MOSS_1)
        c.put(x + 1, y, MOSS_2)
        c.put(x + s, y - 1, MOSS_HI)
        c.put(x + 1 + s, y - 1, MOSS_2)


GLYPHS = [
    ["#.#", "###", ".#.", "#.#"],
    ["###", "#..", "###", "..#"],
    [".#.", "#.#", "###", ".#."],
    ["#.#", ".#.", ".#.", "#.#"],
    ["###", ".#.", ".#.", "###"],
]


def glyph(c, x, y, index, color):
    c.ascii(GLYPHS[index % len(GLYPHS)], {"#": color}, x, y)


# --- props ------------------------------------------------------------------------------------------
def pillar_carved(frame, n):
    """A tall carved pillar: capital, shaft with bands of glyphs, a stepped plinth; the glyphs glint in turn."""
    c = Canvas(20, 60)
    stone_block(c, 1, 2, 18, 3, top=STONE_HI)  # capital, two steps
    stone_block(c, 2, 5, 16, 3, top=STONE_4)
    for y in range(8, 50):  # fluted shaft
        for x in range(3, 17):
            col = shade_x(x, 3, 16, (STONE_4, STONE_3, STONE_3, STONE_2, STONE_1))
            if x in (6, 10, 14):
                col = STONE_1 if x > 8 else STONE_2
            elif x in (7, 11, 15):
                col = STONE_4 if x < 8 else STONE_3
            c.put(x, y, col)
    c.vline(3, 8, 49, STONE_HI)
    # Two carved panels, recessed, each with a glyph; a bronze ring between them.
    for i, y in enumerate((12, 31)):
        c.rect(4, y, 12, 10, STONE_2)
        c.rect(5, y + 1, 10, 8, STONE_1)
        c.hline(4, 15, y, JOINT)
        c.hline(4, 15, y + 9, JOINT)
        c.vline(4, y, y + 9, JOINT)
        c.vline(15, y, y + 9, STONE_3)
        lit = i == (frame // 2) % 2
        color = (RUNE_GLOW if frame % 2 == 0 else GOLD_HI) if lit else BRONZE_D
        glyph(c, 8, y + 3, i * 2, color)
        c.put(6, y + 2, BRONZE_1 if not lit else GOLD_HI)
        c.put(13, y + 7, BRONZE_D)
    c.hline(4, 15, 25, BRONZE_2)
    c.hline(4, 15, 26, BRONZE_D)
    c.put(5, 25, GOLD_HI)
    stone_block(c, 2, 50, 16, 3, top=STONE_4)  # plinth, two steps
    stone_block(c, 1, 53, 18, 5, top=STONE_4)
    # A crack and a bit of moss at the foot.
    c.vline(13, 44, 48, JOINT)
    c.put(14, 47, JOINT)
    c.outline()
    moss(c, ((2, 52), (15, 56)), frame, n)
    embers(c, ((17, 50, 2),), frame, n, rise=3)
    return c


def pillar_block(frame, n):
    """A pillar of four stacked blocks, each a little out of line; moss sways on it and a fleck rises."""
    c = Canvas(20, 52)
    offsets = ((3, 14), (2, 15), (3, 14), (2, 16))
    y = 2
    for i, (x, w) in enumerate(offsets):
        h = 11 if i < 3 else 12
        stone_block(c, x, y, w, h)
        # A few chips and a joint across the face.
        c.put(x + w - 3, y + 3, STONE_1)
        c.put(x + 2, y + h - 3, STONE_2)
        if i == 1:
            c.vline(x + 7, y + 1, y + h - 2, JOINT)
        y += h
    stone_block(c, 1, 46, 18, 4, top=STONE_4)
    c.outline()
    moss(c, ((4, 14), (14, 29), (3, 43)), frame, n)
    embers(c, ((16, 44, 0),), frame, n, rise=3)
    return c


def column_low(frame, n):
    """A squat column with a wide capital, the kind that lines a bridge; a glint runs along its band."""
    c = Canvas(20, 32)
    stone_block(c, 1, 2, 18, 4, top=STONE_HI)
    for y in range(6, 26):
        for x in range(4, 16):
            c.put(x, y, shade_x(x, 4, 15, (STONE_4, STONE_3, STONE_3, STONE_2, STONE_1)))
    c.vline(4, 6, 25, STONE_HI)
    c.hline(5, 14, 12, JOINT)
    c.hline(5, 14, 20, JOINT)
    for x in (6, 9, 12):
        c.put(x, 15, BRONZE_1)
        c.put(x + 1, 16, BRONZE_D)
    stone_block(c, 2, 26, 16, 4, top=STONE_4)
    c.outline()
    glint = (5 + frame * 3) % 10 + 5
    c.put(glint, 15, GOLD_HI)
    moss(c, ((15, 25),), frame, n)
    return c


def column_broken(frame, n):
    """The stump of a column, its top broken in a jagged line, rubble at its foot; dust drifts off it."""
    c = Canvas(20, 28)
    tops = (9, 7, 6, 8, 10, 12, 11, 9, 8, 10, 12, 13)
    for i, x in enumerate(range(4, 16)):
        for y in range(tops[i], 22):
            c.put(x, y, shade_x(x, 4, 15, (STONE_4, STONE_3, STONE_3, STONE_2, STONE_1)))
        c.put(x, tops[i], STONE_HI if i < 6 else STONE_4)
    c.vline(4, 9, 21, STONE_HI)
    c.hline(5, 14, 16, JOINT)
    c.put(8, 12, JOINT)
    c.put(9, 13, JOINT)
    stone_block(c, 2, 22, 16, 4, top=STONE_4)
    # Fallen chips.
    for x, y, col in ((1, 24, STONE_3), (2, 25, STONE_2), (17, 23, STONE_3), (18, 24, STONE_2), (16, 25, STONE_1)):
        c.put(x, y, col)
    c.outline()
    dust = (frame * 2) % n
    c.put(6 + dust, 5 - dust // 2, ASH)
    c.put(13 - dust, 4 + dust % 2, SMOKE_2)
    moss(c, ((3, 21),), frame, n)
    return c


GUARDIAN = """
.............OOOOOO.............
.............O4444O.............
........OOOOOO4433OOOOOO........
........O44444444444444O........
.........O443333333333O.........
.........O433333333333O.........
.........O43OOOO3OOOO3O.........
.........O43OEEO3OEEO3O.........
.........O43OEEO3OEEO3O.........
.........O43OOOO3OOOO3O.........
.........O433333333333O.........
.........O43OOOOOOOO33O.........
.........O43O222222O33O.........
.........O43OOOOOOOO33O.........
.........O433333333333O.........
.........O433333333333O.........
.OOOOOOOOO444444444444OOOOOOOOO.
.O4444444433333333333344444444O.
.O4433333333333333333333333344O.
.O43333O4333333333333332O33332O.
.O43333O4333333333333332O33332O.
.O43333O433333G33G333332O33332O.
.O43333O4333333GG3333332O33332O.
.O43333O4333333GG3333332O33332O.
.O43333O433333G33G333332O33332O.
.O43333O4333333333333332O33332O.
.O43333O4333333333333332O33332O.
.O43333OBBBBBBBGGBBBBBBBO33332O.
.O43333OBBBBBBBGGBBBBBBBO33332O.
.O43333O4333333333333332O33332O.
.O44333O4333333333333332O33332O.
.O43333O4333333333333332O33332O.
.OOOOOOO4333333333333332OOOOOOO.
.......O4333333OO3333332O.......
.......O4333333OO3333332O.......
.......O4333333OO3333332O.......
.......O4333333OO3333332O.......
.......O4333333OO3333332O.......
.......O4333333OO3333332O.......
.......OOOOOOOOOOOOOOOOOOO......
"""


def statue_guardian(frame, n):
    """A guardian of stone on a plinth: a squat, square figure in a brimmed helm, arms at its sides, a bronze
    belt and a gold glyph on its chest; its eyes glow with a slow pulse and moss sways on its shoulder."""
    c = Canvas(36, 52)
    pulse = (LAVA_4, LAVA_HI, LAVA_HI, LAVA_4)[frame % 4]
    rows = [r for r in GUARDIAN.strip("\n").split("\n")]
    key = {"O": OUTLINE, "4": STONE_4, "3": STONE_3, "2": STONE_2, "E": pulse, "B": BRONZE_2, "G": GOLD_HI}
    c.ascii(rows, key, 2, 2)
    # Shading: the right third of the body in shadow, a crack across the chest, chips on the helm.
    for y in range(2, 42):
        for x in range(2, 34):
            p = c.get(x, y)
            if p == STONE_4 and x > 26:
                c.put(x, y, STONE_3)
            elif p == STONE_3 and x > 27:
                c.put(x, y, STONE_2)
    for x, y in ((19, 31), (20, 32), (21, 32), (22, 33), (14, 6), (27, 20)):
        c.put(x, y, JOINT)
    c.hline(11, 22, 17, STONE_HI)
    c.hline(10, 25, 5, STONE_HI)
    # The plinth under its feet.
    stone_block(c, 3, 42, 30, 4, top=STONE_4)
    stone_block(c, 1, 46, 34, 4, top=STONE_4)
    c.outline()
    # The glow spills onto the brow in the brightest frames; the chest glyph glints once a cycle.
    if frame % 4 in (1, 2):
        c.hline(13, 16, 8, LAVA_2)
        c.hline(19, 22, 8, LAVA_2)
    if frame % 4 == 3:
        c.put(17, 24, RUNE_GLOW)
        c.put(18, 24, RUNE_GLOW)
    moss(c, ((5, 19), (28, 45)), frame, n)
    embers(c, ((33, 44, 1),), frame, n, rise=3)
    return c


def brazier(frame, n):
    """A bronze bowl on three legs, embers inside, a flame leaping from it."""
    c = Canvas(20, 28)
    # Legs and the bowl.
    for x0, x1 in ((5, 4), (14, 15)):
        c.vline(x0, 18, 24, BRONZE_1)
        c.put(x1, 24, BRONZE_D)
    c.vline(10, 19, 25, BRONZE_D)
    c.ellipse(10, 16.5, 6.5, 2.6, BRONZE_1)
    c.ellipse(10, 15.5, 6.0, 1.8, BRONZE_2)
    c.ellipse(10, 14.8, 4.5, 1.2, GOLD_HI)
    c.rect(4, 17, 12, 2, BRONZE_1)
    c.hline(5, 14, 19, BRONZE_D)
    c.hline(6, 13, 20, BRONZE_D)
    c.ellipse(10, 15.0, 3.6, 1.0, LAVA_1)
    c.outline()
    flame(c, 10, 15, 9, 3.4, frame, n)
    embers(c, ((7, 12, 0), (12, 11, 3), (10, 10, 6)), frame, n)
    return c


def brazier_pedestal(frame, n):
    """A stone pedestal 16x32 with a bronze bowl on top, its flame lighting the way."""
    c = Canvas(20, 44)
    for y in range(14, 38):
        for x in range(4, 16):
            c.put(x, y, shade_x(x, 4, 15, (STONE_4, STONE_3, STONE_3, STONE_2, STONE_1)))
    c.vline(4, 14, 37, STONE_HI)
    stone_block(c, 3, 12, 14, 3, top=STONE_HI)
    stone_block(c, 2, 38, 16, 4, top=STONE_4)
    c.hline(5, 14, 20, JOINT)
    c.hline(5, 14, 30, JOINT)
    glyph(c, 8, 23, 1, (JOINT, BRONZE_D, GOLD_HI, BRONZE_D, JOINT, JOINT, BRONZE_D, JOINT)[frame % 8])
    c.put(6, 25, BRONZE_1)
    c.put(13, 25, BRONZE_D)
    # The bowl.
    c.ellipse(10, 10.5, 6.5, 2.4, BRONZE_1)
    c.ellipse(10, 9.6, 5.8, 1.6, BRONZE_2)
    c.ellipse(10, 9.0, 4.2, 1.0, GOLD_HI)
    c.rect(4, 11, 12, 2, BRONZE_1)
    c.hline(5, 14, 12, BRONZE_D)
    c.ellipse(10, 9.2, 3.4, 0.9, LAVA_1)
    c.outline()
    flame(c, 10, 9, 9, 3.4, frame, n)
    embers(c, ((7, 6, 0), (12, 5, 3), (9, 4, 5)), frame, n)
    moss(c, ((15, 37),), frame, n)
    return c


def torch_wall(frame, n):
    """A torch in an iron bracket on a wall: a bronze cup on a short shaft, flame above."""
    c = Canvas(14, 28)
    # Bracket and shaft.
    c.rect(5, 16, 4, 8, BRONZE_D)
    c.vline(5, 16, 23, BRONZE_1)
    c.hline(3, 10, 23, BRONZE_1)
    c.hline(3, 10, 24, BRONZE_D)
    c.put(3, 22, BRONZE_1)
    c.put(10, 22, BRONZE_D)
    # Cup.
    c.rect(3, 12, 8, 4, BRONZE_1)
    c.hline(3, 10, 12, BRONZE_2)
    c.hline(4, 9, 11, GOLD_HI)
    c.vline(10, 12, 15, BRONZE_D)
    c.hline(4, 9, 15, BRONZE_D)
    c.outline()
    flame(c, 6, 11, 8, 3.0, frame, n)
    embers(c, ((4, 8, 0), (9, 7, 3)), frame, n)
    return c


def urn(frame, n):
    """A stone urn with a glyph and a bronze rim, ash resting in it; the glyph glints and a fleck of ash drifts."""
    c = Canvas(18, 22)
    c.ellipse(9, 10.5, 6.8, 7.2, STONE_3)
    for y in range(4, 18):
        for x in range(2, 16):
            if c.get(x, y) == STONE_3:
                c.put(x, y, shade_x(x, 2, 15, (STONE_4, STONE_4, STONE_3, STONE_3, STONE_2, STONE_1)))
    c.rect(5, 2, 8, 2, BRONZE_1)
    c.hline(5, 12, 2, BRONZE_2)
    c.hline(6, 11, 1, ASH)
    c.rect(4, 17, 10, 2, STONE_2)
    c.hline(4, 13, 18, STONE_1)
    c.hline(4, 13, 10, JOINT)
    glyph(c, 8, 11, 3, (JOINT, GOLD_HI, BRONZE_D, JOINT)[frame % 4])
    c.outline()
    ash_t = frame % n
    c.put(7 + ash_t, 0 - ash_t // 2 + 1, ASH if ash_t < 3 else SMOKE_2)
    return c


def vase(frame, n):
    """A clay vase with a red band, narrow neck and a flared lip; a glint travels round its belly."""
    c = Canvas(14, 18)
    c.ellipse(7, 10.5, 5.5, 5.5, STONE_3)
    for y in range(4, 17):
        for x in range(1, 13):
            if c.get(x, y) == STONE_3:
                c.put(x, y, shade_x(x, 1, 12, (STONE_4, STONE_4, STONE_3, STONE_2, STONE_1)))
    c.rect(4, 2, 6, 3, STONE_3)
    c.hline(3, 10, 1, STONE_4)
    c.hline(4, 9, 2, STONE_2)
    c.hline(2, 11, 9, BANNER_1)
    c.hline(2, 11, 10, BANNER_2)
    c.hline(3, 10, 11, BANNER_D)
    c.hline(4, 9, 15, STONE_1)
    c.outline()
    glint = (frame * 3) % 9 + 2
    c.put(glint, 9, GOLD_HI)
    c.put(3, 6, STONE_HI)
    return c


def barrel(frame, n):
    """A wooden barrel with two bronze hoops, an ember landing on its lid now and then."""
    c = Canvas(18, 22)
    for y in range(3, 19):
        bulge = 1 if 6 <= y <= 15 else 0
        for x in range(3 - bulge, 15 + bulge):
            stave = (x // 3) % 2
            col = (BRONZE_1, BRONZE_D)[stave] if x < 9 else (BRONZE_D, STONE_D)[stave]
            c.put(x, y, col)
        c.put(3 - bulge, y, BRONZE_2)
    c.ellipse(9, 3.0, 6.0, 1.8, BRONZE_2)
    c.ellipse(9, 2.6, 4.5, 1.1, BRONZE_1)
    for y in (6, 15):
        c.hline(2, 15, y, BRONZE_2)
        c.hline(2, 15, y + 1, BRONZE_D)
    c.outline()
    glint = (frame * 4) % 14 + 2
    c.put(glint, 6, GOLD_HI)
    age = frame % n
    c.put(5 + age, 1 - age, (LAVA_HI, LAVA_4, LAVA_3, LAVA_1)[min(3, age)])
    return c


def rubble(frame, n):
    """A low heap of broken masonry on the floor, ember flecks lifting from it."""
    c = Canvas(28, 14)
    stones = ((2, 8, 6, 4, STONE_3), (7, 5, 7, 5, STONE_4), (13, 7, 5, 4, STONE_3), (17, 4, 6, 5, STONE_4),
              (22, 8, 5, 4, STONE_3), (10, 9, 4, 3, STONE_2), (19, 9, 5, 3, STONE_2), (4, 11, 20, 2, STONE_2))
    for x, y, w, h, col in stones:
        c.rect(x, y, w, h, col)
        c.hline(x, x + w - 1, y, STONE_HI if col == STONE_4 else STONE_4)
        c.vline(x + w - 1, y + 1, y + h - 1, STONE_1)
    c.put(9, 6, JOINT)
    c.put(19, 5, JOINT)
    c.hline(4, 23, 12, STONE_1)
    c.outline()
    embers(c, ((8, 4, 0), (20, 3, 2), (14, 6, 3)), frame, n, rise=1)
    moss(c, ((24, 11),), frame, n, sway=False)
    return c


def rock_smoking(frame, n):
    """A boulder of black basalt cracked with lava that pulses, smoke rising from its crown."""
    c = Canvas(28, 32)
    c.ellipse(14, 19, 11.5, 8.0, SMOKE_D)
    c.ellipse(12, 17, 9.0, 6.0, SMOKE_1)
    c.ellipse(10, 15, 5.0, 3.2, SMOKE_2)
    c.ellipse(14, 23.5, 12, 3.5, CRUST_D)
    c.ellipse(13, 22.5, 10, 2.5, CRUST_1)
    # Cracks that glow with the pulse.
    pulse = (LAVA_2, LAVA_3, LAVA_4, LAVA_3, LAVA_2, LAVA_1)[frame % 6]
    cracks = ((6, 20), (7, 19), (8, 19), (9, 18), (16, 24), (17, 23), (18, 22), (19, 22), (20, 21),
              (12, 12), (13, 13), (13, 14), (22, 17), (23, 18), (23, 19))
    for x, y in cracks:
        c.put(x, y, pulse)
    c.put(8, 18, LAVA_HI if frame % 6 == 2 else pulse)
    c.put(18, 21, LAVA_HI if frame % 6 == 3 else pulse)
    c.outline()
    smoke(c, 13, 9, frame, n, 0)
    smoke(c, 17, 11, frame, n, 3)
    embers(c, ((9, 17, 1), (20, 20, 4)), frame, n)
    return c


def plant(frame, n):
    """A tuft of spiky leaves with a red bud, swaying."""
    c = Canvas(18, 18)
    s = [0, 1, 1, 0][frame % 4]
    leaves = ((9, 15, 2, 4, -1), (9, 15, 9, 6, 0), (9, 15, 15, 4, 1), (9, 15, 5, 8, -1), (9, 15, 13, 8, 1), (9, 15, 9, 1, 0))
    for x0, y0, x1, y1, lean in leaves:
        x1 += s * (1 if lean >= 0 else -1) if y1 < 8 else 0
        steps = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(steps + 1):
            t = i / steps
            x = round(x0 + (x1 - x0) * t)
            y = round(y0 + (y1 - y0) * t)
            c.put(x, y, MOSS_2 if t < 0.6 else MOSS_HI)
            c.put(x + (1 if lean >= 0 else -1), y, MOSS_1)
    c.rect(7, 14, 4, 2, MOSS_D)
    c.put(9 + s, 3, BANNER_2)
    c.put(10 + s, 3, BANNER_1)
    c.put(9 + s, 2, LAVA_4 if frame % 2 else BANNER_2)
    c.outline()
    return c


def vines(frame, n):
    """Vines hanging from a ledge above, their tips swaying."""
    c = Canvas(16, 28)
    s = [0, 1, 1, 0][frame % 4]
    strands = ((2, 22, 0), (5, 26, 1), (8, 18, 0), (11, 25, 1), (14, 21, 0))
    c.hline(0, 15, 0, MOSS_D)
    c.hline(0, 15, 1, MOSS_1)
    for x, length, phase in strands:
        for y in range(1, length):
            sway = s if y > length - 8 and (phase + frame) % 2 == 0 else 0
            c.put(x + sway, y, MOSS_1 if y % 3 else MOSS_2)
            if y % 4 == 2:
                c.put(x + sway - 1, y, MOSS_2)
                c.put(x + sway + 1, y + 1, MOSS_HI)
        c.put(x + s, length, MOSS_HI)
    c.outline()
    return c


def banner(frame, n):
    """A red banner hanging from a bronze crossbar on a pole, a gold glyph on it; it sways and ripples."""
    c = Canvas(20, 44)
    c.vline(2, 2, 41, BRONZE_1)
    c.vline(3, 3, 41, BRONZE_D)
    c.rect(1, 40, 4, 2, BRONZE_D)
    c.hline(2, 17, 4, BRONZE_2)
    c.hline(2, 17, 5, BRONZE_D)
    c.put(17, 3, GOLD_HI)
    c.put(2, 1, GOLD_HI)
    sway = round(math.sin(math.tau * frame / n))
    for y in range(6, 34):
        t = (y - 6) / 28
        shift = round(sway * t * 1.5) + (1 if (y // 6 + frame // 2) % 2 and t > 0.3 else 0)
        x0 = 6 + shift
        width = 11 if y < 30 else 11 - (y - 29) * 2
        if width <= 0:
            continue
        for x in range(x0, x0 + width):
            col = BANNER_1 if x - x0 > 1 else BANNER_2
            if x - x0 >= width - 2:
                col = BANNER_D
            c.put(x, y, col)
        if y in (8, 31):
            c.hline(x0, x0 + width - 1, y, GOLD_HI)
    gx = 9 + round(sway * 0.6) + 1
    glyph(c, gx, 16, 4, GOLD_HI)
    c.put(gx + 1, 21, GOLD_HI)
    c.outline()
    return c


def lava_fall(frame, n):
    """A fall of lava: a crust lip, a stackable middle (rows 8..31 loop in y) and a splash pool at its foot."""
    c = Canvas(16, 48)
    # Lip of crust at the top.
    c.rect(0, 0, 16, 8, CRUST_1)
    c.hline(0, 15, 0, CRUST_D)
    c.hline(1, 14, 7, LAVA_D)
    for x in (3, 9, 13):
        c.put(x, 5, LAVA_1)
    # The falling sheet, the middle band tiles with itself.
    flow = frame * 3
    for y in range(6, 36):
        for x in range(2, 14):
            edge = x in (2, 13)
            v = (y + flow + (x * 7) % 5 + (x * x) % 3) % 12
            if edge:
                col = LAVA_D if v < 6 else LAVA_1
            elif x in (3, 12):
                col = LAVA_1 if v < 7 else LAVA_2
            elif 6 <= x <= 9:
                col = LAVA_HI if v in (0, 1) else (LAVA_4 if v < 7 else LAVA_3)
                if x in (7, 8) and v in (0, 1, 2):
                    col = LAVA_CORE
            else:
                col = LAVA_3 if v < 5 else (LAVA_2 if v < 9 else LAVA_4)
            c.put(x, y, col)
    # The pool: a splash foot, droplets jumping.
    c.ellipse(8, 42.5, 8, 4.2, CRUST_1)
    c.ellipse(8, 42, 7, 3.4, LAVA_1)
    c.ellipse(8, 41.5, 5.5, 2.4, LAVA_3)
    c.ellipse(8, 40.5, 3.5, 1.6, LAVA_4)
    ring = (frame * 2) % 8
    c.hline(5 - ring // 3, 10 + ring // 3, 41 + ring // 4, LAVA_HI)
    for i, (x, phase) in enumerate(((2, 0), (13, 3), (5, 5), (11, 7))):
        age = (frame + phase) % n
        if age < 4:
            c.put(x + (age if i % 2 else -age) // 2, 38 - age * 2, LAVA_HI)
            c.put(x + (age if i % 2 else -age) // 2, 39 - age * 2, LAVA_4)
    c.hline(1, 14, 46, CRUST_D)
    c.hline(0, 15, 47, CRUST_D)
    return c


GEYSER_PHASES = {"idle": (0, 4), "rumble": (4, 8), "erupt": (8, 16), "settle": (16, 20)}


def geyser(frame, n):
    """A vent in the crust that idles with a pulse, rumbles, erupts a column of lava and settles."""
    c = Canvas(32, 48)
    phase = next(name for name, (a, b) in GEYSER_PHASES.items() if a <= frame < b)
    local = frame - GEYSER_PHASES[phase][0]
    # The mound of crust with its vent.
    c.ellipse(16, 42, 14, 4.5, CRUST_D)
    c.ellipse(16, 41, 12.5, 3.5, CRUST_1)
    c.ellipse(16, 40, 9.0, 2.6, LAVA_D)
    c.ellipse(16, 39.5, 5.5, 1.8, LAVA_1)
    shake = (0, 1, -1, 1)[local] if phase == "rumble" else 0
    pulse = (LAVA_1, LAVA_2, LAVA_3, LAVA_2)[local] if phase == "idle" else LAVA_3
    cracks = ((5, 41), (6, 40), (8, 40), (24, 40), (26, 41), (27, 42), (12, 43), (20, 44), (15, 44))
    for x, y in cracks:
        c.put(x + shake, y, pulse if phase != "rumble" else (LAVA_3, LAVA_4)[local % 2])
    c.outline()
    c.ellipse(16, 39.5, 4.0, 1.3, LAVA_2 if phase == "idle" else LAVA_4)
    if phase == "idle":
        if local in (1, 2):
            c.put(15, 38, LAVA_4)
        embers(c, ((14, 37, 0), (19, 37, 2)), local, 4, rise=2)
    elif phase == "rumble":
        c.ellipse(16 + shake, 39, 3.0, 1.0, LAVA_HI)
        for i, x in enumerate((11, 14, 18, 21)):
            if (local + i) % 2:
                c.put(x, 37 - (local + i) % 3, LAVA_4)
                c.put(x, 38 - (local + i) % 3, LAVA_3)
        c.put(4 + shake, 44, STONE_2)
        c.put(28 - shake, 43, STONE_2)
        embers(c, ((12, 36, 0), (20, 36, 1), (16, 35, 2)), local, 4, rise=3)
    elif phase == "erupt":
        height = (14, 26, 34, 38, 38, 36, 30, 22)[local]
        half = (3, 4, 5, 5, 5, 4, 4, 3)[local]
        top = 39 - height
        for y in range(top, 40):
            t = (y - top) / height
            w = half if t > 0.15 else max(1, round(half * t / 0.15))
            for x in range(16 - w, 16 + w + 1):
                d = abs(x - 16)
                v = (y + local * 4 + x) % 7
                if d >= w:
                    col = LAVA_2
                elif d >= w - 1:
                    col = LAVA_3 if v < 4 else LAVA_4
                elif d <= 1:
                    col = LAVA_CORE if v < 3 else LAVA_HI
                else:
                    col = LAVA_4 if v < 5 else LAVA_HI
                c.put(x, y, col)
        # Blobs and drops thrown out of the column's crown.
        for i, (dx, phase_i) in enumerate(((-7, 0), (6, 2), (-4, 4), (9, 1), (-9, 3), (3, 5))):
            age = (local + phase_i) % 8
            x = 16 + dx + (age if dx > 0 else -age) // 2
            y = top - 4 - age * 2 + age * age // 2
            if y < 38:
                c.put(x, y, LAVA_HI)
                c.put(x, y + 1, LAVA_3)
        c.ellipse(16, 39.5, 6.0, 1.8, LAVA_4)
        c.ellipse(16, 39.5, 3.5, 1.0, LAVA_HI)
    else:  # settle
        drop = (30, 18, 8, 2)[local]
        if drop > 2:
            for y in range(39 - drop, 40):
                for x in range(14, 19):
                    v = (y + local * 5 + x) % 7
                    col = LAVA_3 if v < 4 else LAVA_2
                    if x in (15, 16, 17):
                        col = LAVA_HI if v < 2 else (LAVA_4 if v < 5 else LAVA_3)
                    c.put(x, y, col)
            c.put(16, 39 - drop, LAVA_HI)
        splat = (LAVA_4, LAVA_3, LAVA_2, LAVA_1)[local]
        for x, y in ((8, 41), (24, 42), (12, 44), (20, 43), (5, 43), (27, 41)):
            c.put(x, y, splat)
        for i in range(3):
            y = 30 + local * 3 + i * 4
            if y < 38:
                c.put(10 + i * 6, y, LAVA_HI)
        smoke(c, 14, 34, local, 4, 0)
        smoke(c, 19, 35, local, 4, 2)
    return c


FACE = """
.........OOOOOOOOOOOOOOOOOOOOOOOOOOOO.........
........O444444444444444444444444444O........
.......O44333333333333333333333333344O.......
......O443OOO3333OOO3333OOO3333OOO344O......
......O443O.O3333O.O3333O.O3333O.O344O......
......O443OOO3333OOO3333OOO3333OOO344O......
......O443333333333333333333333333344O......
......O4433OOOOOOOO33333333OOOOOOOO344O......
......O443O22222222O333333O22222222O44O......
......O443O2EEEEEE2O333333O2EEEEEE2O44O......
......O443O2EEEEEE2O333333O2EEEEEE2O44O......
......O443O22222222O333333O22222222O44O......
......O4433OOOOOOOO333OO333OOOOOOOO344O......
......O44333333333333O33O3333333333344O......
......O443333333333333OO33333333333344O......
......O44333333333333333333333333333344O......
......O4433OOOOOOOOOOOOOOOOOOOOOOOO3344O......
......O443OMMMMMMMMMMMMMMMMMMMMMMMMO344O......
......O443OM4OM4OMMMMMMMMMMMOM4OM4OMO344O......
......O443OMMOMMOMMMMMMMMMMMOMMOMMOMO344O......
......O443OMMMMMMMMMMMMMMMMMMMMMMMMO344O......
......O443OMMMMMMMMMMMMMMMMMMMMMMMMO344O......
......O443OMMMMMMMMMMMMMMMMMMMMMMMMO344O......
......O443OMMMMMMMMMMMMMMMMMMMMMMMMO344O......
......O4433OOOOOOOOOOOOOOOOOOOOOOOO3344O......
"""


def face_gate(frame, n):
    """The temple's face gate, 80x64: a carved stone face between two pillars, its eyes burning, a tongue
    of lava pouring from its mouth into a pool at its foot."""
    c = Canvas(80, 64)
    # The two flanking pillars and the lintel.
    for x0 in (2, 64):
        for y in range(10, 54):
            for x in range(x0, x0 + 14):
                c.put(x, y, shade_x(x, x0, x0 + 13, (STONE_4, STONE_3, STONE_3, STONE_2, STONE_1)))
        c.vline(x0, 10, 53, STONE_HI)
        for yb in (18, 30, 42):
            c.hline(x0 + 1, x0 + 12, yb, JOINT)
            glyph(c, x0 + 5, yb + 3, (yb // 12 + x0) % 5, (JOINT, BRONZE_D, GOLD_HI, BRONZE_D)[(frame + yb // 12 + x0 // 60) % 4])
        stone_block(c, x0 - 1, 6, 16, 4, top=STONE_HI)
        stone_block(c, x0 - 1, 54, 16, 6, top=STONE_4)
    stone_block(c, 14, 2, 52, 6, top=STONE_HI)
    c.hline(16, 63, 5, JOINT)
    for x in range(18, 62, 8):
        c.put(x, 4, BRONZE_1)
        c.put(x + 1, 4, BRONZE_D)
    # The wall behind the face and the face itself.
    for y in range(8, 54):
        row = (y - 8) // 6
        for x in range(16, 64):
            c.put(x, y, (STONE_2, STONE_1)[((x + row * 4) // 8 + row) % 2])
            if (x + row * 4) % 8 == 0:
                c.put(x, y, JOINT)
    for y in range(8, 54, 6):
        c.hline(16, 63, y, JOINT)
    eyes = (LAVA_3, LAVA_4, LAVA_HI, LAVA_4, LAVA_3, LAVA_2, LAVA_3, LAVA_4)[frame % 8]
    rows = FACE.strip("\n").split("\n")
    key = {"O": OUTLINE, "4": STONE_4, "3": STONE_3, "2": STONE_2, "E": eyes, "M": CRUST_D}
    c.ascii(rows, key, 17, 8)
    # Teeth in the mouth's corners read as fangs; the mouth is dark crust where the lava comes out.
    for y in range(26, 32):
        for x in range(28, 52):
            if c.get(x, y) == CRUST_D:
                c.put(x, y, CRUST_D if (x + y) % 5 else CRUST_1)
    # The floor step and the pool under the mouth.
    stone_block(c, 15, 54, 50, 4, top=STONE_4)
    c.ellipse(40, 59.5, 13, 3.4, CRUST_1)
    c.ellipse(40, 59, 11, 2.6, LAVA_1)
    c.ellipse(40, 58.5, 8, 1.8, LAVA_3)
    c.outline()
    # The tongue of lava flowing from the mouth, with a bright core and a rolling surface.
    flow = frame * 2
    for y in range(29, 58):
        half = 5 if y < 34 else (6 if y < 50 else 7)
        for x in range(40 - half, 40 + half + 1):
            d = abs(x - 40)
            v = (y + flow + (x * 3) % 4) % 9
            if d == half:
                col = LAVA_1 if v < 5 else LAVA_2
            elif d >= half - 1:
                col = LAVA_2 if v < 5 else LAVA_3
            elif d <= 1:
                col = LAVA_CORE if v < 3 else LAVA_HI
            else:
                col = LAVA_4 if v < 5 else LAVA_3
            c.put(x, y, col)
    c.ellipse(40, 58.5, 5.5, 1.2, LAVA_HI)
    # Fire licking out of the mouth's corners and embers over the pool.
    flame(c, 31, 29, 5, 2.0, frame, n)
    flame(c, 49, 29, 5, 2.0, (frame + 3) % n, n)
    embers(c, ((30, 56, 0), (50, 57, 3), (36, 55, 5), (46, 56, 6)), frame, n)
    return c


def altar_rune(frame, n):
    """A low altar slab on two blocks, a rune cut into its top that pulses with lava light."""
    c = Canvas(36, 28)
    stone_block(c, 4, 12, 10, 10, top=STONE_4)
    stone_block(c, 22, 12, 10, 10, top=STONE_4)
    stone_block(c, 2, 6, 32, 6, top=STONE_HI)
    c.hline(3, 32, 8, STONE_3)
    c.rect(4, 2, 28, 5, STONE_3)
    c.hline(4, 31, 2, STONE_HI)
    c.hline(4, 31, 6, STONE_2)
    stone_block(c, 1, 22, 34, 4, top=STONE_4)
    for x in (6, 24):
        glyph(c, x, 14, (x // 6) % 5, JOINT)
    pulse = (LAVA_2, LAVA_3, LAVA_4, LAVA_HI, LAVA_4, LAVA_3)[frame % 6]
    rune = ["..#####..", ".#.....#.", "#..###..#", "#.#.#.#.#", "#..###..#", ".#.....#.", "..#####.."]
    c.ascii(rune[1:6], {"#": pulse}, 13, 2)
    c.ascii([".#.#.#.", "#.....#", ".#.#.#."], {"#": JOINT}, 14, 3)
    c.ascii(["..#..", ".###.", "..#.."], {"#": LAVA_HI if frame % 6 in (2, 3) else pulse}, 16, 3)
    c.outline()
    embers(c, ((12, 2, 0), (23, 1, 2), (18, 0, 4)), frame, n, rise=1)
    moss(c, ((3, 21), (31, 20)), frame, n)
    return c


def ember_vent(frame, n):
    """A crack in the floor where the lava below shows, embers rising from it (a flat piece)."""
    c = Canvas(16, 16)
    c.ellipse(8, 10, 7.5, 4.0, CRUST_D)
    c.ellipse(8, 10, 6.0, 3.0, CRUST_1)
    glow = (LAVA_1, LAVA_2, LAVA_3, LAVA_2, LAVA_1, LAVA_D)[frame % 6]
    for x, y in ((4, 10), (5, 9), (6, 9), (7, 10), (8, 10), (9, 11), (10, 11), (11, 10), (12, 9), (7, 8), (9, 12)):
        c.put(x, y, glow)
    c.put(8, 10, LAVA_HI if frame % 6 in (2, 3) else LAVA_4)
    c.put(6, 9, LAVA_4 if frame % 6 in (1, 2, 3) else glow)
    c.outline()
    embers(c, ((6, 8, 0), (10, 9, 2), (8, 7, 4)), frame, n, rise=2)
    return c


# name: (draw, frames, fps, foot, footprint, extra json)
PROPS = {
    "pillar_carved": (pillar_carved, 4, 3.0, (10, 56), (14, 8), {}),
    "pillar_block": (pillar_block, 4, 4.0, (10, 48), (14, 8), {}),
    "column_low": (column_low, 4, 4.0, (10, 28), (14, 8), {}),
    "column_broken": (column_broken, 4, 3.0, (10, 24), (14, 8), {}),
    "statue_guardian": (statue_guardian, 4, 2.5, (18, 47), (28, 10), {}),
    "brazier": (brazier, 8, 8.0, (10, 24), (12, 6), {}),
    "brazier_pedestal": (brazier_pedestal, 8, 8.0, (10, 40), (14, 8), {}),
    "torch_wall": (torch_wall, 6, 8.0, (7, 24), (0, 0), {}),
    "urn": (urn, 4, 3.0, (9, 18), (12, 6), {}),
    "vase": (vase, 4, 3.0, (7, 15), (0, 0), {}),
    "barrel": (barrel, 4, 4.0, (9, 18), (12, 6), {}),
    "rubble": (rubble, 4, 4.0, (14, 11), (0, 0), {}),
    "rock_smoking": (rock_smoking, 6, 5.0, (14, 25), (20, 8), {}),
    "plant": (plant, 4, 4.0, (9, 15), (0, 0), {}),
    "vines": (vines, 4, 4.0, (8, 27), (0, 0), {}),
    "banner": (banner, 6, 5.0, (10, 41), (0, 0), {}),
    "lava_fall": (lava_fall, 8, 8.0, (8, 45), (0, 0), {"loop_rows": [8, 32]}),
    "geyser": (geyser, 20, 8.0, (16, 42), (20, 10), {"phases": {k: list(v) for k, v in GEYSER_PHASES.items()}}),
    "face_gate": (face_gate, 8, 6.0, (40, 61), (76, 10), {}),
    "altar_rune": (altar_rune, 6, 4.0, (18, 24), (30, 8), {}),
    "ember_vent": (ember_vent, 6, 6.0, (8, 11), (0, 0), {}),
}


def strip_of(name):
    draw, frames, _fps, _foot, _fp, _extra = PROPS[name]
    cells = [draw(f, frames) for f in range(frames)]
    w, h = cells[0].w, cells[0].h
    sheet = Image.new("RGBA", (w * frames, h), CLEAR)
    for f, cell in enumerate(cells):
        sheet.paste(cell.img, (f * w, 0))
    return sheet, (w, h)


def check_palette(img, name):
    allowed = {v for k, v in globals().items() if isinstance(v, tuple) and len(v) == 4 and k.isupper()}
    bad = {p for p in img.getdata() if p[3] != 0 and p not in allowed}
    if bad:
        raise SystemExit("%s uses colours outside the temple palette: %s" % (name, sorted(bad)[:5]))


def write_all():
    os.makedirs(OUT, exist_ok=True)
    meta = {}
    for name, (draw, frames, fps, foot, footprint, extra) in PROPS.items():
        sheet, cell = strip_of(name)
        check_palette(sheet, name)
        sheet.save(os.path.join(OUT, name + ".png"))
        entry = {"cell": list(cell), "frames": frames, "fps": fps, "foot": list(foot), "footprint": list(footprint)}
        entry.update(extra)
        meta[name] = entry
    with open(os.path.join(OUT, "props.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)
        f.write("\n")
    return meta


# --- preview ------------------------------------------------------------------------------------------
def background(w, h, lava_from=None):
    """Temple stone slabs, with a strip of lava on the right when `lava_from` is given."""
    c = Canvas(w, h)
    for y in range(h):
        for x in range(w):
            slab = ((x // 16) + (y // 16)) % 2
            col = (STONE_2, STONE_1)[slab]
            if x % 16 == 0 or y % 16 == 0:
                col = JOINT
            elif (x * 7 + y * 13) % 23 == 0:
                col = STONE_3
            c.put(x, y, col)
    if lava_from is not None:
        for y in range(h):
            for x in range(lava_from, w):
                v = (x * 3 + y * 5 + (x * y) % 7) % 11
                c.put(x, y, LAVA_2 if v < 6 else (LAVA_3 if v < 9 else LAVA_4))
            c.put(lava_from, y, CRUST_1)
            c.put(lava_from + 1, y, CRUST_D if y % 3 else LAVA_1)
    return c.img


def nico_silhouette():
    """A 32 px stand-in so the sheet shows the scale (not Nico's real art)."""
    c = Canvas(14, 32)
    c.rect(4, 2, 6, 7, STONE_HI)
    c.rect(3, 9, 8, 12, BANNER_2)
    c.rect(4, 21, 2, 9, STONE_D)
    c.rect(8, 21, 2, 9, STONE_D)
    c.outline()
    return c.img


def write_preview(folder, meta):
    os.makedirs(folder, exist_ok=True)
    from PIL import ImageDraw
    names = list(PROPS)
    scale = 3
    nico = nico_silhouette()
    # Each prop gets a box with its 1x cell beside a 32 px stand-in and its 3x enlargement; boxes flow in rows.
    boxes = []
    for name in names:
        strip = Image.open(os.path.join(OUT, name + ".png"))
        cw, ch = meta[name]["cell"]
        cell = strip.crop((0, 0, cw, ch))
        small_h = max(ch, 32) + 12
        bg1 = background(cw + 30, small_h, lava_from=cw + 18)
        bg1.alpha_composite(cell, (4, small_h - 6 - ch))
        bg1.alpha_composite(nico, (cw + 6, small_h - 6 - 32))
        bgb = background(cw * scale + 8, ch * scale + 8)
        bgb.alpha_composite(cell.resize((cw * scale, ch * scale), Image.NEAREST), (4, 4))
        box = Image.new("RGBA", (bg1.width + bgb.width + 12, max(bg1.height, bgb.height) + 16), (16, 10, 12, 255))
        box.alpha_composite(bg1, (2, box.height - bg1.height - 2))
        box.alpha_composite(bgb, (bg1.width + 8, box.height - bgb.height - 2))
        ImageDraw.Draw(box).text((2, 1), "%s %dx%d f%d" % (name, cw, ch, meta[name]["frames"]), fill=(255, 230, 200, 255))
        boxes.append(box)
    rows, row, row_w = [], [], 0
    for box in boxes:
        if row and row_w + box.width > 960:
            rows.append(row)
            row, row_w = [], 0
        row.append(box)
        row_w += box.width + 6
    rows.append(row)
    width = max(sum(b.width + 6 for b in r) for r in rows) + 6
    height = sum(max(b.height for b in r) + 6 for r in rows) + 24
    sheet = Image.new("RGBA", (width, height), (16, 10, 12, 255))
    ImageDraw.Draw(sheet).text((4, 4), "Temple props at 1x (left, beside a 32 px stand-in) and 3x", fill=(255, 230, 200, 255))
    y = 24
    for r in rows:
        x = 6
        for box in r:
            sheet.alpha_composite(box, (x, y))
            x += box.width + 6
        y += max(b.height for b in r) + 6
    sheet.save(os.path.join(folder, "contact_sheet.png"))
    for name in names:
        strip = Image.open(os.path.join(OUT, name + ".png"))
        cw, ch = meta[name]["cell"]
        frames = []
        count = meta[name]["frames"]
        gscale = 4
        # A sheet of every frame at 3x, to check the motion frame by frame.
        fsheet = background((cw * 3 + 6) * count + 6, ch * 3 + 12)
        for f in range(count):
            cell = strip.crop((f * cw, 0, (f + 1) * cw, ch))
            fsheet.alpha_composite(cell.resize((cw * 3, ch * 3), Image.NEAREST), (6 + f * (cw * 3 + 6), 6))
            frame = background(cw * gscale + 16 + cw + 8, ch * gscale + 16)
            frame.alpha_composite(cell.resize((cw * gscale, ch * gscale), Image.NEAREST), (8, 8))
            frame.alpha_composite(cell, (cw * gscale + 16, ch * gscale + 8 - ch))
            frames.append(frame.convert("RGB").quantize(colors=64, method=Image.Quantize.MEDIANCUT))
        fsheet.save(os.path.join(folder, name + "_frames.png"))
        duration = int(1000 / meta[name]["fps"])
        frames[0].save(os.path.join(folder, name + ".gif"), save_all=True, append_images=frames[1:], duration=duration, loop=0)


if __name__ == "__main__":
    meta = write_all()
    print("temple props written to", os.path.normpath(OUT))
    if "--preview" in sys.argv:
        folder = sys.argv[sys.argv.index("--preview") + 1]
        write_preview(folder, meta)
        print("preview written to", os.path.normpath(folder))
