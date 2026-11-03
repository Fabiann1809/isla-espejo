"""Builds the Verdugo de piedra's strips from the team's pack and draws its shockwave pixel by pixel.

Its body keeps the team's art (`assets/sprites/verdugo_piedra/source/<animation>_right.png`, 128 px
cells), brought to the game's 80 px cells here, from the sources every time (so it does not matter
whether tools/make_temple_enemy_art.py ran before):
- the pack was cut out of a pale grey background and left chunks of it on the figure (between the
  hammer and the legs, behind the back, around the head): those are cleared before scaling, and the
  outline is closed again after it;
- the black line under one attack frame (the ground of another drawing) goes, and that frame, drawn
  8 px above the floor, is put back on its feet;
- the walk of the pack stomps with the same leg twice and holds the stance in half its frames: its
  legs are redrawn here (thigh, knee, shin and foot blocks in the pack's stone colors, light from
  the upper left) as an 8-frame cycle where each leg lifts and plants in turn, under the pack's upper
  body and swinging hammer, and scaled with the rest so both look alike.
The shockwave of its slam was a circle drawn in code; here it is a ring of dust and lava drawn at the
size it has in the game: one frame per radius, from the burst under the hammer to the full
`wave_max_radius` (110 px), its leading edge white-hot at first and cooling to dust as it spreads.

Writes into `assets/sprites/verdugo_piedra/`:
    verdugo_piedra_<animation>.png   80x80 cells (feet on row 67)
    verdugo_piedra_wave.png          232x232 cells, ring centered on the cell: 16 frames, radius
                                     110 * k / 15 (StoneExecutioner picks the nearest one)

    python tools/make_verdugo_piedra_art.py
tools/enemy_aseprite.lua keeps an editable `source/verdugo_piedra.aseprite` (extras="wave:20").
Needs Pillow.
"""
import math
import os

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "verdugo_piedra")
SOURCE = os.path.join(OUT, "source")
ANIMATIONS = ("idle", "walk", "attack", "special", "hurt", "death")
SOURCE_CELL = 128
CELL = 80
## As tools/make_temple_enemy_art.py scales: pixels averaged under this alpha are dropped.
ALPHA_CUT = 110
## Dark color that closes the outline.
OUTLINE = (14, 9, 9)
## Last row of the feet in the source cells (row 67 once scaled).
SOURCE_GROUND = 108
## Frames drawn off the floor that land on it: (animation, frame).
GROUNDED = [("attack", 3)]

WAVE_RADIUS = 110.0
WAVE_BAND = 12.0
WAVE_FRAMES = 16
WAVE_CELL = 232

PALETTE = {
    "O": (30, 18, 16),
    # dust, from its stone
    "D0": (70, 52, 46),
    "D1": (110, 86, 74),
    "D2": (152, 124, 106),
    "D3": (196, 170, 146),
    # lava
    "S2": (196, 70, 26),
    "S3": (238, 124, 36),
    "S4": (252, 176, 64),
    "Y": (255, 218, 104),
    "Y2": (255, 248, 200),
}

## The legs' stone, picked from the pack's legs (deep shadow to highlight) and its lava.
LEG = {
    "k": (10, 6, 8),
    "0": (48, 34, 44),
    "1": (70, 50, 60),
    "2": (98, 72, 76),
    "3": (130, 98, 92),
    "4": (166, 128, 112),
    "l0": (176, 76, 22),
    "l1": (240, 140, 40),
    "l2": (255, 206, 96),
}


def luminance(c):
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]


def is_hot(c):
    return c[3] > 0 and c[0] > 200 and c[1] > 90 and c[2] < 110


