"""The Ruinas' fires and lamps, drawn pixel by pixel at their own size (not a 16 px tile): a carved brazier, a standing
torch, an iron lantern and a campfire, each in three frames of flickering flame. Run from the project root:
    python tools/make_ruins_fire_art.py [preview.png]
Writes assets/sprites/ruins_props/<name>_<0-2>.png (brazier, torch, lantern, campfire); RuinProp draws them over a
tile, feet at the tile's bottom edge. Stone in the pillars' blue, iron, wood; flame from deep red to a white core."""
import math
import os
import random
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites", "ruins_props")
FRAMES = 3


def C(h, a=255):
    return (int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16), a)


def dark(c, f=0.72):
    return (int(c[0] * f), int(c[1] * f), int(min(255, c[2] * (f + 0.04))), c[3])


OUTLINE = C("#090a1c")
# stone: the pillars' tones, a little darker
S2, S1, M0, M, M2, L, HI = [dark(C(h)) for h in ("#262b62", "#343b78", "#475496", "#4d5aa0", "#53609f", "#6f7fc0", "#95a4de")]
IRON_D, IRON, IRON_L = C("#1d2136"), C("#2f3550"), C("#59627f")
WOOD_D, WOOD, WOOD_L, WOOD_HI = C("#3a2210"), C("#5d3a1a"), C("#7e5128"), C("#a06a36")
FIRE = (C("#a4260f"), C("#d9501a"), C("#ff8a1e"), C("#ffc43a"), C("#fff3b0"))
EMBER = (C("#7a1c0c"), C("#c2410c"), C("#ff7a2a"))
GLASS = (C("#3a2410"), C("#a8561a"), C("#ffb03a"), C("#ffe27a"))


