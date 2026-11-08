"""Cuts the Ruinas' statues out of the reference picture and turns them into game-size pixel art. Run from the root:
    python tools/make_ruins_statues.py <reference.jpg> [out_dir] [height]
The picture (an AI render of pixel art on a green background, two rows of four: clean, with vines, cracked,
ruined / clean, with vines, worn, headless) is chroma-keyed (the green is the background, the vines are greener
and brighter), each statue is found by its outline, shrunk to `height` px (default 64: a little taller than
two Niccos, as the reference asks) with an area average, brought down to a short palette and given the same
1 px dark outline as the rest of the art. Writes statue_<variant>.png (transparent) and a preview sheet.
Variants, in reading order: clean, vines, cracked, ruined, plain, ivy, worn, headless."""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.expanduser("~"), "Downloads", "estatua.jpg")
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.expanduser("~"), "Documents", "capturas-mapas", "ruinas_v2", "estatuas")
HEIGHT = int(sys.argv[3]) if len(sys.argv) > 3 else 64
NAMES = ("clean", "vines", "cracked", "ruined", "plain", "ivy", "worn", "headless")
OUTLINE = (9, 10, 28, 255)
COLORS = 48


def background_distance(rgb):
    """How far each pixel is from the picture's green (its median over the four corners and the edges)."""
    edge = np.concatenate([rgb[:12].reshape(-1, 3), rgb[-12:].reshape(-1, 3), rgb[:, :12].reshape(-1, 3), rgb[:, -12:].reshape(-1, 3)])
    bg = np.median(edge, axis=0)
    return np.sqrt(((rgb - bg) ** 2).sum(axis=2)), bg


def find_statues(mask):
    """The eight bounding boxes, in reading order: split the picture into its two rows at the emptiest line of
    the middle third, then group each row's pieces by columns (rubble and vines stay with their statue)."""
    h = mask.shape[0]
    rows = mask.sum(axis=1)
    mid = h // 3 + int(np.argmin(rows[h // 3:2 * h // 3]))
    boxes = []
    for y0, y1 in ((0, mid), (mid, h)):
        band = mask[y0:y1]
        grown = ndimage.binary_dilation(band, structure=np.ones((1, 61), bool))
        labels, count = ndimage.label(grown)
        found = []
        for sl in ndimage.find_objects(labels):
            piece = band[sl]
            if piece.sum() < 4000:
                continue
            ys, xs = np.nonzero(piece)
            found.append((sl[1].start + xs.min(), y0 + sl[0].start + ys.min(), sl[1].start + xs.max() + 1, y0 + sl[0].start + ys.max() + 1))
        boxes.extend(sorted(found))
    return boxes


def cut(image, mask, box):
    x0, y0, x1, y1 = box
    crop = image.crop(box)
    m = mask[y0:y1, x0:x1].copy()
    m = ndimage.binary_opening(m, iterations=1)
    m = ndimage.binary_fill_holes(m)
    m = ndimage.binary_erosion(m, iterations=2)            # the edge's green fringe goes with it
    labels, n = ndimage.label(m)
    if n > 1:                                              # keep the statue and what touches it (rubble, vines)
        sizes = ndimage.sum(m, labels, range(1, n + 1))
        keep = {i + 1 for i, s in enumerate(sizes) if s > 0.002 * m.size}
        m = np.isin(labels, list(keep))
    out = crop.convert("RGBA")
    out.putalpha(Image.fromarray((m * 255).astype("uint8"), "L"))
    bbox = out.getbbox()
    return out.crop(bbox)


def to_pixel_art(img, height):
    scale = height / img.height
    w = max(8, round(img.width * scale))
    # an area average on premultiplied colors so the edge does not pick up the transparent black
    arr = np.asarray(img).astype(float)
    alpha = arr[..., 3:4] / 255.0
    pre = np.concatenate([arr[..., :3] * alpha, alpha * 255], axis=2)
    small = np.asarray(Image.fromarray(pre.astype("uint8"), "RGBA").resize((w, height), Image.BOX)).astype(float)
    a = small[..., 3:4] / 255.0
    rgb = np.where(a > 0.01, small[..., :3] / np.maximum(a, 0.01), 0).clip(0, 255)
    opaque = a[..., 0] > 0.5
    flat = Image.fromarray(rgb.astype("uint8"), "RGB")
    pal = flat.quantize(colors=COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    res = np.asarray(pal).astype("uint8")
    out = np.zeros((height, w, 4), dtype="uint8")
    out[..., :3] = res
    out[..., 3] = np.where(opaque, 255, 0)
    img = Image.fromarray(out, "RGBA")
    return outline(img)


def outline(img):
    """A 1 px dark line around the shape, as every sprite of the game has."""
    w, h = img.size
    big = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    big.alpha_composite(img, (1, 1))
    px, src = big.load(), big.copy().load()
    for y in range(h + 2):
        for x in range(w + 2):
            if src[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w + 2 and 0 <= ny < h + 2 and src[nx, ny][3] > 0 and src[nx, ny] != OUTLINE:
                        px[x, y] = OUTLINE
                        break
    return big


def main():
    os.makedirs(OUT, exist_ok=True)
    image = Image.open(SRC).convert("RGB")
    rgb = np.asarray(image).astype(float)
    dist, bg = background_distance(rgb)
    mask = dist > 34
    boxes = find_statues(mask)
    print("found", len(boxes), "statues; background", bg.astype(int))
    sprites = []
    for name, box in zip(NAMES, boxes):
        sprite = to_pixel_art(cut(image, mask, box), HEIGHT)
        sprite.save(os.path.join(OUT, f"statue_{name}.png"))
        sprites.append(sprite)
        print(name, sprite.size)
    pad = 10
    cols = 4
    cell_w = max(s.width for s in sprites) + pad
    cell_h = max(s.height for s in sprites) + pad
    sheet = Image.new("RGBA", (cols * cell_w + pad, 2 * cell_h + pad), (26, 29, 51, 255))
    for i, s in enumerate(sprites):
        sheet.alpha_composite(s, (pad + (i % cols) * cell_w + (cell_w - pad - s.width) // 2,
                                  pad + (i // cols) * cell_h + (cell_h - pad - s.height)))
    sheet.resize((sheet.width * 6, sheet.height * 6), Image.NEAREST).save(os.path.join(OUT, "estatuas_x6.png"))


if __name__ == "__main__":
    main()
