"""Adapt the painted temple sources to the existing runtime atlas and anchored strips.

Run from any directory: python tools/adapt_temple_art_v2.py
Atlas coordinates, collision footprints and animation phase ranges are retained.
Tall scenery gets larger sprite cells and feet without changing its physics base.
"""
from pathlib import Path
import json
import math
import re

from PIL import Image, ImageChops, ImageEnhance, ImageFilter
from temple_volume_art import architecture_meta, pillar

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/art_temple_v2'
PROPS = ROOT / 'assets/sprites/temple_props'
TERRAIN = ROOT / 'assets/tilesets/temple'
NEAREST = Image.Resampling.NEAREST
COLORS = list(dict.fromkeys(re.findall(r'#[0-9a-fA-F]{6}', (ROOT / 'tools/temple_palette.py').read_text())))
PALETTE = Image.new('P', (1, 1))
rgb = [tuple(bytes.fromhex(c[1:])) for c in COLORS]
PALETTE.putpalette([v for c in (rgb + [rgb[0]] * (256 - len(rgb))) for v in c])


def palette(image):
    alpha = image.getchannel('A')
    result = image.convert('RGB').quantize(palette=PALETTE, dither=Image.Dither.NONE).convert('RGBA')
    result.putalpha(alpha)
    return result


def cell(image, columns, x, y):
    # Fractional source grids are rounded once, never passed to the runtime atlas.
    return image.crop((round(x * image.width / columns), round(y * image.height / columns),
                       round((x + 1) * image.width / columns), round((y + 1) * image.height / columns)))


def clean(image):
    image = image.copy().convert('RGBA')
    image.putalpha(image.getchannel('A').point(lambda a: 255 if a >= 200 else 0))
    # Remove detached alpha speckles rather than turning halos into solid pixels.
    mask = image.getchannel('A')
    pixels = mask.load()
    seen = set()
    groups = []
    for y in range(image.height):
        for x in range(image.width):
            if not pixels[x, y] or (x, y) in seen:
                continue
            stack = [(x, y)]
            seen.add((x, y))
            group = []
            while stack:
                px, py = stack.pop()
                group.append((px, py))
                for nx, ny in ((px-1, py), (px+1, py), (px, py-1), (px, py+1)):
                    if 0 <= nx < image.width and 0 <= ny < image.height and pixels[nx, ny] and (nx, ny) not in seen:
                        seen.add((nx, ny))
                        stack.append((nx, ny))
            groups.append(group)
    for group in groups:
        if len(group) < 30:
            for x, y in group:
                pixels[x, y] = 0
    image.putalpha(mask)
    return image


