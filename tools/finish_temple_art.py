"""Rebuild the complete temple scenery, retaining topology masks and gameplay anchors.

Usage: python tools/finish_temple_art.py
The template supplies neighbour silhouettes; masonry and bevelled treads are finished at pixel size.
"""
import json
import math
import re
import sys
from PIL import Image, ImageChops, ImageEnhance, ImageFilter
sys.dont_write_bytecode = True
import adapt_temple_art_v2 as art
from temple_volume_art import finish_tiles, extra_rocks, outcrop_edges


def texture(region, size=(16, 16), brightness=1.0):
    source = Image.open(art.SOURCE / 'terrain.png').convert('RGBA')
    return art.palette(ImageEnhance.Brightness(source.crop(region).resize(size, Image.Resampling.BOX)).enhance(brightness))


def finish():
    art.props()
    art.terrain()
    path = art.TERRAIN / 'temple_sheet.png'
    sheet = Image.open(path).convert('RGBA')
    template = Image.open(art.SOURCE / 'atlas_template.png').convert('RGBA')
    data = json.loads((art.TERRAIN / 'temple_tiles.json').read_text())
    tiles = data['tiles']
    stone = texture((8, 8, 155, 155))
    pale = texture((8, 320, 155, 463))
    cliff = texture((5, 648, 154, 750), brightness=.66)
    wall = texture((5, 792, 154, 928), brightness=.8)
    lava = texture((315, 944, 622, 1090))
    wood = texture((650, 1120, 770, 1235))
    moss = texture((5, 175, 154, 300))
    steps = texture((180,1114,290,1240),brightness=.9)
    covered = set()
    visited = set()
    def old(name):
        x,y = tiles[name]
        return template.crop((x*16,y*16,x*16+16,y*16+16))
    def put(name, tile):
        coord = tuple(tiles[name])
        if coord in visited:
            covered.add(name)
            return
        visited.add(coord)
        x,y = coord
        sheet.paste(art.palette(tile), (x*16,y*16))
        covered.add(name)
    def material(mask, sample, contrast=.3):
        result = sample.copy()
        # Retain the sculpted joints and cutouts, with the new painted material throughout.
        gray = mask.convert('L')
        for y in range(16):
            for x in range(16):
                rgb = sample.getpixel((x,y))
                factor = (1-contrast) + contrast*gray.getpixel((x,y))/110
                result.putpixel((x,y), tuple(min(255,round(v*factor)) for v in rgb[:3])+(mask.getpixel((x,y))[3],))
        return result
    # Macros have already been painted by the base adapter. Everything else has an explicit route.
    for name in tiles:
        if re.match(r'floor[012]_m_\d_\d$', name) or re.match(r'lava_m[23]?_\d_\d_f\d$', name):
            covered.add(name)
            visited.add(tuple(tiles[name]))
    for name in tiles:
        if name in covered or name.startswith('_pad'):
            continue
        mask = old(name)
        if name.startswith('shadow_'):
            # Shadows are alpha masks rather than material images.
            out = Image.new('RGBA',(16,16))
            for y in range(16):
                for x in range(16):
                    alpha = mask.getpixel((x,y))[3]
                    out.putpixel((x,y),(20,12,27,min(190,round(alpha*1.55))))
            put(name,out)
        elif name.startswith(('cliff_', 'masonry_')) and not name.startswith('masonry_cap'):
            base = wall if name.startswith('masonry') else cliff
            out = material(mask,base,.16)
            if 'moss' in name:
                for y in range(7):
                    for x in range(16):
                        if (x*7+y*11)%17 < 6-y and mask.getpixel((x,y))[3]:
                            out.putpixel((x,y),[(47,58,20,255),(79,94,28,255),(122,138,42,255)][(x+y)%3])
            if 'foot_lava' in name:
                frame = int(name[-1])
                for y in range(11,16):
                    for x in range(16):
                        if not mask.getpixel((x,y))[3]:
                            continue
                        p=out.getpixel((x,y)); glow=(y-10)/5*(.18+.06*math.sin(frame*math.pi/2))
                        out.putpixel((x,y),(min(255,round(p[0]+85*glow)),round(p[1]*(1-glow*.4)),p[2],p[3]))
            put(name,out)
        elif name.startswith('stairs_'):
            # Painted tread faces, with deep mortar on each original riser and carved balustrades.
            sample = steps if name.startswith('stairs_up') else steps.transpose(Image.Transpose.ROTATE_90)
            put(name,material(mask,sample,.22))
        elif name.startswith('bridge_'):
            sample = wood if 'wood' in name or 'rope' in name else pale
            if name.endswith('_deck_h'):
                sample = sample.transpose(Image.Transpose.ROTATE_90)
            put(name,material(mask,sample,.58))
        elif name.startswith(('ledge_', 'masonry_cap_')):
            put(name,material(mask,pale,.55))
        elif name.startswith('lava_'):
            if 'rim_glow' in name or 'bubble_over' in name:
                # Preserve the animated cutout but replace the black old bubble rings with hot rock.
                put(name,material(mask,lava,.24))
            elif 'rim_' in name:
                put(name,material(mask,cliff,.35))
            else:
                put(name,material(mask,lava,.25))
        elif name.startswith(('moss_', 'floor')):
            sample = moss if 'moss' in name else stone
            if name.startswith('floor0'):
                sample = art.palette(ImageEnhance.Brightness(sample).enhance(.7))
            elif name.startswith('floor2'):
                sample = pale
            put(name,material(mask,sample,.45))
        elif name.startswith(('ash_', 'ember_')):
            put(name,material(mask,cliff if name.startswith('ash') else lava,.4))
        elif name.startswith(('brazier_', 'torch_')):
            stripname = 'brazier' if name.startswith('brazier') else 'torch_wall'
            meta = json.loads((art.PROPS/'props.json').read_text())[stripname]
            image=Image.open(art.PROPS/(stripname+'.png')).convert('RGBA')
            w,h=meta['cell']; frame=int(name[-1])
            sprite=image.crop((frame*w,0,(frame+1)*w,h))
            put(name,art.fit(sprite,{'cell':[16,16],'foot':[8,15]}))
        else:
            # Tile-sized incidental props used by the backdrop and by generic room art.
            source_name = ('face_gate' if name=='stele' else
                           'column_low' if name.startswith('column') else 'rubble' if name.startswith(('rubble','pebbles','rocks_heap')) else
                           'rock_smoking' if name.startswith('boulder') else None)
            if source_name:
                meta=json.loads((art.PROPS/'props.json').read_text())[source_name]
                image=Image.open(art.PROPS/(source_name+'.png')).convert('RGBA')
                put(name,art.fit(image.crop((0,0,*meta['cell'])),{'cell':[16,16],'foot':[8,15]}))
            elif name=='chest_closed':
                source=Image.open(art.SOURCE/'architecture.png').convert('RGBA')
                put(name,art.fit(art.clean(art.cell(source,4,3,3)),{'cell':[16,16],'foot':[8,15]}))
            elif name in ('chest_open','crate'):
                put(name,material(mask,wood,.65))
            else:
                put(name,material(mask,stone,.5))
    finish_tiles(sheet, tiles, template)
    sheet = extra_rocks(sheet, data)
    outcrop_edges(sheet, data)
    covered.update(name for name in tiles if name.startswith("basalt_"))
    (art.TERRAIN / "temple_tiles.json").write_text(json.dumps(data, indent=1)+"\n")
    sheet.save(path)
    finish_props(lava)
    assert set(tiles) - covered == set(), sorted(set(tiles)-covered)
    report={'tile_roles':len(tiles),'adapted_roles':len(covered), 'prop_strips':25,
            'topology':'Atlas coordinates and neighbour masks retained; solid bevelled treads and sculpted basalt faces.',
            'roles':sorted(covered)}
    (art.SOURCE/'coverage.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'Finished {len(covered)} tile roles and all 25 prop strips')


def finish_props(lava):
    meta=json.loads((art.PROPS/'props.json').read_text())
    smoke=Image.open(art.SOURCE/'effects.png').convert('RGBA')
    # Smoking rocks: a fixed body, with the new smoke frames rising above it.
    for name in ('rock_smoking','ember_vent'):
        info=meta[name];w,h=info['cell']
        original=Image.open(art.PROPS/(name+'.png')).convert('RGBA')
        base=original.crop((0,0,w,h)) if name=='rock_smoking' else Image.new('RGBA',(w,h))
        if name=='ember_vent':
            base.alpha_composite(lava.resize((12,4), art.NEAREST),(2,info['foot'][1]-3))
        frames=[]
        for i in range(info['frames']):
            out=base.copy()
            cloud=art.clean(art.cell(smoke,8,1+i%6,7))
            if cloud.getbbox():
                size=(max(4,w//2),max(4,h//3))
                cloud=art.palette(cloud.crop(cloud.getbbox()).resize(size,art.NEAREST))
                out.alpha_composite(cloud,((w-size[0])//2,0))
            frames.append(out)
        art.write_strip(name,frames,info)
    info=meta['saw_track'];w,h=info['cell']
    frames=[]
    for i in range(info['frames']):
        out=texture((8,8,155,155))
        for y in range(h):
            out.putpixel((w//2,y),(26,12,16,255))
            out.putpixel((w//2+1,y),(62,32,36,255))
        frames.append(out)
    art.write_strip('saw_track',frames,info)
    # Replace the remaining old break/spawn poses of the rock with fragments of its painted body.
    info=meta['rolling_rock'];w,h=info['cell']
    image=Image.open(art.PROPS/'rolling_rock.png').convert('RGBA')
    frames=[image.crop((i*w,0,(i+1)*w,h)) for i in range(4)]
    base=frames[0]
    for i in range(4):
        out=Image.new('RGBA',(w,h))
        for quadrant,(x,y) in enumerate(((0,0),(w//2,0),(0,h//2),(w//2,h//2))):
            fragment=base.crop((x,y,x+w//2,y+h//2))
            dx=(-1 if quadrant%2==0 else 1)*(i+1)
            out.paste(fragment,(x+dx,min(h-1,y+i)),fragment)
        frames.append(out)
    for i in range(4):
        out=Image.new('RGBA',(w,h));out.alpha_composite(base,(0,3-i));frames.append(out)
    art.write_strip('rolling_rock',frames,info)


if __name__=='__main__':
    finish()
