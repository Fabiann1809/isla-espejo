"""Draw Mercader room props at native resolution; optional --preview-dir PATH.

All geometry uses integer pixels, binary alpha and upper-left lighting.
World feet: stall (32,47), crates (16,23), lantern per frame (8,23).
"""
from pathlib import Path
import argparse
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
INK = '#2d2624'
WOOD = '#87603e'
SHADE = '#59432f'
LIGHT = '#bd945c'
CREAM = '#d8c798'
OLIVE = '#72764b'
GREEN = '#36ac73'


def canvas(size):
    return Image.new('RGBA', size, (45, 38, 36, 0))


def stall():
    im = canvas((64, 48)); d = ImageDraw.Draw(im)
    # Rear supports, visible beneath the canopy and either side of the goods.
    for x in (8, 54):
        d.rectangle((x, 8, x+3, 44), fill=INK)
        d.line((x+1, 9, x+1, 43), fill=WOOD)
        d.point((x+1, 20), fill=LIGHT)
    # Sloping canopy: shallow top plane, scalloped hanging front edge.
    d.polygon([(10,2),(52,2),(61,13),(60,17),(3,17),(2,13)], fill=INK)
    for i in range(7):
        a = 11+i*6; b = 4+i*8
        color = OLIVE if i % 2 == 0 else CREAM
        d.polygon([(a,3),(a+5,3),(b+7,12),(b,12)], fill=color)
        d.line((a,3,a+5,3), fill='#939465' if i%2==0 else '#ecddba')
        d.rectangle((b,13,min(b+6,59),16), fill='#535c3c' if i%2==0 else '#b7a57d')
        d.line((b+1,17,min(b+5,58),17), fill=INK)
    d.line((4,12,59,12), fill=INK)
    # Counter top and front fascia; right face is in shade.
    d.polygon([(9,28),(52,28),(59,33),(57,42),(55,46),(9,46),(6,41),(5,33)], fill=INK)
    d.polygon([(10,29),(51,29),(56,32),(8,32)], fill=LIGHT)
    d.rectangle((8,34,54,43), fill=WOOD)
    d.polygon([(55,34),(57,34),(55,44)], fill=SHADE)
    for x in (18,29,41):
        d.line((x,35,x,43), fill=SHADE)
        d.line((x+1,35,x+1,42), fill='#9c7549')
    d.line((8,34,54,34), fill=LIGHT)
    d.line((9,44,54,44), fill=SHADE)
    d.rectangle((12,45,15,46), fill=WOOD)
    d.rectangle((48,45,51,46), fill=WOOD)
    d.line((28,47,36,47), fill=INK)
    d.line((13,38,16,38), fill=SHADE); d.point((37,40), fill=LIGHT)
    # A short olive counter runner with a stitched cream hem.
    d.rectangle((32,33,44,42), fill='#535c3c')
    d.rectangle((33,33,42,40), fill=OLIVE)
    d.line((33,41,43,41), fill=CREAM)
    for x in (34,38,42): d.point((x,43), fill=CREAM)
    # Two tiny corked potion bottles.
    for x,y,c,hi in ((12,25,'#92464b','#d17b70'),(20,24,'#467d78','#91b5a1')):
        d.rectangle((x,y-3,x+2,y-2), fill=INK)
        d.point((x+1,y-3), fill=LIGHT)
        d.polygon([(x,y-1),(x+3,y+1),(x+3,y+5),(x-2,y+5),(x-2,y+1)], fill=INK)
        d.rectangle((x-1,y+1,x+2,y+4), fill=c)
        d.line((x-1,y+1,x-1,y+2), fill=hi)
    # Bow laid diagonally, with taut pale string.
    d.line([(27,23),(30,23),(32,25),(33,28),(32,30)], fill=INK)
    d.line([(27,24),(29,24),(31,26),(32,29)], fill=LIGHT)
    d.line((27,24,32,30), fill=CREAM)
    # Bound arrow bundle, shafts and distinct pale fletching.
    for x in (47,50,53):
        d.line((x,23,x-3,30), fill=INK)
        d.line((x,24,x-2,29), fill=LIGHT)
        d.line((x-1,22,x+1,23), fill=CREAM)
    d.line((46,27,51,28), fill='#a17a54')
    # Emerald on a little dark wooden display plinth.
    d.rectangle((35,29,41,30), fill=INK)
    d.line((36,29,40,29), fill=LIGHT)
    d.polygon([(38,22),(41,25),(38,28),(35,25)], fill=INK)
    d.polygon([(38,23),(40,25),(38,27),(36,25)], fill=GREEN)
    d.line((38,23,36,25), fill='#a0dab0')
    d.line((40,25,38,27), fill='#24724f')
    return im


