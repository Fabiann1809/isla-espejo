"""Native pixel sources for the front-only merchant and the six 24px shop icons.

Run with Python + Pillow, then import in Godot and run make_merchant_frames.gd.
No body bob is baked into idle: IdleBreath owns it. Feet stay on row 62 in all
64px cells, matching npc.gd's half-scale alignment. This file is the editable
source (enemy_aseprite.lua requires six enemy animations, unlike this NPC).
Previews, including a simulation of IdleBreath, are written only to tmp_preview.
"""
from pathlib import Path
import math
from PIL import Image, ImageDraw
from temple_palette import (OUTLINE, STONE_COOL_D, STONE_1, STONE_2, STONE_3,
                            STONE_4, STONE_HI, STONE_PALE, BRONZE_D, BRONZE_1,
                            BRONZE_2, GOLD_HI, LAVA_HI, LAVA_CORE, MOSS_D,
                            MOSS_1, MOSS_2, BANNER_D, BANNER_1, BANNER_2)

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/sprites/npcs/merchant'
SHOP = ROOT / 'assets/sprites/shop'
PREVIEW = ROOT / 'tmp_preview/merchant'
# 24 shared colors, including three glass tones for shop bottles.
P = dict(o=OUTLINE, dark=STONE_COOL_D, cloth=STONE_1, fold=STONE_2,
         light=STONE_3, skin=STONE_4, face=STONE_HI, pale=STONE_PALE,
         leather=BRONZE_D, hide=BRONZE_1, bronze=BRONZE_2, gold=GOLD_HI,
         amber=LAVA_HI, white=LAVA_CORE, moss0=MOSS_D, moss=MOSS_1,
         moss2=MOSS_2, red0=BANNER_D, red=BANNER_1, red2=BANNER_2,
         glass0='#25454b', glass='#487b80', glass2='#85b9af', blue='#536d9c')


class Canvas:
    def __init__(self, size):
        self.im = Image.new('RGBA', (size, size))
        self.d = ImageDraw.Draw(self.im)

    def poly(self, points, color, outline=True):
        self.d.polygon(points, fill=P[color])
        if outline:
            self.d.line(points + [points[0]], fill=P['o'], width=1)

    def rect(self, box, color, outline=False):
        self.d.rectangle(box, fill=P[color], outline=P['o'] if outline else None)

    def line(self, points, color, width=1):
        self.d.line(points, fill=P[color], width=width)

    def ellipse(self, box, color, outline=True):
        self.d.ellipse(box, fill=P[color], outline=P['o'] if outline else None)


