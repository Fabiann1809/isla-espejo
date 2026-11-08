"""Art of the compass fragments (one per chapter: green, blue, violet). Run from the project root:
    python tools/make_fragment_art.py
Writes assets/sprites/fragments/:
  fragment_<color>_idle.png   a strip of 8 frames, 24x24 each (the piece lying where the boss fell: a broken
                              sector of Nico's brass compass with a glowing crystal needle; the glint travels)
  fragment_<color>_icon.png   12x12, the same piece for the HUD
  glow.png                    a soft white disc, tinted and added over the picture by the game
The pieces are drawn with a short palette, a 1 px dark outline and light from the upper left, like the rest of the art."""
import math
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites", "fragments")
OUTLINE = (6, 0, 0, 255)
BRASS = [(250, 232, 150), (232, 200, 112), (184, 144, 60), (122, 88, 38), (78, 52, 24)]   # lit -> shaded
FACE = (36, 50, 116, 255)
FACE_DARK = (26, 36, 88, 255)
TICK = (214, 178, 90, 255)
CRYSTALS = {
    # lit, mid, dark, glow tint
    "green": ((190, 255, 206), (61, 220, 132), (22, 122, 74)),
    "blue": ((200, 226, 255), (74, 150, 240), (30, 80, 168)),
    "violet": ((234, 208, 255), (170, 110, 240), (96, 52, 168)),
}


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def sector_mask(size, scale):
    """Pixels of a broken sector of the compass ring (the piece), as a dict (x, y) -> (distance, angle)."""
    cx, cy = 4.5 * scale, (size - 3.5 * scale)
    radius = (size - 6 * scale) * 1.0
    pixels = {}
    for y in range(size):
        for x in range(size):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            a = math.degrees(math.atan2(dy, dx))            # up is negative
            # the two broken edges are jagged: the limit angle wobbles with the distance
            lo = -96 + 4 * math.sin(d * 0.9 / scale) + 2 * math.sin(d * 2.1 / scale)
            hi = -6 + 4 * math.sin(d * 1.1 / scale + 1) + 2 * math.sin(d * 1.7 / scale)
            if d <= radius and lo <= a <= hi and d >= 3 * scale:
                pixels[(x, y)] = (d, a)
    return pixels, radius, (cx, cy)


def draw_piece(color, glint, size=32, scale=1.0):
    lit, mid, dark = CRYSTALS[color]
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    pixels, radius, (cx, cy) = sector_mask(size, scale)
    rim = 3.4 * scale
    for (x, y), (d, a) in pixels.items():
        if d >= radius - rim:                                  # the brass ring, lit on its upper-left side
            t = (d - (radius - rim)) / rim
            shade = 0 if a < -55 and t > 0.45 else (1 if t > 0.3 else 2)
            if a > -35:
                shade += 1
            if t < 0.2:
                shade = min(4, shade + 1)
            px[x, y] = BRASS[min(4, shade)] + (255,) if len(BRASS[min(4, shade)]) == 3 else BRASS[min(4, shade)]
        else:
            px[x, y] = FACE if (x + y) % 5 else FACE_DARK
    # tick marks on the inside of the ring
    for k in range(0, 91, 15):
        ang = math.radians(-96 + k)
        for r_off in (rim + 1.2 * scale, rim + 2.2 * scale):
            x = int(cx + math.cos(ang) * (radius - r_off))
            y = int(cy + math.sin(ang) * (radius - r_off))
            if (x, y) in pixels:
                px[x, y] = TICK
    # the crystal needle: a long diamond pointing out along the middle of the piece, lit on its upper-left
    ang = math.radians(-50)
    tip = (cx + math.cos(ang) * (radius - rim - 1.5 * scale), cy + math.sin(ang) * (radius - rim - 1.5 * scale))
    base = (cx + math.cos(ang) * 5 * scale, cy + math.sin(ang) * 5 * scale)
    nx, ny = -math.sin(ang), math.cos(ang)
    half = 3.2 * scale
    mid_pt = (base[0] + (tip[0] - base[0]) * 0.5, base[1] + (tip[1] - base[1]) * 0.5)
    pts = [tip, (mid_pt[0] + nx * half, mid_pt[1] + ny * half), base, (mid_pt[0] - nx * half, mid_pt[1] - ny * half)]
    for y in range(size):
        for x in range(size):
            if (x, y) in pixels and inside_poly((x + 0.5, y + 0.5), pts):
                # which side of the needle's axis: the upper-left half is lit
                side = (x + 0.5 - mid_pt[0]) * nx + (y + 0.5 - mid_pt[1]) * ny
                px[x, y] = lerp(mid, lit, 0.7) if side < -0.3 * scale else (mid + (255,) if side < 0.6 * scale else dark + (255,))
    # a bright core line and the travelling glint
    tx, ty = int((tip[0] + base[0]) / 2), int((tip[1] + base[1]) / 2)
    for k in (-2, -1, 0):
        gx, gy = int(tx + math.cos(ang) * k * 1.6 * scale), int(ty + math.sin(ang) * k * 1.6 * scale)
        if (gx, gy) in pixels:
            px[gx, gy] = lit + (255,)
    if glint is not None:
        gx = int(base[0] + (tip[0] - base[0]) * glint)
        gy = int(base[1] + (tip[1] - base[1]) * glint)
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            if (gx + dx, gy + dy) in pixels:
                px[gx + dx, gy + dy] = (255, 255, 255, 255) if (dx, dy) == (0, 0) else lit + (255,)
    # dark outline around the whole piece
    out = img.copy()
    op = out.load()
    for y in range(size):
        for x in range(size):
            if px[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < size and 0 <= yy < size and px[xx, yy][3] > 0:
                        op[x, y] = OUTLINE
                        break
    return out


def inside_poly(p, pts):
    x, y = p
    inside = False
    j = len(pts) - 1
    for i in range(len(pts)):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi:
            inside = not inside
        j = i
    return inside


def glow():
    size = 64
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    px = img.load()
    for y in range(size):
        for x in range(size):
            d = math.hypot(x + 0.5 - size / 2, y + 0.5 - size / 2) / (size / 2)
            if d < 1:
                px[x, y] = (255, 255, 255, int(255 * (1 - d) ** 2))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for color in CRYSTALS:
        strip = Image.new("RGBA", (24 * 8, 24), (0, 0, 0, 0))
        for i in range(8):
            glint = None if i in (0, 7) else (i - 0.5) / 6.0           # the glint walks from the base to the tip
            strip.alpha_composite(draw_piece(color, glint, size=24, scale=0.75), (i * 24, 0))
        strip.save(os.path.join(OUT, "fragment_%s_idle.png" % color))
        draw_piece(color, None, size=12, scale=0.375).save(os.path.join(OUT, "fragment_%s_icon.png" % color))
    glow().save(os.path.join(OUT, "glow.png"))
    # a preview sheet to look at the art (not used by the game)
    sheet = Image.new("RGBA", (24 * 8, 24 * 3 + 16), (30, 34, 56, 255))
    for r, color in enumerate(CRYSTALS):
        sheet.alpha_composite(Image.open(os.path.join(OUT, "fragment_%s_idle.png" % color)), (0, r * 24))
        sheet.alpha_composite(Image.open(os.path.join(OUT, "fragment_%s_icon.png" % color)), (r * 14, 72 + 2))
    sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(os.path.join(OUT, "preview.png"))
    print("ok")


if __name__ == "__main__":
    main()