class Cv:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.px = self.img.load()

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = c

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, c)

    def outline(self):
        src = self.img.copy().load()
        for y in range(self.h):
            for x in range(self.w):
                if src[x, y][3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < self.w and 0 <= ny < self.h and src[nx, ny][3] > 0:
                            self.px[x, y] = OUTLINE
                            break
        return self


def flame(cv, cx, base_y, h, w, frame, seed=1):
    """A flame standing on (cx, base_y): four nested layers, the tip and the width swaying a little per frame."""
    rng = random.Random(seed * 7 + frame)
    sway = (0.0, 1.1, -0.9)[frame % 3]
    for layer, (shrink, top, color) in enumerate(((1.0, 1.0, FIRE[1]), (0.78, 0.86, FIRE[2]), (0.5, 0.66, FIRE[3]), (0.28, 0.42, FIRE[4]))):
        height = h * top * (1.0 + 0.06 * (frame - 1))
        for i in range(int(height) + 1):
            t = i / max(1.0, height)
            half = w / 2.0 * shrink * (1.0 - t) ** 0.62 * (0.88 + 0.12 * math.cos(frame * 2.2 + t * 4.0))
            if t > 0.9:
                half = max(half, 0.0)
            x_mid = cx + sway * t * 1.6 * (1.0 + layer * 0.2)
            y = base_y - i
            for x in range(int(round(x_mid - half)), int(round(x_mid + half)) + 1):
                cv.put(x, y, color)
        if layer == 0:                                   # the red root of the flame, wider at the foot
            for x in range(int(cx - w / 2.0), int(cx + w / 2.0) + 1):
                cv.put(x, base_y, FIRE[0])
    for _ in range(2):                                   # sparks above the tip
        sx = int(cx + rng.uniform(-w / 2.0, w / 2.0))
        sy = int(base_y - h - rng.uniform(1, 4))
        cv.put(sx, sy, FIRE[3] if rng.random() < 0.5 else FIRE[2])


def brazier(frame):
    """A carved stone brazier: a plinth, a shaft with a diamond, a bowl full of coals and a flame. 24x34."""
    cv = Cv(24, 34)
    # plinth
    cv.rect(3, 29, 20, 32, M)
    cv.rect(3, 29, 20, 29, L)
    cv.rect(3, 32, 20, 32, S1)
    cv.rect(18, 30, 20, 31, M0)
    # shaft
    cv.rect(8, 21, 15, 28, M)
    cv.rect(8, 21, 9, 28, L)
    cv.rect(14, 21, 15, 28, M0)
    for y, dx in ((24, 0), (25, 1), (26, 0)):
        cv.put(11 + dx, y, S2)
    cv.put(12, 25, C("#5cc8ff"))
    cv.rect(6, 27, 17, 28, M2)
    cv.rect(6, 27, 17, 27, L)
    # bowl
    for y in range(15, 22):
        t = (y - 15) / 6.0
        half = int(round(10 - 3 * t))
        for x in range(12 - half, 12 + half):
            c = M if x > 8 else L
            if x >= 12 + half - 3:
                c = M0
            if y == 15:
                c = HI if x < 16 else L
            if y == 21:
                c = S1
            cv.put(x, y, c)
    cv.rect(2, 14, 21, 15, L)
    cv.rect(2, 14, 21, 14, HI)
    cv.rect(3, 16, 20, 16, M2)
    # coals
    for x in range(5, 19):
        cv.put(x, 13, EMBER[(x + frame) % 3])
    flame(cv, 12, 13, 15, 11, frame, 3)
    return cv.outline().img


def torch(frame):
    """A standing torch: a square stone foot, an iron pole with a ring, a cup and the flame. 14x34."""
    cv = Cv(14, 34)
    cv.rect(2, 28, 11, 32, M)
    cv.rect(2, 28, 11, 28, L)
    cv.rect(2, 32, 11, 32, S1)
    cv.rect(9, 29, 11, 31, M0)
    cv.rect(6, 12, 7, 27, IRON)
    cv.rect(6, 12, 6, 27, IRON_L)
    cv.rect(5, 22, 8, 23, IRON_L)
    cv.rect(5, 23, 8, 23, IRON)
    cv.rect(3, 10, 10, 12, IRON)
    cv.rect(2, 9, 11, 9, IRON_L)
    cv.rect(3, 12, 10, 12, IRON_D)
    for x in range(4, 10):
        cv.put(x, 8, EMBER[(x + frame) % 3])
    flame(cv, 7, 8, 11, 7, frame, 5)
    return cv.outline().img


def lantern(frame):
    """An iron lantern standing on the floor: a ring, a cap, four posts around a glass that glows. 14x22."""
    cv = Cv(14, 22)
    glow = (0.0, 0.5, 1.0)[frame % 3]
    cv.rect(4, 0, 9, 0, IRON_L)                                 # the ring
    cv.put(4, 1, IRON_L)
    cv.put(9, 1, IRON_L)
    cv.rect(4, 2, 9, 2, IRON_L)
    cv.rect(3, 3, 10, 4, IRON)                                  # the cap
    cv.rect(3, 3, 10, 3, IRON_L)
    cv.rect(2, 5, 11, 5, IRON_D)
    for y in range(6, 17):                                      # the glass: a hot center, an amber rim
        for x in range(3, 11):
            d = abs(x - 6.5) / 3.5
            v = max(0.0, 1.0 - d * d) * (0.75 + 0.25 * glow) * (1.0 - abs(y - 11) / 8.0)
            cv.put(x, y, GLASS[3] if v > 0.55 else (GLASS[2] if v > 0.34 else (GLASS[1] if v > 0.12 else GLASS[0])))
    cv.rect(6, 9 + (frame % 2), 7, 13, GLASS[3])                # the flame inside
    cv.put(6, 8 + (frame % 2), GLASS[2])
    for x in (2, 11):                                           # the posts
        cv.rect(x, 5, x, 17, IRON_L if x == 2 else IRON)
    cv.rect(3, 11, 10, 11, IRON_D)                              # a band
    cv.rect(2, 17, 11, 18, IRON)                                # the base
    cv.rect(2, 17, 11, 17, IRON_L)
    cv.rect(3, 19, 10, 20, M)
    cv.rect(3, 19, 10, 19, L)
    cv.rect(3, 20, 10, 20, S1)
    return cv.outline().img


def campfire(frame):
    """A campfire: a ring of stones, two crossed logs burnt at the ends, embers and a lively flame. 30x24."""
    cv = Cv(30, 24)
    rng = random.Random(11)
    for i in range(9):                                          # the ring of stones
        a = math.pi * 2 * i / 9.0
        x, y = int(round(15 + math.cos(a) * 11)), int(round(17 + math.sin(a) * 4.5))
        cv.rect(x - 2, y - 1, x + 2, y + 1, M)
        cv.rect(x - 2, y - 1, x + 1, y - 1, L)
        cv.rect(x - 1, y + 1, x + 2, y + 1, S1)
    for dx in range(-8, 9):                                     # two logs
        y1 = 17 + (dx // 3) - 1
        for k in range(3):
            cv.put(15 + dx, y1 + k, WOOD_L if k == 0 else (WOOD if k == 1 else WOOD_D))
        y2 = 17 - (dx // 3) - 1
        for k in range(3):
            cv.put(15 + dx, y2 + k, WOOD_L if k == 0 else (WOOD if k == 1 else WOOD_D))
    for x in (7, 23):                                           # the burnt ends
        cv.rect(x - 1, 14, x + 1, 19, WOOD_D)
    for _ in range(14):                                         # embers
        cv.put(rng.randrange(9, 21), rng.randrange(16, 20), EMBER[(frame + rng.randrange(3)) % 3])
    flame(cv, 15, 17, 16, 12, frame, 9)
    return cv.outline().img


def main():
    os.makedirs(OUT, exist_ok=True)
    makers = {"brazier": brazier, "torch": torch, "lantern": lantern, "campfire": campfire}
    sheet = Image.new("RGBA", (4 * 3 * 40 + 20, 60), (22, 26, 46, 255))
    x = 8
    for name, make in makers.items():
        for f in range(FRAMES):
            img = make(f)
            img.save(os.path.join(OUT, f"{name}_{f}.png"))
            sheet.alpha_composite(img, (x, 56 - img.height))
            x += img.width + 6
        x += 8
    preview = sys.argv[1] if len(sys.argv) > 1 else None
    if preview:
        sheet.crop((0, 0, x, 60)).resize((x * 6, 360), Image.NEAREST).save(preview)
    print("ok")


if __name__ == "__main__":
    main()