def rug():
    im = canvas((48,32)); d = ImageDraw.Draw(im)
    # Flat textile in a foreshortened plane, soft palette edges, no ink rim.
    d.polygon([(9,4),(39,4),(44,27),(4,27)], fill='#786044')
    d.polygon([(10,5),(38,5),(42,25),(6,25)], fill='#ab8860')
    d.polygon([(12,7),(36,7),(39,23),(9,23)], fill='#626442')
    d.polygon([(14,9),(34,9),(37,21),(11,21)], fill='#794e43')
    d.polygon([(24,9),(33,15),(24,21),(15,15)], fill='#c1a773')
    d.polygon([(24,11),(29,15),(24,19),(19,15)], fill='#626442')
    d.polygon([(24,13),(27,15),(24,17),(21,15)], fill='#998354')
    for x in (14,34):
        d.line((x,13,x,17), fill='#c1a773'); d.line((x-2,15,x+2,15), fill='#c1a773')
    # Fringe follows the two short side edges.
    for y in range(6,27,3):
        left = 9-(y-4)*5//23; right = 39+(y-4)*5//23
        d.line((left-3,y,left-1,y), fill='#baa17a')
        d.line((right+1,y,right+3,y), fill='#96815c')
    for x,y in ((12,6),(30,6),(8,24),(35,24),(17,8),(36,20)):
        d.line((x,y,x+2,y), fill='#c1a773')
    d.point((7,26), fill=(45,38,36,0)); d.point((40,25), fill='#786044')
    return im


def lantern(phase):
    im = canvas((16,24)); d = ImageDraw.Draw(im)
    d.line((11,3,11,21), fill=INK)
    d.line((12,4,12,21), fill=SHADE)
    d.line([(4,4),(4,2),(6,1),(11,1),(12,2),(12,5)], fill=INK)
    d.line((6,2,10,2), fill=LIGHT)
    d.line((4,4,4,5), fill=LIGHT)
    d.polygon([(2,7),(3,5),(6,5),(8,7),(8,15),(6,17),(2,17),(1,15),(1,8)], fill=INK)
    d.rectangle((2,8,7,14), fill='#9a6439')
    d.rectangle((2,8,5,13), fill='#d6a353')
    # Only the flame and glass highlights change; post/foot stay fixed.
    tip = (4,3,5,4)[phase]; top = (9,8,9,10)[phase]
    d.polygon([(tip,top),(6,12),(5,14),(3,14),(2,12),(3,11)], fill='#f0b14e')
    d.line((4,11,4,13), fill='#ffe0a0')
    d.point((3,9), fill='#f3ce87' if phase%2 else '#d6a353')
    d.line((2,7,7,7), fill=LIGHT)
    d.line((2,15,7,15), fill=WOOD)
    d.point((2,8), fill=CREAM)
    d.polygon([(10,20),(13,21),(14,22),(13,23),(6,23),(5,22),(7,21)], fill=INK)
    d.line((7,22,12,22), fill=WOOD)
    d.point((7,22), fill=LIGHT)
    return im


