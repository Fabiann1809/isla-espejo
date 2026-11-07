"""Prologue, scene 3 (v5): Nico kneels with the broken compass, using the generated sprite
(Sprite animado_ joven y brújula.gif). Same beach as scene 2, the smooth 3x camera, and the compass close-up
(brass case, cracked glass, restless needle) between the medium shots.
    python make_scene3_v5.py"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageSequence

import make_scene2 as m2
import make_scene3 as m3

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.environ.get("PROLOGUE_OUT", os.path.join(ROOT, "builds", "prologue"))
os.makedirs(OUT, exist_ok=True)
SOURCES = os.path.join(ROOT, "assets", "sprites", "nico_prologue", "source")
SRC = os.path.join(SOURCES, "brujula.gif")
W, H = m2.W, m2.H
S = 3
FPS = 30
SECONDS = 10.0
FRAMES = int(FPS * SECONDS)
SPRITE_H = 62               # height of the kneeling Nico in the 480x270 world


def smooth(a, b, k):
    k = min(1.0, max(0.0, k))
    return a + (b - a) * k * k * (3 - 2 * k)


def key_green(rgb):
    a = rgb.astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    greenness = g - np.maximum(r, b)
    alpha = np.where((greenness > 70) | ((g > 200) & (r < 90) & (b < 90)), 0.0, 1.0)
    out = a.copy()
    spill = np.clip(g - np.maximum(r, b), 0, None)
    out[..., 1] = np.where(alpha > 0, g - spill * 0.9, g)
    return np.dstack([np.clip(out, 0, 255), alpha * 255]).astype(np.uint8)


def load_sprite():
    im = Image.open(SRC)
    raw = [key_green(np.array(f.convert("RGB"))) for f in ImageSequence.Iterator(im)]
    boxes = []
    for fr in raw:
        ys, xs = np.where(fr[..., 3] > 0)
        boxes.append((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    x0, y0 = min(b[0] for b in boxes), min(b[1] for b in boxes)
    x1, y1 = max(b[2] for b in boxes), max(b[3] for b in boxes)
    scale = SPRITE_H * S / float(y1 - y0)
    frames, anchors = [], []
    for fr in raw:
        crop = fr[y0:y1, x0:x1]
        arr = crop.astype(np.float32)
        arr[..., :3] *= arr[..., 3:4] / 255.0                      # premultiply: no halo when resizing
        small = Image.fromarray(arr.astype(np.uint8), "RGBA").resize((int((x1 - x0) * scale), int((y1 - y0) * scale)), Image.LANCZOS)
        sa = np.array(small).astype(np.float32)
        a = sa[..., 3:4] / 255.0
        sa[..., :3] = np.where(a > 0.01, sa[..., :3] / np.maximum(a, 0.01), 0)
        sa[..., 3] = np.where(sa[..., 3] > 127, 255, 0)
        frames.append(Image.fromarray(np.clip(sa, 0, 255).astype(np.uint8), "RGBA"))
        hair = (crop[..., 3] > 0) & (crop[..., 0] > crop[..., 1]) & (crop[..., 1] > crop[..., 2]) & (crop[..., 0] < 170) & (crop[..., 1] < 100)
        ys, xs = np.where(hair)
        head = (xs.mean() * scale / S, ys.mean() * scale / S)
        brass = (crop[..., 3] > 0) & (crop[..., 0] > 170) & (crop[..., 1] > 120) & (crop[..., 1] < 200) & (crop[..., 2] < 110)
        by, bx = np.where(brass)
        comp = (bx.mean() * scale / S, by.mean() * scale / S) if len(bx) else (head[0] + 30, head[1] + 30)
        anchors.append({"head": head, "hand": comp})
    return frames, anchors


FRAMES_IMG, ANCHORS = load_sprite()
N = len(FRAMES_IMG)
SPR_W, SPR_H = FRAMES_IMG[0].size


def sprite_at(t):
    """Plays the 12-frame loop at its own 80 ms rhythm."""
    i = int(t * 12.5) % N
    return FRAMES_IMG[i], ANCHORS[i]


def build_frame(t):
    if m2.BACKDROP is None:
        m2.BACKDROP = m2.make_backdrop()
    tt = t + 6.0
    img = m2.BACKDROP.copy()
    img = m2.sky_clouds(img, tt)
    img = m2.forest_silhouette(img)
    img = m2.far_ocean(img, tt)
    img = m2.wreck_far(img, tt)
    img = m2.floating_wood(img, tt)
    img, edge = m2.beach(img, tt)
    img = m2.shore_debris(img, tt, edge)
    img = m2.sand_details(img, tt)
    img = m2.wood_pieces(img, tt)
    img = m2.fog(img, tt)
    img = m2.rain_residual(img, t)
    img = m2.sand_dust(img, t)
    spr, anchor = sprite_at(t)
    ground = 241
    nx = 214 - SPR_W / S / 2
    ny = ground - SPR_H / S
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse((nx - 4, ground - 6, nx + SPR_W / S + 6, ground + 4), fill=(16, 12, 28, 190))
    img = m2.draw_to(img, shadow)
    below = np.clip(img, 0, 255).astype(np.uint8)
    hi = Image.fromarray(below).resize((W * S, H * S), Image.NEAREST).convert("RGBA")
    hi.alpha_composite(spr, (int(nx * S), int(ny * S)))
    front = np.array(hi.convert("RGB")).astype(np.float32)
    veg = m2.vegetation(np.zeros((H, W, 3), np.float32), tt)
    mask = veg.sum(axis=2) > 0
    if mask.any():
        veg_hi = np.array(Image.fromarray(np.clip(veg, 0, 255).astype(np.uint8)).resize((W * S, H * S), Image.NEAREST))
        mask_hi = np.array(Image.fromarray((mask * 255).astype(np.uint8)).resize((W * S, H * S), Image.NEAREST)) > 0
        front[mask_hi] = veg_hi[mask_hi]
    anchors = {k: (nx + v[0], ny + v[1]) for k, v in anchor.items()}
    return np.clip(front, 0, 255).astype(np.uint8), anchors


def camera(hi_frame, t, a):
    head = (a["head"][0] + 2, a["head"][1] + 8)
    comp = a["hand"]
    if t < 3.0:
        z, c = smooth(1.9, 2.5, t / 3.0), head
    elif t < 4.8:
        k = (t - 3.0) / 1.8
        z = smooth(2.5, 3.3, k)
        c = (smooth(head[0], comp[0] - 4, k), smooth(head[1], comp[1] - 2, k))
    elif t < 5.8:
        z, c = smooth(3.3, 4.4, (t - 4.8) / 1.0), (comp[0] - 2, comp[1])
    elif t < 7.4:
        z, c = 4.4, (comp[0] - 2, comp[1])
    elif t < 8.4:
        k = (t - 7.4) / 1.0
        z = smooth(4.4, 2.5, k)
        c = (smooth(comp[0] - 2, head[0] + 4, k), smooth(comp[1], head[1] + 2, k))
    else:
        k = (t - 8.4) / 1.6
        z = smooth(2.5, 1.5, k)
        c = (smooth(head[0] + 4, 250, k), smooth(head[1] + 2, 190, k))
    c = (c[0], c[1] + math.sin(t * 0.9) * 0.5)
    w, h = W / z, H / z
    cx = min(max(c[0], w / 2), W - w / 2)
    cy = min(max(c[1], h / 2), H - h / 2)
    box = ((cx - w / 2) * S, (cy - h / 2) * S, (cx + w / 2) * S, (cy + h / 2) * S)
    return Image.fromarray(hi_frame).resize((W, H), Image.BICUBIC, box=box)


def main():
    m3.CUFF = (126, 78, 48, 255)             # the close-up's wristband matches the new Nico's brown cuffs
    frames = []
    for i in range(FRAMES):
        t = i / FPS
        hi, anchors = build_frame(t)
        cam = camera(hi, t, anchors).convert("RGB")
        k = 0.0
        if 5.2 <= t < 5.8:
            k = (t - 5.2) / 0.6
        elif 5.8 <= t < 7.4:
            k = 1.0
        elif 7.4 <= t < 8.0:
            k = 1 - (t - 7.4) / 0.6
        out = cam
        if k > 0:
            out = Image.blend(cam, m3.compass_closeup(t, cam), smooth(0, 1, k))
        frame = m2.vignette(np.array(out).astype(np.float32))
        frames.append(Image.fromarray(np.clip(frame, 0, 255).astype(np.uint8)))
        if i % 60 == 0:
            print("frame", i, "of", FRAMES)
    frames[0].save(os.path.join(OUT, "scene3_compass_v5.gif"), save_all=True, append_images=frames[1:], duration=1000 // FPS, loop=0)
    sheet = Image.new("RGB", (W * 2, H * 3))
    for k, tt in enumerate((0.2, 2.8, 4.3, 6.3, 7.9, 9.6)):
        sheet.paste(frames[min(int(tt * FPS), FRAMES - 1)], ((k % 2) * W, (k // 2) * H))
    sheet.resize((W * 3, H * 4 + 270), Image.NEAREST).save(os.path.join(OUT, "scene3_v5_sheet.png"))
    hi, _ = build_frame(0.0)
    Image.fromarray(hi).resize((W * 3, H * 3), Image.LANCZOS).save(os.path.join(OUT, "scene3_v5_wide.png"))
    print("ok")


if __name__ == "__main__":
    main()
