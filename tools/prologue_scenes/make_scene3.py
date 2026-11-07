"""Prologue, scene 3: the broken compass (480x270). Draft outside the project.
    python make_scene3.py
Same beach as scene 2 (imported from make_scene2.py) so the cut is continuous; Nico kneels, his head is the
reference sprite's, the compass gets its own extreme close-up with a cracked glass and a needle that cannot settle."""
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

import make_scene2 as m2

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.environ.get("PROLOGUE_OUT", os.path.join(ROOT, "builds", "prologue"))
os.makedirs(OUT, exist_ok=True)
SOURCES = os.path.join(ROOT, "assets", "sprites", "nico_prologue", "source")
W, H = m2.W, m2.H
FPS = 20
SECONDS = 10.0
FRAMES = int(FPS * SECONDS)

OUT = m2.OUT
BLUE, BLUE_L, BLUE_D, CUFF = m2.BLUE, m2.BLUE_L, m2.BLUE_D, m2.CUFF
PANT, PANT_L = m2.PANT, m2.PANT_L
BOOT, BOOT_D, BOOT_L = m2.BOOT, m2.BOOT_D, m2.BOOT_L
SCARF, SCARF_D, SCARF_L = m2.SCARF, m2.SCARF_D, m2.SCARF_L
SKIN, SKIN_D = m2.SKIN, m2.SKIN_D
BELT = m2.BELT

CW, CH = 120, 110       # Nico's canvas
GR = 104                # the sand line inside it
HIPS = (40, 70)
HEAD_SRC = Image.open(m2.NICO_SRC).convert("RGBA").crop((20, 0, 48, 26))      # the reference head, facing right


def smooth(a, b, k):
    k = min(1.0, max(0.0, k))
    return a + (b - a) * k * k * (3 - 2 * k)


def pose(t):
    """Angles and hand positions over time (degrees, forward = toward the right)."""
    lean = smooth(40, 10, t / 2.4)
    if t < 2.4:
        pitch = 6
    elif t < 3.6:
        pitch = 6 + 12 * math.sin((t - 2.4) / 1.2 * math.pi * 1.5) * (1 - (t - 2.4) / 1.4) * -1
    elif t < 4.6:
        pitch = smooth(3, 20, (t - 3.6) / 1.0)
    elif t < 8.0:
        pitch = 20
    else:
        pitch = smooth(20, -16, (t - 8.0) / 0.9)
    raise_k = smooth(0, 1, (t - 3.0) / 1.4)
    if t > 8.3:
        raise_k = smooth(1, 0.35, (t - 8.3) / 0.9)
    return lean, pitch, raise_k


