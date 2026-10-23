"""Turns the artist's character art into game-ready sprite sheets (1:1, no scaling, 8 columns).
Usage from the repo root (needs Pillow):  python tools/make_character_sheets.py <art folder>
Then: godot --headless --path . --script res://tools/make_character_frames.gd

Enemies: <art folder>/<name>.gif is copied to assets/sprites/<folder>/<folder>_source.gif and its
frames are laid out in <folder>.png (32x32 or 64x64 cells, in GIF order).
NPCs: the 8 rotation PNGs and the south animation are laid out in assets/sprites/npcs/<id>/<id>.png:
cells 0-7 are the rotations (east, north-east, north-west, north, south-east, south-west, south,
west), the rest is the animation. Its 84/96 px frames are cropped to 64x64 so the character matches
the rotations (same horizontal center, feet on row 62)."""
import glob
import os
import shutil
import sys

from PIL import Image

ART = sys.argv[1]
COLS = 8
# GIF file -> folder under assets/sprites/
ENEMIES = {
    "sombra errante.gif": "sombra_errante",
    "murcielago.gif": "murcielago",
    "guardian antiguo.gif": "guardian_antiguo",
    "guardian del bosque.gif": "guardian_del_bosque",
    "serpiente.gif": "serpiente",
    "guardian de la isla.gif": "guardian_de_la_isla",
}
# art subfolder -> NPC id
NPCS = {
    "personajesMapas/el_mago": "elder",
    "personajesMapas/La_Viajera_Complet": "traveler",
    "personajesMapas/3._El_Mercader_NPC": "merchant",
}
# Their cells vary a lot in size (a bat's wings up or down), so each cell is shifted to put the
# body on the cell center: the sprite then does not jump between frames.
ANCHORED = {"murcielago"}
ROTATIONS = ["east", "north-east", "north-west", "north", "south-east", "south-west", "south", "west"]


def anchor(frame: Image.Image) -> Image.Image:
    """Centers the cell on the sprite's horizontal middle and on its body (the central columns:
    the wings swing up and down and would drag a plain center of mass with them)."""
    alpha = frame.getchannel("A")
    left, top, right, bottom = alpha.getbbox()
    middle = (left + right) // 2
    total = body_rows = body_pixels = 0
    for y in range(frame.height):
        for x in range(frame.width):
            if alpha.getpixel((x, y)) > 0:
                total += 1
                if abs(x - middle) <= 8:
                    body_rows += y
                    body_pixels += 1
    dx, dy = frame.width // 2 - middle, round(frame.height / 2 - body_rows / body_pixels)
    # Never push pixels out of the cell (a full-wing frame may not reach the exact center).
    dx = max(-left, min(frame.width - right, dx))
    dy = max(-top, min(frame.height - bottom, dy))
    moved = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    moved.paste(frame, (dx, dy))
    kept = sum(1 for v in moved.getchannel("A").getdata() if v > 0)
    assert kept == total, "anchoring clipped pixels"
    return moved


def save_sheet(frames: list, cell: int, path: str) -> None:
    sheet = Image.new("RGBA", (COLS * cell, ((len(frames) + COLS - 1) // COLS) * cell), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        sheet.paste(frame, ((i % COLS) * cell, (i // COLS) * cell))
    sheet.save(path)


for gif_name, folder in ENEMIES.items():
    out = f"assets/sprites/{folder}"
    os.makedirs(out, exist_ok=True)
    shutil.copyfile(os.path.join(ART, gif_name), f"{out}/{folder}_source.gif")
    gif = Image.open(f"{out}/{folder}_source.gif")
    frames = []
    for i in range(gif.n_frames):
        gif.seek(i)
        frames.append(gif.convert("RGBA"))
    if folder in ANCHORED:
        frames = [anchor(f) for f in frames]
    save_sheet(frames, frames[0].width, f"{out}/{folder}.png")
    print(folder, len(frames), "frames of", frames[0].size)

for sub, npc in NPCS.items():
    src = os.path.join(ART, sub)
    out = f"assets/sprites/npcs/{npc}"
    os.makedirs(f"{out}/source/rotations", exist_ok=True)
    os.makedirs(f"{out}/source/south", exist_ok=True)
    rotations = []
    for name in ROTATIONS:
        shutil.copyfile(f"{src}/rotations/{name}.png", f"{out}/source/rotations/{name}.png")
        rotations.append(Image.open(f"{out}/source/rotations/{name}.png").convert("RGBA"))
    files = sorted(glob.glob(f"{src}/animations/*/south/frame_*.png"))
    anim = []
    for path in files:
        shutil.copyfile(path, f"{out}/source/south/{os.path.basename(path)}")
        anim.append(Image.open(path).convert("RGBA"))
    left, _, right, bottom = anim[0].getchannel("A").getbbox()
    box_left = (left + right) // 2 - 32
    box_top = bottom - 62
    anim = [f.crop((box_left, box_top, box_left + 64, box_top + 64)) for f in anim]
    save_sheet(rotations + anim, 64, f"{out}/{npc}.png")
    print(npc, len(rotations), "rotations +", len(anim), "animation frames")
