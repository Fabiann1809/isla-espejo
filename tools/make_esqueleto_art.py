"""Draws the Esqueleto (a small skeleton that clubs with a bone) with Pillow, from the palette of the
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
LIGHT = (247, 224, 186, 255)
BONE = (232, 199, 154, 255)
SHADE = (190, 148, 98, 255)
RIB = (150, 104, 64, 255)
SOCKET = (26, 13, 10, 255)
WHITE = (244, 244, 240, 255)
WHITE_SHADE = (190, 196, 200, 255)


def rect(c, x0, y0, x1, y1, color):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            c[(x, y)] = color


def line(c, x0, y0, x1, y1, color, thick=2):
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        x = round(x0 + (x1 - x0) * i / n)
        y = round(y0 + (y1 - y0) * i / n)
        for t in range(thick):
            c[(x + t, y)] = color


def bone(c, x0, y0, x1, y1):
    """A club: a white bone with a knob at each end."""
    line(c, x0, y0, x1, y1, WHITE, 1)
    for (x, y) in ((x0, y0), (x1, y1)):
        rect(c, x - 1, y - 1, x, y, WHITE)
    c[(x0 - 1, y0 - 1)] = WHITE_SHADE
    c[(x1, y1)] = WHITE_SHADE


def skeleton(bob=0, dx=0, lleg=0, rleg=0, larm=(9, 19), rarm=(22, 19), club=None, eyes="n",
             tint=0.0, head_dx=0, lean=0):
    c = {}
    ox, oy = dx, bob
    # legs (the lifted leg is shorter and a step forward)
    for side, lift in ((0, lleg), (1, rleg)):
        x = 12 + side * 6
        top = 21 + oy
        foot = 26 - lift + (0 if lift == 0 else 0)
        rect(c, x + ox, top, x + 1 + ox, foot, BONE)
        rect(c, x - 1 + ox + side * 2, foot, x + 1 + ox + side * 2, foot + 1, SHADE if side else BONE)
    rect(c, 13 + ox, 21 + oy, 18 + ox, 21 + oy, SHADE)
    # torso with ribs
    rect(c, 12 + ox + lean, 14 + oy, 19 + ox + lean, 20 + oy, BONE)
    for ry in (15, 17, 19):
        rect(c, 13 + ox + lean, ry + oy, 18 + ox + lean, ry + oy, RIB)
    rect(c, 19 + ox + lean, 14 + oy, 19 + ox + lean, 20 + oy, SHADE)
    # arms
    line(c, 11 + ox + lean, 15 + oy, larm[0] + ox, larm[1] + oy, BONE)
    line(c, 20 + ox + lean, 15 + oy, rarm[0] + ox, rarm[1] + oy, BONE)
    rect(c, larm[0] + ox, larm[1] + oy, larm[0] + 1 + ox, larm[1] + 1 + oy, SHADE)
    rect(c, rarm[0] + ox, rarm[1] + oy, rarm[0] + 1 + ox, rarm[1] + 1 + oy, SHADE)
    # head: rounded box, narrower jaw
    hx, hy = 11 + ox + head_dx + lean, 5 + oy
    rect(c, hx, hy + 1, hx + 9, hy + 7, BONE)
    rect(c, hx + 1, hy, hx + 8, hy, LIGHT)
    rect(c, hx + 1, hy + 8, hx + 8, hy + 8, SHADE)
    rect(c, hx + 1, hy + 1, hx + 2, hy + 2, LIGHT)
    rect(c, hx + 9, hy + 2, hx + 9, hy + 7, SHADE)
    for ex in (hx + 1, hx + 7):
        if eyes == "n":
            rect(c, ex, hy + 3, ex + 1, hy + 5, SOCKET)
        elif eyes == "x":
            for p in ((0, 3), (1, 4), (0, 5), (1, 3), (0, 4), (1, 5)):
                pass
            c[(ex, hy + 3)] = SOCKET
            c[(ex + 1, hy + 3)] = BONE
            c[(ex, hy + 4)] = BONE
            c[(ex + 1, hy + 4)] = SOCKET
            c[(ex, hy + 5)] = SOCKET
            c[(ex + 1, hy + 5)] = BONE
        elif eyes == "blink":
            rect(c, ex, hy + 4, ex + 1, hy + 4, SOCKET)
    c[(hx + 4, hy + 6)] = SOCKET
    c[(hx + 5, hy + 6)] = SOCKET
    for tx in (hx + 2, hx + 4, hx + 6):
        c[(tx, hy + 8)] = RIB
    if club:
        bone(c, *club)

    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    for (x, y), col in c.items():
        if 0 <= x < SIZE and 0 <= y < SIZE:
            px[x, y] = col
    outline = []
    for y in range(SIZE):
        for x in range(SIZE):
            if px[x, y][3] == 0 and any(0 <= x + a < SIZE and 0 <= y + b < SIZE and px[x + a, y + b][3]
                                        for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                outline.append((x, y))
    for p in outline:
        px[p] = OUTLINE
    if tint:
        for y in range(SIZE):
            for x in range(SIZE):
                r, g, b, a = px[x, y]
                if a:
                    px[x, y] = (int(r + (255 - r) * tint), int(g + (245 - g) * tint), int(b + (230 - b) * tint), 255)
    return img


def pile(skull_x, skull_y, bones, eyes="x", skull=True):
    """Bones on the ground: a skull and a few loose bones."""
    c = {}
    if skull:
        rect(c, skull_x, skull_y + 1, skull_x + 7, skull_y + 5, BONE)
        rect(c, skull_x + 1, skull_y, skull_x + 6, skull_y, LIGHT)
        rect(c, skull_x + 1, skull_y + 6, skull_x + 6, skull_y + 6, SHADE)
        c[(skull_x + 1, skull_y + 3)] = SOCKET
        c[(skull_x + 2, skull_y + 3)] = SOCKET
        c[(skull_x + 5, skull_y + 3)] = SOCKET
        c[(skull_x + 6, skull_y + 3)] = SOCKET
    for (x0, y0, x1, y1) in bones:
        bone(c, x0, y0, x1, y1)
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    px = img.load()
    for (x, y), col in c.items():
        if 0 <= x < SIZE and 0 <= y < SIZE:
            px[x, y] = col
    outline = [(x, y) for y in range(SIZE) for x in range(SIZE)
               if px[x, y][3] == 0 and any(0 <= x + a < SIZE and 0 <= y + b < SIZE and px[x + a, y + b][3]
                                           for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for p in outline:
        px[p] = OUTLINE
    return img


IDLE_CLUB = (23, 20, 25, 24)
idle = [
    skeleton(club=IDLE_CLUB), skeleton(bob=0, club=IDLE_CLUB), skeleton(bob=-1, club=(23, 19, 25, 23)),
    skeleton(bob=-1, club=(23, 19, 25, 23)), skeleton(club=IDLE_CLUB), skeleton(eyes="blink", club=IDLE_CLUB),
]
walk = [
    skeleton(bob=0, lleg=0, rleg=0, larm=(9, 19), rarm=(22, 19), club=IDLE_CLUB),
    skeleton(bob=-1, lleg=2, rleg=0, larm=(9, 18), rarm=(22, 20), club=(23, 21, 25, 25)),
    skeleton(bob=0, lleg=0, rleg=0, larm=(9, 19), rarm=(22, 19), club=IDLE_CLUB),
    skeleton(bob=0, lleg=0, rleg=0, larm=(9, 19), rarm=(22, 19), club=IDLE_CLUB),
    skeleton(bob=-1, lleg=0, rleg=2, larm=(9, 20), rarm=(22, 18), club=(23, 20, 25, 23)),
    skeleton(bob=0, lleg=0, rleg=0, larm=(9, 19), rarm=(22, 19), club=IDLE_CLUB),
]
attack = [
    skeleton(club=IDLE_CLUB),                                                   # ready
    skeleton(bob=0, rarm=(22, 15), club=(23, 12, 25, 16), lean=0),              # lifts the club
    skeleton(bob=-1, rarm=(22, 11), club=(23, 5, 26, 10), lean=-1),             # overhead
    skeleton(bob=-1, rarm=(22, 10), club=(22, 4, 26, 9), lean=-1, larm=(9, 16)),  # holds it, tense
    skeleton(bob=0, rarm=(22, 10), club=(22, 4, 26, 9), lean=-1, larm=(9, 16)),   # about to strike
    skeleton(bob=0, dx=1, rarm=(24, 18), club=(25, 18, 30, 21), lean=1),        # the swing
    skeleton(bob=0, dx=1, rarm=(23, 20), club=(24, 21, 29, 26), lean=1),        # follow-through
]
hurt = [
    skeleton(tint=0.7, eyes="x", head_dx=-1, dx=-1, larm=(8, 16), rarm=(23, 16)),
    skeleton(eyes="x", head_dx=-1, dx=-2, bob=1, larm=(8, 15), rarm=(23, 15)),
    skeleton(eyes="x", head_dx=-1, dx=-1, larm=(8, 16), rarm=(23, 16), club=(24, 15, 26, 19)),
    skeleton(eyes="x", dx=-1, larm=(9, 18), rarm=(22, 18), club=IDLE_CLUB),
    skeleton(club=IDLE_CLUB),
    skeleton(club=IDLE_CLUB),
]
death = [
    skeleton(tint=0.5, eyes="x", dx=-1, head_dx=-1, larm=(8, 15), rarm=(23, 15)),
    skeleton(eyes="x", dx=-2, bob=2, lean=-1, larm=(8, 17), rarm=(22, 21), lleg=1, rleg=1),
    pile(10, 17, [(17, 23, 22, 25), (7, 24, 11, 26), (22, 22, 25, 25)], skull=True),
    pile(11, 21, [(4, 25, 9, 26), (19, 24, 25, 26), (13, 26, 17, 27)]),
    pile(12, 23, [(5, 26, 9, 27), (20, 26, 25, 27)]),
    pile(0, 0, [(9, 26, 11, 27), (18, 26, 21, 27), (14, 25, 15, 26)], skull=False),
    pile(0, 0, [(11, 27, 12, 27), (19, 27, 20, 27)], skull=False),
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
