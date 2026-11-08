"""Pixel-sized masonry finishing passes; never changes atlas coordinates or physics."""
import random
from PIL import Image, ImageDraw
from temple_palette import *


ARCHITECTURE = {
    'pillar_carved': ([40, 104], [20, 100]),
    'pillar_block': ([40, 104], [20, 100]),
    'statue_guardian': ([64, 88], [32, 83]),
    'brazier_pedestal': ([32, 64], [16, 60]),
    'face_gate': ([112, 112], [56, 105]),
}


def architecture_meta(meta):
    for name, (cell, foot) in ARCHITECTURE.items():
        meta[name]['cell'] = cell
        meta[name]['foot'] = foot


def pillar(name, frame):
    out = Image.new('RGBA', (40, 104))
    d = ImageDraw.Draw(out)
    # Broad plinth and projecting capital; the right return is always in shade.
    for box in [(2, 91, 37, 100), (6, 86, 33, 92), (9, 16, 30, 87),
                (5, 9, 34, 19), (2, 3, 37, 12)]:
        x, y, r, b = box
        d.rectangle(box, fill=OUTLINE)
        d.rectangle((x+1,y+1,r-1,b-1), fill=STONE_COOL_2)
        d.line((x+1,y+1,r-2,y+1), fill=STONE_HI)
        d.line((x+1,y+2,x+1,b-2), fill=STONE_4)
        d.rectangle((r-6,y+2,r-1,b-1), fill=STONE_D)
    d.rectangle((12,21,23,83), fill=STONE_2)
    d.line((12,21,12,83), fill=STONE_4)
    for y in (24, 44, 64):
        d.rectangle((14,y,23,y+14), fill=OUTLINE)
        d.line((15,y+13,15,y+1,22,y+1,22,y+10,18,y+10,18,y+5,20,y+5), fill=BRONZE_1)
        d.point((16,y+2), fill=GOLD_HI if frame == (y//20)%4 else STONE_HI)
    for x, length in ((6,8),(10,5),(29,10)):
        for y in range(11,11+length):
            d.point((x+(y%3==0),y), fill=MOSS_1 if y%2 else MOSS_D)
    return out


def finish_tiles(sheet, tiles, template):
    def put(name, tile):
        x,y=tiles[name]
        sheet.paste(tile,(x*16,y*16))
    # Calm, mid-value flagstones. Small chips, not a second lava-like noise field.
    for level in range(3):
        field=Image.new('RGBA',(64,64), STONE_COOL_1)
        d=ImageDraw.Draw(field)
        ramp=[STONE_COOL_2,STONE_COOL_3,STONE_3]
        for y in range(0,64,8):
            for x in range(-8,64,16):
                xx=x+(8 if (y//8)%2 else 0)
                d.rectangle((xx+1,y+1,xx+15,y+7),fill=ramp[level])
                d.line((xx+2,y+1,xx+13,y+1),fill=[STONE_COOL_3,STONE_3,STONE_4][level])
                if (x+y)%24==0:
                    d.point((xx+3,y+5),fill=STONE_COOL_1)
        for y in range(4):
            for x in range(4):
                put(f'floor{level}_m_{x}_{y}',field.crop((x*16,y*16,x*16+16,y*16+16)))
    # Bright, nearly flat molten field with fine, connected crackle (periodic at 128px).
    rng=random.Random(710)
    sites=[(rng.randrange(128),rng.randrange(128)) for _ in range(45)]
    lava=Image.new('RGBA',(128,128),LAVA_3)
    p=lava.load()
    for y in range(128):
        for x in range(128):
            distances=sorted(min(abs(x-sx),128-abs(x-sx))**2 + min(abs(y-sy),128-abs(y-sy))**2 for sx,sy in sites)
            if distances[1]-distances[0]<11:
                p[x,y]=LAVA_CRACK
    for frame in range(8):
        for variant in ('lava_m','lava_m2','lava_m3'):
            for y in range(8):
                for x in range(8):
                    put(f'{variant}_{x}_{y}_f{frame}',lava.crop((x*16,y*16,x*16+16,y*16+16)))
    for name,(cx,cy) in tiles.items():
        alpha=template.crop((cx*16,cy*16,cx*16+16,cy*16+16)).getchannel('A')
        out=Image.new('RGBA',(16,16),CLIFF_D)
        d=ImageDraw.Draw(out)
        if name.startswith(('cliff_','masonry_')) and 'cap' not in name:
            out = basalt(sum(map(ord, name)))
            d = ImageDraw.Draw(out)
            if 'moss' in name:
                for x in (2,6,11):
                    for y in range(2,8+x%5):
                        d.point((x+(y%3==0),y),fill=MOSS_1 if y%2 else MOSS_D)
            if 'foot_lava' in name:
                d.polygon([(2,15),(1,11),(4,8),(8,9),(10,13),(9,15)],fill=CLIFF_D)
                d.line((2,11,4,9,7,10),fill=CLIFF_3)
                d.line((0,15,15,15),fill=LAVA_4)
                for x in range(16):
                    d.point((x,14-(x%5==0)),fill=CLIFF_LAVA_LIT)
        elif name.startswith('stairs_'):
            out=Image.new('RGBA',(16,16),STAIR_D);d=ImageDraw.Draw(out)
            for y in range(0,16,4):
                d.rectangle((0,y,15,y+1),fill=STAIR_1)
                d.line((0,y+2,15,y+2),fill=STAIR_HI)
                d.line((0,y+3,15,y+3),fill=STAIR_2)
            if 'side' in name:
                out=Image.new('RGBA',(16,16),STAIR_2);d=ImageDraw.Draw(out)
                for x in range(0,16,4):
                    d.polygon([(x,0),(x+2,0),(x+2,12),(x,15)],fill=STAIR_1)
                    d.line((x+2,0,x+2,12),fill=STAIR_1)
                    for joint in (5 + (x//4)%2*3, 13):
                        d.line((x,joint,x+2,joint),fill=STAIR_2)
                        d.line((x,joint+1,x+1,joint+1),fill=STAIR_HI)
                    d.line((x,15,x+2,12),fill=STAIR_HI)
                    d.line((x+3,0,x+3,15),fill=STONE_COOL_2)
            suffix=name.split('steps')[-1].strip('_') if 'steps' in name else name.rsplit('_',1)[-1]
            for side in suffix:
                if side in 'lr':
                    x=0 if side=='l' else 14
                    d.rectangle((x,0,x+1,15),fill=STONE_D)
                    d.line((x,0,x,15),fill=STONE_4)
                if side in 'tb':
                    y=0 if side=='t' else 14
                    d.rectangle((0,y,15,y+1),fill=STONE_D)
                    d.line((0,y,15,y),fill=STONE_4)
            # Stair topology is in the room plan; the treads fill its walkable cell.
            put(name,out)
            continue
        elif name.startswith('bridge_stone_'):
            out=Image.new('RGBA',(16,16),STONE_D);d=ImageDraw.Draw(out)
            if 'deck' in name:
                d.rectangle((0,1,15,13),fill=STONE_COOL_2)
                d.line((0,1,15,1),fill=STONE_3)
                d.line((7,2,7,12),fill=STONE_COOL_1)
                d.line((0,14,15,14),fill=STONE_4)
            else:
                d.rectangle((0,2,15,5),fill=STONE_4)
                d.line((0,2,15,2),fill=STONE_HI)
                d.rectangle((0,6,15,13),fill=STONE_COOL_1)
                d.line((7,6,7,13),fill=OUTLINE)
                d.line((0,14,15,14),fill=OUTLINE)
                if name.endswith(('_w','_e')):
                    out=out.transpose(Image.Transpose.ROTATE_90)
        else:
            continue
        out.putalpha(alpha)
        put(name,out)


def basalt(seed, top=False):
    rng = random.Random(seed)
    out = Image.new('RGBA', (16,16), STONE_COOL_D if top else CLIFF_D)
    d = ImageDraw.Draw(out)
    for i in range(6 if top else 4):
        x,y = rng.randrange(-5,16),rng.randrange(-6,16)
        w,h = rng.randrange(8,16),rng.randrange(10,21)
        points=[(x,y+2),(x+3,y),(x+w-2,y+1),(x+w,y+h-3),(x+w-3,y+h),(x+1,y+h-1)]
        d.polygon(points,fill=rng.choice([STONE_COOL_1,STONE_COOL_2,CLIFF_2] if top else [CLIFF_1,CLIFF_2,STONE_COOL_D]))
        d.line(points[:3],fill=STONE_COOL_3 if top else CLIFF_3)
        d.line((x+1,y+3,x+2,y+h-3),fill=CLIFF_D)
    return out


def extra_rocks(sheet, data):
    # Append visual roles without moving any existing atlas coordinates.
    width, row = sheet.width // 16, sheet.height // 16
    out = Image.new('RGBA',(sheet.width,sheet.height+144))
    out.paste(sheet,(0,0))
    for i in range(16):
        name = ('basalt_top_' if i < 8 else 'basalt_face_') + str(i%8)
        data['tiles'][name]=[i%width,row+i//width]
        out.paste(basalt(801+i, i<8),(i%width*16,(row+i//width)*16))
    return out


def outcrop_edges(sheet, data):
    width, row = sheet.width // 16, sheet.height // 16 - 8
    for variant in range(8):
        for mask in range(16):
            tile = basalt(801+variant, True)
            # Missing neighbours expose a chipped edge within the reserved footprint.
            for y in range(16):
                for x in range(16):
                    north, east, south, west = [bool(mask & bit) for bit in (1,2,4,8)]
                    inset = 1 + ((x*3+y*5+variant)%3 == 0)
                    cut = ((not north and y < inset) or (not south and y > 15-inset)
                           or (not west and x < inset) or (not east and x > 15-inset))
                    cut |= not north and not west and x+y < 7
                    cut |= not north and not east and 15-x+y < 7
                    cut |= not south and not west and x+15-y < 6
                    cut |= not south and not east and 30-x-y < 6
                    if cut: tile.putpixel((x,y),CLEAR)
            i=variant*16+mask
            data['tiles'][f'basalt_edge_{variant}_{mask}']=[i%width,row+i//width]
            sheet.paste(tile,(i%width*16,(row+i//width)*16))
