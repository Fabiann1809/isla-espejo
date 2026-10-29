"""Draws the Esqueleto (a skeleton that clubs with a bone) with Pillow, from the palette of the
reference sheet. Usage from the repo root:  python tools/make_esqueleto_art.py [--preview <folder>]
Writes assets/sprites/esqueleto/esqueleto_<animation>.png (idle, walk, attack, hurt, death; 32x32
cells, facing the viewer). With --preview it also writes a labeled contact sheet and one GIF per
animation to <folder> (not part of the game).
Then: godot --headless --path . --script res://tools/make_esqueleto.gd"""
import os
import sys

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites", "esqueleto")
PREVIEW = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None
SIZE = 32

OUTLINE = (42, 20, 15, 255)
LIGHT = (250, 232, 196, 255)
BONE = (232, 199, 154, 255)
SHADE = (190, 148, 98, 255)
DEEP = (134, 92, 56, 255)
SOCKET = (24, 11, 9, 255)
EMBER = (214, 72, 44, 255)
WHITE = (244, 244, 240, 255)
WHITE_SHADE = (176, 184, 192, 255)
WRAP = (150, 70, 52, 255)


def rect(c, x0, y0, x1, y1, color):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c[(x, y)] = color


def line(c, x0, y0, x1, y1, color, thick=1):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        x = round(x0 + (x1 - x0) * i / n)
        y = round(y0 + (y1 - y0) * i / n)
        for t in range(thick):
            c[(x + t, y)] = color


def joint(c, x, y, color=BONE):
    rect(c, x, y, x + 1, y + 1, color)
    c[(x, y)] = LIGHT if color == BONE else color


def bone(c, x0, y0, x1, y1):
    """A club: a thick white bone with a knob at each end and a strip of cloth wound at the grip."""
    line(c, x0, y0, x1, y1, WHITE, 2)
    line(c, x0, y0 + 1, x1, y1 + 1, WHITE_SHADE, 1)
    for (x, y) in ((x0, y0), (x1, y1)):
        rect(c, x - 1, y - 1, x + 1, y + 1, WHITE)
        c[(x + 1, y + 1)] = WHITE_SHADE
    mx, my = (x0 * 3 + x1) // 4, (y0 * 3 + y1) // 4
    rect(c, mx, my, mx + 1, my + 1, WRAP)


def to_image(c, tint=0.0):
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    for (x, y), col in c.items():
        y += 1  # one row of headroom for the outline of the skull
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
                    px[x, y] = (int(r + (255 - r) * tint), int(g + (245 - g) * tint), int(b + (230 - b) * tint), 255)
    return img


def skull(c, hx, hy, eyes="n", jaw_open=0):
    """A 12x11 skull at (hx, hy): brow, cheekbones, glowing sockets and a row of teeth."""
    rect(c, hx, hy + 1, hx + 11, hy + 8, BONE)
    rect(c, hx + 2, hy, hx + 9, hy, LIGHT)
    rect(c, hx + 1, hy + 1, hx + 3, hy + 2, LIGHT)
    rect(c, hx + 11, hy + 2, hx + 11, hy + 8, SHADE)
    rect(c, hx + 1, hy + 9, hx + 10, hy + 9, SHADE)
    rect(c, hx + 2, hy + 10, hx + 9, hy + 10, DEEP)
    rect(c, hx + 2, hy + 4, hx + 4, hy + 4, SHADE)       # brow
    rect(c, hx + 7, hy + 4, hx + 9, hy + 4, SHADE)
    c[(hx, hy + 7)] = SHADE
    c[(hx + 10, hy + 7)] = SHADE
    for ex in (hx + 2, hx + 7):
        if eyes == "x":
            for (a, b) in ((0, 0), (2, 0), (1, 1), (0, 2), (2, 2)):
                c[(ex + a, hy + 5 + b)] = SOCKET
        else:
            rect(c, ex, hy + 5, ex + 2, hy + 7, SOCKET)
            if eyes == "n":
                c[(ex + 1, hy + 6)] = EMBER
            elif eyes == "blink":
                rect(c, ex, hy + 5, ex + 2, hy + 6, BONE)
    rect(c, hx + 5, hy + 7, hx + 6, hy + 8, SOCKET)        # nose
    for i, tx in enumerate(range(hx + 2, hx + 10)):         # teeth
        c[(tx, hy + 9 + jaw_open)] = LIGHT if i % 2 == 0 else SHADE
    if jaw_open:
        rect(c, hx + 3, hy + 9, hx + 8, hy + 9, SOCKET)


