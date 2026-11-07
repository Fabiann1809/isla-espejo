"""Prologue, scene 4: an unknown island (480x270). Draft outside the project.
    python make_scene4.py
Nico from behind is the generated video (gemini_generated_video_7375429e.mp4, solid green background, keyed out and
looped). The world is new: a moonlit sea, a beach, palms, and across the water a mountain island with forest, cliffs,
fog and the faint glow of ancient ruins on its summit. Camera: close on Nico -> pulls back to reveal the island ->
holds on the wide shot -> starts to move in toward the landscape and goes to black."""
import math
import os
import random
import subprocess

import numpy as np
from PIL import Image, ImageDraw

import make_scene2 as m2

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.environ.get("PROLOGUE_OUT", os.path.join(ROOT, "builds", "prologue"))
os.makedirs(OUT, exist_ok=True)
SOURCES = os.path.join(ROOT, "assets", "sprites", "nico_prologue", "source")
VIDEO = os.path.join(SOURCES, "de_espaldas.mp4")
CACHE = os.path.join(os.environ.get("TEMP", HERE), "scene4_frames")
W, H, S = m2.W, m2.H, 3
FPS = 30
SECONDS = 11.8
FRAMES = int(FPS * SECONDS)
HORIZON = m2.HORIZON            # 112
NICO_H = 60                     # his height in the 480x270 world
GROUND = 242
NICO_X = 168
smooth = lambda a, b, k: a + (b - a) * (min(1, max(0, k)) ** 2 * (3 - 2 * min(1, max(0, k))))


def c(h):
    return m2.c(h)


# ---------------------------------------------------------------- Nico from behind (the video)
def load_nico():
    if not os.path.exists(os.path.join(CACHE, "f_001.png")):
        os.makedirs(CACHE, exist_ok=True)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", VIDEO, os.path.join(CACHE, "f_%03d.png")], check=True)
    raw = []
    for i in range(1, 241):
        a = np.array(Image.open(os.path.join(CACHE, "f_%03d.png" % i)).convert("RGB")).astype(np.float32)
        r, g, b = a[..., 0], a[..., 1], a[..., 2]
        green = g - np.maximum(r, b)
        alpha = np.where(np.clip((95 - green) / 45.0, 0, 1) > 0.5, 1.0, 0.0)
        out = a.copy()
        out[..., 1] = np.where(alpha > 0, g - np.clip(g - np.maximum(r, b), 0, None) * 0.9, g)
        raw.append(np.dstack([np.clip(out, 0, 255), alpha * 255]).astype(np.uint8))
    ys = [np.where(f[..., 3] > 0) for f in raw]
    x0 = min(y[1].min() for y in ys)
    y0 = min(y[0].min() for y in ys)
    x1 = max(y[1].max() for y in ys) + 1
    y1 = max(y[0].max() for y in ys) + 1
    scale = NICO_H * S / float(y1 - y0)
    frames = []
    for f in raw:
        crop = f[y0:y1, x0:x1].astype(np.float32)
        crop[..., :3] *= crop[..., 3:4] / 255.0
        small = Image.fromarray(crop.astype(np.uint8), "RGBA").resize((int((x1 - x0) * scale), int((y1 - y0) * scale)), Image.LANCZOS)
        sa = np.array(small).astype(np.float32)
        a = sa[..., 3:4] / 255.0
        sa[..., :3] = np.where(a > 0.01, sa[..., :3] / np.maximum(a, 0.01), 0)
        sa[..., 3] = np.where(sa[..., 3] > 127, 255, 0)
        frames.append(Image.fromarray(np.clip(sa, 0, 255).astype(np.uint8), "RGBA"))
    return frames


NICO = load_nico()
NW, NHH = NICO[0].size


# ---------------------------------------------------------------- the island
PL0, PL1, CL1 = 304, 360, 378            # the summit plateau and the end of the cliff