def limb(d, pts, w, fill, light=None):
    for a, b in zip(pts, pts[1:]):
        m2._thick(d, a, b, w + 2, OUT)
    for a, b in zip(pts, pts[1:]):
        m2._thick(d, a, b, w, fill)
    if light:
        for a, b in zip(pts, pts[1:]):
            d.line(((a[0], a[1] - w // 2 + 1), (b[0], b[1] - w // 2 + 1)), fill=light, width=1)


def rot(p, c, deg):
    th = math.radians(deg)
    dx, dy = p[0] - c[0], p[1] - c[1]
    return (c[0] + dx * math.cos(th) - dy * math.sin(th), c[1] + dx * math.sin(th) + dy * math.cos(th))


def kneeling_nico(t):
    """Returns (RGBA image, anchors dict). Half-kneeling, facing right, one hand on the sand, one holding the compass."""
    lean, pitch, raise_k = pose(t)
    img = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    wind = math.sin(t * 2.4) * 2.0
    breath = 1 if math.sin(t * 2.2) > 0.2 else 0
    # legs: back leg on the knee, front foot flat
    knee_back = (34, GR - 4)
    limb(d, [HIPS, (38, 88), knee_back], 9, PANT, PANT_L)
    limb(d, [knee_back, (16, GR - 4)], 7, PANT, PANT_L)
    d.polygon([(8, GR + 1), (8, GR - 9), (18, GR - 9), (20, GR + 1)], fill=OUT)
    d.polygon([(9, GR), (9, GR - 8), (17, GR - 8), (19, GR)], fill=BOOT)
    d.line((10, GR - 1, 18, GR - 1), fill=BOOT_D)
    knee_front = (58, 76)
    limb(d, [HIPS, (50, 70), knee_front, (62, GR - 8)], 9, PANT, PANT_L)
    d.line((54, 72, 60, 72), fill=PANT_L)
    d.polygon([(54, GR + 1), (56, GR - 9), (68, GR - 8), (76, GR - 2), (76, GR + 1)], fill=OUT)
    d.polygon([(55, GR), (57, GR - 8), (67, GR - 7), (74, GR - 2), (74, GR)], fill=BOOT)
    d.line((56, GR - 1, 74, GR - 1), fill=BOOT_D)
    d.line((58, GR - 8, 66, GR - 7), fill=BOOT_L)
    # torso leaning forward about the hips
    neck0 = (HIPS[0], HIPS[1] - 31 + breath)
    sh0 = (HIPS[0] + 2, HIPS[1] - 26 + breath)
    neck, sh = rot(neck0, HIPS, lean), rot(sh0, HIPS, lean)
    limb(d, [HIPS, ((HIPS[0] + neck[0]) / 2, (HIPS[1] + neck[1]) / 2), neck], 15, BLUE, BLUE_L)
    mid = ((HIPS[0] + neck[0]) / 2 + 2, (HIPS[1] + neck[1]) / 2 + 4)
    d.line((HIPS[0] + 6, HIPS[1] - 6, neck[0] + 5, neck[1] + 8), fill=BELT, width=1)               # strap
    bx, by = rot((HIPS[0], HIPS[1] - 3), HIPS, lean)
    d.line((bx - 7, by + 1, bx + 7, by - 1), fill=BELT, width=3)                                    # belt
    # arm on the sand
    hand = (sh[0] + 14, GR - 3)
    limb(d, [sh, ((sh[0] + hand[0]) / 2 + 3, (sh[1] + hand[1]) / 2), hand], 5, BLUE, BLUE_L)
    d.rectangle((hand[0] - 3, GR - 4, hand[0] + 4, GR), fill=SKIN, outline=OUT)
    d.line((hand[0] - 2, GR - 3, hand[0] + 2, GR - 3), fill=SKIN_D)
    # head (the reference's), tilted by the pitch and the lean
    head = HEAD_SRC.rotate(-(pitch + lean * 0.5), center=(14, 24), resample=Image.NEAREST, expand=False)
    canvas_head = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    canvas_head.paste(head, (18, 18))
    canvas_head = canvas_head.rotate(0)
    hx, hy = int(neck[0] + 3 - 32), int(neck[1] - 13 - 31)     # head centred just above the neck, a little forward
    img.alpha_composite(canvas_head, (hx, hy))
    d = ImageDraw.Draw(img)
    # scarf at the neck with a tail that the breeze lifts
    d.polygon([(neck[0] - 7, neck[1] - 2), (neck[0] + 8, neck[1] - 3), (neck[0] + 9, neck[1] + 7), (neck[0] - 7, neck[1] + 8)], fill=OUT)
    d.polygon([(neck[0] - 6, neck[1] - 1), (neck[0] + 7, neck[1] - 2), (neck[0] + 7, neck[1] + 6), (neck[0] - 6, neck[1] + 7)], fill=SCARF)
    d.line((neck[0] - 5, neck[1], neck[0] + 6, neck[1] - 1), fill=SCARF_L)
    tail = [(neck[0] - 5, neck[1] + 4), (neck[0] - 15, neck[1] + 4 + wind * 0.5), (neck[0] - 25, neck[1] + 1 + wind), (neck[0] - 33, neck[1] - 3 + wind * 1.3)]
    limb(d, tail, 4, SCARF, SCARF_L)
    # the other arm, raising the compass from the knee to the chest
    elbow0, hand0 = (sh[0] + 8, sh[1] + 16), (knee_front[0] - 4, knee_front[1] - 4)
    elbow1, hand1 = (sh[0] + 14, sh[1] + 10), (sh[0] + 34, sh[1] + 2)
    elbow = (smooth(elbow0[0], elbow1[0], raise_k), smooth(elbow0[1], elbow1[1], raise_k))
    hp = (smooth(hand0[0], hand1[0], raise_k), smooth(hand0[1], hand1[1], raise_k))
    limb(d, [sh, elbow, hp], 5, BLUE, BLUE_L)
    d.rectangle((hp[0] - 3, hp[1] - 2, hp[0] + 1, hp[1] + 3), fill=CUFF, outline=OUT)
    d.ellipse((hp[0] - 1, hp[1] - 4, hp[0] + 7, hp[1] + 4), fill=SKIN, outline=OUT)
    # the compass in his palm: brass ring, dark face, a restless red needle, one white glint
    cx, cy = hp[0] + 4, hp[1] - 2
    d.ellipse((cx - 5, cy - 5, cx + 5, cy + 5), fill=OUT)
    d.ellipse((cx - 4, cy - 4, cx + 4, cy + 4), fill=(184, 144, 60, 255))
    d.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), fill=(18, 24, 60, 255))
    ang = needle_angle(t)
    nx_, ny_ = math.cos(ang) * 3, math.sin(ang) * 3
    d.line((cx, cy, cx + nx_, cy + ny_), fill=(200, 56, 60, 255))
    d.line((cx, cy, cx - nx_, cy - ny_), fill=(216, 220, 236, 255))
    d.point((cx - 2, cy - 3), fill=(255, 255, 255, 255))
    anchors = {"head": (neck[0], neck[1] - 12), "hand": (cx, cy), "neck": neck}
    return img, anchors


def needle_angle(t):
    """The needle spins, jerks and stalls: it cannot find north."""
    base = 0.7 * t + 1.2 * math.sin(t * 3.1) + 0.6 * math.sin(t * 7.3)
    if int(t * 2.5) % 3 == 0:
        base = 0.5 + 0.3 * math.sin(t * 40) * 0.5       # a nervous twitch while it stalls
    return base



# ================================================================ v2: a shaped, believable kneeling Nico
def taper(d, a, b, w0, w1, fill, edge=OUT, light=None, dark=None):
    """A limb as a tapered polygon with a 1 px outline and rounded ends (better than a constant-width tube)."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    ln = math.hypot(dx, dy) or 1.0
    ux, uy = dx / ln, dy / ln
    px, py = -uy, ux

    def poly(extra):
        h0, h1 = w0 / 2 + extra, w1 / 2 + extra
        return [(a[0] + px * h0, a[1] + py * h0), (b[0] + px * h1, b[1] + py * h1), (b[0] - px * h1, b[1] - py * h1), (a[0] - px * h0, a[1] - py * h0)]
    for extra, col in ((1, edge), (0, fill)):
        d.polygon(poly(extra), fill=col)
        for p, w in ((a, w0), (b, w1)):
            r = w / 2 + extra
            d.ellipse((p[0] - r, p[1] - r, p[0] + r, p[1] + r), fill=col)
    if light:
        d.line(((a[0] - px * w0 * 0.28, a[1] - py * w0 * 0.28), (b[0] - px * w1 * 0.28, b[1] - py * w1 * 0.28)), fill=light, width=1)
    if dark:
        d.line(((a[0] + px * w0 * 0.30, a[1] + py * w0 * 0.30), (b[0] + px * w1 * 0.30, b[1] + py * w1 * 0.30)), fill=dark, width=1)


def kneeling_nico(t):
    """Half-kneeling, facing right: back knee on the sand, front foot flat, one hand planted, the other holding the
    compass. The torso is a shaped jacket (back, chest, folds, strap, belt), not a tube."""
    lean, pitch, raise_k = pose(t)
    img = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    wind = math.sin(t * 2.4) * 2.0
    breath = 1 if math.sin(t * 2.2) > 0.2 else 0
    H0 = HIPS

    def R(dx, dy):
        return rot((H0[0] + dx, H0[1] + dy + (breath if dy < -20 else 0) * 0), H0, lean)
    # ---- legs
    K2, A2 = (40, GR - 5), (14, GR - 5)                       # back knee and ankle, shin along the sand
    taper(d, (H0[0] - 2, H0[1] - 2), K2, 12, 9, PANT, light=PANT_L)
    taper(d, K2, A2, 9, 7, PANT, light=PANT_L)
    d.polygon([(3, GR + 1), (3, GR - 9), (12, GR - 11), (19, GR - 9), (21, GR + 1)], fill=OUT)         # back boot, sole up
    d.polygon([(4, GR), (4, GR - 8), (12, GR - 10), (18, GR - 8), (19, GR)], fill=BOOT)
    d.line((5, GR - 1, 18, GR - 1), fill=BOOT_D)
    d.line((6, GR - 7, 13, GR - 9), fill=BOOT_L)
    K1, A1 = (62, 82), (66, GR - 9)                            # front knee (up) and ankle
    taper(d, (H0[0] + 2, H0[1] - 2), K1, 12, 9, PANT, light=PANT_L)
    taper(d, K1, A1, 9, 7, PANT, light=PANT_L)
    d.line((57, 78, 64, 79), fill=PANT_L)                      # the fold over the knee
    d.polygon([(58, GR + 1), (59, GR - 12), (68, GR - 13), (73, GR - 8), (84, GR - 4), (84, GR + 1)], fill=OUT)
    d.polygon([(59, GR), (60, GR - 11), (67, GR - 12), (72, GR - 7), (83, GR - 3), (83, GR)], fill=BOOT)
    d.line((60, GR - 1, 83, GR - 1), fill=BOOT_D)
    d.line((61, GR - 11, 67, GR - 11), fill=BOOT_L)
    # ---- torso geometry (rotated about the hips by the lean)
    sh = R(1, -26)                                             # shoulder
    neck = R(2, -33)
    # the arm planted on the sand goes behind the body
    g = (sh[0] + 8, GR - 3)
    e2 = (sh[0] + 7, (sh[1] + g[1]) / 2)
    taper(d, sh, e2, 6, 5, BLUE_D)
    taper(d, e2, (g[0] - 2, g[1] - 3), 5, 5, BLUE_D)
    d.rectangle((g[0] - 3, GR - 4, g[0] + 4, GR), fill=SKIN, outline=OUT)
    d.line((g[0] - 2, GR - 3, g[0] + 2, GR - 3), fill=SKIN_D)
    d.line((g[0] - 1, GR - 3, g[0] - 1, GR), fill=SKIN_D)
    # jacket: back, chest, with a lit front and a shaded back
    back = [R(-8, 3), R(-11, -10), R(-10, -24), R(-4, -31), R(0, -34)]
    front = [R(5, -34), R(11, -25), R(11, -11), R(9, 3)]
    d.polygon(back + front, fill=OUT)
    inner_b = [R(-7, 2), R(-10, -10), R(-9, -23), R(-4, -30), R(0, -33)]
    inner_f = [R(5, -33), R(10, -25), R(10, -11), R(8, 2)]
    d.polygon(inner_b + inner_f, fill=BLUE)
    d.polygon([R(-7, 2), R(-10, -10), R(-9, -23), R(-4, -30), R(-1, -30), R(-3, -12), R(-1, 2)], fill=BLUE_D)       # shaded back
    d.polygon([R(5, -33), R(10, -25), R(10, -11), R(8, 2), R(6, 2), R(7, -12), R(6, -26)], fill=BLUE_L)              # moonlit chest
    for k in (-18, -9):                                                                                              # folds of the wet cloth
        a, b = R(-3, k), R(4, k + 3)
        d.line((a, b), fill=BLUE_D)
    d.line((R(-6, -22), R(8, -6)), fill=BELT, width=1)                                                               # strap
    ba, bb = R(-9, -1), R(9, -1)
    d.line((ba, bb), fill=BELT, width=3)
    bx, by = R(5, -1)
    d.rectangle((bx - 1, by - 2, bx + 1, by + 1), fill=(217, 180, 106, 255))                                         # buckle
    # ---- scarf around the neck, a knot, and a tail that the wind lifts
    nx_, ny_ = neck[0], neck[1] + 4          # the scarf sits below the chin, not over the mouth
    d.polygon([(nx_ - 8, ny_ - 3), (nx_ + 9, ny_ - 4), (nx_ + 10, ny_ + 6), (nx_ - 8, ny_ + 7)], fill=OUT)
    d.polygon([(nx_ - 7, ny_ - 2), (nx_ + 8, ny_ - 3), (nx_ + 8, ny_ + 5), (nx_ - 7, ny_ + 6)], fill=SCARF)
    d.line((nx_ - 6, ny_ - 1, nx_ + 7, ny_ - 2), fill=SCARF_L)
    d.line((nx_ - 6, ny_ + 5, nx_ + 7, ny_ + 4), fill=SCARF_D)
    tail = [(nx_ - 6, ny_ + 3), (nx_ - 14, ny_ + 5 + wind * 0.4), (nx_ - 23, ny_ + 3 + wind), (nx_ - 32, ny_ - 1 + wind * 1.4)]
    for a_, b_, w0, w1 in zip(tail, tail[1:], (5, 4, 4), (4, 4, 3)):
        taper(d, a_, b_, w0, w1, SCARF, light=SCARF_L)
    # ---- head: the reference head, tilted forward/back with the pitch
    head = HEAD_SRC.rotate(-(pitch + lean * 0.4), center=(14, 24), resample=Image.NEAREST)
    canvas_head = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    canvas_head.paste(head, (18, 18))
    hx, hy = int(neck[0] + 2 - 32), int(neck[1] - 14 - 31)
    img.alpha_composite(canvas_head, (hx, hy))
    d = ImageDraw.Draw(img)
    d = ImageDraw.Draw(img)
    # ---- the arm that holds the compass: upper arm and forearm tapered, cuff, hand cupped around it
    e0, h0 = (sh[0] + 5, sh[1] + 14), (K1[0] - 8, K1[1] - 5)           # resting on the knee
    e1, h1 = (sh[0] + 13, sh[1] + 12), (sh[0] + 30, sh[1] + 4)         # raised in front of the chest
    elbow = (smooth(e0[0], e1[0], raise_k), smooth(e0[1], e1[1], raise_k))
    hp = (smooth(h0[0], h1[0], raise_k), smooth(h0[1], h1[1], raise_k))
    taper(d, sh, elbow, 7, 6, BLUE, light=BLUE_L, dark=BLUE_D)
    taper(d, elbow, (hp[0] - 2, hp[1] + 1), 6, 5, BLUE, light=BLUE_L, dark=BLUE_D)
    d.rectangle((hp[0] - 4, hp[1] - 3, hp[0] - 1, hp[1] + 3), fill=CUFF, outline=OUT)
    cx, cy = hp[0] + 4, hp[1] - 2
    d.ellipse((cx - 7, cy - 6, cx + 7, cy + 7), fill=OUT)
    d.ellipse((cx - 6, cy - 5, cx + 6, cy + 6), fill=SKIN)                           # the hand under the compass
    d.ellipse((cx - 6, cy - 7, cx + 6, cy + 5), fill=OUT)
    d.ellipse((cx - 5, cy - 6, cx + 5, cy + 4), fill=(184, 144, 60, 255))           # brass case
    d.ellipse((cx - 4, cy - 5, cx + 4, cy + 3), fill=(18, 24, 60, 255))
    ang = needle_angle(t)
    nx2, ny2 = math.cos(ang) * 3.2, math.sin(ang) * 3.2
    d.line((cx, cy - 1, cx + nx2, cy - 1 + ny2), fill=(200, 56, 60, 255))
    d.line((cx, cy - 1, cx - nx2, cy - 1 - ny2), fill=(216, 220, 236, 255))
    d.point((cx - 2, cy - 4), fill=(255, 255, 255, 255))
    d.rectangle((cx - 6, cy - 1, cx - 4, cy + 3), fill=SKIN, outline=OUT)             # a thumb over the rim
    anchors = {"head": (neck[0] + 2, neck[1] - 16), "hand": (cx, cy), "neck": neck}
    return img, anchors


# ---------------------------------------------------------------- the world
def render_world(t):
    if m2.BACKDROP is None:
        m2.BACKDROP = m2.make_backdrop()
    img = m2.BACKDROP.copy()
    img = m2.sky_clouds(img, t + 6.0)
    img = m2.forest_silhouette(img)
    img = m2.far_ocean(img, t + 6.0)
    img = m2.wreck_far(img, t + 6.0)
    img = m2.floating_wood(img, t + 6.0)
    img, edge = m2.beach(img, t + 6.0)
    img = m2.shore_debris(img, t + 6.0, edge)
    img = m2.sand_details(img, t + 6.0)
    img = m2.wood_pieces(img, t + 6.0)
    nico, anchors = kneeling_nico(t)
    nx, ny = 186, 238 - GR
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse((nx - 2, 233, nx + 92, 244), fill=(16, 12, 28, 200))
    img = m2.draw_to(img, shadow)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    layer.alpha_composite(nico, (nx, ny))
    img = m2.draw_to(img, layer)
    img = m2.vegetation(img, t + 6.0)
    img = m2.fog(img, t + 6.0)
    img = m2.rain_residual(img, t)
    img = m2.sand_dust(img, t)
    world_anchors = {k: (nx + v[0], ny + v[1]) for k, v in anchors.items()}
    return np.clip(img, 0, 255).astype(np.uint8), world_anchors


# ---------------------------------------------------------------- the camera
def camera(frame, t, a):
    """Close-up on Nico rising -> his face -> down to the hand -> in on the compass -> back to him -> he looks at the
    horizon and the camera starts to pull away."""
    head, hand = (a["head"][0] + 4, a["head"][1] + 16), a["hand"]     # frame the upper body, not just the face
    if t < 3.0:
        z, c = smooth(1.9, 2.5, t / 3.0), head
    elif t < 4.8:
        k = (t - 3.0) / 1.8
        z = smooth(2.7, 3.4, k)
        c = (smooth(head[0], hand[0] - 6, k), smooth(head[1], hand[1] + 2, k))
    elif t < 5.8:
        z, c = smooth(3.4, 4.6, (t - 4.8) / 1.0), (hand[0] - 2, hand[1])
    elif t < 7.4:
        z, c = 4.6, (hand[0] - 2, hand[1])
    elif t < 8.4:
        k = (t - 7.4) / 1.0
        z = smooth(4.6, 2.5, k)
        c = (smooth(hand[0] - 2, head[0] + 6, k), smooth(hand[1], head[1] + 6, k))
    else:
        k = (t - 8.4) / 1.6
        z = smooth(2.5, 1.5, k)
        c = (smooth(head[0] + 6, 250, k), smooth(head[1] + 6, 190, k))
    c = (c[0], c[1] + math.sin(t * 0.9) * 0.6)
    w, h = W / z, H / z
    cx = min(max(c[0], w / 2), W - w / 2)
    cy = min(max(c[1], h / 2), H - h / 2)
    box = (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2)
    return Image.fromarray(frame).resize((W, H), Image.NEAREST, box=box)


# ---------------------------------------------------------------- compass close-up (its own picture)
def compass_closeup(t, backdrop):
    """The compass filling the screen, drawn at half resolution (240x135) and doubled so its pixels read as art."""
    S = 2
    w, h = W // S, H // S
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, cy, R = 128, 66, 46
    # the hand holding it: palm below and fingers curling over the rim, a blue cuff coming from the lower right
    d.polygon([(w - 10, h), (w - 56, h), (cx + 36, cy + 40), (cx - 8, cy + 56), (cx - 46, cy + 40), (cx - 62, cy + 18), (cx - 50, cy + 20), (cx - 24, cy + 40), (cx + 30, cy + 34), (w - 4, cy + 64)], fill=OUT)
    d.polygon([(w - 14, h), (w - 52, h), (cx + 34, cy + 38), (cx - 8, cy + 52), (cx - 44, cy + 38), (cx - 58, cy + 20), (cx - 48, cy + 22), (cx - 22, cy + 38), (cx + 28, cy + 32), (w - 8, cy + 62)], fill=SKIN)
    d.polygon([(w - 12, h), (w - 56, h), (w - 40, h - 30), (w - 12, h - 52)], fill=OUT)
    d.polygon([(w - 14, h), (w - 52, h), (w - 38, h - 28), (w - 14, h - 48)], fill=BLUE)
    d.line([(w - 52, h - 2), (w - 40, h - 28), (w - 15, h - 48)], fill=BLUE_L, width=1)
    d.polygon([(w - 38, h - 28), (w - 14, h - 48), (w - 12, h - 52), (w - 40, h - 33)], fill=CUFF)
    # fingers
    for fx, fy, ln in ((cx - 50, cy + 6, 18), (cx - 40, cy - 22, 20), (cx - 18, cy - 44, 20)):
        d.rounded_rectangle((fx - 6, fy - 6, fx + 10, fy + ln), radius=6, fill=OUT)
        d.rounded_rectangle((fx - 5, fy - 5, fx + 9, fy + ln - 1), radius=5, fill=SKIN)
        d.line((fx - 3, fy - 2, fx - 3, fy + ln - 4), fill=SKIN_D)
    d.ellipse((cx + 30, cy - 30, cx + 56, cy - 4), fill=OUT)                  # thumb
    d.ellipse((cx + 31, cy - 29, cx + 54, cy - 6), fill=SKIN)
    # case: dark outline, brass ring with lit upper left and shaded lower right
    d.ellipse((cx - R - 3, cy - R - 3, cx + R + 3, cy + R + 3), fill=OUT)
    d.ellipse((cx - R, cy - R, cx + R, cy + R), fill=(120, 88, 36, 255))
    d.ellipse((cx - R + 2, cy - R + 2, cx + R - 4, cy + R - 4), fill=(184, 144, 60, 255))
    d.arc((cx - R + 1, cy - R + 1, cx + R - 1, cy + R - 1), 190, 280, fill=(240, 214, 130, 255), width=3)
    d.arc((cx - R + 1, cy - R + 1, cx + R - 1, cy + R - 1), 20, 90, fill=(90, 62, 24, 255), width=3)
    # winder at the top
    d.rectangle((cx - 5, cy - R - 9, cx + 5, cy - R), fill=OUT)
    d.rectangle((cx - 4, cy - R - 8, cx + 4, cy - R), fill=(184, 144, 60, 255))
    # face: deep blue with gold marks
    fr = R - 7
    d.ellipse((cx - fr - 1, cy - fr - 1, cx + fr + 1, cy + fr + 1), fill=(60, 44, 20, 255))
    d.ellipse((cx - fr, cy - fr, cx + fr, cy + fr), fill=(16, 22, 62, 255))
    d.ellipse((cx - fr + 3, cy - fr + 3, cx + fr - 3, cy + fr - 3), fill=(22, 30, 80, 255))
    for k in range(32):
        a = k / 32 * math.tau
        r0 = fr - (5 if k % 4 else 9)
        d.line((cx + math.cos(a) * r0, cy + math.sin(a) * r0, cx + math.cos(a) * (fr - 2), cy + math.sin(a) * (fr - 2)), fill=(214, 178, 90, 255))
    for k, label in enumerate((0, 1, 2, 3)):                                   # four-point star
        a = k * math.pi / 2 - math.pi / 2
        px, py = math.cos(a), math.sin(a)
        tx, ty = -py, px
        d.polygon([(cx + px * (fr - 10), cy + py * (fr - 10)), (cx + tx * 3, cy + ty * 3), (cx - tx * 3, cy - ty * 3)], fill=(150, 120, 60, 255))
    d.rectangle((cx - 2, cy - fr + 3, cx + 2, cy - fr + 9), fill=(200, 56, 60, 255))   # the N mark
    # the needle: it jerks and cannot settle
    ang = needle_angle(t)
    nl = fr - 9
    tip = (cx + math.cos(ang) * nl, cy + math.sin(ang) * nl)
    tail = (cx - math.cos(ang) * nl, cy - math.sin(ang) * nl)
    sx, sy = -math.sin(ang) * 4, math.cos(ang) * 4
    d.polygon([tip, (cx + sx, cy + sy), (cx - sx, cy - sy)], fill=(200, 56, 60, 255), outline=OUT)
    d.polygon([tail, (cx + sx, cy + sy), (cx - sx, cy - sy)], fill=(216, 220, 236, 255), outline=OUT)
    d.ellipse((cx - 3, cy - 3, cx + 3, cy + 3), fill=(184, 144, 60, 255), outline=OUT)
    # cracked glass: lines fanning from the point of impact, drawn thin and pale
    ix, iy = cx + 14, cy - 12
    r = random.Random(9)
    for i in range(7):
        a = i / 7 * math.tau + r.random() * 0.3
        pts = [(ix, iy)]
        x, y = ix, iy
        for _ in range(4):
            a += r.uniform(-0.4, 0.4)
            x += math.cos(a) * r.uniform(7, 13)
            y += math.sin(a) * r.uniform(7, 13)
            if math.hypot(x - cx, y - cy) > fr:
                break
            pts.append((x, y))
        d.line(pts, fill=(226, 236, 255, 230), width=1)
    d.arc((ix - 9, iy - 9, ix + 9, iy + 9), 0, 300, fill=(200, 214, 250, 200))
    # glass highlight, and a glint that flashes once when Nico looks at it
    d.arc((cx - fr + 4, cy - fr + 4, cx + fr - 4, cy + fr - 4), 200, 255, fill=(255, 255, 255, 230), width=2)
    g = max(0.0, 1 - abs(t - 6.3) / 0.35)
    if g > 0:
        gx, gy = cx - 18, cy - 20
        L = int(14 * g)
        d.line((gx - L, gy, gx + L, gy), fill=(255, 255, 255, 255))
        d.line((gx, gy - L, gx, gy + L), fill=(255, 255, 255, 255))
        d.ellipse((gx - 2, gy - 2, gx + 2, gy + 2), fill=(255, 255, 255, 255))
        for k in (-1, 1):
            d.line((gx - k * L * 0.6, gy - L * 0.6, gx + k * L * 0.6, gy + L * 0.6), fill=(210, 224, 255, 255))
    big = im.resize((W, H), Image.NEAREST)
    # backdrop: the last camera frame, blurred and darkened, so the cut feels like a focus pull
    bg = backdrop.filter(ImageFilter.GaussianBlur(3)).point(lambda v: int(v * 0.45))
    bg = bg.convert("RGBA")
    bg.alpha_composite(big)
    return bg.convert("RGB")


def main():
    frames = []
    for i in range(FRAMES):
        t = i / FPS
        world, anchors = render_world(t)
        cam = camera(world, t, anchors)
        # crossfade into the compass close-up while the camera is pushed all the way in
        k = 0.0
        if 5.2 <= t < 5.8:
            k = (t - 5.2) / 0.6
        elif 5.8 <= t < 7.4:
            k = 1.0
        elif 7.4 <= t < 8.0:
            k = 1 - (t - 7.4) / 0.6
        out = cam
        if k > 0:
            ci = compass_closeup(t, cam)
            out = Image.blend(cam.convert("RGB"), ci, k)
        frame = m2.vignette(np.array(out.convert("RGB")).astype(np.float32))
        frames.append(Image.fromarray(np.clip(frame, 0, 255).astype(np.uint8)))
        if i % 40 == 0:
            print("frame", i, "of", FRAMES)
    frames[0].save(os.path.join(OUT, "scene3_compass.gif"), save_all=True, append_images=frames[1:], duration=1000 // FPS, loop=0)
    sheet = Image.new("RGB", (W * 2, H * 3))
    for k, tt in enumerate((0.2, 2.8, 4.3, 6.3, 7.9, 9.6)):
        sheet.paste(frames[min(int(tt * FPS), FRAMES - 1)], ((k % 2) * W, (k // 2) * H))
    sheet.resize((W * 3, H * 4 + 270), Image.NEAREST).save(os.path.join(OUT, "scene3_sheet.png"))
    world, anchors = render_world(4.5)
    Image.fromarray(world).resize((W * 3, H * 3), Image.NEAREST).save(os.path.join(OUT, "scene3_wide.png"))
    print("ok")


if __name__ == "__main__":
    main()
