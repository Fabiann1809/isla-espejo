"""Draws the Planta tiradora (an orange pumpkin plant that spits orbs) and its orb with Pillow, from
the palette of the reference sheet. Usage from the repo root:
  python tools/make_planta_art.py [--preview <folder>]
Writes assets/sprites/planta/planta_<animation>.png (idle, walk, attack, hurt, death; 32x32 cells) and
orb.png / orb_impact.png (16x16 cells). With --preview it also writes a labeled contact sheet and
one GIF per animation to <folder> (not part of the game).
Then: godot --headless --path . --script res://tools/make_planta.gd"""
import math
import os
import sys

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites", "planta")
PREVIEW = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
SIZE = 32
GROUND = 27

OUTLINE = (34, 15, 10, 255)
O1 = (255, 179, 71, 255)
O2 = (245, 144, 30, 255)
O3 = (219, 111, 18, 255)
O4 = (176, 82, 12, 255)
FACE = (35, 16, 25, 255)
MOUTH = (14, 6, 10, 255)
CREAM = (248, 227, 176, 255)
LEAF1 = (70, 184, 58, 255)
LEAF2 = (46, 148, 51, 255)
LEAF3 = (27, 107, 42, 255)


def ellipse(cx, cy, rx, ry):
    return {(x, y) for y in range(SIZE) for x in range(SIZE)
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0}


# Leaf blades: (x offset from the body's center, start row, direction x, direction y, length).
BACK_BLADES = [(-5, 22, -1.0, -0.35, 7), (5, 22, 1.0, -0.35, 7), (-4, 24, -1.0, 0.1, 8), (4, 24, 1.0, 0.1, 8)]
FRONT_BLADES = [(-2, 23, -1.0, 0.55, 6), (2, 23, 1.0, 0.55, 6), (-1, 24, -0.3, 1.0, 3), (1, 24, 0.3, 1.0, 3)]


def leaves(canvas, cx, sway, front):
    for dx, y0, vx, vy, length in (FRONT_BLADES if front else BACK_BLADES):
        for t in range(length):
            x = round(cx + dx + vx * t + (0 if front else sway * vx))
            y = round(y0 + vy * t)
            if y > GROUND:
                continue
            canvas[(x, y)] = LEAF1 if t < length - 2 else LEAF2
            if t < length * 0.7:
                canvas[(x, y + 1)] = LEAF2 if t < length * 0.4 else LEAF3


