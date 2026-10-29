"""Draws the Ente del bosque (a wooden forest spirit with branching antlers, a glowing eye and a mossy
belly) with Pillow, from the palette of the reference sheet. Usage from the repo root:
  python tools/make_ente_art.py [--preview <folder>]
Writes assets/sprites/ente/ente_<animation>.png (idle, walk, attack, hurt, death; 64x64 cells,
facing the viewer, feet on row 61). With --preview it also writes a labeled contact sheet and one GIF
per animation to <folder> (not part of the game).
Then: godot --headless --path . --script res://tools/make_ente.gd"""
import os
import sys

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites", "ente")
PREVIEW = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
SIZE = 64
GROUND = 60

OUTLINE = (22, 12, 7, 255)
BARK1 = (150, 98, 58, 255)
BARK2 = (110, 68, 40, 255)
BARK3 = (76, 44, 25, 255)
BARK4 = (50, 29, 16, 255)
MOSS1 = (190, 208, 112, 255)
MOSS2 = (146, 170, 80, 255)
MOSS3 = (102, 128, 54, 255)
MOSS4 = (70, 92, 40, 255)
LEAF1 = (140, 184, 72, 255)
LEAF2 = (88, 128, 48, 255)
LEAF3 = (58, 92, 36, 255)
EYE = (255, 236, 168, 255)
EYE_HOT = (255, 252, 228, 255)
RING = (46, 26, 14, 255)
HALO = (182, 128, 74, 255)


def ellipse(cx, cy, rx, ry):
    return {(x, y) for y in range(SIZE) for x in range(SIZE)
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0}


def noise(x, y, k=0):
    return (x * 73856093 ^ y * 19349663 ^ k * 83492791) % 11


