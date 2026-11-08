"""Tiles of the Ruinas' deep water and cliffs (16x16 each), drawn pixel by pixel; imported by
make_ruins_tileset_art.py, which adds them to the sheet:
  abyss_<a-d>_<0-2>   deep water, four variants of three frames (the ripples move), tileable
  abyss_shade_<a-b>   the water in a cliff's shade (darker, no glints)
  abyss_foam_<a-b>    the first row of water under a cliff: a broken line of foam over the shade
  cliff_top_<a-d>     a cliff face, upper row: bright lip, uneven courses, blocks that jut out, moss, cracks
  cliff_foot_<a-d>    a cliff face, lower row: darker, wet, a ragged foot
  rim_n, rim_w, rim_e the lip of a floor tile whose neighbour (north, west, east) is deep water
Palette: the game's rock and floor tones, the pillars' blue, the water darker than the river's."""
import random

from PIL import Image

T = 16
CLEAR = (0, 0, 0, 0)


def rgb(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


OUTLINE = rgb("#050a1a")
ROCK_D, ROCK_1, ROCK_2, ROCK_3, ROCK_4, ROCK_HI = (rgb("#131a30"), rgb("#212a44"), rgb("#2c3a53"), rgb("#3a4666"),
                                                    rgb("#4e557a"), rgb("#7a82a6"))
FLOOR_2, FLOOR_HI = rgb("#525a7c"), rgb("#7d7f9e")
MOSS_D, MOSS_1, MOSS_2, MOSS_HI = rgb("#14442f"), rgb("#1f6b4a"), rgb("#2fa070"), rgb("#72d49a")
DEEP = (rgb("#0a1a36"), rgb("#0d2142"), rgb("#112749"))
SHADE = (rgb("#040c1e"), rgb("#071429"), rgb("#0b1d3b"))
FOAM = (rgb("#8fd0e8"), rgb("#4f9cc0"), rgb("#2a6a94"))
GLINT = (rgb("#3a8fb4"), rgb("#6fe6ff"))


def shade(c, f):
    return tuple(max(0, min(255, int(c[i] * f))) for i in range(3)) + (255,)


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3)) + (255,)


def _periodic_noise(rng, cell=8):
    """A 16x16 value noise that wraps around, so tiles of the same variant continue into each other."""
    n = T // cell
    lattice = [[rng.random() for _ in range(n)] for _ in range(n)]
    out = [[0.0] * T for _ in range(T)]
    for y in range(T):
        for x in range(T):
            gx, gy = x / cell, y / cell
            x0, y0 = int(gx) % n, int(gy) % n
            x1, y1 = (x0 + 1) % n, (y0 + 1) % n
            fx, fy = gx - int(gx), gy - int(gy)
            fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
            top = lattice[y0][x0] * (1 - fx) + lattice[y0][x1] * fx
            bottom = lattice[y1][x0] * (1 - fx) + lattice[y1][x1] * fx
            out[y][x] = top * (1 - fy) + bottom * fy
    return out


def _blend_noise(rng):
    """Slow blobs with a little finer grain on top, so no tile shows the diamond of a single lattice."""
    slow, fine = _periodic_noise(rng, 8), _periodic_noise(rng, 4)
    return [[slow[y][x] * 0.68 + fine[y][x] * 0.32 for x in range(T)] for y in range(T)]


def abyss(seed, frame):
    """Deep water: dark, slow blobs of tone, short ripples that drift one pixel per frame, rare glints."""
    rng = random.Random(seed)
    noise = _blend_noise(rng)
    img = Image.new("RGBA", (T, T))
    for y in range(T):
        for x in range(T):
            v = noise[y][x]
            k = 0 if v < 0.40 else (1 if v < 0.68 else 2)
            img.putpixel((x, y), DEEP[k])
    ripples = [(rng.randrange(T), rng.randrange(T), rng.choice((3, 4, 5))) for _ in range(2)]
    for x0, y, length in ripples:
        for i in range(length):
            x = (x0 + i + frame) % T
            base = img.getpixel((x, y))
            img.putpixel((x, y), shade(base, 1.32))
    for _ in range(1):
        x, y = rng.randrange(T), rng.randrange(T)
        if (x + frame * 3 + y) % 3 == 0:
            img.putpixel((x, y), GLINT[rng.randrange(2)])
    return img


def abyss_shade(seed):
    rng = random.Random(seed)
    noise = _blend_noise(rng)
    img = Image.new("RGBA", (T, T))
    for y in range(T):
        for x in range(T):
            v = noise[y][x]
            img.putpixel((x, y), SHADE[0 if v < 0.4 else (1 if v < 0.75 else 2)])
    return img


def abyss_foam(seed):
    """The first row of water under a cliff: shade with a broken line of foam along its top."""
    rng = random.Random(seed)
    img = abyss_shade(seed + 7)
    for x in range(T):
        if rng.random() < 0.62:
            img.putpixel((x, 0), FOAM[0] if rng.random() < 0.45 else FOAM[1])
        if rng.random() < 0.3:
            img.putpixel((x, 1), FOAM[2])
    for _ in range(2):                          # a splash of foam a little lower
        x = rng.randrange(1, T - 3)
        for i in range(rng.randrange(2, 4)):
            img.putpixel((x + i, 3), FOAM[1])
    return img


