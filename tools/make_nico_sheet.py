"""Turns the artist's Nico.gif (58 frames, 248x248 = 4x upscaled 62x62) into a sprite sheet PNG.
Run from the repo root: python tools/make_nico_sheet.py  (needs Pillow)
Then: godot --headless --path . --script res://tools/make_nico_frames.gd"""
from PIL import Image

SRC = "assets/sprites/nico/nico_source.gif"
CELL, COLS = 62, 8
gif = Image.open(SRC)
n = gif.n_frames
sheet = Image.new("RGBA", (COLS * CELL, ((n + COLS - 1) // COLS) * CELL), (0, 0, 0, 0))
for i in range(n):
    gif.seek(i)
    frame = gif.convert("RGBA").resize((CELL, CELL), Image.NEAREST)
    sheet.paste(frame, ((i % COLS) * CELL, (i // COLS) * CELL))
sheet.save("assets/sprites/nico/nico.png")
print(n, "frames")

# --- Attack art -------------------------------------------------------------------------------
# Cell `n` (right after the walk frames) is frame 0 with the sword erased, so the sword can be
# swung as its own sprite (assets/sprites/nico/sword.png) while Nico attacks.
STEEL = lambda p: p[3] > 0 and p[2] >= p[0] - 5 and max(p[:3]) > 90
cell = sheet.crop((0, 0, CELL, CELL)).copy()
px = cell.load()
seen, best = set(), []
for sx in range(CELL):
    for sy in range(CELL):
        if (sx, sy) in seen or not STEEL(px[sx, sy]):
            continue
        comp, stack = [], [(sx, sy)]
        seen.add((sx, sy))
        while stack:
            x, y = stack.pop()
            comp.append((x, y))
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    q = (x + dx, y + dy)
                    if 0 <= q[0] < CELL and 0 <= q[1] < CELL and q not in seen and STEEL(px[q]):
                        seen.add(q)
                        stack.append(q)
        if len(comp) > len(best):
            best = comp
erase = set(best)
for x, y in best:  # the dark outline around the blade goes too
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            q = (x + dx, y + dy)
            if 0 <= q[0] < CELL and 0 <= q[1] < CELL and px[q][3] > 0 and max(px[q][:3]) < 40:
                erase.add(q)
for q in erase:
    px[q] = (0, 0, 0, 0)
# floating specks of leftover outline (disconnected from the body) go as well
seen = set()
for sx in range(CELL):
    for sy in range(CELL):
        if (sx, sy) in seen or px[sx, sy][3] == 0:
            continue
        comp, stack = [], [(sx, sy)]
        seen.add((sx, sy))
        while stack:
            x, y = stack.pop()
            comp.append((x, y))
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    q = (x + dx, y + dy)
                    if 0 <= q[0] < CELL and 0 <= q[1] < CELL and q not in seen and px[q][3] > 0:
                        seen.add(q)
                        stack.append(q)
        if len(comp) < 60:
            for q in comp:
                px[q] = (0, 0, 0, 0)
sheet.paste(cell, ((n % COLS) * CELL, (n // COLS) * CELL))
sheet.save("assets/sprites/nico/nico.png")

# The sword that swings: 24x7, points right, grip at its left end (pivot at x=3, y=3).
K, HI, MID, LO, GUARD, GRIP = (8, 6, 14), (218, 225, 230), (176, 176, 189), (106, 127, 144), (131, 131, 180), (110, 62, 40)
sword = Image.new("RGBA", (24, 7), (0, 0, 0, 0))
sp = sword.load()
for x in range(0, 22):                       # outline of the blade
    for y in (1, 5):
        sp[x, y] = K
for x in range(5, 22):
    sp[x, 2], sp[x, 3], sp[x, 4] = HI, MID, LO
sp[22, 3] = K; sp[22, 2] = K; sp[22, 4] = K; sp[23, 3] = K
for y in range(0, 7):                        # cross guard
    sp[4, y] = GUARD if 1 <= y <= 5 else K
for x in range(0, 4):                        # grip
    sp[x, 2], sp[x, 3], sp[x, 4] = GRIP, GRIP, GRIP
    sp[x, 1] = sp[x, 5] = K
sword.save("assets/sprites/nico/sword.png")
print("attack cell", n, "erased", len(erase), "px")