def island_profile():
    xs = np.arange(W)
    h = np.zeros(W, np.float32)
    r = np.random.RandomState(4)
    noise = np.cumsum(r.randn(W)) * 0.18
    noise -= np.linspace(noise[0], noise[-1], W)
    for x in range(W):
        if x < 190:
            h[x] = 0
        elif x < PL0:                                           # long forested slope rising to the summit
            u = (x - 190) / float(PL0 - 190)
            h[x] = 4 + 60 * (u ** 1.5) + noise[x] * 1.6
        elif x < PL1:                                           # the summit plateau with the ruins
            h[x] = 66 + noise[x] * 0.5 + 1.5 * math.sin((x - PL0) / 6.0)
        elif x < CL1:                                           # a sheer cliff on the right
            u = (x - PL1) / float(CL1 - PL1)
            h[x] = 66 - 36 * (u ** 0.6)
        elif x < 430:
            u = (x - CL1) / float(430 - CL1)
            h[x] = 30 + 7 * math.sin(u * math.pi * 0.9) + noise[x] * 0.8
        else:
            u = (x - 430) / 50.0
            h[x] = 32 - 14 * u + noise[x] * 0.6
    return np.clip(h, 0, None)


PROFILE = island_profile()
FOG_TEX = m2.FOG_TEX


def _rect(img, x0, y0, x1, y1, col):
    img[max(0, y0):max(0, y1), max(0, x0):max(0, x1)] = col


