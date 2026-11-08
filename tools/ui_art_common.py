"""Native pixel drawing, editable Aseprite export and review sheets for UI art."""
from pathlib import Path
import struct
import zlib
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
CLEAR = (0, 0, 0, 0)
INK = '#211820'

def canvas(n):
    return Image.new('RGBA', (n, n))

def edge(im, color=INK):
    alpha = im.getchannel('A')
    # Four neighbours only: one native pixel, never a soft/diagonal halo.
    expanded = Image.new('L', im.size)
    from PIL import ImageChops
    for dx, dy in ((1,0),(-1,0),(0,1),(0,-1)):
        shifted = Image.new('L', im.size)
        shifted.paste(alpha, (dx,dy))
        expanded = ImageChops.lighter(expanded, shifted)
    under = Image.new('RGBA', im.size, color)
    under.putalpha(expanded)
    under.alpha_composite(im)
    return under

def spark(d,x,y,c,large=False):
    d.point((x,y),fill=c)
    if large:
        d.line((x-2,y,x+2,y),fill=c)
        d.line((x,y-2,x,y+2),fill=c)

def strip(frames):
    out = Image.new('RGBA',(frames[0].width*len(frames),frames[0].height))
    for i,f in enumerate(frames): out.paste(f,(i*f.width,0))
    return out

def aseprite(path, animations):
    """RGBA cels and named timeline tags; no external editor installation needed."""
    def chunk(kind, data): return struct.pack('<IH',len(data)+6,kind)+data
    def string(s):
        b=s.encode(); return struct.pack('<H',len(b))+b
    frames=[]; tags=[]
    for name, cells, fps in animations:
        start=len(frames)
        frames.extend((im,round(1000/fps)) for im in cells)
        tags.append((start,len(frames)-1,name))
    n=frames[0][0].width
    layer=chunk(0x2004,struct.pack('<HHHHHHB',1,0,0,n,n,0,255)+bytes(3)+string('Pixel art'))
    tag_data=struct.pack('<H',len(tags))+bytes(8)
    for first,last,name in tags:
        tag_data+=struct.pack('<HHBH',first,last,0,0)+bytes(6)+bytes((180,150,100,0))+string(name)
    tag_chunk=chunk(0x2018,tag_data)
    body=b''
    for i,(im,ms) in enumerate(frames):
        cel=chunk(0x2005,struct.pack('<HhhBHh',0,0,0,255,2,0)+bytes(5)+struct.pack('<HH',n,n)+zlib.compress(im.tobytes()))
        chunks=([layer,tag_chunk] if i==0 else [])+[cel]
        data=b''.join(chunks)
        body+=struct.pack('<IHHHHI',16+len(data),0xf1fa,len(chunks),ms,0,0)+data
    # Header offsets per Aseprite spec: speed at 18, transparent index at 28.
    h=bytearray(128)
    struct.pack_into('<IHHHHHI',h,0,128+len(body),0xa5e0,len(frames),n,n,32,1)
    struct.pack_into('<H',h,18,100)
    h[34]=h[35]=1
    path=Path(path); path.parent.mkdir(parents=True,exist_ok=True)
    path.write_bytes(h+body)

def save_set(folder, name, frames, fps=10):
    folder=Path(folder); folder.mkdir(parents=True,exist_ok=True)
    strip(frames).save(folder/(name+'.png'))
    aseprite(folder/'source'/(name+'.aseprite'),[(name,frames,fps)])

def preview(stage, folder=None):
    folder=Path(folder) if folder else ROOT/'tmp_preview/ui_art'/stage
    folder.mkdir(parents=True,exist_ok=True)
    paths=[]
    for sub in ('sprites/skills','sprites/pickups','sprites/fragments','ui/hud'):
        p=ROOT/'assets'/sub
        if p.exists(): paths.extend(sorted(p.glob('*.png')))
    paths += [ROOT/'assets/sprites/shop/gold_coin.png',ROOT/'assets/sprites/nico/nico_idle_side.png']
    rows=[]
    for path in paths:
        im=Image.open(path).convert('RGBA'); n=im.height
        if im.width % n: continue
        frames=[im.crop((i*n,0,(i+1)*n,n)) for i in range(im.width//n)]
        rows.append((path.stem,im))
        if len(frames)>1:
            gif=[]
            for f in frames:
                bg=Image.new('RGB',f.size,'#363039'); bg.paste(f,mask=f.getchannel('A'))
                gif.append(bg.resize((n*4,n*4),Image.Resampling.NEAREST))
            fps=6 if 'roots_loop' in path.stem else 12
            gif[0].save(folder/(path.stem+'.gif'),save_all=True,append_images=gif[1:],duration=round(1000/fps),loop=0,disposal=2)
    w=max(600,max(im.width for _,im in rows)+156); h=sum(max(24,im.height)+10 for _,im in rows)
    out=Image.new('RGB',(w,h),'#211d28'); d=ImageDraw.Draw(out); y=0
    for row,(name,im) in enumerate(rows):
        rh=max(24,im.height)+10
        d.rectangle((150,y,w,y+rh), fill=('#4f603b' if row%2 else '#4b393d'))
        d.text((3,y+4),name,fill='#e4d2b0')
        out.paste(im,(154,y+4),im); y+=rh
    out.save(folder/'contact_1x.png')
    out.resize((w*4,h*4),Image.Resampling.NEAREST).save(folder/'contact_4x.png')
    print('Preview:',folder)

if __name__=='__main__':
    import sys
    preview(sys.argv[1])
