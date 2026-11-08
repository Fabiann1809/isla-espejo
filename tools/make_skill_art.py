"""Native-size skill art. Run python tools/make_skill_art.py [--preview folder].

Preserves the SkillZone/frames contract: roots 96px 4/4/3, current 64px 6,
shadow 32px 6, burst 32px 4, HUD icons 24px. Binary alpha, upper-left light.
Editable timeline sources are rebuilt beside the PNGs.
"""
import math
import sys
from PIL import Image, ImageDraw
from ui_art_common import ROOT, canvas, edge, spark, save_set, aseprite, preview

OUT=ROOT/'assets/sprites/skills'
WOOD=['#382327','#694030','#a16840','#d19a60']
LEAF=['#345137','#63994a','#b4cf73']
WATER=['#223554','#285b89','#358fb2','#78cbd3','#d7f1df']
SMOKE=['#2b233c','#483454','#705275','#a482a2','#d5bbce']

def poly(d,pts,c): d.polygon([(round(x),round(y)) for x,y in pts],fill=c)

def root_piece(grow,sway,variant=0):
    im=canvas(28); d=ImageDraw.Draw(im)
    base=24; top=round(base-19*grow); lean=round(sway)
    d.ellipse((3,22,24,26),fill=WOOD[0])
    d.line((5,24,10,26,20,25,24,23),fill=WOOD[2])
    # Broad twisting taproot and two unequal, tapering forks.
    poly(d,[(10,24),(10,19),(7,15),(6,top+6),(8+lean,top+3),(10+lean,top+4),(10,14),(14,17),(15,12),(14+lean,top),(17+lean,top+2),(19,14),(17,20),(20,24)],WOOD[1])
    d.line([(11,23),(13,20),(12,17),(9,14),(8+lean,top+5)],fill=WOOD[3],width=1)
    d.line([(15,22),(16,18),(17,14),(16+lean,top+3)],fill=WOOD[2],width=2)
    if grow>.45:
        poly(d,[(18,18),(20,13),(23,10),(23,14),(20,19),(18,22)],WOOD[2])
        d.line((19,18,22,13),fill=WOOD[3])
        poly(d,[(8+lean,top+4),(4+lean,top+3),(3+lean,top),(7+lean,top+1)],LEAF[1])
        d.point((4+lean,top),fill=LEAF[2])
        poly(d,[(16+lean,top+3),(18+lean,top-1),(21+lean,top-2),(20+lean,top+2)],LEAF[0])
        d.line((17+lean,top+2,20+lean,top-1),fill=LEAF[2])
    return edge(im)

def roots_frame(g,phase,dust=0):
    im=canvas(96); d=ImageDraw.Draw(im)
    # Broken earth, not an opaque magic disc; keep the middle readable under Nico.
    for k in range(8):
        a=k*math.tau/8+.2
        bx=round(48+32*math.cos(a)); by=round(54+24*math.sin(a))
        d.line([(bx-5,by+3),(bx-2,by+1),(bx+2,by+3),(bx+6,by)],fill=WOOD[0])
        d.point((bx-4,by+2),fill=WOOD[2])
        if g>0:
            r=root_piece(g,math.sin(phase+k)*1.4,k)
            im.alpha_composite(r,(bx-14,by-24))
        if dust:
            for j in range(3):
                x=bx-7+j*6; y=by-3-round(dust*(3+j*2))
                d.rectangle((x,y,x+1,y+1),fill=WOOD[2 if j%2 else 1])
    return im

def wave_frame(i):
    im=canvas(64); d=ImageDraw.Draw(im)
    # A right-facing body, rolling scalloped crest, coherent trailing ribbons.
    scale=[.65,.85,1,1,.8,.45][i]
    upper=[]; lower=[]
    for y in range(7,57):
        t=(y-32)/25
        front=round(38+13*(1-t*t)+math.sin(y*.4+i*.8)*1.4)
        width=round((8+4*(1-t*t))*scale)
        upper.append((front,y)); lower.append((front-width,y))
    poly(d,upper+lower[::-1],WATER[1])
    for y in range(10,54):
        t=(y-32)/25; x=round(38+13*(1-t*t)+math.sin(y*.4+i*.8)*1.4)
        d.line((x-round(8*scale),y,x-2,y),fill=WATER[2])
        if (y+i*3)%14<9: d.line((x-2,y,x,y),fill=WATER[3])
    for k in range(5):
        y=13+k*9; x=round(39+11*(1-((y-32)/25)**2))
        # Hooked foam lobes tumble along the leading edge.
        y+= (i+k)%3-1
        d.arc((x-5,y-4,x+2,y+3),180,450,fill=WATER[4],width=2)
        d.point((x-3,y+1),fill=WATER[3])
        x0=10+(k%3)*5+i%3*2
        d.line([(x0,y+2),(x0+5,y),(x-8,y+2)],fill=WATER[1],width=2)
        d.line((x0+2,y+1,x0+7,y),fill=WATER[3])
    if i>=4:
        # Break into separated ribbons rather than random single-pixel noise.
        for y in (17,35,48): d.rectangle((35,y,58,y+2),fill=(0,0,0,0))
    for k in range(7):
        x=15+(k*13)%39; y=5+(k*17+i*3)%53
        d.line((x,y,x+1,y-1),fill=WATER[3 if k%2 else 4])
    return edge(im,WATER[0])