def crate(d,x,y,w,h):
    d.polygon([(x,y+3),(x+4,y),(x+w-4,y),(x+w,y+3),(x+w,y+h),(x,y+h)], fill=INK)
    d.polygon([(x+2,y+3),(x+4,y+1),(x+w-4,y+1),(x+w-2,y+3)], fill=LIGHT)
    d.rectangle((x+1,y+4,x+w-2,y+h-1), fill=WOOD)
    d.line((x+w-1,y+4,x+w-1,y+h-1), fill=SHADE)
    for xx in range(x+4,x+w-2,4): d.line((xx,y+5,xx,y+h-2), fill=SHADE)
    d.line((x+2,y+5,x+w-3,y+h-2), fill=INK)
    d.line((x+2,y+4,x+w-3,y+h-3), fill=LIGHT)
    d.line((x+1,y+4,x+w-2,y+4), fill=LIGHT)
    d.line((x+1,y+h-1,x+w-2,y+h-1), fill=SHADE)
    for xx in (x+2,x+w-3):
        d.point((xx,y+5),fill=INK); d.point((xx,y+h-2),fill=INK)


def crates():
    im = canvas((32,24)); d = ImageDraw.Draw(im)
    crate(d,2,10,18,13); crate(d,4,1,14,11)
    # Gathered sack overlaps the bottom crate, warm flax against dark timber.
    d.polygon([(24,10),(28,10),(27,13),(30,16),(31,21),(29,23),(20,23),(18,21),(19,17),(23,13)],fill=INK)
    d.polygon([(24,12),(26,12),(26,14),(29,17),(30,21),(28,22),(21,22),(20,20),(21,17)],fill='#a38a5b')
    d.line([(24,14),(22,17),(21,20)], fill='#c8af7c')
    d.line([(26,16),(28,19),(28,21)],fill='#796544')
    d.line((23,12,27,12),fill=SHADE)
    d.line((24,10,27,10),fill=LIGHT)
    return im


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--preview-dir', type=Path)
    args = parser.parse_args()
    frames = [lantern(i) for i in range(4)]
    strip = canvas((64,24))
    for i, frame in enumerate(frames): strip.paste(frame, (i*16,0))
    art = {'stall':stall(), 'rug':rug(), 'lantern':strip, 'crates':crates()}
    folder = ROOT/'assets/sprites/shop'
    expected = {'stall':(64,48), 'rug':(48,32), 'lantern':(64,24), 'crates':(32,24)}
    for name,im in art.items():
        assert set(im.getchannel('A').getdata()) == {0,255}
        assert not any(r==g==b==0 for r,g,b,a in im.getdata())
        im.save(folder/(name+'.png'))
        with Image.open(folder/(name+'.png')) as saved:
            assert saved.mode == 'RGBA' and saved.size == expected[name]
            assert set(saved.getchannel('A').getdata()) == {0,255}
            assert not any(r==g==b==0 for r,g,b,a in saved.getdata())
        print('{}: {} RGBA, binary transparency, no pure black'.format(name,im.size))
    assert strip.size == (64,24)
    assert len({f.tobytes() for f in frames}) == 4
    if args.preview_dir:
        args.preview_dir.mkdir(parents=True, exist_ok=True)
        sheet = Image.new('RGB',(224,192))
        d = ImageDraw.Draw(sheet)
        for row,bg in enumerate(('#4f603b','#55515b','#63504a')):
            d.rectangle((0,row*64,223,row*64+63),fill=bg)
            for name,x,y in (('stall',2,5),('rug',72,23),('lantern',128,22),('crates',192,22)):
                sheet.paste(art[name],(x,row*64+y),art[name])
        sheet.resize((1568,1344),Image.NEAREST).save(args.preview_dir/'shop_7x.png')
        print('Preview:',args.preview_dir/'shop_7x.png')


if __name__ == '__main__':
    main()
