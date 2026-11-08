"""Animate original serpent pixels, facing right, without resampling.

python tools/make_serpent_charge_art.py
The lunge uses cell 9's open jaw; all body colors and ink are source pixels.
"""
from pathlib import Path
import math
from PIL import Image, ImageDraw
from make_power_up_art import write

ROOT = Path(__file__).resolve().parents[1]
GROUND = 62


def cell(sheet, index):
    x,y=index%8*64,index//8*64
    return sheet.crop((x,y,x+64,y+64))


def ground(im):
    """Keep the lowest body pixel on the source coiled poses' ground row."""
    bottom=im.getbbox()[3]-1
    out=Image.new('RGBA',(64,64))
    out.paste(im,(0,GROUND-bottom))
    return out


def windup(src, frame):
    out=Image.new('RGBA',(64,64))
    # Inverse mapping visits EVERY destination row. Forward row pastes left
    # holes wherever the rounded rise changed by one; repeat the nearest
    # source row at those transitions instead, including its outline pixels.
    destinations = [y-round(frame*.65*max(0,min(1,(43-y)/22)))
                    for y in range(64)]
    for target_y in range(64):
        y=min(range(64),key=lambda row: abs(destinations[row]-target_y))
        retreat=round(frame*1.7*max(0,min(1,(48-y)/25)))
        out.paste(src.crop((0,y,64,y+1)),(-retreat,target_y))
    return ground(out)


def charge(src, frame):
    frame %= 6
    out=Image.new('RGBA',(64,64))
    phase=frame/6*math.tau
    # The descending lunge is laid low by integer column translations.
    # The original jaw stays rigid; the S wave moves from neck to tail.
    for x in range(64):
        fade=max(0,min(1,(46-x)/15))
        # A 24px wavelength advances bends exactly 4px per frame. Six steps
        # return to the same phase, including the last-to-first transition.
        dy=round(13*(1-x/63)+5*fade*math.sin(math.tau*x/24-phase))
        out.paste(src.crop((x,0,x+1,64)),(x,dy))
    out=ground(out)
    d=ImageDraw.Draw(out)
    # Source moss/stone colors; discrete trailing dust, never soft streaks.
    dust=[(50,78,62,255),(133,103,101,255),(57,47,72,255)]
    for j in range(3):
        x=2+(frame*2+j*5)%12
        y=55+(j*3+frame)%7
        d.line((x,y,x+1+(frame+j)%2,y),fill=dust[j])
    return out


def check_seams(im, label):
    """Reject empty scanlines between overlapping opaque horizontal runs.

    Work with runs rather than individual pixels: isolated mouth/eye holes
    and the concave silhouette are intentional, full cross-body cuts are not.
    """
    alpha=im.getchannel('A')
    top,bottom=alpha.getbbox()[1],alpha.getbbox()[3]
    for y in range(top+1,bottom-1):
        shared=[x for x in range(64)
                if alpha.getpixel((x,y-1)) and alpha.getpixel((x,y+1))]
        runs=[]
        for x in shared:
            if not runs or x!=runs[-1][-1]+1:
                runs.append([])
            runs[-1].append(x)
        for run in runs:
            if len(run)>=3 and not any(alpha.getpixel((x,y)) for x in run):
                raise ValueError(f'{label}: transparent seam at row {y}, columns {run[0]}..{run[-1]}')


def main():
    sheet=Image.open(ROOT/'assets/sprites/serpiente/serpiente.png').convert('RGBA')
    assert sheet.size==(512,128), sheet.size
    animations=[('serpiente_charge_windup',[windup(cell(sheet,1),i) for i in range(4)]),
                ('serpiente_charge',[charge(cell(sheet,9),i) for i in range(6)])]
    for name,frames in animations:
        for i,im in enumerate(frames):
            check_seams(im,f'{name} frame {i+1}')
            assert im.getbbox()[3]-1==GROUND
        write(Path('assets/sprites/serpiente')/(name+'.png'),frames)
        print(f'{name}: seam check passed on all {len(frames)} frames')


if __name__=='__main__':
    main()