def plant(w=14, h=13, dx=0, dy=0, mouth=0, eyes="open", tint=0.0, sway=0):
    cx = 16 + dx
    bottom = 22 + dy
    a, b = w / 2.0, h / 2.0
    cy = bottom - b
    canvas = {}
    leaves(canvas, cx, sway, False)
    mask = {(x, y) for y in range(SIZE) for x in range(SIZE)
            if (abs(x + 0.5 - cx) / a) ** 4 + (abs(y + 0.5 - cy) / b) ** 4 <= 1.0}

    def edge(p):
        x, y = p
        return any((x + ox, y + oy) not in mask for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)))

    for (x, y) in mask:
        nx, ny = (x + 0.5 - cx) / a, (y + 0.5 - cy) / b
        lit = -(nx * 0.6 + ny * 0.8)
        col = O1 if lit > 0.55 else O2 if lit > 0.1 else O3 if lit > -0.4 else O4
        canvas[(x, y)] = col
    if h >= 8:
        left, right = int(cx - a) + 3, int(cx + a) - 2
        top, low = int(cy - b) + 3, int(cy + b) - 2
        face = {(x, y) for (x, y) in mask if left <= x < right and top <= y < low and not edge((x, y))}
        for p in face:
            canvas[p] = FACE
        fx = (left + right) // 2
        ey = top + 1
        if mouth == 2:  # wide open: a deep mouth framed by teeth
            for (x, y) in face:
                canvas[(x, y)] = MOUTH
            for x in range(left, right):
                if (x - left) % 2 == 0:
                    for y in (top, low - 1):
                        if (x, y) in face:
                            canvas[(x, y)] = CREAM
        else:
            for p in ((fx - 2, ey), (fx + 1, ey)):
                if eyes == "open":
                    cells = [p, (p[0], p[1] + 1)]
                elif eyes == "blink":
                    cells = [(p[0], p[1] + 1)]
                elif eyes == "squint":
                    cells = [(p[0] - 1, p[1]), (p[0], p[1] + 1), (p[0] - 1, p[1] + 2)] if p[0] < fx else \
                            [(p[0] + 1, p[1]), (p[0], p[1] + 1), (p[0] + 1, p[1] + 2)]
                else:  # x
                    cells = [(p[0] - 1, p[1]), (p[0] + 1, p[1]), (p[0], p[1] + 1), (p[0] - 1, p[1] + 2), (p[0] + 1, p[1] + 2)]
                for c in cells:
                    if c in face:
                        canvas[c] = CREAM
            if mouth == 1:  # teeth showing while it charges
                for x in range(left + 1, right - 1):
                    if (x - left) % 2 == 1 and (x, low - 1) in face:
                        canvas[(x, low - 1)] = CREAM
            elif eyes in ("open", "blink"):
                for c in ((fx - 1, low - 1), (fx + 1, low - 1)):
                    if c in face:
                        canvas[c] = CREAM
    leaves(canvas, cx, sway, True)

    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    for (x, y), col in canvas.items():
        px[x, y] = col
    out = []
    for y in range(SIZE):
        for x in range(SIZE):
            if px[x, y][3] == 0 and any(0 <= x + ox < SIZE and 0 <= y + oy < SIZE and px[x + ox, y + oy][3] and
                                        px[x + ox, y + oy] != OUTLINE
                                        for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out.append((x, y))
    for p in out:
        px[p] = OUTLINE
    if tint:
        for y in range(SIZE):
            for x in range(SIZE):
                r, g, bb, al = px[x, y]
                if al:
                    px[x, y] = (int(r + (255 - r) * tint), int(g + (240 - g) * tint), int(bb + (225 - bb) * tint), 255)
    return img


def specks(img, pts, color):
    px = img.load()
    for x, y in pts:
        if 0 <= x < SIZE and 0 <= y < SIZE:
            px[x, y] = color
    return img


idle = [plant(), plant(h=13, w=14, sway=0), plant(h=14, w=13, sway=1), plant(h=14, w=13, sway=1), plant(eyes="blink"), plant(sway=0)]
attack = [
    plant(w=15, h=12, dy=0),                         # crouch
    plant(w=16, h=11, mouth=1),                      # charging
    plant(w=17, h=10, dy=0, mouth=1, sway=1),        # fully charged
    plant(w=17, h=10, dx=1, mouth=1, sway=1),        # trembles
    plant(w=12, h=15, dy=-1, mouth=2),               # spits the orb
    plant(w=15, h=12, dy=0),                         # recoil
]
hurt = [
    plant(tint=0.7, eyes="squint", dx=-1),
    plant(w=16, h=11, eyes="squint", dx=-2),
    plant(eyes="squint", dx=-1),
    plant(),
]
death = [
    plant(eyes="x"),
    plant(w=16, h=11, eyes="x", dy=1),
    plant(w=18, h=8, eyes="x", dy=2),
    plant(w=19, h=5, eyes="x", dy=3),
    specks(plant(w=10, h=3, dy=3, eyes="x"), [(8, 22), (23, 21), (12, 20)], LEAF2),
    specks(Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0)), [(9, 26), (14, 25), (19, 26), (23, 25), (16, 27), (11, 24)], LEAF2),
]
walk = [  # it scurries in short hops, the leaves staying on the ground
    plant(w=15, h=12), plant(w=13, h=14, dy=-2, sway=1), plant(w=13, h=14, dy=-2, sway=1),
    plant(w=15, h=12), plant(w=13, h=14, dy=-2, sway=-1), plant(w=13, h=14, dy=-2, sway=-1),
]
anims = {"idle": idle, "walk": walk, "attack": attack, "hurt": hurt, "death": death}