def bark(c, cells, cx, cy, rx, ry, base=BARK2, grain=True):
    """Bark lit from the top left, with vertical streaks and knots."""
    for (x, y) in cells:
        lit = -(((x + 0.5 - cx) / rx) * 0.6 + ((y + 0.5 - cy) / ry) * 0.8)
        col = BARK1 if lit > 0.45 else base if lit > -0.3 else BARK3 if lit > -0.75 else BARK4
        n = noise(x, y // 3)
        if grain and n == 0:
            col = BARK4 if col != BARK4 else BARK3
        elif grain and n == 1 and col != BARK1:
            col = BARK1 if col == BARK2 else BARK2
        c[(x, y)] = col


def disc(cells, x, y, r):
    for yy in range(int(y - r) - 1, int(y + r) + 2):
        for xx in range(int(x - r) - 1, int(x + r) + 2):
            if (xx + 0.5 - x) ** 2 + (yy + 0.5 - y) ** 2 <= r * r:
                cells.add((xx, yy))


def branch(cells, pts, widths):
    """A tapering branch through `pts` (widths at the first and last point)."""
    for (p, q), (w0, w1) in zip(zip(pts, pts[1:]), zip(widths, widths[1:])):
        n = max(abs(q[0] - p[0]), abs(q[1] - p[1]), 1) * 2
        for i in range(n + 1):
            t = i / n
            disc(cells, p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t, (w0 + (w1 - w0) * t) / 2.0)


def paint_wood(c, cells):
    for (x, y) in cells:
        if (x - 1, y) not in cells:
            col = BARK1
        elif (x + 1, y) not in cells or (x, y + 1) not in cells:
            col = BARK3
        else:
            col = BARK2
        if noise(x, y, 3) == 0 and col == BARK2:
            col = BARK3
        c[(x, y)] = col


def leaf(c, x, y, flip=1, big=False):
    c[(x, y)] = LEAF2
    c[(x + flip, y)] = LEAF1
    c[(x + 2 * flip, y - 1)] = LEAF1
    c[(x + flip, y - 1)] = LEAF1
    c[(x + 2 * flip, y)] = LEAF2
    c[(x + flip, y + 1)] = LEAF3
    if big:
        c[(x + 3 * flip, y - 1)] = LEAF2
        c[(x + 2 * flip, y - 2)] = LEAF1


def antlers(c, hx, hy, sway):
    """Two branching antlers: a main beam with a brow tine, two upper tines and leaves."""
    for s in (-1, 1):
        sw = sway * s
        beam = [(hx + 4 * s, hy - 6), (hx + 8 * s, hy - 10), (hx + 10 * s + sw // 2, hy - 14), (hx + 11 * s + sw, hy - 19)]
        cells = set()
        branch(cells, beam, [4, 3.4, 2.6, 1.6])
        branch(cells, [(hx + 6 * s, hy - 7), (hx + 12 * s, hy - 7), (hx + 16 * s + sw, hy - 10)], [2.6, 2.2, 1.4])     # brow tine
        branch(cells, [(hx + 9 * s, hy - 11), (hx + 14 * s, hy - 14), (hx + 18 * s + sw, hy - 16)], [2.4, 2.0, 1.2])      # middle tine
        branch(cells, [(hx + 10 * s + sw // 2, hy - 15), (hx + 6 * s + sw, hy - 18), (hx + 5 * s + sw, hy - 21)], [2.0, 1.6, 1.0])  # inner tine
        branch(cells, [(hx + 16 * s + sw, hy - 10), (hx + 20 * s + sw, hy - 9)], [1.4, 1.0])
        paint_wood(c, cells)
        for (lx, ly, big) in ((hx + 11 * s + sw, hy - 20, True), (hx + 18 * s + sw, hy - 17, False), (hx + 21 * s + sw, hy - 9, False),
                              (hx + 5 * s + sw, hy - 21, False), (hx + 9 * s, hy - 13, False), (hx + 13 * s, hy - 8, True)):
            leaf(c, lx, ly, s, big)


def arm(c, shoulder, hand, side):
    """A branch arm: shoulder, bent elbow, a moss tuft on the elbow and a hand of three twigs."""
    ex = (shoulder[0] + hand[0]) // 2 + 3 * side
    ey = (shoulder[1] + hand[1]) // 2 + 1
    cells = set()
    branch(cells, [shoulder, (ex, ey), hand], [5, 4, 3])
    paint_wood(c, cells)
    for (x, y) in ellipse(ex, ey - 1, 2.4, 1.8):
        c[(x, y)] = MOSS2 if (x + y) % 2 else MOSS3
    for k in (-2, 0, 2):
        cells = set()
        branch(cells, [hand, (hand[0] + k, hand[1] + 4)], [2, 1])
        paint_wood(c, cells)
    leaf(c, hand[0] - side, hand[1] - 2, side)


def ente(bob=0, dx=0, sway=0, lleg=0, rleg=0, lhand=(10, 50), rhand=(54, 50), eye="n", tint=0.0, glow=False,
         leaves=(), head_dy=0, squash=0):
    c = {}
    ox, oy = dx, bob
    cx = 32 + ox
    # legs: bark stumps with moss on the knee and root toes
    for side, lift in ((-1, lleg), (1, rleg)):
        lx = cx + 7 * side
        leg = ellipse(lx, 52 - lift, 5.2, 6.5)
        bark(c, leg, lx, 52 - lift, 5.2, 6.5)
        for (x, y) in ellipse(lx - 1, 48 - lift, 2.6, 1.6):
            c[(x, y)] = MOSS2 if noise(x, y, 1) % 2 else MOSS3
        for k in (-3, 0, 3):
            for yy in range(GROUND - 3 - lift, GROUND + 1 - lift):
                c[(lx + k, yy)] = BARK3 if yy < GROUND - lift else BARK4
            c[(lx + k, GROUND - lift)] = BARK1 if k < 0 else BARK3
    # torso with a mossy belly
    ty = 42 + oy
    torso = ellipse(cx, ty, 11, 9)
    bark(c, torso, cx, ty, 11, 9)
    belly = ellipse(cx, ty + 1, 7.5, 6.5)
    for (x, y) in belly:
        lit = -(((x + 0.5 - cx) / 7.5) * 0.5 + ((y + 0.5 - ty - 1) / 6.5) * 0.85)
        col = MOSS1 if lit > 0.5 else MOSS2 if lit > 0.0 else MOSS3 if lit > -0.55 else MOSS4
        if noise(x, y, 5) == 0:
            col = MOSS1 if col == MOSS2 else MOSS3
        c[(x, y)] = col
    for (x, y) in ((cx - 3, ty - 2), (cx + 2, ty + 1), (cx - 1, ty + 4)):
        c[(x, y)] = BARK3  # little knots on the belly
    # shoulders: moss pads
    for side in (-1, 1):
        for (x, y) in ellipse(cx + 12 * side, ty - 6, 4.2, 3.0):
            c[(x, y)] = MOSS2 if noise(x, y, 2) % 3 else MOSS3
        c[(cx + 12 * side - 1, ty - 7)] = MOSS1
    # arms
    arm(c, (cx - 11, ty - 4), (lhand[0] + ox, lhand[1] + oy), -1)
    arm(c, (cx + 11, ty - 4), (rhand[0] + ox, rhand[1] + oy), 1)
    # head: a round stump with ridges, small lumps for ears and the glowing eye
    hx, hy = cx, 26 + oy + head_dy + squash
    for side in (-1, 1):
        for (x, y) in ellipse(hx + 12 * side, hy - 2, 2.6, 3.2):
            c[(x, y)] = BARK3 if side > 0 else BARK2
    head = ellipse(hx, hy, 12.2, 10.2 - squash * 0.5)
    bark(c, head, hx, hy, 12.2, 10.2)
    for k in (-6, -3, 3, 6):
        for yy in range(hy - 9, hy - 5):
            if (hx + k, yy) in head:
                c[(hx + k, yy)] = BARK3 if noise(hx + k, yy) % 2 else BARK1
    ex, ey = hx, hy + 1
    for (x, y) in ellipse(ex, ey, 7.0 if glow else 6.0, 7.0 if glow else 6.0):
        if (x, y) in head:
            c[(x, y)] = HALO if noise(x, y, 7) % 2 or glow else c[(x, y)]
    for (x, y) in ellipse(ex, ey, 4.8, 4.8):
        c[(x, y)] = RING
    if eye == "n":
        for (x, y) in ellipse(ex, ey, 3.4, 3.4):
            c[(x, y)] = EYE
        for (x, y) in ellipse(ex - 0.5, ey - 0.5, 1.8, 1.8):
            c[(x, y)] = EYE_HOT
    elif eye == "blink":
        for (x, y) in ellipse(ex, ey, 3.4, 1.2):
            c[(x, y)] = EYE
    elif eye == "dim":
        for (x, y) in ellipse(ex, ey, 2.4, 2.4):
            c[(x, y)] = (176, 150, 100, 255)
    antlers(c, hx, hy - (squash and 1), sway)
    for (lx, ly) in leaves:
        leaf(c, lx, ly, 1 if lx > 32 else -1)
    return finish(c, tint)


def finish(c, tint=0.0):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    for (x, y), col in c.items():
        y += 1  # a row of headroom for the antler tips
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


def heap(head_y, pieces, leaves=(), with_head=True, tilt=0):
    """What is left on the ground: the head with its antlers fallen beside it, twigs and leaves."""
    c = {}
    if with_head:
        hx, hy = 32, head_y
        head = ellipse(hx, hy, 11.0, 7.0)
        bark(c, head, hx, hy, 11.0, 7.0)
        for (x, y) in ellipse(hx, hy, 3.4, 3.0):
            c[(x, y)] = RING
        c[(hx, hy)] = (176, 150, 100, 255)
        c[(hx + 1, hy)] = (176, 150, 100, 255)
    for pts in pieces:
        cells = set()
        branch(cells, pts, [3.0] + [1.6] * (len(pts) - 1))
        paint_wood(c, cells)
    for (lx, ly) in leaves:
        leaf(c, lx, ly, 1 if lx > 32 else -1)
    return finish(c)


idle = [ente(), ente(), ente(sway=1, bob=-1), ente(sway=1, bob=-1), ente(), ente(eye="blink", sway=-1)]
walk = [
    ente(),
    ente(bob=-1, lleg=3, lhand=(9, 49), rhand=(55, 51), sway=1),
    ente(),
    ente(),
    ente(bob=-1, rleg=3, lhand=(9, 51), rhand=(55, 49), sway=-1),
    ente(),
]
attack = [
    ente(),
    ente(lhand=(6, 42), rhand=(58, 42), sway=1),                                                       # arms spread
    ente(bob=-1, lhand=(3, 33), rhand=(61, 33), glow=True, sway=2, leaves=((6, 26), (58, 26))),
    ente(bob=-2, lhand=(2, 27), rhand=(62, 27), glow=True, sway=3, leaves=((4, 20), (58, 21), (10, 12), (53, 12))),
    ente(bob=-2, lhand=(2, 24), rhand=(62, 24), glow=True, sway=3, leaves=((4, 17), (58, 18), (12, 9), (51, 10), (7, 28))),   # tense
    ente(bob=2, head_dy=2, lhand=(20, 58), rhand=(44, 58), glow=True,
         leaves=((10, 56), (50, 56), (22, 58), (40, 58), (6, 52), (56, 52))),                           # slam
    ente(bob=0, lhand=(14, 55), rhand=(50, 55), leaves=((12, 59), (50, 59), (24, 60))),
]
hurt = [
    ente(tint=0.7, eye="blink", dx=-2, sway=3, leaves=((12, 16), (50, 20))),
    ente(eye="blink", dx=-3, bob=2, sway=-2, leaves=((8, 30), (54, 36), (16, 12), (44, 8))),
    ente(eye="dim", dx=-2, sway=2, leaves=((10, 40), (55, 30))),
    ente(dx=-1),
    ente(),
    ente(),
]
death = [
    ente(tint=0.5, eye="dim", dx=-2, sway=3, leaves=((12, 16), (50, 20))),
    ente(eye="dim", bob=4, head_dy=3, squash=2, sway=-3, lleg=1, rleg=1, lhand=(10, 54), rhand=(54, 54),
         leaves=((8, 30), (55, 34), (14, 16), (46, 12))),
    heap(48, [[(22, 44), (12, 48), (4, 52)], [(42, 44), (52, 49), (60, 53)]],
         [(10, 49), (54, 50), (18, 46), (46, 46)]),
    heap(52, [[(21, 53), (12, 55), (4, 57)], [(43, 53), (52, 55), (60, 57)]],
         [(8, 54), (56, 55), (22, 51), (42, 51)]),
    heap(55, [[(22, 58), (12, 59), (4, 60)], [(42, 58), (52, 59), (60, 60)]], [(10, 57), (54, 57)]),
    heap(0, [[(18, 60), (24, 59)], [(38, 60), (46, 59)], [(28, 61), (34, 60)]], [(14, 59), (50, 59), (32, 58)], with_head=False),
    heap(0, [[(24, 61), (28, 60)]], [(20, 60), (44, 60)], with_head=False),
]
anims = {"idle": idle, "walk": walk, "attack": attack, "hurt": hurt, "death": death}

for name, frames in anims.items():
    strip = Image.new("RGBA", (SIZE * len(frames), SIZE), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * SIZE, 0))
    strip.save(os.path.join(OUT, f"ente_{name}.png"))

if PREVIEW:
    S = 2
    cols = 7
    sheet = Image.new("RGBA", (96 + cols * SIZE * S, len(anims) * SIZE * S + 10), (20, 24, 20, 255))
    d = ImageDraw.Draw(sheet)
    for r, (name, frames) in enumerate(anims.items()):
        d.text((8, r * SIZE * S + 60), name.upper(), fill=(220, 230, 220, 255))
        for i, f in enumerate(frames):
            cell = Image.alpha_composite(Image.new("RGBA", (SIZE, SIZE), (46, 74, 46, 255)), f).resize((SIZE * S, SIZE * S), Image.NEAREST)
            sheet.paste(cell, (96 + i * SIZE * S, r * SIZE * S + 5))
        big = [Image.alpha_composite(Image.new("RGBA", (SIZE, SIZE), (36, 60, 36, 255)), f).resize((SIZE * 5, SIZE * 5), Image.NEAREST).convert("P", palette=Image.ADAPTIVE) for f in frames]
        big[0].save(os.path.join(PREVIEW, f"ente_{name}.gif"), save_all=True, append_images=big[1:], duration=130, loop=0)
    sheet.save(os.path.join(PREVIEW, "ente_hoja.png"))
    big_idle = Image.alpha_composite(Image.new("RGBA", (SIZE, SIZE), (46, 74, 46, 255)), idle[0]).resize((SIZE * 8, SIZE * 8), Image.NEAREST)
    big_idle.save(os.path.join(PREVIEW, "ente_grande.png"))