def frames_of(anim):
    strip = Image.open(os.path.join(SOURCE, "%s_right.png" % anim)).convert("RGBA")
    return [strip.crop((i * SOURCE_CELL, 0, (i + 1) * SOURCE_CELL, SOURCE_CELL))
            for i in range(strip.width // SOURCE_CELL)]


# --- cleaning the pack's frames (128 px) ---------------------------------------------------

def near_hot(px, x, y, size, reach=2):
    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            if 0 <= x + dx < size and 0 <= y + dy < size and is_hot(px[x + dx, y + dy]):
                return True
    return False


def clear_matte(frame):
    """The pale grey background left on the figure becomes transparent: patches of grey pixels
    walled in by the outline or bare to the outside. The stone's own highlights are pale too, but
    pinker, and they sit among the stone's middle tones, so they stay; white-hot fire stays too."""
    px = frame.load()
    size = frame.width

    def pale(c):
        spread = max(c[:3]) - min(c[:3])
        return c[3] > 0 and (luminance(c) >= 95 and c[0] - c[2] <= 32 and spread <= 34
                             or luminance(c) >= 50 and spread <= 18)

    def dark(p):
        return not (0 <= p[0] < size and 0 <= p[1] < size) or px[p][3] == 0 or luminance(px[p]) < 40

    seen = set()
    for y in range(size):
        for x in range(size):
            if (x, y) in seen or not pale(px[x, y]) or near_hot(px, x, y, size):
                continue
            patch, todo = [], [(x, y)]
            seen.add((x, y))
            while todo:
                p = todo.pop()
                patch.append(p)
                for n in ((p[0] + 1, p[1]), (p[0] - 1, p[1]), (p[0], p[1] + 1), (p[0], p[1] - 1)):
                    if n not in seen and 0 <= n[0] < size and 0 <= n[1] < size and pale(px[n])                             and not near_hot(px, n[0], n[1], size):
                        seen.add(n)
                        todo.append(n)
            inside = set(patch)
            border = {n for p in patch for n in ((p[0] + 1, p[1]), (p[0] - 1, p[1]), (p[0], p[1] + 1), (p[0], p[1] - 1))
                      if n not in inside}
            # near-white crumbs are the matte wherever they are
            white = all(min(px[p][:3]) >= 225 for p in patch)
            if white or sum(1 for n in border if dark(n)) >= 0.5 * len(border):
                for p in patch:
                    px[p] = (0, 0, 0, 0)


def pieces_of(frame):
    px = frame.load()
    size = frame.width
    seen = set()
    pieces = []
    for y in range(size):
        for x in range(size):
            if (x, y) in seen or px[x, y][3] == 0:
                continue
            piece, todo = [], [(x, y)]
            seen.add((x, y))
            while todo:
                p = todo.pop()
                piece.append(p)
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        n = (p[0] + dx, p[1] + dy)
                        if 0 <= n[0] < size and 0 <= n[1] < size and n not in seen and px[n][3] > 0:
                            seen.add(n)
                            todo.append(n)
            pieces.append(piece)
    return pieces


def drop_strays(frame):
    """Small dark bits apart from the figure (lines of other drawings, matte crumbs) go; sparks,
    which are bright, stay."""
    px = frame.load()
    for piece in pieces_of(frame):
        if len(piece) < 60 and sum(luminance(px[p]) for p in piece) / len(piece) < 70:
            for p in piece:
                px[p] = (0, 0, 0, 0)


def ground(frame):
    """Moves the figure down until its feet are on the floor row."""
    bottom = frame.getchannel("A").getbbox()[3] - 1
    out = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    out.paste(frame, (0, SOURCE_GROUND - bottom))
    return out


# --- the walk's legs (drawn at the source's 128 px, scaled with the rest) --------------------

## Upper bodies of the walk: source walk frame, row where the legs start under the belt, x of the
## belt's middle, and the boxes (y0, y1, x0, x1) cleared for the new legs: under the belt, right of
## the hammer and below the fist.
UPPERS = {
    0: (88, 74, [(88, 95, 54, 86), (95, 110, 54, 106)]),
    1: (86, 76, [(86, 92, 56, 84), (92, 110, 56, 106)]),
    2: (86, 72, [(86, 92, 58, 90), (92, 110, 49, 106)]),
    3: (86, 76, [(86, 95, 61, 84), (95, 98, 61, 106), (98, 110, 54, 106)]),
}
## Order of the upper bodies along the cycle: the hammer swings forward on every step.
WALK_UPPERS = [0, 1, 2, 3, 0, 1, 2, 3]
WALK_FRAMES = 8
HIP_SPREAD = 13
STRIDE = 4.0
LIFT = 12.0


def grain(x, y):
    """A stable speckle of the stone: -1, 0 or +1 tone."""
    h = (x * 73856093 ^ y * 19349663) & 0xffff
    return -1 if h % 13 == 0 else 1 if h % 11 == 0 else 0


def block(c, top, bottom, w, lava=False):
    """A stone block of the leg from `top` (x, y) to `bottom` (x, y), `w` px to each side: lit on
    its left, dark on its right, its top edge catching the light, with a 1 px seam around it."""
    (tx, ty), (bx, by) = top, bottom
    body = {}
    for y in range(round(ty), round(by) + 1):
        t = (y - ty) / max(1.0, by - ty)
        cx = tx + (bx - tx) * t
        # rounded corners: the first and last rows are narrower
        inset = 2 if y in (round(ty), round(by)) else 1 if y in (round(ty) + 1, round(by) - 1) else 0
        for x in range(round(cx - w) + inset, round(cx + w) - inset + 1):
            u = (x + 0.5 - cx) / w
            tone = 3 if u < -0.45 else 1 if u > 0.5 else 2
            if y <= round(ty) + 1 and u < 0.5:
                tone += 1
            if y >= round(by) - 1:
                tone -= 1
            tone += grain(x, y)
            body[(x, y)] = str(max(0, min(4, tone)))
    for (x, y) in body:
        for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if n not in body:
                c[n] = "k"
    c.update(body)
    if lava:
        # a crack of lava across the block, glowing at its middle
        y = round(ty) + 3
        x0 = round(tx - w * 0.4)
        for i, x in enumerate(range(x0, x0 + round(w))):
            p = (x, y - i // 3)
            if p in body:
                c[p] = "l2" if i in (2, 3) else "l1"
                if (x, p[1] + 1) in body:
                    c[(x, p[1] + 1)] = "l0"


def foot(c, cx, bottom):
    """The flat block of the foot, toes to the right."""
    x0, x1 = cx - 10, cx + 12
    y0 = bottom - 5
    body = {}
    for y in range(y0, bottom + 1):
        for x in range(x0, x1 + 1):
            corner = (x - x0 < 2 or x1 - x < 2) and y == y0
            if corner:
                continue
            tone = 4 if y == y0 else 3 if y < y0 + 3 else 2
            if x < x0 + 3:
                tone += 1
            elif x > x1 - 3:
                tone -= 1
            tone += grain(x, y)
            body[(x, y)] = str(max(0, min(4, tone)))
    for (x, y) in list(body):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n not in body:
                c[n] = "k"
    c.update(body)
    # toe split
    for y in range(y0 + 3, bottom + 1):
        c[(cx + 4, y)] = "k"


def leg(c, hip_x, hip_y, phase):
    """One leg at `phase` of its step (0 = just planted in front, 0.5 = leaving behind)."""
    if phase < 0.5:
        # planted: the body passes over the foot
        t = phase / 0.5
        fx = STRIDE * (1 - 2 * t)
        lift = 0.0
    else:
        t = (phase - 0.5) / 0.5
        fx = -STRIDE + 2 * STRIDE * (0.5 - 0.5 * math.cos(t * math.pi))
        lift = LIFT * math.sin(t * math.pi)
    # the 2 px outline under the sole ends on the floor row
    bottom = SOURCE_GROUND - 2 - round(lift)
    ankle = (hip_x + fx, bottom - 5)
    # the knee comes up and forward with the foot: the thigh shortens as it swings toward us
    knee = (hip_x + fx * 0.5 + lift * 0.3, hip_y + 11 - lift * 0.6)
    foot(c, round(ankle[0]), bottom)
    block(c, (knee[0] + 0.5, knee[1] + 1), ankle, 7.5)
    block(c, (hip_x, hip_y - 4), knee, 9.5)
    block(c, (knee[0], knee[1] - 2), (knee[0], knee[1] + 3), 8, lava=True)


def walk_frame(uppers, i):
    src, (hip_y, mid, boxes) = WALK_UPPERS[i], UPPERS[WALK_UPPERS[i]]
    upper = uppers[src].copy()
    px = upper.load()
    for y0, y1, x0, x1 in boxes:
        for y in range(y0, min(y1, SOURCE_CELL)):
            for x in range(x0, x1):
                px[x, y] = (0, 0, 0, 0)
    c = {}
    phase = i / WALK_FRAMES
    # the leg behind the hammer first, then the near one over it
    leg(c, mid - HIP_SPREAD, hip_y - 4, phase)
    leg(c, mid + HIP_SPREAD, hip_y - 2, (phase + 0.5) % 1.0)
    # the pack's 2 px outline around the pair
    edge = set()
    for (x, y) in c:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0), (0, 2), (1, 1), (-1, 1)):
            if (x + dx, y + dy) not in c:
                edge.add((x + dx, y + dy))
    for p in edge:
        c[p] = "k"
    legs = Image.new("RGBA", upper.size, (0, 0, 0, 0))
    lp = legs.load()
    for (x, y), col in c.items():
        if 0 <= x < SOURCE_CELL and 0 <= y < SOURCE_CELL:
            lp[x, y] = LEG[col] + (255,)
    legs.alpha_composite(upper)
    return legs


# --- scaling to the game (80 px) and closing the outline ------------------------------------

def scale(frame):
    """Averages the frame down to the game's cell, then gives it a hard edge. Pillow already
    weighs colors by alpha when it resizes RGBA, so the edge keeps the stone's color (scaling a
    premultiplied copy and dividing by alpha again, as the pack's tool does, whitens the border)."""
    small = frame.resize((CELL, CELL), Image.BOX)
    px = small.load()
    for y in range(CELL):
        for x in range(CELL):
            r, g, b, a = px[x, y]
            px[x, y] = (0, 0, 0, 0) if a < ALPHA_CUT else (r, g, b, 255)
    return small


def is_pale(c):
    return min(c[:3]) >= 120 and max(c[:3]) - min(c[:3]) <= 40


def close_outline(frame):
    """Pale crumbs on the border go dark, then every bare border pixel of the stone gets a dark
    pixel outside it (fire keeps its soft edge)."""
    px = frame.load()
    size = frame.width

    def inside(x, y):
        return 0 <= x < size and 0 <= y < size

    def near(x, y):
        return [(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if inside(x + dx, y + dy)]

    for y in range(size):
        for x in range(size):
            c = px[x, y]
            if c[3] and is_pale(c) and not near_hot(px, x, y, size, 1) \
                    and any(px[n][3] == 0 for n in near(x, y)):
                px[x, y] = OUTLINE + (255,)
    add = []
    for y in range(size):
        for x in range(size):
            if px[x, y][3]:
                continue
            if any(px[n][3] and luminance(px[n]) >= 45 and not is_hot(px[n]) for n in near(x, y)):
                add.append((x, y))
    for p in add:
        px[p] = OUTLINE + (255,)
    # lone pixels left by the scaling
    for y in range(size):
        for x in range(size):
            if px[x, y][3] and not is_hot(px[x, y]) \
                    and not any(px[x + dx, y + dy][3] for dx in (-1, 0, 1) for dy in (-1, 0, 1)
                                if (dx or dy) and inside(x + dx, y + dy)):
                px[x, y] = (0, 0, 0, 0)
    return frame


def build_strips():
    for anim in ANIMATIONS:
        frames = frames_of(anim)
        for i, frame in enumerate(frames):
            clear_matte(frame)
            drop_strays(frame)
            if (anim, i) in GROUNDED:
                frames[i] = ground(frame)
        if anim == "walk":
            frames = [walk_frame(frames, i) for i in range(WALK_FRAMES)]
        strip = Image.new("RGBA", (CELL * len(frames), CELL), (0, 0, 0, 0))
        for i, frame in enumerate(frames):
            strip.paste(close_outline(scale(frame)), (i * CELL, 0))
        path = os.path.join(OUT, "verdugo_piedra_%s.png" % anim)
        strip.save(path)
        print(os.path.relpath(path), len(frames), "frames")


# --- the shockwave -------------------------------------------------------------------------

def lit(nx, ny):
    """How much a surface with normal (nx, ny) faces the light (upper left)."""
    return -0.55 * nx - 0.8 * ny


def wave_frame(k):
    r = WAVE_RADIUS * k / (WAVE_FRAMES - 1)
    p = k / (WAVE_FRAMES - 1)
    c = {}
    mid = WAVE_CELL / 2.0
    if k == 0:
        # the burst under the hammer
        for y in range(WAVE_CELL // 2 - 5, WAVE_CELL // 2 + 5):
            for x in range(WAVE_CELL // 2 - 5, WAVE_CELL // 2 + 5):
                d = math.hypot(x + 0.5 - mid, y + 0.5 - mid)
                spoke = abs(math.sin(math.atan2(y + 0.5 - mid, x + 0.5 - mid) * 4)) > 0.7
                if d < 2.2:
                    c[(x, y)] = "Y2"
                elif d < 3.4 or (spoke and d < 4.6):
                    c[(x, y)] = "Y" if d < 3.4 else "S4"
        return outline(c, "O")
    rim = ("Y2", "Y", "S4") if p < 0.3 else ("Y", "S4", "S3") if p < 0.55 else ("S4", "S3", "D3") if p < 0.8         else ("S3", "D3", "D2")
    # puffs of dust trailing the front, about every 11 px, each reaching its own depth into the band
    clumps = max(3, round(math.tau * r / 11.0))
    lo = max(0, int(mid - r - 2))
    hi = min(WAVE_CELL, int(mid + r + 3))
    for y in range(lo, hi):
        for x in range(lo, hi):
            dx, dy = x + 0.5 - mid, y + 0.5 - mid
            d = math.hypot(dx, dy)
            depth = r - d
            if depth < 0 or depth >= WAVE_BAND:
                continue
            if depth < 3:
                c[(x, y)] = rim[int(depth)]
                continue
            a = math.atan2(dy, dx)
            n = 0.6 + 0.3 * math.sin(a * clumps + k * 0.9) + 0.15 * math.sin(a * round(clumps * 1.6) + 1.7)
            if depth > 3 + (WAVE_BAND - 3) * n * (1.0 - 0.35 * p):
                continue
            l = lit(dx / max(d, 0.01), dy / max(d, 0.01))
            if depth < 6:
                col = "D3" if l > 0.2 else "D2"
            elif depth < 9:
                col = "D2" if l > 0.2 else "D1"
            else:
                col = "D1" if l > 0.2 else "D0"
            # embers caught in the dust while it is still hot
            if p < 0.65 and (x * 7 + y * 13 + k * 5) % 29 == 0:
                col = "S4" if depth < 7 else "S3"
            c[(x, y)] = col
    return outline(c, "O" if p < 0.8 else "D0", mid, r)


def outline(c, color, mid=None, r=None):
    """A 1 px dark edge outside the ring's front, so it reads on any floor (the dust behind it
    stays soft)."""
    ring = {}
    for (x, y) in c:
        for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if n in c or not (0 <= n[0] < WAVE_CELL and 0 <= n[1] < WAVE_CELL):
                continue
            if r is None or math.hypot(n[0] + 0.5 - mid, n[1] + 0.5 - mid) > r:
                ring[n] = color
    c.update(ring)
    return c


def wave_strip():
    img = Image.new("RGBA", (WAVE_CELL * WAVE_FRAMES, WAVE_CELL), (0, 0, 0, 0))
    for k in range(WAVE_FRAMES):
        for (x, y), col in wave_frame(k).items():
            img.putpixel((k * WAVE_CELL + x, y), PALETTE[col] + (255,))
    path = os.path.join(OUT, "verdugo_piedra_wave.png")
    img.save(path)
    print(os.path.relpath(path), WAVE_FRAMES, "frames")


if __name__ == "__main__":
    build_strips()
    wave_strip()
