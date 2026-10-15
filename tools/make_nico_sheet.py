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