def puff_frame(i):
    im=canvas(32); d=ImageDraw.Draw(im)
    # The compact cloud opens into curling wisps; no stochastic dissolve.
    for k in range(5):
        a=k*math.tau/5+i*.15
        spread=[3,5,7,8,10,11][i]
        x=round(16+math.cos(a)*spread); y=round(18+math.sin(a)*spread*.65-i)
        r=[4,5,5,4,3,2][i]
        d.ellipse((x-r,y-r,x+r,y+r),fill=SMOKE[1])
        d.arc((x-r,y-r,x+r-1,y+r-1),165,290,fill=SMOKE[3],width=1)
        d.arc((x-r+2,y-r+2,x+r-1,y+r-1),170,330,fill=SMOKE[2],width=1)
    if i<4:
        d.ellipse((10,12-i,21,23-i),fill=SMOKE[1])
        d.arc((10,11-i,20,21-i),150,340,fill=SMOKE[2],width=2)
        d.arc((12,13-i,18,19-i),170,340,fill=SMOKE[3])
    im=edge(im,SMOKE[0]); d=ImageDraw.Draw(im)
    for k in range(3):
        spark(d,5+k*10,6+(k*7+i*2)%16,SMOKE[3],i==2 and k==0)
    return im

def burst_frame(i):
    im=canvas(32); d=ImageDraw.Draw(im); r=[5,9,12,14][i]
    box=(16-r,21-r//2,16+r,21+r//2)
    d.arc(box,185,350,fill='#b8c1b8',width=1)
    d.arc(box,5,165,fill='#fbf4dd',width=1)
    if i<3: d.arc((box[0]+1,box[1]+1,box[2]-1,box[3]-1),20,150,fill='#d8ded3')
    for k in range(5):
        a=k*math.tau/5+.25
        x=round(16+(r+1)*math.cos(a)); y=round(21+(r*.5+2)*math.sin(a)-i)
        spark(d,x,y,'#fbf4dd',i==1 and k<2)
    return edge(im,'#474451')

def icons():
    root=root_piece(.8,0).crop((2,2,26,26))
    water=canvas(24); d=ImageDraw.Draw(water)
    poly(d,[(3,17),(7,16),(9,11),(10,6),(13,3),(18,3),(21,6),(20,10),(17,11),(15,9),(16,7),(13,8),(13,12),(18,16),(21,17),(20,20),(4,20)],WATER[1])
    poly(d,[(5,17),(10,15),(12,9),(14,6),(18,5),(20,6),(17,6),(15,8),(16,12),(20,17),(18,18),(6,18)],WATER[2])
    d.line([(7,17),(11,16),(14,18),(18,18)],fill=WATER[3])
    d.line([(10,10),(11,6),(14,4),(18,4),(20,6)],fill=WATER[4],width=1)
    d.point((5,11),fill=WATER[3]); water=edge(water,WATER[0])
    shadow=canvas(24); d=ImageDraw.Draw(shadow)
    poly(d,[(6,6),(11,3),(16,4),(18,7),(15,6),(12,8),(11,12),(13,16),(18,17),(21,14),(20,19),(16,21),(10,20),(5,17),(3,12)],SMOKE[1])
    d.line([(5,13),(5,9),(8,6),(11,5),(14,5)],fill=SMOKE[3],width=2)
    d.line([(6,15),(9,18),(13,19),(17,18)],fill=SMOKE[2],width=2)
    spark(d,18,10,SMOKE[4],True); shadow=edge(shadow,SMOKE[0])
    return {'icon_roots':root,'icon_current':water,'icon_shadow':shadow}

def main():
    sets={
      'roots_start':[roots_frame(g,i,1 if i in (1,2) else 0) for i,g in enumerate((0,.28,.65,1))],
      'roots_loop':[roots_frame(1,i*math.pi/2) for i in range(4)],
      'roots_end':[roots_frame(g,i,0) for i,g in enumerate((.7,.35,0))],
      'current_wave':[wave_frame(i) for i in range(6)],
      'shadow_puff':[puff_frame(i) for i in range(6)],
      'cast_burst':[burst_frame(i) for i in range(4)]}
    for name,frames in sets.items(): save_set(OUT,name,frames,6 if name=='roots_loop' else 14)
    aseprite(OUT/'source/roots.aseprite',[(tag,sets['roots_'+tag],fps) for tag,fps in [('start',12),('loop',6),('end',10)]])
    for name,im in icons().items(): save_set(OUT,name,[im])
    if '--preview' in sys.argv: preview('after',sys.argv[sys.argv.index('--preview')+1])
    print('Skill art: 6 strips, 3 icons; native cells and frame counts preserved.')

if __name__=='__main__': main()
