"""Draws the Brote (a small sprout of the Ente del bosque: the minions it grows from its body) with
Pillow, in the palette of the Ente. Usage from the repo root:
  python tools/make_brote_art.py [--preview <folder>]
Writes assets/sprites/brote/brote_<animation>.png (idle, walk, attack, hurt, death; 32x32 cells,
facing the viewer). With --preview it also writes a labeled contact sheet and one GIF per animation
to <folder> (not part of the game).
Then: godot --headless --path . --script res://tools/make_brote.gd"""
import math
import os
import sys

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites", "brote")
PREVIEW = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
SIZE = 32

OUTLINE = (24, 14, 8, 255)
BARK1 = (134, 86, 52, 255)
BARK2 = (101, 62, 36, 255)
BARK3 = (68, 40, 22, 255)
MOSS1 = (176, 196, 104, 255)
MOSS2 = (138, 162, 76, 255)
MOSS3 = (98, 122, 52, 255)
LEAF1 = (126, 168, 64, 255)
LEAF2 = (82, 120, 44, 255)
EYE = (255, 236, 168, 255)
EYE_HOT = (255, 252, 226, 255)
RING = (60, 34, 18, 255)


def ellipse(cx, cy, rx, ry):
    return {(x, y) for y in range(SIZE) for x in range(SIZE)
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0}


def line(c, x0, y0, x1, y1, color, thick=1):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        x = round(x0 + (x1 - x0) * i / n)
        y = round(y0 + (y1 - y0) * i / n)
        for t in range(thick):
            c[(x + t, y)] = color


def bark(c, cells, cx, cy, rx, ry, base=BARK2):
    for (x, y) in cells:
        lit = -(((x + 0.5 - cx) / rx) * 0.6 + ((y + 0.5 - cy) / ry) * 0.8)
        col = BARK1 if lit > 0.35 else base if lit > -0.45 else BARK3
        if (x * 5 + y * 3) % 7 == 0:
            col = BARK3 if col != BARK3 else BARK2   # rough bark
        c[(x, y)] = col