def merchant(frame, interact=False):
    c = Canvas(64)
    # Pack frame, side bundles and rolled blanket behind the hood.
    c.poly([(13, 16), (18, 10), (44, 10), (49, 17), (49, 45),
            (44, 49), (14, 47)], 'leather')
    c.rect((15, 16, 18, 45), 'bronze', True)
    c.rect((44, 16, 47, 46), 'hide', True)
    c.poly([(10, 23), (18, 20), (22, 25), (21, 43), (11, 45), (8, 39)], 'hide')
    c.poly([(10, 25), (16, 23), (15, 40), (10, 39)], 'bronze', False)
    c.line([(10, 31), (20, 30)], 'o')
    c.line([(11, 33), (20, 32)], 'gold')
    c.poly([(43, 21), (52, 23), (54, 39), (49, 44), (43, 40)], 'cloth')
    c.line([(49, 25), (50, 37)], 'light', 2)
    c.line([(44, 30), (52, 32)], 'bronze', 2)
    c.rect((17, 8, 45, 16), 'moss', True)
    c.line([(20, 9), (41, 9)], 'moss2', 2)
    c.ellipse((13, 8, 22, 16), 'moss2')
    c.ellipse((15, 10, 20, 14), 'moss0')
    c.rect((25, 8, 27, 16), 'leather', True)
    c.rect((38, 8, 40, 16), 'leather', True)
    # Fixed feet. Long split coat and a slightly asymmetrical shoulder mantle.
    c.poly([(23, 49), (31, 49), (30, 61), (20, 62), (19, 59)], 'leather')
    c.poly([(34, 49), (41, 49), (44, 59), (43, 62), (33, 62)], 'leather')
    c.line([(21, 59), (28, 59)], 'hide', 2)
    c.line([(35, 59), (41, 59)], 'hide', 2)
    c.poly([(22, 28), (40, 28), (44, 53), (38, 57), (32, 53),
            (27, 57), (18, 54)], 'cloth')
    c.poly([(24, 35), (29, 35), (27, 52), (22, 53)], 'fold', False)
    c.poly([(34, 36), (38, 35), (41, 52), (37, 52)], 'dark', False)
    c.line([(20, 51), (26, 54), (31, 50), (38, 54), (42, 52)], 'bronze', 2)
    c.poly([(18, 27), (24, 24), (39, 24), (45, 29), (43, 37),
            (33, 41), (21, 37), (16, 33)], 'fold')
    c.line([(18, 29), (23, 26), (29, 27)], 'light', 2)
    c.line([(18, 33), (24, 37), (33, 39), (43, 35)], 'bronze', 2)
    # Hood: bright left seam, recessed face, reserved eyes under the brow.
    c.poly([(23, 15), (28, 11), (35, 11), (40, 16), (42, 27),
            (37, 32), (25, 31), (20, 26)], 'cloth')
    c.poly([(23, 17), (28, 13), (33, 13), (28, 19), (24, 28), (22, 25)], 'light', False)
    c.poly([(28, 18), (35, 17), (38, 22), (37, 28), (33, 31), (27, 28), (26, 22)], 'dark')
    c.poly([(28, 23), (36, 23), (36, 27), (32, 29), (28, 27)], 'skin', False)
    c.line([(28, 23), (30, 23)], 'pale')
    c.line([(34, 23), (35, 23)], 'gold')
    c.rect((31, 24, 32, 26), 'face')
    c.line([(30, 28), (34, 28)], 'o')
    c.line([(26, 19), (30, 17), (35, 17)], 'bronze')
    # Diagonal strap, buckle and a weighty coin pouch.
    c.line([(23, 32), (37, 46)], 'o', 4)
    c.line([(23, 32), (37, 46)], 'hide', 2)
    c.rect((27, 36, 31, 40), 'gold', True)
    c.rect((28, 37, 29, 38), 'dark')
    c.line([(22, 44), (40, 44)], 'leather', 3)
    c.poly([(36, 44), (41, 44), (44, 48), (42, 53), (36, 53), (34, 49)], 'hide')
    c.line([(36, 45), (41, 45)], 'gold')
    c.rect((36, 48, 37, 50), 'bronze')
    # Lantern suspended from the left hand. Only it sways in idle.
    c.poly([(17, 35), (22, 37), (21, 43), (16, 43), (14, 39)], 'cloth')
    c.rect((16, 41, 20, 44), 'skin', True)
    sway = [0, 1, 1, 0, -1, -1][frame]
    x = 12 + sway
    c.line([(17, 44), (x + 3, 47)], 'bronze')
    c.ellipse((x + 1, 45, x + 5, 49), 'bronze')
    c.poly([(x, 49), (x + 6, 49), (x + 7, 55), (x + 5, 58),
            (x + 1, 58), (x - 1, 55)], 'bronze')
    c.rect((x + 1, 50, x + 5, 55), 'amber')
    c.rect((x + 1, 50, x + 2, 53), 'white')
    c.line([(x + 3, 50), (x + 3, 56)], 'hide')
    # Right hand lifts a coin toward the customer in the interaction strip.
    lift = [0, 3, 8, 11, 8, 3][frame] if interact else 0
    y = 42 - lift
    c.poly([(40, 35), (44, 35), (48, y - 1), (46, y + 4),
            (41, y + 4), (39, 39)], 'cloth')
    c.line([(43, 36), (45, y)], 'fold', 2)
    c.ellipse((42, y, 47, y + 4), 'face')
    if interact:
        c.ellipse((43, y - 5, 48, y), 'gold')
        c.line([(44, y - 4), (46, y - 4), (44, y - 2)], 'white')
    return c.im


