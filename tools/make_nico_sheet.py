"""Turns the artist's Nico.gif (64 frames, 32x32) into a sprite sheet PNG (8 columns, 1:1).
Run from the repo root: python tools/make_nico_sheet.py  (needs Pillow)
Then: godot --headless --path . --script res://tools/make_nico_frames.gd

The GIF is a pack of different animations (see tools/make_nico_frames.gd for the frame map).
The game flips the art when Nico faces left, so every cell that is used for movement must face
right: the side idle (8-15) and side walk (23-31) are drawn facing left in the GIF and are
mirrored here."""
from PIL import Image, ImageOps

SRC = "assets/sprites/nico/nico_source.gif"
CELL, COLS = 32, 8
MIRROR = list(range(8, 16)) + list(range(23, 32))
gif = Image.open(SRC)
n = gif.n_frames
sheet = Image.new("RGBA", (COLS * CELL, ((n + COLS - 1) // COLS) * CELL), (0, 0, 0, 0))
for i in range(n):
    gif.seek(i)
    frame = gif.convert("RGBA")
    if i in MIRROR:
        frame = ImageOps.mirror(frame)
    sheet.paste(frame, ((i % COLS) * CELL, (i // COLS) * CELL))
sheet.save("assets/sprites/nico/nico.png")
print(n, "frames")

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
print("sword written")
