"""Draws Nico's sword, assets/sprites/nico/sword.png (24x7, points right, grip at its left end,
pivot at x=3, y=3). Nico's body art no longer comes from here: it is the strips
assets/sprites/nico/nico_<animation>_<view>.png, read by tools/make_nico_frames.gd.
The old Nico.gif sheet and its sources are kept in assets/sprites/nico/_old/.
Run from the repo root only to redraw the sword: python tools/make_nico_sheet.py  (needs Pillow)"""
from PIL import Image

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