def orb_frame(radius, core_dx=0):
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = img.load()
    for y in range(16):
        for x in range(16):
            d = math.hypot(x + 0.5 - 8, y + 0.5 - 8)
            if d <= radius - 3.4:
                px[x, y] = (255, 242, 176, 255)
            elif d <= radius - 2.0:
                px[x, y] = (255, 197, 61, 255)
            elif d <= radius - 0.8:
                px[x, y] = (255, 138, 31, 255)
            elif d <= radius:
                px[x, y] = (217, 72, 15, 255)
    return img


def impact_frame(step):
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = img.load()
    ring = [3.2, 5.4, 6.8][step]
    for y in range(16):
        for x in range(16):
            d = math.hypot(x + 0.5 - 8, y + 0.5 - 8)
            if ring - 1.1 <= d <= ring:
                px[x, y] = (255, 197, 61, 255) if step < 2 else (255, 138, 31, 255)
            elif step == 0 and d < ring - 1.1:
                px[x, y] = (255, 242, 176, 255)
    for a in range(0, 360, 60):
        r = ring + 1.2
        x, y = int(8 + math.cos(math.radians(a + 30 * step)) * r), int(8 + math.sin(math.radians(a + 30 * step)) * r)
        if 0 <= x < 16 and 0 <= y < 16 and step > 0:
            px[x, y] = (217, 72, 15, 255)
    return img


orb = [orb_frame(5.4), orb_frame(4.6)]
impact = [impact_frame(i) for i in range(3)]


def strip(frames, cell):
    s = Image.new("RGBA", (cell * len(frames), cell), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        s.paste(f, (i * cell, 0))
    return s


for name, frames in anims.items():
    strip(frames, SIZE).save(os.path.join(OUT, f"planta_{name}.png"))
strip(orb, 16).save(os.path.join(OUT, "orb.png"))
strip(impact, 16).save(os.path.join(OUT, "orb_impact.png"))

if PREVIEW:
    S = 5
    sheet = Image.new("RGBA", (96 + 6 * SIZE * S, (len(anims) + 1) * SIZE * S + 10), (28, 34, 48, 255))
    d = ImageDraw.Draw(sheet)
    for r, (name, frames) in enumerate(anims.items()):
        d.text((8, r * SIZE * S + 70), name.upper(), fill=(220, 230, 220, 255))
        for i, f in enumerate(frames):
            cell = Image.alpha_composite(Image.new("RGBA", (SIZE, SIZE), (46, 74, 46, 255)), f).resize((SIZE * S, SIZE * S), Image.NEAREST)
            sheet.paste(cell, (96 + i * SIZE * S, r * SIZE * S + 5))
        big = [Image.alpha_composite(Image.new("RGBA", (SIZE, SIZE), (36, 60, 36, 255)), f).resize((SIZE * 8, SIZE * 8), Image.NEAREST).convert("P", palette=Image.ADAPTIVE) for f in frames]
        big[0].save(os.path.join(PREVIEW, f"planta_{name}.gif"), save_all=True, append_images=big[1:], duration=130, loop=0)
    d.text((8, len(anims) * SIZE * S + 70), "ORB", fill=(220, 230, 220, 255))
    for i, f in enumerate(orb + impact):
        cell = Image.alpha_composite(Image.new("RGBA", (16, 16), (46, 74, 46, 255)), f).resize((16 * 8, 16 * 8), Image.NEAREST)
        sheet.paste(cell, (96 + i * 16 * 8, len(anims) * SIZE * S + 5))
    sheet.save(os.path.join(PREVIEW, "planta_hoja.png"))
