"""Builds the Anciano's idle: standing still, breathing slowly.

His sheet's idle row (assets/sprites/npcs/elder/elder.png, second row) is a walk on the spot whose
feet land on a different row in each frame, so at 6 frames per second he never stopped moving. The
idle is now the one frame of that row where he stands on both feet, moved down so his feet rest on
the row the others used, in two frames: as he is, and breathing
in, with his head, shoulders and staff a little lower (2 px of the 64 px cell = 1 px in the game,
where he is drawn at half size). His feet never move.

    python tools/make_elder_idle.py
Writes assets/sprites/npcs/elder/elder_idle.png (two 64x64 cells); data/npcs/elder_frames.tres
plays it as "idle". Needs Pillow.
"""
import os

from PIL import Image

DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "npcs", "elder")
CELL = 64
## The frame of the idle row where he stands on both feet, and how far down its feet go to rest on
## row 62 like the rest of his frames.
STANDING = (64, 64)
FEET_DOWN = 2
## Rows above this one sink while he breathes in (his chest); the rest stays put.
CHEST_ROW = 34
BREATH = 2


def main():
    sheet = Image.open(os.path.join(DIR, "elder.png")).convert("RGBA")
    still = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    still.paste(sheet.crop((STANDING[0], STANDING[1], STANDING[0] + CELL, STANDING[1] + CELL - FEET_DOWN)), (0, FEET_DOWN))
    breath = still.copy()
    upper = still.crop((0, 0, CELL, CHEST_ROW))
    # Clear the top, then lay the upper body back down a little lower, over the top of the chest.
    breath.paste((0, 0, 0, 0), (0, 0, CELL, CHEST_ROW + BREATH))
    breath.paste(still.crop((0, CHEST_ROW, CELL, CHEST_ROW + BREATH)), (0, CHEST_ROW))
    breath.alpha_composite(upper, (0, BREATH))
    strip = Image.new("RGBA", (CELL * 2, CELL), (0, 0, 0, 0))
    strip.paste(still, (0, 0))
    strip.paste(breath, (CELL, 0))
    strip.save(os.path.join(DIR, "elder_idle.png"))
    print("elder idle written")


if __name__ == "__main__":
    main()
