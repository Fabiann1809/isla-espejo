"""Derives the Serpiente de piedra frames the source sheet does not have.

The source (assets/sprites/serpiente/serpiente.png, 8x2 cells of 64 px, from serpiente_source.gif)
has poses but no cycles. This writes assets/sprites/serpiente/serpiente_extra.png, one row of
64 px cells:
  0      idle breath: the coiled side pose (cell 1) squashed 1 px, so idle can breathe
  1..4   slither: the side crawl (cell 7) with a travelling wave along the body (head kept still)
  5      petrifying: the dying pose (cell 13) half turned to the grey stone of the corpse (cell 14)
and assets/sprites/serpiente/poison_orb.png: the plant's orb (assets/sprites/planta/orb.png)
recoloured to venom green, for the serpent's spit.

Run from the repo root: python tools/make_serpent_art.py
Then import (godot --headless --path . --import) and run tools/make_serpent_frames.gd.
"""
import colorsys
import math

from PIL import Image

SHEET = "assets/sprites/serpiente/serpiente.png"
EXTRA = "assets/sprites/serpiente/serpiente_extra.png"
ORB_IN = "assets/sprites/planta/orb.png"
ORB_OUT = "assets/sprites/serpiente/poison_orb.png"
CELL = 64
COLS = 8
SLITHER_FRAMES = 4
# Wave of the crawl: pixels up/down, and its length along the body.
WAVE_AMPLITUDE = 1.2
WAVE_LENGTH = 30.0
# The crawl's head is on the right; from here on the wave fades out so the head glides.
HEAD_X = 44
# Stone tint of the petrifying frame (the corpse's mossy grey) and how far it goes.
STONE = (150, 146, 120)
STONE_MIX = 0.55
# Orange orb -> venom green.
ORB_HUE_SHIFT = 0.25


def cell(sheet: Image.Image, index: int) -> Image.Image:
    x, y = (index % COLS) * CELL, (index // COLS) * CELL
    return sheet.crop((x, y, x + CELL, y + CELL))


def breath(src: Image.Image) -> Image.Image:
    """Squashes the pose 1 px from the top, keeping its base on the ground."""
    box = src.getbbox()
    body = src.crop(box)
    squashed = body.resize((body.width, body.height - 1), Image.NEAREST)
    out = Image.new("RGBA", src.size)
    out.paste(squashed, (box[0], box[1] + 1))
    return out


def slither(src: Image.Image, phase: float) -> Image.Image:
    out = Image.new("RGBA", src.size)
    for x in range(CELL):
        fade = 1.0 if x < HEAD_X else max(0.0, 1.0 - (x - HEAD_X) / 8.0)
        dy = round(WAVE_AMPLITUDE * fade * math.sin(2 * math.pi * (x / WAVE_LENGTH - phase)))
        column = src.crop((x, 0, x + 1, CELL))
        out.paste(column, (x, dy))
    return out


def petrify(src: Image.Image) -> Image.Image:
    out = src.copy()
    pixels = out.load()
    for y in range(CELL):
        for x in range(CELL):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            light = (0.3 * r + 0.59 * g + 0.11 * b) / 255.0
            stone = [int(c * (0.45 + 0.75 * light)) for c in STONE]
            mixed = [int(c * (1 - STONE_MIX) + s * STONE_MIX) for c, s in zip((r, g, b), stone)]
            pixels[x, y] = (*[min(255, v) for v in mixed], a)
    return out


def poison_orb() -> Image.Image:
    orb = Image.open(ORB_IN).convert("RGBA")
    pixels = orb.load()
    for y in range(orb.height):
        for x in range(orb.width):
            r, g, b, a = pixels[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            nr, ng, nb = colorsys.hsv_to_rgb((h + ORB_HUE_SHIFT) % 1.0, s, v)
            pixels[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
    return orb


def main() -> None:
    sheet = Image.open(SHEET).convert("RGBA")
    frames = [breath(cell(sheet, 1))]
    frames += [slither(cell(sheet, 7), i / SLITHER_FRAMES) for i in range(SLITHER_FRAMES)]
    frames.append(petrify(cell(sheet, 13)))
    extra = Image.new("RGBA", (CELL * len(frames), CELL))
    for i, frame in enumerate(frames):
        extra.paste(frame, (i * CELL, 0))
    extra.save(EXTRA)
    poison_orb().save(ORB_OUT)
    print("serpent art written:", EXTRA, ORB_OUT)


if __name__ == "__main__":
    main()
