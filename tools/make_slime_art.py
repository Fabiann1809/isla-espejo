"""Draws the green slime (32x32 cells, facing right) with Pillow from the palette of the reference
sheet. Usage from the repo root:  python tools/make_slime_art.py [--preview <folder>]
Writes assets/sprites/slime/slime_<animation>.png (idle, walk, attack, hurt, death); with --preview
it also writes a labeled contact sheet and one GIF per animation to <folder> (not part of the game).
Then: godot --headless --path . --script res://tools/make_slime.gd"""
import os
import sys

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites", "slime")
PREVIEW = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
OUTLINE = (26, 26, 26, 255)
C1 = (168, 224, 99, 255)   # A8E063
C2 = (126, 217, 87, 255)   # 7ED957
C3 = (86, 176, 74, 255)    # 56B04A
C4 = (46, 125, 50, 255)    # 2E7D32
GLINT = (230, 255, 214, 255)
EYE = (26, 26, 26, 255)
SIZE = 32


SCALE = 0.7  # the frames below are laid out at full size; the body is drawn at this fraction


def blob(cx, bottom, w, h, eye_dx=1, eyes="normal", tint=0.0, n=2.7):
    w, h = w * SCALE, max(h * SCALE, 3.0)
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    a, b = w / 2.0, h / 2.0
    cy = bottom - b
    mask = set()
    for y in range(SIZE):
        for x in range(SIZE):
            dx, dy = abs(x + 0.5 - cx) / a, abs(y + 0.5 - cy) / b
            if dx ** n + dy ** n <= 1.0:
                mask.add((x, y))

    def edge(p):
        x, y = p
        return any((x + ox, y + oy) not in mask for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)))

    for (x, y) in mask:
        if edge((x, y)):
            px[x, y] = OUTLINE
            continue
        nx, ny = (x + 0.5 - cx) / a, (y + 0.5 - cy) / b
        lit = -(nx * 0.55 + ny * 0.85)
        col = C1 if lit > 0.55 else C2 if lit > 0.15 else C3 if lit > -0.35 else C4
        if edge((x, y + 1)):  # darker rim above the bottom outline
            col = C4
        px[x, y] = col
    hx, hy = int(cx - a * 0.55), int(cy - b * 0.55)
    for p in ((hx, hy), (hx + 1, hy), (hx, hy + 1)):
        if p in mask and not edge(p):
            px[p] = GLINT
    ey = int(cy - b * 0.15)
    ex = int(cx + eye_dx)
    gap = max(2, round(w * 0.2))
    for side in (-gap, gap - 1):
        x0 = ex + side
        if eyes == "normal":
            cells = [(x0, ey), (x0, ey + 1), (x0, ey + 2)]
        elif eyes == "squint":
            cells = [(x0, ey + 1), (x0 + 1, ey + 1)]
        elif eyes == "xx":
            cells = [(x0, ey), (x0 + 1, ey + 1), (x0, ey + 2)] if side < 0 else [(x0 + 1, ey), (x0, ey + 1), (x0 + 1, ey + 2)]
        else:
            cells = []
        for c in cells:
            if c in mask:
                px[c] = EYE
    if tint:
        for y in range(SIZE):
            for x in range(SIZE):
                r, g, bb, al = px[x, y]
                if al:
                    px[x, y] = (int(r + (230 - r) * tint), int(g + (255 - g) * tint), int(bb + (214 - bb) * tint), 255)
    return img


def dots(img, pts, color=C2):
    px = img.load()
    for x, y in pts:
        if 0 <= x < SIZE and 0 <= y < SIZE:
            px[x, y] = color
    return img


def spark(img, pts):
    return dots(img, pts, (240, 240, 255, 255))


B = 27  # ground line
idle = [blob(15, B, 16, 15), blob(15, B, 17, 14), blob(15, B, 18, 13), blob(15, B, 17, 14)]
walk = [blob(15, B, 18, 12), blob(15, B - 2, 16, 15), blob(15, B - 3, 15, 16), blob(15, B - 1, 17, 14), blob(15, B, 19, 11)]
attack = [
    blob(12, B, 20, 11),                             # crouch (anticipation)
    blob(14, B - 6, 14, 17),                         # leap, stretched
    dots(blob(20, B - 9, 16, 15), [(15, B - 6), (13, B - 4)], C3),  # peak, lunging forward
    blob(22, B, 21, 10),                              # lands squashed, ahead
    blob(18, B, 17, 14),                             # recovers
]
hurt = [
    spark(blob(13, B, 17, 14, tint=0.45), [(3, 14), (4, 11), (23, 12), (25, 9)]),
    spark(blob(12, B, 20, 11, eyes="xx"), [(2, 15), (3, 12), (22, 13), (24, 11)]),
    spark(blob(13, B, 17, 14, eyes="squint"), [(24, 11), (25, 9)]),
    blob(15, B, 16, 15),
]
die = [
    blob(15, B, 16, 15),
    dots(blob(15, B, 19, 11, eyes="xx"), [(4, 17), (27, 16), (3, 21)], C2),
    dots(blob(15, B, 20, 8, eyes="none"), [(3, 19), (28, 18), (5, 22), (26, 22)], C2),
    dots(blob(15, B, 21, 5, eyes="none"), [(3, 23), (28, 23), (7, 22), (24, 22)], C3),
    dots(blob(15, B, 17, 3, eyes="none"), [(5, 24), (26, 24), (10, 23), (21, 24)], C3),
    dots(Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0)), [(8, 26), (13, 25), (19, 26), (24, 25), (16, 27)], C3),
]
anims = {"idle": idle, "walk": walk, "attack": attack, "hurt": hurt, "die": die}

FILES = {"die": "death"}
for name, frames in anims.items():
    strip = Image.new("RGBA", (SIZE * len(frames), SIZE), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * SIZE, 0))
    strip.save(os.path.join(OUT, f"slime_{FILES.get(name, name)}.png"))
    if PREVIEW:
        big = [Image.alpha_composite(Image.new("RGBA", (SIZE, SIZE), (36, 60, 36, 255)), f).resize((SIZE * 8, SIZE * 8), Image.NEAREST).convert("P", palette=Image.ADAPTIVE) for f in frames]
        big[0].save(os.path.join(PREVIEW, f"slime_{name}.gif"), save_all=True, append_images=big[1:], duration=130, loop=0)

if PREVIEW:
    S = 5
    cols = 6
    sheet = Image.new("RGBA", (96 + cols * SIZE * S, len(anims) * SIZE * S + 10), (28, 34, 48, 255))
    d = ImageDraw.Draw(sheet)
    for r, (name, frames) in enumerate(anims.items()):
        d.text((8, r * SIZE * S + 70), name.upper(), fill=(220, 230, 220, 255))
        for i, f in enumerate(frames):
            cell = Image.alpha_composite(Image.new("RGBA", (SIZE, SIZE), (46, 74, 46, 255)), f).resize((SIZE * S, SIZE * S), Image.NEAREST)
            sheet.paste(cell, (96 + i * SIZE * S, r * SIZE * S + 5))
    sheet.save(os.path.join(PREVIEW, "slime_hoja.png"))