def draw_island(img, t):
    """A solid mountain (forest, a bare cliff, a rim of moonlight) crowned by a ruined city: a broken temple wall
    with arched windows, towers, a colonnade, a standing ring of stone with a faint light, stairs climbing the slope."""
    from PIL import ImageFilter
    top = (HORIZON - PROFILE).astype(int)
    body_a, body_b = c("#111a52"), c("#0b1240")
    for x in range(W):
        if PROFILE[x] <= 0:
            continue
        for y in range(top[x], HORIZON + 4):
            depth = (y - top[x]) / max(1.0, PROFILE[x])
            img[y, x] = body_a if depth < 0.6 else body_b
    r = random.Random(17)
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for _ in range(540):
        x = r.randint(190, W - 1)
        if PROFILE[x] < 8 or PL1 <= x < CL1:
            continue
        y = r.randint(int(top[x]) + 2, HORIZON - 1)
        if PL0 <= x < PL1 and y < top[x] + 12:
            continue                                         # keep the ruins' ground clear of trees
        rad = r.randint(3, 6)
        shade = r.random()
        d.ellipse((x - rad, y - rad, x + rad, y + rad), fill=(10, 34, 48, 255) if shade < 0.6 else (14, 46, 60, 255))
        if x > 270 and shade > 0.3:
            d.arc((x - rad, y - rad, x + rad, y + rad), 200, 300, fill=(40, 98, 104, 255))
    mask = np.array(layer)[..., 3] > 0
    inside = np.zeros((H, W), bool)
    for x in range(W):
        if PROFILE[x] > 0:
            inside[top[x]:HORIZON + 4, x] = True
    sel = mask & inside
    img[sel] = np.array(layer)[..., :3][sel].astype(np.float32)
    for x in range(PL1, CL1):                                # the cliff: bare rock, lit on its right edge
        for y in range(top[x], HORIZON):
            k = (x * 5 + y // 3) % 6
            col = c("#2c3278") if k < 2 else (c("#3e4690") if k < 4 else c("#1e2562"))
            img[y, x] = np.clip(col * (1.25 if x > CL1 - 8 else 1.0), 0, 255)
    x = 192
    while x < W:                                             # a crest of small trees against the sky
        if PROFILE[x] > 6 and not (PL0 - 6 <= x < CL1):
            y = top[x]
            hh = r.randint(3, 6)
            for k in range(hh):
                half = min(2, k // 2 + 1)
                for dx in range(-half, half + 1):
                    if 0 <= x + dx < W:
                        img[y - hh + k + 2, x + dx] = c("#0a2634") if k < hh - 1 else c("#1a4a58")
            x += r.randint(3, 6)
        else:
            x += 1
    for x in range(190, W):
        if PROFILE[x] > 0 and 0 <= top[x] < H:
            img[top[x], x] = c("#8a9ce8") if x > 300 else c("#56649e")

    # ---------------- the ruined city on the summit
    by = int(HORIZON - PROFILE[330])                       # top of the plateau
    R0, R1, RL = c("#1a2366"), c("#2a3688"), c("#7a8ce0")
    DARK, WARM = c("#0a0f3a"), c("#f8d078")
    glow = 0.7 + 0.3 * math.sin(t * 1.3)
    flick = 0.6 + 0.4 * math.sin(t * 7.1) * math.sin(t * 3.3)
    for k in range(12):                                    # stairs climbing the slope to the plateau
        sx = PL0 - 4 - k * 4
        sy = int(HORIZON - PROFILE[sx]) + 1
        _rect(img, sx, sy, sx + 6, sy + 1, RL if k % 3 == 0 else c("#5866b0"))
        _rect(img, sx, sy + 1, sx + 6, sy + 2, R0)
    tops = [0, 2, 1, 4, 3, 0, 5, 2, 1, 3, 6, 4, 1, 0, 2, 4, 3, 1, 5, 2, 0, 3, 4, 1, 2, 5, 3, 1, 0, 2, 4, 3, 1, 2, 0, 4, 3, 1, 2, 3, 4, 1, 0, 2, 3, 5, 1, 2, 3, 0, 4]
    for i, x in enumerate(range(PL0 + 4, PL1 - 2)):        # the temple's back wall, broken along its top
        h0 = by - 15 + tops[i % len(tops)]
        _rect(img, x, h0, x + 1, by + 6, R1 if (x // 6) % 2 else R0)
        img[h0, x] = RL
    for wx in (PL0 + 8, PL0 + 15, PL0 + 22, PL0 + 29, PL0 + 36, PL0 + 43):
        for yy in range(by - 8, by - 1):                   # arched windows
            half = 2 if yy > by - 7 else 1
            _rect(img, wx - half + 1, yy, wx + half + 1, yy + 1, DARK)
        if wx in (PL0 + 15, PL0 + 36, PL0 + 29):
            _rect(img, wx, by - 5, wx + 2, by - 2, WARM * glow + DARK * (1 - glow))
    _rect(img, PL0 + 1, by - 26, PL0 + 8, by + 8, R0)     # tall tower with a conical roof
    _rect(img, PL0 + 7, by - 26, PL0 + 8, by + 8, c("#3a4890"))
    for k in range(5):
        _rect(img, PL0 + 1 + k // 2 + 1, by - 31 + k, PL0 + 8 - k // 2 - 1, by - 30 + k, R0)
    img[by - 32, PL0 + 4] = RL
    _rect(img, PL0 + 3, by - 18, PL0 + 5, by - 14, WARM * glow + DARK * (1 - glow))
    _rect(img, PL0 + 3, by - 8, PL0 + 5, by - 5, WARM * flick + DARK * (1 - flick))
    _rect(img, PL1 - 8, by - 20, PL1 - 1, by + 8, R0)      # crenellated tower on the right
    _rect(img, PL1 - 2, by - 20, PL1 - 1, by + 8, c("#3a4890"))
    for k in range(0, 7, 2):
        _rect(img, PL1 - 8 + k, by - 23, PL1 - 7 + k, by - 20, R0)
    _rect(img, PL1 - 5, by - 14, PL1 - 3, by - 10, WARM * glow + DARK * (1 - glow))
    for px_, hh in ((PL0 + 12, 12), (PL0 + 18, 8), (PL0 + 24, 14), (PL0 + 40, 10), (PL0 + 46, 13)):   # colonnade
        y = by + 3 - hh
        _rect(img, px_, y, px_ + 3, by + 8, R0)
        _rect(img, px_ + 2, y, px_ + 3, by + 8, c("#3a4890"))
        img[y, px_:px_ + 3] = RL
    _rect(img, PL0 + 24, by - 12, PL0 + 49, by - 10, R0)   # a lintel still holding
    img[by - 12, PL0 + 24:PL0 + 49] = RL
    cx, cy, rad = (PL0 + PL1) // 2 + 1, by - 2, 9          # the standing ring of stone, a faint teal light inside
    for yy in range(cy - rad - 2, cy + rad + 3):
        for xx in range(cx - rad - 2, cx + rad + 3):
            dd = math.hypot(xx - cx, (yy - cy) * 1.05)
            if rad - 1.6 <= dd <= rad + 0.6:
                img[yy, xx] = RL if (xx < cx and yy < cy) else R1
            elif dd < rad - 1.6 and m2.DITHER[yy % H, xx % W] < 0.45 * (0.6 + 0.4 * math.sin(t * 2 + dd)):
                img[yy, xx] = c("#8fe8d8") * 0.55 + img[yy, xx] * 0.45
    _rect(img, cx - 3, cy + rad, cx + 4, cy + rad + 4, R0)
    for bx, bh in ((PL0 - 2, 3), (PL1 + 1, 4), (PL0 + 31, 3), (PL0 + 10, 2)):   # fallen blocks
        _rect(img, bx, by + 6 - bh, bx + 4, by + 8, R1)
        img[by + 6 - bh, bx:bx + 4] = RL
    for fx in (PL0 + 13, PL0 + 41):                        # brazier flames
        y = by - 10 if fx == PL0 + 13 else by - 7
        img[y - 1:y + 1, fx + 1] = WARM * flick + R0 * (1 - flick)
    halo = Image.new("L", (W, H), 0)                       # a warm, soft halo over the summit
    ImageDraw.Draw(halo).ellipse((PL0 - 6, by - 36, PL1 + 6, by + 14), fill=int(110 * glow))
    halo = np.array(halo.filter(ImageFilter.GaussianBlur(10))).astype(np.float32) / 255.0
    img[:] = img + (c("#f2c068") - img) * (halo * 0.22)[..., None]
    return img


def island_fog(img, t):
    """Banks of mist hugging the mountain, drifting slowly sideways."""
    off = int(t * 3) % m2.CLOUD_W
    cols = (np.arange(W) + off) % m2.CLOUD_W
    n = FOG_TEX[:, cols]
    for y in range(HORIZON - 34, HORIZON + 2):
        k = (y - (HORIZON - 34)) * 54 // 36
        strength = math.sin(k / 54 * math.pi) ** 1.5 * 0.32
        a = np.clip((n[min(k // 2, 39)] - 0.30) * 2.4, 0, 1) * strength
        a[:185] *= 0.15
        sel = a > m2.DITHER[y]
        img[y][sel] = img[y][sel] * 0.55 + c("#7a88c8") * 0.45
    return img


def island_reflection(img, t):
    """A dark, shimmering reflection of the island in the water."""
    for x in range(190, W):
        hgt = int(PROFILE[x] * 0.45)
        for k in range(hgt):
            y = HORIZON + 2 + k
            wob = int(1.5 * math.sin(y * 0.8 + t * 1.5))
            xx = x + wob
            if 0 <= xx < W and (y + xx) % 2 == 0 and m2.DITHER[y, xx] < 0.7 * (1 - k / max(1, hgt)):
                img[y, xx] = img[y, xx] * 0.6 + c("#0a1240") * 0.4
    return img


# ---------------------------------------------------------------- sky, stars, clouds
STARS = []
_r = random.Random(21)
for _ in range(60):
    STARS.append((_r.randrange(W), _r.randrange(0, 96), _r.random() * 6.28))


def sky(img, t):
    for x, y, ph in STARS:
        if math.hypot(x - 392, y - 46) < 34:
            continue
        tw = 0.6 + 0.4 * math.sin(t * 2.0 + ph)
        img[y, x] = img[y, x] * (1 - tw) + c("#dfe6ff") * tw
        if tw > 0.95 and x % 3 == 0:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                img[y + dy, x + dx] = c("#7f8fd8")
    off = int(t * 3) % m2.CLOUD_W
    cols = (np.arange(W) + off) % m2.CLOUD_W
    n = m2.CLOUDS[np.ix_(np.clip(np.arange(H), 0, 139), cols)]
    fade = np.clip(1 - (m2.YY - 10) / 110.0, 0, 1)
    v = n * (0.45 + 0.65 * fade)
    mask = v > 0.58                                                  # thin, broken: the moon is clear
    img[mask] = c("#27338a")
    body = v > 0.64
    img[body] = c("#34429e")
    rim = mask & ~np.roll(mask, 1, axis=0)
    img[rim] = c("#7c8ce0")
    return img


def draw_rocks(img, t):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    m2.rock(d, 56, 232, 44, 30)
    m2.rock(d, 262, 250, 36, 20)
    m2.rock(d, 396, 238, 40, 26)
    m2.rock(d, 232, 258, 20, 10)
    rr = random.Random(5)
    for _ in range(40):
        x, y = rr.randint(0, W), rr.randint(210, 266)
        d.ellipse((x, y, x + 2, y + 1), fill=(28, 24, 40, 255))
        d.point((x, y), fill=(110, 98, 120, 255))
    return m2.draw_to(img, layer)


def vegetation(img, t):
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    m2.palm(layer, 26, 244, 200, -16, t, 0.0, 1.25)
    m2.palm(layer, 70, 250, 120, 10, t, 1.7, 0.85)
    m2.palm(layer, 452, 246, 160, 12, t, 3.0, 0.95)
    m2.bushes(layer, t)
    d = ImageDraw.Draw(layer)
    for x, y in ((40, 256), (96, 262), (430, 258)):                  # small pink flowers
        d.point((x, y), fill=(210, 80, 160, 255))
        d.point((x + 1, y), fill=(240, 150, 210, 255))
        d.point((x, y - 1), fill=(240, 150, 210, 255))
    return m2.draw_to(img, layer)


def sparkles(img, t):
    """Tiny lights among the leaves and the bushes."""
    r = random.Random(33)
    for _ in range(26):
        x, y = r.choice((r.randint(0, 110), r.randint(380, W - 1))), r.randint(150, 262)
        ph = r.random() * 6.28
        k = 0.5 + 0.5 * math.sin(t * 2.2 + ph)
        if k > 0.55:
            img[y, x] = img[y, x] * (1 - k) + c("#d8f0a0") * k
            if k > 0.92:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    img[y + dy, x + dx] = img[y + dy, x + dx] * 0.5 + c("#a8c870") * 0.5
    return img


# ---------------------------------------------------------------- composition
BACKDROP = None


def build_frame(t):
    global BACKDROP
    if BACKDROP is None:
        BACKDROP = m2.make_backdrop()
    img = BACKDROP.copy()
    img = sky(img, t)
    img = draw_island(img, t)
    img = island_fog(img, t)
    img = m2.far_ocean(img, t)
    img = island_reflection(img, t)
    img, edge = m2.beach(img, t)
    img = draw_rocks(img, t)
    img = m2.fog(img, t)
    img = m2.sand_dust(img, t)
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse((NICO_X - NW / S / 2 + 4, GROUND - 4, NICO_X + NW / S / 2 - 2, GROUND + 4), fill=(16, 12, 28, 190))
    img = m2.draw_to(img, shadow)
    below = np.clip(img, 0, 255).astype(np.uint8)
    hi = Image.fromarray(below).resize((W * S, H * S), Image.NEAREST).convert("RGBA")
    sprite = NICO[int(t * 24) % len(NICO)]
    nx, ny = NICO_X - NW / S / 2, GROUND - NHH / S
    hi.alpha_composite(sprite, (int(nx * S), int(ny * S)))
    front = np.array(hi.convert("RGB")).astype(np.float32)
    fg = np.zeros((H, W, 3), np.float32)
    fg = vegetation(fg, t)
    mask = fg.sum(axis=2) > 0
    fg_hi = np.array(Image.fromarray(np.clip(fg, 0, 255).astype(np.uint8)).resize((W * S, H * S), Image.NEAREST))
    mask_hi = np.array(Image.fromarray((mask * 255).astype(np.uint8)).resize((W * S, H * S), Image.NEAREST)) > 0
    front[mask_hi] = fg_hi[mask_hi]
    # sparkles drawn at 1x on top, upscaled as small squares
    sp = sparkles(np.zeros((H, W, 3), np.float32) + 0.0, t)
    sm = sp.sum(axis=2) > 0
    sp_hi = np.array(Image.fromarray(np.clip(sp, 0, 255).astype(np.uint8)).resize((W * S, H * S), Image.NEAREST))
    sm_hi = np.array(Image.fromarray((sm * 255).astype(np.uint8)).resize((W * S, H * S), Image.NEAREST)) > 0
    front[sm_hi] = sp_hi[sm_hi]
    return np.clip(front, 0, 255).astype(np.uint8), (nx, ny)


def camera(hi_frame, t, nico):
    nx, ny = nico
    torso = (nx + NW / S / 2, ny + NHH / S * 0.35)
    wide_c = (W / 2, H / 2)
    if t < 1.8:
        z, c_ = 2.5, torso
    elif t < 8.0:
        k = (t - 1.8) / 6.2
        z = smooth(2.5, 1.0, k)
        c_ = (smooth(torso[0], wide_c[0], k), smooth(torso[1], wide_c[1], k))
    elif t < 9.3:
        z, c_ = 1.0, wide_c
    else:
        k = (t - 9.3) / 2.5
        z = smooth(1.0, 1.45, k)
        c_ = (smooth(wide_c[0], 340, k), smooth(wide_c[1], 92, k))      # drifts in toward the island
    c_ = (c_[0], c_[1] + math.sin(t * 0.7) * 0.5)
    w, h = W / z, H / z
    cx = min(max(c_[0], w / 2), W - w / 2)
    cy = min(max(c_[1], h / 2), H - h / 2)
    box = ((cx - w / 2) * S, (cy - h / 2) * S, (cx + w / 2) * S, (cy + h / 2) * S)
    return Image.fromarray(hi_frame).resize((W, H), Image.BICUBIC, box=box)


def fade(t):
    f = smooth(0, 1, t / 0.9)
    return min(f, smooth(1, 0, (t - 10.2) / 1.2))


def main():
    frames = []
    for i in range(FRAMES):
        t = i / FPS
        hi, nico = build_frame(t)
        cam = camera(hi, t, nico)
        frame = m2.vignette(np.array(cam.convert("RGB")).astype(np.float32)) * fade(t)
        frames.append(Image.fromarray(np.clip(frame, 0, 255).astype(np.uint8)))
        if i % 60 == 0:
            print("frame", i, "of", FRAMES)
    frames[0].save(os.path.join(OUT, "scene4_island.gif"), save_all=True, append_images=frames[1:], duration=1000 // FPS, loop=0)
    sheet = Image.new("RGB", (W * 3, H * 3))
    for k, tt in enumerate((0.6, 2.4, 4.4, 6.2, 8.0, 9.2, 10.2, 10.9, 11.5)):
        sheet.paste(frames[min(int(tt * FPS), FRAMES - 1)], ((k % 3) * W, (k // 3) * H))
    sheet.save(os.path.join(OUT, "scene4_sheet.png"))
    hi, nico = build_frame(0.0)
    Image.fromarray(hi).resize((W * 3, H * 3), Image.LANCZOS).save(os.path.join(OUT, "scene4_wide.png"))
    print("ok")


if __name__ == "__main__":
    main()
