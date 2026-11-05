"""Draws the art of Nico's skills pixel by pixel (light from the upper left, 1 px outline), so the
zones they leave on the ground are no longer flat circles and arcs drawn in code.

Writes into assets/sprites/skills/ (cells side by side, one per frame):
    roots_start.png   96x96, 4 frames: the earth cracks in a ring and six root clumps burst out.
    roots_loop.png    96x96, 4 frames (looping): the roots sway and their buds glow.
    roots_end.png     96x96, 3 frames: the roots sink back into the ground.
    current_wave.png  64x64, 6 frames, facing right: a crest of water rises, foams and dissolves
                      into drops (the zone moves and turns it along the cast).
    shadow_puff.png   32x32, 6 frames: a puff of violet smoke where Nico vanishes and reappears.
    cast_burst.png    32x32, 4 frames: a white ring with sparks at Nico's feet when he casts; the
                      game tints it with the skill's color.
    icon_roots.png, icon_current.png, icon_shadow.png   24x24 HUD icons.

    python tools/make_skill_art.py [--preview <folder>]
Original art (no third-party source). Needs Pillow. Then build the frames:
    godot --headless --path . --script res://tools/make_skill_frames.gd
"""
import math
import os
import random
import sys

from PIL import Image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites", "skills")
PREVIEW = sys.argv[sys.argv.index("--preview") + 1] if "--preview" in sys.argv else None

# Roots: the forest guardian's wood, with the skill's green.
WOOD_OUT = (34, 15, 10, 255)
WOOD_DK = (73, 38, 21, 255)
WOOD = (115, 62, 36, 255)
WOOD_HI = (150, 102, 62, 255)
BUD = (70, 184, 58, 255)
BUD_HI = (126, 217, 87, 255)
EARTH = (62, 44, 30, 255)
EARTH_DK = (40, 28, 18, 255)
GREEN_RING = (77, 191, 77, 110)
GREEN_RING_DK = (20, 60, 24, 140)
# Current: deep water, lit water and foam.
WATER_OUT = (24, 52, 120, 255)
WATER_DK = (40, 90, 180, 255)
WATER = (76, 140, 242, 255)
WATER_HI = (150, 200, 255, 255)
FOAM = (236, 246, 255, 255)
# Shadow: violet smoke.
SMOKE_OUT = (36, 18, 64, 255)
SMOKE_DK = (90, 50, 140, 255)
SMOKE = (140, 92, 200, 255)
SMOKE_HI = (200, 165, 245, 255)
# Cast burst: white, tinted by the game.
BURST = (255, 255, 255, 255)
BURST_SOFT = (255, 255, 255, 150)


def cell(size):
    return Image.new("RGBA", (size, size), (0, 0, 0, 0))


def put(img, x, y, color):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), color)


def disc(img, cx, cy, r, color, ry=None):
    ry = r if ry is None else ry
    if r <= 0.0 or ry <= 0.0:
        return
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            if ((x + 0.5 - cx) / r) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                put(img, x, y, color)


def ring(img, cx, cy, r, width, color, ry=None, a0=0.0, a1=math.tau):
    """An elliptic ring of `width` px (optionally only between the angles a0..a1, radians)."""
    ry = r if ry is None else ry
    for y in range(int(cy - ry - width - 1), int(cy + ry + width + 2)):
        for x in range(int(cx - r - width - 1), int(cx + r + width + 2)):
            dx, dy = (x + 0.5 - cx), (y + 0.5 - cy)
            d = math.hypot(dx / r, dy / ry)
            if 1.0 - width / r <= d <= 1.0:
                ang = math.atan2(dy, dx) % math.tau
                if a0 <= a1 and a0 <= ang <= a1 or a0 > a1 and (ang >= a0 or ang <= a1):
                    put(img, x, y, color)


def line(img, x0, y0, x1, y1, color, width=1):
    steps = max(int(math.hypot(x1 - x0, y1 - y0) * 2), 1)
    for i in range(steps + 1):
        t = i / steps
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        if width <= 1:
            put(img, x, y, color)
        else:
            disc(img, x, y, width / 2.0, color)


