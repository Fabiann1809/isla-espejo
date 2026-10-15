"""Turns the artist's source files into game-ready PNGs (everything is a 4x upscale of the real art).
 - murcielago_source.gif (47 frames, 248x248) -> murcielago.png, 8 columns of 62x62 cells
 - guardian_antiguo_source.png (192x192)       -> guardian_antiguo.png, 48x48
Run from the repo root: python tools/make_monster_sheets.py (needs Pillow), then
godot --headless --path . --script res://tools/make_monsters.gd"""
from PIL import Image

gif = Image.open("assets/sprites/murcielago/murcielago_source.gif")
CELL, COLS = 62, 8
n = gif.n_frames
sheet = Image.new("RGBA", (COLS * CELL, ((n + COLS - 1) // COLS) * CELL), (0, 0, 0, 0))
for i in range(n):
    gif.seek(i)
    sheet.paste(gif.convert("RGBA").resize((CELL, CELL), Image.NEAREST), ((i % COLS) * CELL, (i // COLS) * CELL))
sheet.save("assets/sprites/murcielago/murcielago.png")

golem = Image.open("assets/sprites/guardian_antiguo/guardian_antiguo_source.png").convert("RGBA")
golem.resize((48, 48), Image.NEAREST).save("assets/sprites/guardian_antiguo/guardian_antiguo.png")
print(n, "bat frames")