def skeleton(bob=0, dx=0, lleg=0, rleg=0, larm=((8, 17), (8, 21)), rarm=((23, 17), (23, 21)),
             club=None, eyes="n", tint=0.0, head_dx=0, head_dy=0, lean=0, jaw=0):
    c = {}
    ox, oy = dx, bob
    # legs: femur, knee knob, shin and a foot of small bones; a lifted leg is shorter
    for side, lift in ((0, lleg), (1, rleg)):
        x = 12 + side * 6 + ox
        rect(c, x, 22 + oy, x + 1, 24 + oy - lift // 2, BONE)
        joint(c, x, 24 + oy - lift // 2, SHADE)
        rect(c, x, 25 + oy - lift, x + 1, 26 - lift, BONE)
        rect(c, x - 1 + side * 2, 27 - lift, x + 2 + side * 2, 27 - lift, SHADE)
    # pelvis
    rect(c, 12 + ox, 20 + oy, 19 + ox, 22 + oy, BONE)
    rect(c, 15 + ox, 21 + oy, 16 + ox, 22 + oy, SOCKET)
    rect(c, 12 + ox, 22 + oy, 19 + ox, 22 + oy, SHADE)
    # spine and rib cage: bright ribs with dark gaps, the spine down the middle
    tx = ox + lean
    rect(c, 15 + tx, 13 + oy, 16 + tx, 20 + oy, BONE)
    rect(c, 10 + tx, 14 + oy, 21 + tx, 14 + oy, LIGHT)  # collarbones
    for ry, half in ((15, 5), (17, 5), (19, 4)):
        rect(c, 16 - half + tx, ry + oy, 15 + half + tx, ry + oy, BONE)
        rect(c, 16 - half + tx, ry + 1 + oy, 15 + half + tx, ry + 1 + oy, SOCKET)
        rect(c, 15 + tx, ry + 1 + oy, 16 + tx, ry + 1 + oy, BONE)
        c[(15 + half + tx, ry + oy)] = SHADE
    # arms: shoulder -> elbow -> hand, with knobs at the elbow and the hand
    for shoulder, (elbow, hand) in (((10, 14), larm), ((21, 14), rarm)):
        sx, sy = shoulder[0] + tx, shoulder[1] + oy
        line(c, sx, sy, elbow[0] + ox, elbow[1] + oy, BONE, 2)
        line(c, elbow[0] + ox, elbow[1] + oy, hand[0] + ox, hand[1] + oy, BONE, 2)
        joint(c, elbow[0] + ox, elbow[1] + oy, SHADE)
        rect(c, hand[0] + ox, hand[1] + oy, hand[0] + 1 + ox, hand[1] + 1 + oy, LIGHT)
    # skull
    skull(c, 10 + ox + head_dx + lean, 1 + oy + head_dy, eyes, jaw)
    rect(c, 15 + ox + lean, 12 + oy, 16 + ox + lean, 13 + oy, SHADE)   # neck bone
    if club:
        bone(c, *club)
    return to_image(c, tint)


def pile(skull_x, skull_y, bones, skull_on=True):
    """Bones on the ground: a skull and a few loose bones."""
    c = {}
    if skull_on:
        skull(c, skull_x, skull_y, "x")
    for (x0, y0, x1, y1) in bones:
        bone(c, x0, y0, x1, y1)
    return to_image(c)


HOLD = (24, 21, 26, 26)
idle = [
    skeleton(club=HOLD), skeleton(club=HOLD, jaw=0), skeleton(bob=-1, club=(24, 20, 26, 25), larm=((8, 17), (8, 20))),
    skeleton(bob=-1, club=(24, 20, 26, 25), larm=((8, 17), (8, 20))), skeleton(club=HOLD), skeleton(eyes="blink", club=HOLD),
]
walk = [
    skeleton(club=HOLD),
    skeleton(bob=-1, lleg=2, larm=((9, 16), (10, 19)), rarm=((22, 18), (22, 22)), club=(23, 22, 25, 27), lean=0),
    skeleton(club=HOLD),
    skeleton(club=HOLD),
    skeleton(bob=-1, rleg=2, larm=((7, 18), (7, 22)), rarm=((24, 16), (23, 19)), club=(24, 19, 26, 24)),
    skeleton(club=HOLD),
]
attack = [
    skeleton(club=HOLD),                                                                          # ready
    skeleton(rarm=((24, 15), (24, 12)), club=(24, 9, 26, 13)),                                    # lifts the club
    skeleton(bob=-1, rarm=((25, 11), (24, 7)), club=(24, 3, 27, 8), lean=-1, larm=((8, 16), (8, 19))),  # overhead
    skeleton(bob=-1, rarm=((25, 10), (24, 6)), club=(23, 2, 27, 7), lean=-1, larm=((7, 15), (7, 18)), jaw=1),
    skeleton(bob=0, rarm=((25, 10), (24, 6)), club=(23, 2, 27, 7), lean=-1, larm=((7, 15), (7, 18)), jaw=1),  # tense
    skeleton(dx=1, rarm=((25, 16), (28, 17)), club=(27, 17, 30, 21), lean=1, jaw=1),               # the swing
    skeleton(dx=1, rarm=((24, 19), (26, 23)), club=(25, 23, 29, 27), lean=1),                      # follow-through
]
hurt = [
    skeleton(tint=0.7, eyes="x", head_dx=-1, dx=-1, larm=((7, 15), (6, 12)), rarm=((24, 15), (25, 12))),
    skeleton(eyes="x", head_dx=-1, dx=-2, bob=1, larm=((7, 15), (6, 11)), rarm=((24, 15), (25, 11)), jaw=1),
    skeleton(eyes="x", head_dx=-1, dx=-1, larm=((7, 16), (6, 13)), rarm=((24, 16), (25, 13)), club=(25, 11, 27, 15)),
    skeleton(eyes="x", dx=-1, club=HOLD),
    skeleton(club=HOLD),
    skeleton(club=HOLD),
]
death = [
    skeleton(tint=0.5, eyes="x", dx=-1, head_dx=-1, larm=((7, 15), (6, 12)), rarm=((24, 15), (25, 12)), jaw=1),
    skeleton(eyes="x", dx=-2, bob=3, lean=-2, head_dy=2, larm=((7, 18), (6, 22)), rarm=((22, 21), (24, 25)), lleg=1, rleg=1, jaw=1),
    pile(9, 18, [(17, 23, 23, 25), (4, 24, 9, 26), (21, 26, 27, 27)]),
    pile(10, 19, [(2, 25, 8, 26), (19, 24, 26, 26), (12, 27, 17, 27)]),
    pile(11, 20, [(4, 26, 9, 27), (20, 26, 26, 27)]),
    pile(0, 0, [(8, 26, 11, 27), (17, 26, 21, 27), (13, 25, 15, 26)], skull_on=False),
    pile(0, 0, [(10, 27, 12, 27), (19, 27, 21, 27)], skull_on=False),
]
anims = {"idle": idle, "walk": walk, "attack": attack, "hurt": hurt, "death": death}

for name, frames in anims.items():
    strip = Image.new("RGBA", (SIZE * len(frames), SIZE), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        strip.paste(f, (i * SIZE, 0))
    strip.save(os.path.join(OUT, f"esqueleto_{name}.png"))

if PREVIEW:
    S = 4
    cols = 7
    sheet = Image.new("RGBA", (96 + cols * SIZE * S, len(anims) * SIZE * S + 10), (28, 34, 48, 255))
    d = ImageDraw.Draw(sheet)
    for r, (name, frames) in enumerate(anims.items()):
        d.text((8, r * SIZE * S + 60), name.upper(), fill=(220, 230, 220, 255))
        for i, f in enumerate(frames):
            cell = Image.alpha_composite(Image.new("RGBA", (SIZE, SIZE), (70, 62, 52, 255)), f).resize((SIZE * S, SIZE * S), Image.NEAREST)
            sheet.paste(cell, (96 + i * SIZE * S, r * SIZE * S + 5))
        big = [Image.alpha_composite(Image.new("RGBA", (SIZE, SIZE), (60, 52, 44, 255)), f).resize((SIZE * 8, SIZE * 8), Image.NEAREST).convert("P", palette=Image.ADAPTIVE) for f in frames]
        big[0].save(os.path.join(PREVIEW, f"esqueleto_{name}.gif"), save_all=True, append_images=big[1:], duration=130, loop=0)
    sheet.save(os.path.join(PREVIEW, "esqueleto_hoja.png"))