def icon(name):
    c = Canvas(24)
    if name in ('potion', 'elixir'):
        full = name == 'elixir'
        c.rect((9, 3, 14, 6), 'hide', True)
        c.line([(10, 3), (13, 3)], 'bronze')
        c.poly([(8, 6), (15, 6), (15, 10), (19, 13), (19, 19),
                (16, 21), (7, 21), (4, 18), (4, 13), (8, 10)], 'glass0')
        c.poly([(8, 11), (15, 11), (18, 14), (17, 19), (15, 20),
                (7, 20), (5, 17), (5, 14)], 'blue' if full else 'red')
        c.poly([(6, 14), (10, 12), (16, 13), (16, 15), (7, 16)], 'glass' if full else 'red2', False)
        c.line([(7, 12), (6, 14), (6, 17)], 'glass2')
        c.rect((9, 7, 10, 9), 'glass2')
        if full:
            c.poly([(11, 12), (14, 12), (14, 15), (17, 15), (17, 17),
                    (14, 17), (14, 20), (11, 20), (11, 17), (8, 17), (8, 15), (11, 15)], 'gold', False)
            c.rect((9, 6, 14, 7), 'gold')
        else:
            c.rect((10, 15, 13, 18), 'pale', True)
    elif name == 'taut_string':
        c.poly([(5, 3), (9, 3), (14, 6), (17, 10), (18, 15),
                (17, 20), (14, 21), (15, 16), (14, 12), (11, 8), (7, 6)], 'bronze')
        c.line([(7, 4), (12, 7), (15, 11)], 'gold')
        c.line([(5, 4), (16, 20)], 'o', 3)
        c.line([(5, 4), (16, 20)], 'pale')
        c.line([(12, 10), (16, 15)], 'leather', 3)
        c.line([(13, 10), (16, 14)], 'gold')
    elif name == 'hawk_eye':
        c.poly([(2, 11), (7, 6), (15, 6), (21, 10), (19, 15),
                (13, 18), (6, 16)], 'hide')
        c.poly([(4, 11), (9, 8), (15, 8), (19, 11), (15, 15), (8, 14)], 'pale')
        c.ellipse((9, 8, 15, 15), 'gold')
        c.ellipse((11, 9, 13, 14), 'o', False)
        c.rect((10, 9, 11, 10), 'white')
        c.line([(4, 8), (8, 5), (16, 5), (21, 8)], 'dark', 2)
        c.line([(12, 2), (12, 4)], 'gold')
        c.line([(12, 19), (12, 21)], 'gold')
    elif name == 'stone_heart':
        c.poly([(3, 6), (7, 3), (11, 4), (12, 6), (16, 3),
                (20, 5), (22, 10), (19, 15), (12, 21), (4, 14), (2, 10)], 'light')
        c.poly([(4, 6), (7, 4), (10, 5), (11, 8), (5, 12), (3, 10)], 'pale', False)
        c.poly([(12, 8), (17, 5), (20, 6), (20, 10), (12, 18)], 'skin', False)
        c.poly([(5, 13), (11, 11), (12, 19)], 'fold', False)
        c.line([(12, 6), (10, 10), (14, 12), (12, 16)], 'o')
        c.line([(13, 7), (12, 10)], 'bronze')
    elif name == 'gold_coin':
        c.ellipse((3, 3, 21, 21), 'leather')
        c.ellipse((2, 2, 20, 20), 'gold')
        c.ellipse((5, 5, 17, 17), 'bronze')
        c.line([(5, 13), (5, 8), (8, 5), (14, 5)], 'amber')
        c.poly([(11, 7), (14, 10), (11, 15), (8, 12)], 'gold')
        c.line([(11, 8), (9, 11)], 'white')
        c.line([(5, 4), (8, 3), (13, 3)], 'white')
    return c.im