def antlers(c, hx, hy, sway):
    """Two branching antlers rising from the head, with leaves on some tips."""
    for s in (-1, 1):
        sw = sway * s
        pts = [(hx + 3 * s, hy - 4), (hx + 5 * s + sw // 2, hy - 7), (hx + 6 * s + sw, hy - 11)]
        line(c, pts[0][0], pts[0][1], pts[1][0], pts[1][1], BARK2, 2)
        line(c, pts[1][0], pts[1][1], pts[2][0], pts[2][1], BARK2, 2)
        line(c, pts[1][0], pts[1][1], hx + 9 * s + sw, hy - 8, BARK2, 1)
        line(c, pts[1][0] + s, pts[1][1] - 2, hx + 3 * s + sw, hy - 10, BARK3, 1)
        for (lx, ly) in ((hx + 9 * s + sw, hy - 9), (pts[2][0], pts[2][1] - 1), (hx + 3 * s + sw, hy - 11)):
            c[(lx, ly)] = LEAF1
            c[(lx + s, ly)] = LEAF2


def ente(bob=0, dx=0, sway=0, lleg=0, rleg=0, larm=((9, 22), 0), rarm=((23, 22), 0), eye="n", tint=0.0,
         glow=False, leaves=(), head_dy=0, squash=0):
    c = {}
    ox, oy = dx, bob
    # legs: bark stumps with root toes
    for side, lift in ((0, lleg), (1, rleg)):
        x = 12 + side * 6 + ox
        for (px_, py_) in ellipse(x + 1, 25.5 - lift, 2.6, 2.2 + 0):
            c[(px_, py_)] = BARK2
        rect_x = range(x - 1, x + 3)
        for xx in rect_x:
            c[(xx, 27 - lift)] = BARK3
        c[(x - 1 + side * 3, 27 - lift)] = BARK1
    # torso with a mossy belly
    torso = ellipse(16 + ox, 20.5 + oy, 6.2, 4.6)
    bark(c, torso, 16 + ox, 20.5 + oy, 6.2, 4.6)
    belly = ellipse(16 + ox, 21 + oy, 4.2, 3.4)
    for (x, y) in belly:
        lit = -(((x + 0.5 - 16 - ox) / 4.2) * 0.5 + ((y + 0.5 - 21 - oy) / 3.4) * 0.8)
        c[(x, y)] = MOSS1 if lit > 0.4 else MOSS2 if lit > -0.35 else MOSS3
    # arms: thin branches with a twig hand
    for shoulder, (hand, lift) in (((11, 19), larm), ((21, 19), rarm)):
        hx_, hy_ = hand[0] + ox, hand[1] + oy - lift
        line(c, shoulder[0] + ox, shoulder[1] + oy, hx_, hy_, BARK2, 2)
        line(c, hx_, hy_, hx_ + (1 if hand[0] > 16 else -2), hy_ + 2, BARK3, 1)
        c[(hx_, hy_ - 1)] = LEAF1
    # head: a round stump with the glowing eye
    hx, hy = 16 + ox, 12 + oy + head_dy + squash
    head = ellipse(hx, hy, 6.2, 5.0 - squash * 0.4)
    bark(c, head, hx, hy, 6.2, 5.0)
    for (x, y) in ellipse(hx, hy + 0.5, 2.6, 2.6):
        c[(x, y)] = RING
    if eye == "n":
        for (x, y) in ellipse(hx, hy + 0.5, 1.7, 1.7):
            c[(x, y)] = EYE_HOT if glow else EYE
    elif eye == "blink":
        for (x, y) in ellipse(hx, hy + 0.5, 1.7, 0.7):
            c[(x, y)] = EYE
    elif eye == "dim":
        for (x, y) in ellipse(hx, hy + 0.5, 1.2, 1.2):
            c[(x, y)] = (176, 150, 100, 255)
    antlers(c, hx, hy, sway)
    for (lx, ly) in leaves:
        c[(lx, ly)] = LEAF1
        c[(lx + 1, ly)] = LEAF2
    return finish(c, tint)


def finish(c, tint=0.0):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    for (x, y), col in c.items():
        y += 2  # headroom for the antlers
        if 0 <= x < SIZE and 0 <= y < SIZE:
            px[x, y] = col
    outline = [(x, y) for y in range(SIZE) for x in range(SIZE)
               if px[x, y][3] == 0 and any(0 <= x + a < SIZE and 0 <= y + b < SIZE and px[x + a, y + b][3]
                                           for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for p in outline:
        px[p] = OUTLINE
    if tint:
        for y in range(SIZE):
            for x in range(SIZE):
                r, g, b, a = px[x, y]
                if a:
                    px[x, y] = (int(r + (255 - r) * tint), int(g + (245 - g) * tint), int(b + (225 - b) * tint), 255)
    return img


def heap(head_y, head_dx, pieces, with_head=True, eye="dim"):
    """What is left on the ground: the head (antlers fallen beside it) and twigs and leaves."""
    c = {}
    if with_head:
        hx, hy = 16 + head_dx, head_y
        head = ellipse(hx, hy, 6.0, 3.8)
        bark(c, head, hx, hy, 6.0, 3.8)
        if eye == "dim":
            for (x, y) in ellipse(hx, hy, 1.3, 1.3):
                c[(x, y)] = RING
            c[(hx, hy)] = (176, 150, 100, 255)
    for (x0, y0, x1, y1, col) in pieces:
        line(c, x0, y0, x1, y1, col, 1)
    return finish(c)


SPARKS = ((6, 9), (25, 8), (11, 6), (21, 5))
idle = [ente(), ente(sway=0, bob=0), ente(sway=1, bob=-1), ente(sway=1, bob=-1), ente(sway=0), ente(eye="blink", sway=-1)]
walk = [
    ente(),
    ente(bob=-1, lleg=2, larm=((8, 22), 1), rarm=((24, 21), 0), sway=1),
    ente(),
    ente(),
    ente(bob=-1, rleg=2, larm=((8, 21), 0), rarm=((24, 22), 1), sway=-1),
    ente(),
]
attack = [
    ente(),
    ente(larm=((6, 18), 0), rarm=((26, 18), 0), glow=False, sway=1),                    # arms spread
    ente(bob=-1, larm=((4, 14), 0), rarm=((28, 14), 0), glow=True, sway=2, leaves=((3, 11), (28, 11))),
    ente(bob=-1, larm=((3, 12), 0), rarm=((29, 12), 0), glow=True, sway=2, leaves=((2, 9), (29, 9), (5, 6), (26, 6))),
    ente(bob=-1, larm=((3, 11), 0), rarm=((29, 11), 0), glow=True, sway=2, leaves=((2, 8), (29, 8), (4, 5), (27, 5))),  # tense
    ente(bob=1, larm=((11, 25), 0), rarm=((21, 25), 0), glow=True, head_dy=1, leaves=((12, 26), (20, 26), (8, 24), (24, 24))),  # slam
    ente(bob=0, larm=((9, 24), 0), rarm=((23, 24), 0), leaves=((10, 27), (22, 27))),
]
hurt = [
    ente(tint=0.7, eye="blink", dx=-1, sway=2, leaves=((7, 8), (24, 9))),
    ente(eye="blink", dx=-2, bob=1, sway=-1, leaves=((6, 12), (25, 14), (9, 5))),
    ente(eye="dim", dx=-1, sway=1, leaves=((8, 16), (26, 12))),
    ente(eye="n", dx=-1),
    ente(),
    ente(),
]
death = [
    ente(tint=0.5, eye="dim", dx=-1, sway=2, leaves=((7, 8), (24, 9))),
    ente(eye="dim", bob=3, head_dy=2, squash=1, sway=-2, lleg=1, rleg=1, larm=((7, 24), 0), rarm=((25, 24), 0),
         leaves=((5, 14), (26, 15), (9, 8))),
    heap(21, 0, [(4, 25, 11, 24, BARK2), (21, 24, 28, 25, BARK2), (8, 21, 9, 22, LEAF1), (24, 22, 25, 23, LEAF1)]),
    heap(23, 0, [(2, 26, 9, 25, BARK2), (22, 25, 29, 26, BARK2), (5, 24, 6, 24, LEAF1), (26, 23, 27, 23, LEAF1)]),
    heap(25, 0, [(2, 27, 8, 27, BARK2), (23, 27, 29, 27, BARK2), (10, 24, 11, 24, LEAF1), (20, 24, 21, 24, LEAF1)]),
    heap(0, 0, [(6, 27, 10, 27, BARK2), (21, 27, 25, 27, BARK2), (13, 26, 14, 26, LEAF1), (18, 26, 19, 26, LEAF2)], with_head=False),
    heap(0, 0, [(9, 27, 10, 27, LEAF2), (22, 27, 23, 27, LEAF1)], with_head=False),
]
anims = {"idle": idle, "walk": walk, "attack": attack, "hurt": hurt, "death": death}

for name, frames in anims.items():
    strip = Image.new("RGBA", (SIZE * len(frames), SIZE), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * SIZE, 0))
    strip.save(os.path.join(OUT, f"brote_{name}.png"))

if PREVIEW:
    S = 4
    cols = 7
    sheet = Image.new("RGBA", (96 + cols * SIZE * S, len(anims) * SIZE * S + 10), (20, 24, 20, 255))
    d = ImageDraw.Draw(sheet)
    for r, (name, frames) in enumerate(anims.items()):
        d.text((8, r * SIZE * S + 60), name.upper(), fill=(220, 230, 220, 255))
        for i, f in enumerate(frames):
            cell = Image.alpha_composite(Image.new("RGBA", (SIZE, SIZE), (46, 74, 46, 255)), f).resize((SIZE * S, SIZE * S), Image.NEAREST)
            sheet.paste(cell, (96 + i * SIZE * S, r * SIZE * S + 5))
        big = [Image.alpha_composite(Image.new("RGBA", (SIZE, SIZE), (36, 60, 36, 255)), f).resize((SIZE * 8, SIZE * 8), Image.NEAREST).convert("P", palette=Image.ADAPTIVE) for f in frames]
        big[0].save(os.path.join(PREVIEW, f"brote_{name}.gif"), save_all=True, append_images=big[1:], duration=130, loop=0)
    sheet.save(os.path.join(PREVIEW, "brote_hoja.png"))