def outline(img, color):
    """A 1 px edge of `color` around every opaque pixel (drawn into the transparent neighbours)."""
    src = img.copy()
    for y in range(img.height):
        for x in range(img.width):
            if src.getpixel((x, y))[3] > 0:
                continue
            for ox, oy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + ox, y + oy
                if 0 <= nx < img.width and 0 <= ny < img.height and src.getpixel((nx, ny))[3] == 255:
                    put(img, x, y, color)
                    break


def strip(frames, path):
    sheet = Image.new("RGBA", (frames[0].width * len(frames), frames[0].height), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        sheet.paste(frame, (i * frame.width, 0))
    sheet.save(path)
    return sheet


# --- Raíces --------------------------------------------------------------------------------------

ROOT_SIZE = 96
ROOT_RADIUS = 36.0
ROOT_CLUMPS = 6


def root_clump(img, bx, by, grow, sway, seed, lit):
    """A clump of three roots rising from (bx, by): `grow` 0..1 is how far they are out of the
    ground, `sway` -1..1 leans the tips, `lit` brightens the buds."""
    rnd = random.Random(seed)
    for k in range(3):
        angle = -math.pi / 2 + (k - 1) * 0.55 + rnd.uniform(-0.2, 0.2) + sway * 0.18
        length = (15 + rnd.uniform(0, 8)) * grow
        x, y = bx, by
        width = 4.0 if k == 1 else 2.5
        segments = 3
        for s in range(segments):
            seg = length / segments
            bend = rnd.uniform(-0.35, 0.35) + sway * 0.12
            angle += bend
            nx, ny = x + math.cos(angle) * seg, y + math.sin(angle) * seg
            shade = WOOD_HI if (s == 0 and k == 0) else WOOD if s < 2 else WOOD_DK
            if length > 0.0:
                line(img, x, y, nx, ny, shade, width)
            x, y = nx, ny
            width = max(width - 0.5, 1.0)
        if grow > 0.6:
            bud = BUD_HI if lit else BUD
            put(img, x, y, bud)
            put(img, x + 1, y, bud)
            put(img, x, y - 1, BUD_HI if lit else BUD_HI)
    # The hole the roots came out of.
    if grow > 0.0:
        disc(img, bx, by + 1, 2.5 * min(grow * 1.5, 1.0), EARTH_DK, 1.5)


def roots_frame(grow, sway, lit, ring_alpha, crack):
    img = cell(ROOT_SIZE)
    c = ROOT_SIZE / 2.0
    # The green ring on the ground (dark rim first), flatter than a circle so it lies on the floor.
    if ring_alpha > 0:
        rim = GREEN_RING_DK[:3] + (int(GREEN_RING_DK[3] * ring_alpha),)
        fill = GREEN_RING[:3] + (int(GREEN_RING[3] * ring_alpha),)
        ring(img, c, c + 4, ROOT_RADIUS + 2, 4, rim, ROOT_RADIUS * 0.8 + 2)
        ring(img, c, c + 4, ROOT_RADIUS, 2, fill, ROOT_RADIUS * 0.8)
    # Cracks from the middle toward the clumps.
    if crack > 0:
        for i in range(ROOT_CLUMPS):
            a = math.tau * i / ROOT_CLUMPS + 0.3
            rnd = random.Random(100 + i)
            x, y = c, c + 4
            for s in range(4):
                a += rnd.uniform(-0.3, 0.3)
                r = ROOT_RADIUS * 0.22 * crack
                nx, ny = x + math.cos(a) * r, y + math.sin(a) * r * 0.8
                line(img, x, y, nx, ny, EARTH_DK if s % 2 else EARTH)
                x, y = nx, ny
    roots = cell(ROOT_SIZE)
    for i in range(ROOT_CLUMPS):
        a = math.tau * i / ROOT_CLUMPS + 0.3
        bx = c + math.cos(a) * ROOT_RADIUS
        by = c + 4 + math.sin(a) * ROOT_RADIUS * 0.8
        root_clump(roots, bx, by, grow, sway, 7 + i, lit)
    outline(roots, WOOD_OUT)
    img.alpha_composite(roots)
    return img


def make_roots():
    start = [
        roots_frame(0.0, 0.0, False, 0.4, 0.5),
        roots_frame(0.0, 0.0, False, 0.8, 1.0),
        roots_frame(0.45, 0.3, False, 1.0, 1.0),
        roots_frame(0.85, -0.2, False, 1.0, 1.0),
    ]
    loop = [
        roots_frame(1.0, 0.0, True, 1.0, 1.0),
        roots_frame(1.0, 0.5, False, 0.9, 1.0),
        roots_frame(1.0, 0.0, True, 1.0, 1.0),
        roots_frame(1.0, -0.5, False, 0.9, 1.0),
    ]
    end = [
        roots_frame(0.7, 0.3, False, 0.7, 1.0),
        roots_frame(0.35, -0.2, False, 0.4, 0.8),
        roots_frame(0.0, 0.0, False, 0.15, 0.4),
    ]
    return {"roots_start": start, "roots_loop": loop, "roots_end": end}


# --- Corriente -----------------------------------------------------------------------------------

WAVE_SIZE = 64


def wave_frame(i, total):
    """A crest facing right: an arc of water whose front is at the cell's right, rising and foaming
    through the first frames, then breaking into drops."""
    img = cell(WAVE_SIZE)
    t = i / (total - 1)
    c = WAVE_SIZE / 2.0
    rnd = random.Random(40 + i)
    if t < 0.75:
        # The arc: centered left of the cell, so its front is a bow; thicker as it grows.
        spread = 0.55 + 0.35 * t
        reach = 22 + 8 * t
        thick = 7 + 4 * (1.0 - abs(t - 0.4) / 0.4)
        a0, a1 = (-spread) % math.tau, spread
        ring(img, c - 12, c, reach + thick, thick, WATER_DK, (reach + thick) * 0.9, a0, a1)
        ring(img, c - 12, c, reach + thick - 2, thick - 4, WATER, (reach + thick - 2) * 0.9, a0, a1)
        ring(img, c - 12, c - 1, reach + thick - 3, 2, WATER_HI, (reach + thick - 3) * 0.9, a0 + 0.15, a1 - 0.3)
        # Foam along the crest.
        for k in range(int(10 + 8 * t)):
            a = rnd.uniform(-spread, spread)
            r = reach + thick - rnd.uniform(0, 2.5)
            put(img, c - 12 + math.cos(a) * r, c + math.sin(a) * r * 0.9, FOAM)
        outline(img, WATER_OUT)
    else:
        # Breaking: the water scatters into drops that fall.
        fall = (t - 0.75) / 0.25
        for k in range(26):
            a = rnd.uniform(-0.9, 0.9)
            r = 30 + rnd.uniform(0, 8) + fall * 6
            x, y = c - 12 + math.cos(a) * r, c + math.sin(a) * r * 0.9 + fall * 4
            color = [WATER, WATER_HI, FOAM][k % 3]
            put(img, x, y, color)
            if k % 4 == 0:
                put(img, x + 1, y, WATER_DK)
    return img


def make_wave():
    return {"current_wave": [wave_frame(i, 6) for i in range(6)]}


# --- Sombra --------------------------------------------------------------------------------------

PUFF_SIZE = 32


def puff_frame(i, total):
    img = cell(PUFF_SIZE)
    t = i / (total - 1)
    c = PUFF_SIZE / 2.0
    rnd = random.Random(60 + i)
    size = 5 + 9 * t
    blobs = 5
    for k in range(blobs):
        a = math.tau * k / blobs + t * 0.8
        d = size * 0.55
        x, y = c + math.cos(a) * d, c + 2 + math.sin(a) * d * 0.8 - t * 5
        r = size * 0.5 * (1.0 - t * 0.35) + rnd.uniform(-1, 1)
        if r <= 0.5:
            continue
        disc(img, x, y, r, SMOKE_DK)
        disc(img, x - 1, y - 1, r * 0.6, SMOKE)
        disc(img, x - 1.5, y - 1.5, r * 0.3, SMOKE_HI)
    if t < 0.9:
        outline(img, SMOKE_OUT)
    # Thin out at the end: every other pixel goes.
    if t > 0.6:
        keep = 1.0 - (t - 0.6) / 0.4
        for y in range(img.height):
            for x in range(img.width):
                if img.getpixel((x, y))[3] > 0 and rnd.random() > keep:
                    put(img, x, y, (0, 0, 0, 0))
    return img


def make_puff():
    return {"shadow_puff": [puff_frame(i, 6) for i in range(6)]}


# --- Cast burst ----------------------------------------------------------------------------------

BURST_SIZE = 32


def burst_frame(i, total):
    img = cell(BURST_SIZE)
    t = i / (total - 1)
    c = BURST_SIZE / 2.0
    r = 4 + 10 * t
    alpha = int(255 * (1.0 - t * 0.7))
    ring(img, c, c + 6, r, 2, BURST[:3] + (alpha,), r * 0.45)
    rnd = random.Random(80 + i)
    for k in range(8):
        a = math.tau * k / 8 + 0.2
        d = r + 2 + t * 4
        put(img, c + math.cos(a) * d, c + 6 + math.sin(a) * d * 0.45 - t * 6, BURST_SOFT[:3] + (alpha,))
    return img


def make_burst():
    return {"cast_burst": [burst_frame(i, 4) for i in range(4)]}


# --- Icons ---------------------------------------------------------------------------------------

ICON = 24


def icon_roots():
    img = cell(ICON)
    disc(img, 12, 18, 9, EARTH, 3.5)
    roots = cell(ICON)
    root_clump(roots, 12, 17, 1.0, 0.0, 3, True)
    outline(roots, WOOD_OUT)
    img.alpha_composite(roots)
    return img


def icon_current():
    img = cell(ICON)
    ring(img, 2, 12, 15, 7, WATER_DK, 13, (-0.9) % math.tau, 0.9)
    ring(img, 2, 12, 13, 4, WATER, 11, (-0.8) % math.tau, 0.8)
    ring(img, 2, 11, 12, 2, WATER_HI, 10, (-0.5) % math.tau, 0.6)
    for k, a in enumerate((-0.7, -0.3, 0.1, 0.5, 0.8)):
        put(img, 2 + math.cos(a) * 15.5, 12 + math.sin(a) * 13.5, FOAM)
    outline(img, WATER_OUT)
    return img


def icon_shadow():
    img = cell(ICON)
    disc(img, 12, 12, 9, SMOKE_DK)
    disc(img, 10, 10, 7, SMOKE)
    disc(img, 9, 9, 3, SMOKE_HI)
    # A bite of darkness: the crescent of a moon.
    disc(img, 16, 10, 7, (0, 0, 0, 0))
    outline(img, SMOKE_OUT)
    # Two watching eyes in the dark of the bite.
    put(img, 15, 11, SMOKE_HI)
    put(img, 18, 11, SMOKE_HI)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    sets = {}
    for maker in (make_roots, make_wave, make_puff, make_burst):
        sets.update(maker())
    sheets = {}
    for name, frames in sets.items():
        sheets[name] = strip(frames, os.path.join(OUT, name + ".png"))
    icons = {"icon_roots": icon_roots(), "icon_current": icon_current(), "icon_shadow": icon_shadow()}
    for name, icon in icons.items():
        icon.save(os.path.join(OUT, name + ".png"))
        sheets[name] = icon
    print("skill art written to", os.path.normpath(OUT))
    if PREVIEW:
        os.makedirs(PREVIEW, exist_ok=True)
        width = max(s.width for s in sheets.values())
        height = sum(s.height + 4 for s in sheets.values())
        contact = Image.new("RGBA", (width, height), (70, 110, 70, 255))
        y = 0
        for sheet in sheets.values():
            contact.paste(sheet, (0, y), sheet)
            y += sheet.height + 4
        contact.resize((contact.width * 3, contact.height * 3), Image.NEAREST).save(os.path.join(PREVIEW, "skills_x3.png"))


if __name__ == "__main__":
    main()
