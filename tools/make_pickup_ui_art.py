"""Draw compass shards, rotating gold and bronze HUD frames at native game size.

python tools/make_pickup_ui_art.py
The shop coin stays untouched. Sources are RGBA Aseprite timelines with tags.
"""
import math
from PIL import ImageDraw
from ui_art_common import ROOT, canvas, edge, spark, save_set

BRONZE=['#4b302b','#92613c','#cf9a54','#f3cf81']
COLORS={
 'green':['#244537','#45764a','#80b65e','#d3e997'],
 'blue':['#263c59','#3e7195','#74b9cd','#d5eddf'],
 'violet':['#3d2c53','#705080','#ae81b2','#e7c4dc']}

def shard(id):
    im=canvas(16); d=ImageDraw.Draw(im); c=COLORS[id]
    # Three different broken sectors of the same ornate compass rose.
    points={
      'green':[(3,3),(6,2),(11,3),(13,6),(10,7),(11,10),(7,13),(6,10),(3,9)],
      'blue':[(3,4),(7,2),(11,3),(13,7),(11,12),(8,10),(5,13),(4,9),(2,8)],
      'violet':[(4,2),(9,3),(12,5),(11,8),(13,10),(9,13),(6,11),(3,12),(3,7)]}[id]
    d.polygon(points,fill=BRONZE[1]); d.line(points+[points[0]],fill=BRONZE[2],width=1)
    d.polygon([(5,5),(8,4),(10,6),(9,9),(7,11),(5,8)],fill=c[1])
    d.polygon([(5,5),(8,4),(7,8),(5,8)],fill=c[2])
    d.line((5,5,7,4),fill=c[3])
    # Needle + boss-colored jewel, not a generic gem silhouette.
    d.line((8,5,7,10),fill=BRONZE[3]); d.point((8,7),fill=c[3])
    d.point((4,4),fill=BRONZE[3]); d.point((11,5),fill=BRONZE[0])
    return edge(im)

def world(id,i):
    im=canvas(32); d=ImageDraw.Draw(im); c=COLORS[id]
    bob=[0,-1,-2,-2,-1,0,1,1][i]
    # Hard-edged aura marks and floor reflection, entirely binary alpha.
    d.arc((9,25,23,28),0,170,fill=c[0]); d.line((13,26,18,26),fill=c[1])
    d.arc((5,6+bob,27,24+bob),205+i*15,255+i*15,fill=c[1])
    d.arc((7,6+bob,25,24+bob),25+i*12,65+i*12,fill=c[2])
    im.alpha_composite(shard(id),(8,5+bob))
    d=ImageDraw.Draw(im)
    spark(d,6,11+((i*2)%9),c[2],i in (1,2))
    spark(d,25,16-((i*2)%9),c[3],i in (5,6))
    if i in (0,7): d.point((17,3+bob),fill=c[2])
    return im

def coin(i):
    im=canvas(16); d=ImageDraw.Draw(im)
    # Front/back/edge, round embossed face and darker milled lower/right rim.
    widths=[5,4,2,1,2,4,5,5]; r=widths[i]
    d.ellipse((8-r,3,8+r,12),fill=BRONZE[1])
    d.ellipse((8-r,3,7+r,10),fill='#d9a33e')
    if r>=3:
        d.arc((8-r,3,8+r-1,11),155,300,fill='#f7df8b')
        d.arc((9-r,5,7+r,10),0,150,fill='#93602f')
        d.line((8,5,8,9),fill='#fff0b2')
        d.point((7,6),fill='#fff0b2'); d.point((9,8),fill='#93602f')
    else: d.line((8-r,4,8-r,10),fill='#f7df8b')
    im=edge(im,'#362427'); d=ImageDraw.Draw(im)
    if i in (0,1,7): spark(d,5,4,'#fff0b2',i==0)
    return im

def slot(locked=False):
    im=canvas(28); d=ImageDraw.Draw(im)
    dark='#2d2529'; mid='#564a4c'; light='#8e796b'
    # Exactly 24x24 clear centre at (2,2), corner relief stays on the outer rim.
    d.rectangle((1,1,26,26),outline=mid)
    d.line((2,0,25,0),fill=dark); d.line((0,2,0,25),fill=dark)
    d.line((27,2,27,25),fill=dark); d.line((2,27,25,27),fill=dark)
    d.line((3,1,24,1),fill=light if not locked else mid)
    d.line((1,3,1,24),fill=light if not locked else mid)
    d.line((3,26,24,26),fill=dark); d.line((26,3,26,24),fill=dark)
    for x,y in ((1,1),(25,1),(1,25),(25,25)):
        d.rectangle((x,y,x+1,y+1),fill=BRONZE[1] if not locked else mid)
        d.point((x,y),fill=BRONZE[3] if not locked else light)
    for x in (7,20):
        d.point((x,0),fill=BRONZE[1] if not locked else mid)
        d.point((0,x),fill=BRONZE[1] if not locked else mid)
    d.rectangle((2,2,25,25),fill=(0,0,0,0))
    if locked:
        d.arc((11,9,17,17),180,360,fill=light,width=2)
        d.rectangle((10,14,18,20),fill=dark,outline=mid)
        d.line((11,15,17,15),fill=light)
        d.point((14,17),fill='#b19b80'); d.point((14,18),fill='#b19b80')
    return im

def empty():
    im=canvas(16); d=ImageDraw.Draw(im)
    d.ellipse((2,2,13,13),outline='#292630'); d.arc((3,3,12,12),175,300,fill='#6b625b')
    d.line((7,4,7,6),fill='#413c43'); d.line((4,7,6,7),fill='#413c43')
    d.line((9,8,11,8),fill='#413c43'); d.line((8,9,8,11),fill='#413c43')
    d.polygon([(7,7),(8,6),(9,8),(8,9)],fill='#6b625b')
    return im

def main():
    save_set(ROOT/'assets/sprites/pickups','gold_coin_spin',[coin(i) for i in range(8)],10)
    for id in COLORS:
        save_set(ROOT/'assets/sprites/fragments','fragment_'+id,[shard(id)])
        save_set(ROOT/'assets/sprites/fragments','fragment_'+id+'_world',[world(id,i) for i in range(8)],8)
    save_set(ROOT/'assets/sprites/fragments','fragment_slot_empty',[empty()])
    for name,locked in [('skill_slot',False),('skill_slot_locked',True)]:
        save_set(ROOT/'assets/ui/hud',name,[slot(locked)])
    print('Pickup/UI art: coin 8x16, shards 16px + 8x32, frames 28px.')

if __name__=='__main__': main()