def fit(image, info, shared_scale=None):
    bounds = image.getbbox()
    assert bounds, 'empty source sprite'
    image = image.crop(bounds)
    width, height = info['cell']
    foot_x, foot_y = info['foot']
    scale = shared_scale if shared_scale is not None else min((width - 2) / image.width, foot_y / image.height)
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    image = palette(image.resize(size, NEAREST))
    out = Image.new('RGBA', (width, height))
    out.alpha_composite(image, (foot_x - size[0] // 2, foot_y - size[1] + 1))
    return out


def pulse(image, frame, count):
    # Geometry stays fixed. Only emissive pixels breathe; masonry never wobbles.
    out = image.copy()
    strength = 0.88 + 0.12 * math.cos(frame * math.tau / count)
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = out.getpixel((x, y))
            if a and r > 190 and r > g * 1.15 and g > b * 1.5:
                out.putpixel((x, y), (round(r * strength), round(g * strength), b, a))
    return palette(out)


def write_strip(name, frames, info):
    width, height = info['cell']
    assert len(frames) == info['frames']
    strip = Image.new('RGBA', (width * len(frames), height))
    for i, frame in enumerate(frames):
        assert frame.size == (width, height)
        strip.paste(frame, (i * width, 0))
    palette(strip).save(PROPS / (name + '.png'))


def props():
    meta = json.loads((PROPS / 'props.json').read_text())
    architecture_meta(meta)
    (PROPS / 'props.json').write_text(json.dumps(meta, indent=2) + '\n')
    art = Image.open(SOURCE / 'props.png').convert('RGBA')
    architecture = Image.open(SOURCE / 'architecture.png').convert('RGBA')
    effects = Image.open(SOURCE / 'effects.png').convert('RGBA')
    names = ['pillar_carved', 'pillar_block', 'column_low', 'column_broken',
             'statue_guardian', 'brazier_pedestal', 'brazier', 'torch_wall',
             'face_gate', 'altar_rune', 'urn', 'vase', 'barrel', 'rubble', 'rock_smoking', 'plant']
    sources = {name: clean(cell(art, 4, i % 4, i // 4)) for i, name in enumerate(names)}
    sources['vines'] = clean(cell(architecture, 4, 0, 3))
    sources['banner'] = clean(cell(architecture, 4, 1, 3))
    for name, source in sources.items():
        info = meta[name]
        base = fit(source, info)
        frames = [pulse(base, i, info['frames']) for i in range(info['frames'])]
        if name in ('vines', 'banner', 'plant'):
            for i, frame in enumerate(frames):
                sway = math.sin(i * math.tau / len(frames))
                moved = Image.new('RGBA', frame.size)
                for y in range(frame.height):
                    # Fix the plant's root and the hanging objects' attachment point.
                    weight = (1-y/frame.height) if name == 'plant' else y/frame.height
                    offset = round(sway * weight)
                    moved.paste(frame.crop((0,y,frame.width,y+1)), (offset,y))
                frames[i] = moved
        if name in ('brazier', 'brazier_pedestal', 'torch_wall'):
            # Fit a flame to the original flame's bounding box, keeping the new stone base fixed.
            points = [(x, y) for y in range(base.height * 2 // 3) for x in range(base.width)
                      if (lambda p: p[3] > 0 and p[0] > 190 and p[1] > 65 and p[0] > p[1]*1.12 and p[1] > p[2]*1.5)(base.getpixel((x, y)))]
            if points:
                left, top = min(p[0] for p in points), min(p[1] for p in points)
                right, bottom = max(p[0] for p in points)+1, max(p[1] for p in points)+1
                stone = base.copy()
                for p in points:
                    stone.putpixel(p, (0, 0, 0, 0))
                frames = []
                for i in range(info['frames']):
                    flame = clean(cell(effects, 8, i % 8, 0 if name != 'torch_wall' else 1))
                    # Isolate fire, excluding all of the effect sheet's moving bowl/bracket.
                    for y in range(flame.height):
                        for x in range(flame.width):
                            r, g, b, a = flame.getpixel((x, y))
                            if not (r > 190 and g > 65 and r > g*1.12 and g > b*1.5 and y < flame.height*0.62):
                                flame.putpixel((x, y), (0, 0, 0, 0))
                    frame = stone.copy()
                    if flame.getbbox():
                        fire = palette(flame.crop(flame.getbbox()).resize((right-left, bottom-top), NEAREST))
                        frame.alpha_composite(fire, (left, top + (1 if i % 4 == 1 else 0)))
                    frames.append(frame)
        write_strip(name, frames, info)
        if name in ('pillar_carved', 'pillar_block'):
            write_strip(name, [pillar(name, i) for i in range(info['frames'])], info)
    # Keep hazard silhouettes in the same cells/phase spans as their hitboxes.
    sequences = {'lava_fall': (2, list(range(8))),
                 'geyser': (3, [0]*4 + [1]*4 + [2,3,4,4,5,5,6,6] + [7,7,0,0]),
                 'spikes': (4, [0]*4 + [1]*4 + [3,4,4,3] + [2,1,1,0]),
                 'saw': (5, [0,2,4,6]),
                 'rolling_rock': (6, [0,2,4,6])}
    for name, (row, indices) in sequences.items():
        info = meta[name]
        original = Image.open(PROPS / (name + '.png')).convert('RGBA')
        frames = [original.crop((i*info['cell'][0], 0, (i+1)*info['cell'][0], info['cell'][1])) for i in range(info['frames'])]
        # Preserve the rock's authored break/spawn phases, replacing only its rolling cycle.
        cells = [clean(cell(effects, 8, index, row)) for index in indices]
        bounds = [image.getbbox() for image in cells]
        scale = min((info['cell'][0]-2) / max(b[2]-b[0] for b in bounds),
                    info['foot'][1] / max(b[3]-b[1] for b in bounds))
        for i, image in enumerate(cells):
            frames[i] = fit(image, info, scale)
        write_strip(name, frames, info)
    print('Adapted 23 temple sprite strips; collision/phase metadata unchanged')


def periodic(image):
    """Join only the outer bands, preserving the painted interior without mirror motifs."""
    out = image.copy()
    width, height = image.size
    band = 6
    for y in range(height):
        edge = tuple((image.getpixel((0,y))[c] + image.getpixel((width-1,y))[c]) // 2 for c in range(4))
        for d in range(band):
            amount = (band-d) / band
            for x in (d, width-1-d):
                p = image.getpixel((x,y))
                out.putpixel((x,y), tuple(round(p[c]*(1-amount)+edge[c]*amount) for c in range(4)))
    original = out.copy()
    for x in range(width):
        edge = tuple((original.getpixel((x,0))[c] + original.getpixel((x,height-1))[c]) // 2 for c in range(4))
        for d in range(band):
            amount = (band-d) / band
            for y in (d, height-1-d):
                p = original.getpixel((x,y))
                out.putpixel((x,y), tuple(round(p[c]*(1-amount)+edge[c]*amount) for c in range(4)))
    return out


def terrain():
    source = Image.open(SOURCE / 'terrain.png').convert('RGBA')
    sheet = Image.open(TERRAIN / 'temple_sheet.png').convert('RGBA')
    tiles = json.loads((TERRAIN / 'temple_tiles.json').read_text())['tiles']
    def paste(name, tile):
        if name in tiles:
            x, y = tiles[name]
            sheet.paste(tile, (x*16, y*16))
    for level, brightness in ((0, .72), (1, 1.0), (2, 1.22)):
        # A 64px macro crosses cell boundaries, instead of framing every 16px tile.
        patch = source.crop((8, 8, 155, 155)).filter(ImageFilter.MinFilter(3)).resize((64, 64), NEAREST)
        field = palette(ImageEnhance.Brightness(periodic(patch)).enhance(brightness))
        for y in range(4):
            for x in range(4):
                paste(f'floor{level}_m_{x}_{y}', field.crop((x*16,y*16,(x+1)*16,(y+1)*16)))
    # Repaint faces inside the existing silhouettes; ledge masks and their corners stay intact.
    for prefix, region in (('cliff', (4,638,309,750)), ('masonry', (3,788,309,931))):
        face = palette(source.crop(region).resize((48,16), Image.Resampling.BOX))
        for index, side in enumerate(('l','m','r')):
            tile = face.crop((index*16,0,(index+1)*16,16))
            for suffix, brightness in (('face',1.0), ('face2_top',.9), ('face2_bot',.72), ('face_mid',.8)):
                name = f'{prefix}_{suffix}_{side}'
                if name in tiles:
                    x,y = tiles[name]
                    alpha = sheet.crop((x*16,y*16,x*16+16,y*16+16)).getchannel('A')
                    painted = palette(ImageEnhance.Brightness(tile).enhance(brightness))
                    painted.putalpha(alpha)
                    paste(name,painted)
    # Quieter continuous lava: same common boundary for all three macro variations.
    lava = palette(periodic(source.crop((315, 944, 622, 1090)).resize((128,128), Image.Resampling.BOX).filter(ImageFilter.MedianFilter(3))))
    for frame in range(8):
        # Out-and-back drift closes the eight-frame loop without a large jump.
        shift = [0,1,2,3,4,3,2,1][frame]
        flow = ImageChops.offset(lava, shift, 0)
        for variant in ('lava_m', 'lava_m2', 'lava_m3'):
            for y in range(8):
                for x in range(8):
                    paste(f'{variant}_{x}_{y}_f{frame}', flow.crop((x*16,y*16,(x+1)*16,(y+1)*16)))
    sheet.save(TERRAIN / 'temple_sheet.png')
    print('Adapted three floor heights and all 1536 lava macro frames in place')


if __name__ == '__main__':
    props()
    terrain()
