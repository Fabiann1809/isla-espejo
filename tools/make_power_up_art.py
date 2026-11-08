"""Draw native-size pickups, HUD motifs and echo bubble. Run from repo root."""
from pathlib import Path
import math
from PIL import Image, ImageDraw
from ui_art_common import edge, strip

ROOT = Path(__file__).resolve().parents[1]
PALETTES = {
    'arrows': ('#294054', '#32799b', '#59cbf2', '#d5f5f5'),
    'pierce': ('#4b302b', '#a96a34', '#eeb458', '#fff0b2'),
    'frost': ('#294653', '#578eab', '#a6e4ed', '#edfaff'),
    'haste': ('#244537', '#45764a', '#80c878', '#d3e997'),
    'shield': ('#3d2c53', '#705080', '#ae81ce', '#e7dafa'),
    'heart': ('#50283b', '#a43250', '#e85b64', '#ffb1a1'),
}


def motif(name, size=12, phase=0):
    """Coordinates are authored at 12px; world art adds space, never scales."""
    im = Image.new('RGBA', (size, size))
    d = ImageDraw.Draw(im)
    dark, shade, mid, light = PALETTES[name]
    offset = (size - 12) // 2
    def line(points, color, width=1):
        d.line([(x+offset, y+offset) for x,y in points], fill=color, width=width)
    def poly(points, color):
        d.polygon([(x+offset,y+offset) for x,y in points], fill=color)
    def arrow(x,y,dx,dy):
        line([(x,y),(x+dx,y+dy)],shade)
        line([(x-1,y),(x+dx-1,y+dy)],mid)
        poly([(x+dx,y+dy-2),(x+dx-3,y+dy+1),(x+dx+1,y+dy+1)],mid)
        line([(x+dx-1,y+dy-1),(x+dx,y+dy-2)],light)
    if name == 'arrows':
        arrow(3,9,0,-5); arrow(6,10,0,-8); arrow(8,9,2,-5)
    elif name == 'pierce':
        d.ellipse((2+offset,3+offset,8+offset,9+offset),fill=shade)
        d.ellipse((3+offset,4+offset,7+offset,8+offset),fill=dark)
        d.ellipse((4+offset,5+offset,6+offset,7+offset),fill=(0,0,0,0))
        line([(2,5),(3,3),(6,3)],light)
        line([(2,10),(9,3)],mid)
        poly([(10,1),(6,3),(9,5)],mid)
        line([(7,3),(10,1)],light)
    elif name == 'frost':
        poly([(5,1),(9,3),(10,7),(6,10),(2,8),(1,4)],shade)
        poly([(5,1),(5,7),(1,4)],light)
        poly([(5,1),(9,3),(5,7)],mid)
        poly([(5,4),(8,7),(4,9)],light)
        line([(5,5),(5,9)],shade)
        line([(2,8),(5,7),(9,3)],mid)
    elif name == 'haste':
        poly([(1,8),(4,3),(10,1),(10,5),(7,8),(3,9)],shade)
        poly([(2,7),(5,3),(10,1),(7,5)],mid)
        line([(2,9),(8,3)],light)
        line([(5,6),(8,6),(10,4)],mid)
        line([(1,4),(3,4)],mid)
        line([(7,10),(10,10)],mid)
    elif name == 'shield':
        d.ellipse((2+offset,1+offset,9+offset,10+offset),fill=shade)
        d.arc((2+offset,1+offset,9+offset,10+offset),145,300,fill=light)
        poly([(4,3),(7,2),(8,6),(5,9),(3,6)],mid)
        poly([(4,3),(7,2),(4,6)],light)
        line([(6,6),(7,7)],shade)
    else:
        poly([(1,3),(2,2),(4,2),(5,3),(7,2),(9,2),(10,3),(10,6),(6,10),(5,10),(1,6)],shade)
        poly([(1,3),(2,2),(4,2),(5,3),(7,2),(9,2),(9,5),(5,8),(2,6)],mid)
        line([(2,3),(3,3)],light)
        line([(2,4),(2,5)],light)
    return edge(im, dark)


def pickup(name, i):
    im = Image.new('RGBA', (16,16))
    bob = [0,0,-1,-1,0,0][i]
    im.alpha_composite(motif(name), (2,2+bob))
    d = ImageDraw.Draw(im)
    _,shade,mid,light = PALETTES[name]
    # Separate, hard-edged pulse marks leave the silhouette readable at 1x.
    d.line((6,14,9,14), fill=shade)
    x,y = [(1,8),(2,4),(12,2),(14,6),(13,11),(3,12)][i]
    d.point((x,y),fill=mid)
    if i in (1,2,3):
        d.point((x,y-1),fill=light)
    if i == 2:
        d.point((6,3+bob),fill=light)
    return im


def bubble(i):
    im = Image.new('RGBA',(32,32)); p=im.load()
    for y in range(32):
        for x in range(32):
            r=((x-15.5)/14.8)**2+((y-15.5)/15.2)**2
            if .86 <= r <= 1.04:
                p[x,y]=(72,48,101,180)
            if .78 <= r < .91:
                p[x,y]=(166,122,204,145)
    d=ImageDraw.Draw(im)
    d.arc((2,1,29,30),195,258,fill=(231,218,250,215))
    d.arc((3,2,28,29),205,240,fill=(191,166,232,150))
    d.arc((2,1,29,30),15+i*48,34+i*48,fill=(231,218,250,235))
    d.arc((3,2,28,29),30+i*48,43+i*48,fill=(174,129,206,190))
    # No fill over the character: only perimeter facets and a travelling glint.
    a=math.radians(215+i*60)
    x=round(15.5+14*math.cos(a)); y=round(15.5+14*math.sin(a))
    d.line((x-1,y,x+1,y),fill=(241,230,255,245))
    d.point((x,y-1),fill=(241,230,255,245))
    return im


def write(path, frames):
    path=ROOT/path; path.parent.mkdir(parents=True,exist_ok=True)
    strip(frames).save(path)
    verify(path,frames[0].width,len(frames))


def verify(path, cell, count):
    with Image.open(path) as im:
        assert im.size == (cell*count,cell), (path,im.size)
        frames=[im.crop((i*cell,0,(i+1)*cell,cell)) for i in range(count)]
        assert all(f.getbbox() for f in frames), path
        assert len({f.tobytes() for f in frames}) == count, path
        print(f'{path.relative_to(ROOT)}: {im.width}x{im.height}; {count} distinct non-empty frames')


def main():
    for name in PALETTES:
        filename='heart' if name=='heart' else 'buff_'+name
        write(Path('assets/sprites/pickups')/(filename+'.png'),[pickup(name,i) for i in range(6)])
        if name!='heart':
            write(Path('assets/ui/hud')/(filename+'.png'),[motif(name)])
    write(Path('assets/sprites/effects/shield_bubble.png'),[bubble(i) for i in range(6)])


if __name__ == '__main__':
    main()