def cliff_face(seed, variant):
    """A cliff two tiles tall (16x32): courses of uneven height with blocks of uneven width that darken toward the
    water, some blocks that jut out (lit on top, a shadow under them), some sunk in, an overhanging lip, moss drips and
    cracks, a wet and ragged foot. Returns the two tiles (upper, lower)."""
    rng = random.Random(seed)
    img = Image.new("RGBA", (T, 2 * T))
    px = img.load()
    ramp = (ROCK_4, ROCK_3, ROCK_2, ROCK_1)
    courses, y = [], 0
    while y < 2 * T:
        h = min(rng.choice((6, 7, 8, 9)), 2 * T - y)
        courses.append((y, h))
        y += h
    jut = []
    for y0, h in courses:
        base = ramp[min(3, y0 * 4 // (2 * T))]
        x = -rng.randrange(0, 8)
        while x < T:
            bw = rng.choice((6, 8, 10, 12))
            tone = shade(base, rng.uniform(0.90, 1.10))
            sunk = rng.random() < 0.18
            if rng.random() < 0.30 and 3 < y0 and y0 + h < 27:
                jut.append((x, bw, y0, h, base, tone))
            for yy in range(h):
                for xx in range(bw):
                    X, Y = x + xx, y0 + yy
                    if not 0 <= X < T:
                        continue
                    c = tone
                    if yy == h - 1 or xx == bw - 1:
                        c = shade(base, 0.5)
                    elif yy == 0:
                        c = shade(base, 1.25)
                    elif xx == 0:
                        c = shade(base, 1.12)
                    px[X, Y] = shade(c, 0.74) if sunk else c
            x += bw
    for x, bw, y0, h, base, tone in jut:
        for xx in range(bw):
            X = x + xx
            if 0 <= X < T:
                for k in range(1, 4):
                    Y = y0 + h - 1 + k
                    if 0 <= Y < 2 * T:
                        px[X, Y] = shade(px[X, Y], 0.58 + 0.1 * k)
    for x, bw, y0, h, base, tone in jut:
        for yy in range(-1, h):
            for xx in range(-1, bw):
                X, Y = x + xx, y0 + yy
                if not (0 <= X < T and 0 <= Y < 2 * T):
                    continue
                if yy == -1 and (xx == -1 or xx == bw - 1):
                    continue
                c = shade(tone, 1.16)
                if yy == h - 1 or xx == bw - 1:
                    c = shade(base, 0.45)
                elif yy <= 0:
                    c = shade(base, 1.5)
                elif xx <= 0:
                    c = shade(base, 1.25)
                px[X, Y] = c
        if rng.random() < 0.7 and y0 - 1 >= 0:
            for xx in range(1, bw - 1):
                X = x + xx
                if 0 <= X < T and rng.random() < 0.7:
                    px[X, y0 - 1] = rng.choice((MOSS_2, MOSS_HI, MOSS_D))
    for X in range(T):                           # lip and the band of shade under it
        px[X, 0] = mix(ROCK_HI, FLOOR_HI, 0.5)
        px[X, 1] = shade(ROCK_4, 1.05)
        for k in (2, 3):
            px[X, k] = shade(px[X, k], 0.62 if k == 2 else 0.8)
    for x0 in rng.sample(range(1, 15), rng.choice((2, 3))):      # moss drips
        for i in range(rng.randrange(5, 14)):
            px[x0, 2 + i] = MOSS_1 if i % 2 else MOSS_D
            if i % 3 == 2:
                px[min(T - 1, max(0, x0 + rng.choice((-1, 1)))), 2 + i] = MOSS_D
    for _ in range(rng.choice((1, 2))):          # cracks
        x, y = rng.randrange(3, 13), rng.randrange(3, 10)
        for _ in range(rng.randrange(10, 20)):
            px[x, y] = ROCK_D
            x = max(1, min(14, x + rng.choice((-1, 0, 0, 1))))
            y += 1
            if y > 29:
                break
    for y in range(24, 2 * T):                   # a wet foot
        for X in range(T):
            px[X, y] = shade(px[X, y], 0.80 - (y - 24) * 0.035)
    return img.crop((0, 0, T, T)), img.crop((0, T, T, 2 * T))


def _lip(side):
    img = Image.new("RGBA", (T, T), CLEAR)
    px = img.load()
    for i in range(T):
        if side == "n":
            px[i, 0], px[i, 1], px[i, 2] = OUTLINE, mix(FLOOR_HI, rgb("#95a4de"), 0.4), FLOOR_2
        elif side == "w":
            px[0, i], px[1, i] = OUTLINE, mix(FLOOR_HI, rgb("#95a4de"), 0.3)
        else:
            px[T - 1, i], px[T - 2, i] = OUTLINE, shade(FLOOR_2, 0.8)
    return img


def tiles():
    """[(name, image)] in the order the sheet adds them."""
    out = []
    for v, name in enumerate("abcd"):
        for f in range(3):
            out.append((f"abyss_{name}_{f}", abyss(40 + v, f)))
    for v, name in enumerate("ab"):
        out.append((f"abyss_shade_{name}", abyss_shade(60 + v)))
        out.append((f"abyss_foam_{name}", abyss_foam(70 + v)))
    for v, name in enumerate("abcd"):
        top, foot = cliff_face(80 + v * 7, v)
        out.append((f"cliff_top_{name}", top))
        out.append((f"cliff_foot_{name}", foot))
    for side in "nwe":
        out.append((f"rim_{side}", _lip(side)))
    return out
