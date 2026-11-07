"""Prologue, scene 3 (v7): the compass scene with cuts through black instead of dissolves.
    python make_scene3_v7.py
No poses are blended any more: the scene fades in from black, pushes in on the compass and goes to black, the
close-up fades in, goes to black again, and the medium shot comes back from black; the scene ends in black.
Only the 12-frame loop of the generated sprite is used, so Nico is the same in every shot."""
import math
import os

import numpy as np
from PIL import Image

import make_scene2 as m2
import make_scene3 as m3
import make_scene3_v5 as v5

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.environ.get("PROLOGUE_OUT", os.path.join(ROOT, "builds", "prologue"))
os.makedirs(OUT, exist_ok=True)
SOURCES = os.path.join(ROOT, "assets", "sprites", "nico_prologue", "source")
W, H, S = m2.W, m2.H, 3
FPS = 30
SECONDS = 11.0
FRAMES = int(FPS * SECONDS)
smooth = v5.smooth


def black(t):
    """1 = fully visible, 0 = black."""
    f = smooth(0, 1, t / 0.9)                                     # fade in at the start
    for a, b, c, d in ((5.5, 5.8, 5.8, 6.1), (8.0, 8.3, 8.3, 8.6)):   # two dips: into the close-up and out of it
        if a <= t < d:
            f = min(f, smooth(1, 0, (t - a) / (b - a)) if t < b else smooth(0, 1, (t - c) / (d - c)))
    if t >= 10.0:
        f = min(f, smooth(1, 0, (t - 10.0) / 0.8))                # out to black at the end
    return f


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
    elif t < 8.3:
        z, c = 4.4, (comp[0] - 2, comp[1])                       # (hidden by the close-up while it is on screen)
    else:
        k = (t - 8.3) / 2.5
        z = smooth(2.5, 1.5, k)
        c = (smooth(head[0] + 4, 250, k), smooth(head[1] + 2, 190, k))
    c = (c[0], c[1] + math.sin(t * 0.9) * 0.5)
    w, h = W / z, H / z
    cx = min(max(c[0], w / 2), W - w / 2)
    cy = min(max(c[1], h / 2), H - h / 2)
    box = ((cx - w / 2) * S, (cy - h / 2) * S, (cx + w / 2) * S, (cy + h / 2) * S)
    return Image.fromarray(hi_frame).resize((W, H), Image.BICUBIC, box=box)


def main():
    m3.CUFF = (126, 78, 48, 255)
    frames = []
    for i in range(FRAMES):
        t = i / FPS
        hi, anchors = v5.build_frame(t)
        cam = camera(hi, t, anchors).convert("RGB")
        out = cam
        if 5.8 <= t < 8.3:                                         # the close-up replaces the shot (no blending)
            out = m3.compass_closeup(t - 0.6, cam)
        frame = m2.vignette(np.array(out).astype(np.float32)) * black(t)
        frames.append(Image.fromarray(np.clip(frame, 0, 255).astype(np.uint8)))
        if i % 60 == 0:
            print("frame", i, "of", FRAMES)
    frames[0].save(os.path.join(OUT, "scene3_compass_v7.gif"), save_all=True, append_images=frames[1:], duration=1000 // FPS, loop=0)
    sheet = Image.new("RGB", (W * 3, H * 3))
    for k, tt in enumerate((0.3, 2.8, 5.0, 5.65, 6.5, 8.15, 8.9, 10.2, 10.7)):
        sheet.paste(frames[min(int(tt * FPS), FRAMES - 1)], ((k % 3) * W, (k // 3) * H))
    sheet.save(os.path.join(OUT, "scene3_v7_sheet.png"))
    print("ok")


if __name__ == "__main__":
    main()