def breathe(im, pixels):
    # Same row remapping as IdleBreath.breathe_image (leg share from Tuning).
    used = im.getbbox()
    end = used[3]
    legs = int((end - used[1]) * 0.3 + 0.5)
    top = end - legs
    result = Image.new('RGBA', im.size)
    for y in range(end):
        src = y + pixels if y < top - pixels else min(end - 1, top + int((y - top + pixels) / (legs + pixels) * legs))
        result.paste(im.crop((0, src, 64, src + 1)), (0, y))
    return result


def main():
    for folder in (OUT, SHOP, PREVIEW):
        folder.mkdir(parents=True, exist_ok=True)
    animations = {}
    for anim in ('idle', 'interact'):
        frames = [merchant(i, anim == 'interact') for i in range(6)]
        strip = Image.new('RGBA', (384, 64))
        for i, frame in enumerate(frames):
            strip.paste(frame, (64 * i, 0))
        strip.save(OUT / ('merchant_' + anim + '.png'))
        animations[anim] = frames
    names = ('potion', 'elixir', 'taut_string', 'hawk_eye', 'stone_heart', 'gold_coin')
    sheet = Image.new('RGBA', (24 * len(names), 24), '#302221')
    for i, name in enumerate(names):
        im = icon(name)
        im.save(SHOP / (name + '.png'))
        sheet.alpha_composite(im, (24 * i, 0))
    sheet.save(PREVIEW / 'icons_1x.png')
    sheet.resize((sheet.width * 4, 96), Image.NEAREST).save(PREVIEW / 'icons_4x.png')
    nico = Image.open(ROOT / 'assets/sprites/nico/nico_idle_down.png').convert('RGBA').crop((0, 0, 32, 32))
    def pair(frame):
        result = Image.new('RGBA', (88, 40), '#302221')
        result.alpha_composite(nico, (8, 4))
        result.alpha_composite(frame.resize((32, 32), Image.NEAREST), (48, 4))
        return result
    still = pair(animations['idle'][0])
    still.save(PREVIEW / 'merchant_nico_1x.png')
    still.resize((264, 120), Image.NEAREST).save(PREVIEW / 'merchant_nico_3x.png')
    for anim, frames in animations.items():
        pictures = []
        for i in range(24 if anim == 'idle' else 6):
            frame = frames[i % 6]
            if anim == 'idle':
                frame = breathe(frame, int(1.5 * (0.5 - 0.5 * math.cos(i / 6 / 1.2 * math.tau)) + 0.5))
            pictures.append(pair(frame).resize((264, 120), Image.NEAREST).convert('RGB'))
        palette_sheet = Image.new('RGB', (264 * len(pictures), 120))
        for i, picture in enumerate(pictures):
            palette_sheet.paste(picture, (264 * i, 0))
        palette = palette_sheet.quantize(colors=256, dither=Image.NONE)
        pictures = [picture.quantize(palette=palette, dither=Image.NONE) for picture in pictures]
        pictures[0].save(PREVIEW / (anim + '.gif'), save_all=True, append_images=pictures[1:], duration=167 if anim == 'idle' else 125, loop=0, optimize=False)
        contact = Image.new('RGBA', (384, 64), '#302221')
        for i, frame in enumerate(frames):
            contact.alpha_composite(frame, (i * 64, 0))
        contact.resize((768, 128), Image.NEAREST).save(PREVIEW / (anim + '_poses.png'))
    print('Merchant: 64x64, idle/interact x6. Shop: six 24x24 icons. Previews:', PREVIEW)


if __name__ == '__main__':
    main()
