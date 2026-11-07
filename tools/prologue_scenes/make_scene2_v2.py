"""Prologue, scene 2 (v2): Nico wakes up, using the generated sprite sheet (Despertar del guerrero pixelado.gif).
    python make_scene2_v2.py
The green background is keyed out, the frames are cropped to one shared box (so his position never jumps), scaled to
the scene, and composed over the same beach (make_scene2.py) at 3x with the smooth camera of scene 3."""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageSequence

import make_scene2 as m2

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.environ.get("PROLOGUE_OUT", os.path.join(ROOT, "builds", "prologue"))
os.makedirs(OUT, exist_ok=True)
SOURCES = os.path.join(ROOT, "assets", "sprites", "nico_prologue", "source")
SRC = os.path.join(SOURCES, "despertar.gif")
W, H = m2.W, m2.H
S = 3
FPS = 30
SECONDS = 10.6
FRAMES = int(FPS * SECONDS)
SPRITE_LEN = 112            # length of Nico lying down in the 480x270 world


def smooth(a, b, k):
    k = min(1.0, max(0.0, k))
    return a + (b - a) * k * k * (3 - 2 * k)


def key_green(rgb):
    """Chroma key with despill: pure green becomes transparent, green-tinted edges lose their tint."""
    a = rgb.astype(np.float32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    greenness = g - np.maximum(r, b)
    alpha = np.clip(1.0 - (greenness - 40) / 100.0, 0, 1)
    alpha[greenness < 40] = 1.0
    alpha[(g > 200) & (r < 90) & (b < 90)] = 0.0
    alpha = np.where(alpha > 0.5, 1.0, 0.0)                    # hard edges: it is pixel art
    out = a.copy()
    spill = np.clip(g - np.maximum(r, b), 0, None)
    out[..., 1] = np.where(alpha > 0, g - spill * 0.9, g)
    rgba = np.dstack([np.clip(out, 0, 255), alpha * 255]).astype(np.uint8)
    return rgba


def load_sprite():
    im = Image.open(SRC)
    raw = [key_green(np.array(f.convert("RGB"))) for f in ImageSequence.Iterator(im)]
    # one shared crop box so the character never shifts between frames
    boxes = []
    for fr in raw:
        ys, xs = np.where(fr[..., 3] > 0)
        boxes.append((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    x0 = min(b[0] for b in boxes)
    y0 = min(b[1] for b in boxes)
    x1 = max(b[2] for b in boxes)
    y1 = max(b[3] for b in boxes)
    scale = SPRITE_LEN * S / float(x1 - x0)
    frames, anchors = [], []
    for fr in raw:
        crop = Image.fromarray(fr[y0:y1, x0:x1], "RGBA")
        pm = crop.copy()
        # premultiply while resizing so the edges never pick up a halo
        arr = np.array(pm).astype(np.float32)
        arr[..., :3] *= arr[..., 3:4] / 255.0
        pm = Image.fromarray(arr.astype(np.uint8), "RGBA")
        small = pm.resize((int((x1 - x0) * scale), int((y1 - y0) * scale)), Image.LANCZOS)
        sa = np.array(small).astype(np.float32)
        a = sa[..., 3:4] / 255.0
        sa[..., :3] = np.where(a > 0.01, sa[..., :3] / np.maximum(a, 0.01), 0)
        sa[..., 3] = np.where(sa[..., 3] > 127, 255, 0)
        frames.append(Image.fromarray(np.clip(sa, 0, 255).astype(np.uint8), "RGBA"))
        # head = centroid of the brown hair; hands = skin pixels in the lower part
        c = fr[y0:y1, x0:x1]
        hair = (c[..., 3] > 0) & (c[..., 0] > c[..., 1]) & (c[..., 1] > c[..., 2]) & (c[..., 0] < 170) & (c[..., 1] < 100)
        ys, xs = np.where(hair)
        head = (xs.mean() * scale / S, ys.mean() * scale / S) if len(xs) else (20, 20)
        skin = (c[..., 3] > 0) & (c[..., 0] > 200) & (c[..., 1] > 140) & (c[..., 1] < 200) & (c[..., 2] > 100) & (c[..., 2] < 170)
        sy, sx = np.where(skin)
        low = sy > (y1 - y0) * 0.6
        hand = (sx[low].mean() * scale / S, sy[low].mean() * scale / S) if low.any() else (head[0] + 40, head[1] + 30)
        anchors.append({"head": head, "hand": hand})
    return frames, anchors


FRAMES_IMG, ANCHORS = load_sprite()
N = len(FRAMES_IMG)
SPR_W, SPR_H = FRAMES_IMG[0].size


def frame_position(t):
    """Which source frame (fractional) is showing at time t: a breathing hold, then the wake-up, then the final pose."""
    if t < 2.4:
        return (t / 0.6) % 4.0                              # frames 0-3: asleep, breathing
    k = (t - 2.4) / 5.2
    return 4.0 + 11.0 * (k * k * (3 - 2 * k) if k < 1 else 1.0)


def sprite_at(t):
    pos = frame_position(t)
    i = int(pos)
    f = pos - i
    j = min(N - 1, i + 1) if t >= 2.4 else (i + 1) % 4
    a = FRAMES_IMG[min(i, N - 1)]
    b = FRAMES_IMG[j]
    k = smooth(0, 1, (f - 0.55) / 0.45) if f > 0.55 else 0.0        # hold, then dissolve into the next frame
    img = Image.blend(a, b, k) if k > 0 else a
    aa = (np.array(img)[..., 3] > 127)
    arr = np.array(img)
    arr[..., 3] = np.where(aa, 255, 0)
    anchor = {key: (ANCHORS[min(i, N - 1)][key][0] * (1 - k) + ANCHORS[j][key][0] * k,
                    ANCHORS[min(i, N - 1)][key][1] * (1 - k) + ANCHORS[j][key][1] * k) for key in ("head", "hand")}
    return Image.fromarray(arr, "RGBA"), anchor


def fade_factor(t):
    """Black at the very start and the very end: in over 0.9 s, out over the last 1.0 s, with a short black hold."""
    f_in = smooth(0, 1, t / 0.9)
    f_out = smooth(1, 0, (t - (SECONDS - 1.4)) / 1.0)
    return min(f_in, f_out)


def build_frame(t):
    if m2.BACKDROP is None:
        m2.BACKDROP = m2.make_backdrop()
    img = m2.BACKDROP.copy()
    img = m2.sky_clouds(img, t)
    img = m2.forest_silhouette(img)
    img = m2.far_ocean(img, t)
    img = m2.wreck_far(img, t)
    img = m2.floating_wood(img, t)
    img, edge = m2.beach(img, t)
    img = m2.shore_debris(img, t, edge)
    img = m2.sand_details(img, t)
    img = m2.wood_pieces(img, t)
    img = m2.fog(img, t)
    img = m2.rain_residual(img, t)
    img = m2.sand_dust(img, t)
    spr, anchor = sprite_at(t)
    nx = 168
    ground = 241
    ny = ground - SPR_H / S
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse((nx - 2, ground - 8, nx + SPRITE_LEN + 6, ground + 4), fill=(16, 12, 28, 190))
    img = m2.draw_to(img, shadow)
    below = np.clip(img, 0, 255).astype(np.uint8)
    hi = Image.fromarray(below).resize((W * S, H * S), Image.NEAREST).convert("RGBA")
    hi.alpha_composite(spr, (int(nx * S), int(ny * S)))
    front = np.array(hi.convert("RGB")).astype(np.float32)
    veg = m2.vegetation(np.zeros((H, W, 3), np.float32), t)
    mask = veg.sum(axis=2) > 0
    if mask.any():
        veg_hi = np.array(Image.fromarray(np.clip(veg, 0, 255).astype(np.uint8)).resize((W * S, H * S), Image.NEAREST))
        mask_hi = np.array(Image.fromarray((mask * 255).astype(np.uint8)).resize((W * S, H * S), Image.NEAREST)) > 0
        front[mask_hi] = veg_hi[mask_hi]
    anchors = {k: (nx + v[0], ny + v[1]) for k, v in anchor.items()}
    return np.clip(front, 0, 255).astype(np.uint8), anchors


def camera(hi_frame, t, a):
    """Wide beach -> slow push-in toward his face -> down to his hands, always following where he is."""
    head, hand = a["head"], a["hand"]
    if t < 1.0:
        z, c = 1.0, (W / 2, H / 2)
    elif t < 7.5:
        k = (t - 1.0) / 6.5
        z = smooth(1.0, 2.3, k)
        c = (smooth(W / 2, head[0] + 6, k), smooth(H / 2, head[1] + 4, k))
    else:
        k = (t - 7.5) / 2.5
        z = 2.3
        c = (smooth(head[0] + 6, hand[0] - 4, k), smooth(head[1] + 4, hand[1] - 6, k))
    c = (c[0], c[1] + math.sin(t * 0.9) * 0.5)
    w, h = W / z, H / z
    cx = min(max(c[0], w / 2), W - w / 2)
    cy = min(max(c[1], h / 2), H - h / 2)
    box = ((cx - w / 2) * S, (cy - h / 2) * S, (cx + w / 2) * S, (cy + h / 2) * S)
    return Image.fromarray(hi_frame).resize((W, H), Image.BICUBIC, box=box)


def main():
    frames = []
    for i in range(FRAMES):
        t = i / FPS
        hi, anchors = build_frame(t)
        cam = camera(hi, t, anchors)
        frame = m2.vignette(np.array(cam.convert("RGB")).astype(np.float32))
        frame *= fade_factor(t)
        frames.append(Image.fromarray(np.clip(frame, 0, 255).astype(np.uint8)))
        if i % 60 == 0:
            print("frame", i, "of", FRAMES)
    frames[0].save(os.path.join(OUT, "scene2_wake_v3.gif"), save_all=True, append_images=frames[1:], duration=1000 // FPS, loop=0)
    sheet = Image.new("RGB", (W * 2, H * 3))
    for k, tt in enumerate((0.0, 3.0, 4.2, 5.6, 7.4, 9.6)):
        sheet.paste(frames[min(int(tt * FPS), FRAMES - 1)], ((k % 2) * W, (k // 2) * H))
    sheet.resize((W * 3, H * 4 + 270), Image.NEAREST).save(os.path.join(OUT, "scene2_v3_sheet.png"))
    hi, _ = build_frame(0.0)
    Image.fromarray(hi).resize((W * 3, H * 3), Image.LANCZOS).save(os.path.join(OUT, "scene2_v2_wide.png"))
    print("ok")


if __name__ == "__main__":
    main()
