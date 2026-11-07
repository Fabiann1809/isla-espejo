import math


import os


import random


from PIL import Image, ImageDraw, ImageFont


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HERE = os.path.join(ROOT, "assets", "ui", "menu")




W, H = 480, 270


rnd = random.Random(7)


BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def hexc(s, a=255):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), a)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3)) + (255,)


def dith(x, y, t):
    """True when the pixel should take the 'second' color at blend t (0..1)."""
    return t * 16 > BAYER[y % 4][x % 4] + 0.5


def ramp(stops, t, x, y):
    t = max(0.0, min(0.9999, t)) * (len(stops) - 1)
    i = int(t)
    return stops[i + 1] if dith(x, y, t - i) else stops[i]


def noise1(seed, n):
    r = random.Random(seed)
    pts = [r.random() for _ in range(n + 2)]
    def f(x):
        i = int(x) % n
        t = x - int(x)
        t = t * t * (3 - 2 * t)
        return pts[i] * (1 - t) + pts[i + 1] * t
    return f


def sky(img):
    px = img.load()
    stops = [hexc(c) for c in ("#0d0b24", "#171345", "#241c5c", "#34297a", "#4a3d94", "#6a58a8")]
    for y in range(H):
        for x in range(W):
            px[x, y] = ramp(stops, y / 175, x, y)
    d = ImageDraw.Draw(img)
    # stars
    for _ in range(70):
        x, y = rnd.randrange(W), rnd.randrange(0, 110)
        c = rnd.choice(["#c9c3ff", "#e8e2ff", "#9d95e0"])
        d.point((x, y), hexc(c))
    for x, y in [(106, 17), (314, 20), (460, 22), (57, 40), (212, 33)]:
        c = hexc("#f4efff")
        d.point((x, y), c)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            d.point((x + dx, y + dy), hexc("#a9a0f0"))
        if x in (314, 460):  # the two big sparkles
            for k in (2, 3):
                for dx, dy in ((k, 0), (-k, 0), (0, k), (0, -k)):
                    d.point((x + dx, y + dy), hexc("#7d73cf"))


def moon(img):
    cx, cy, r = 404, 46, 20
    px = img.load()
    for rr, col in ((46, "#2a2266"), (38, "#33297a"), (30, "#40348a")):
        for y in range(cy - rr, cy + rr):
            for x in range(cx - rr, cx + rr):
                dd = math.hypot(x - cx, y - cy)
                if dd <= rr and dith(x, y, 0.35):
                    px[x, y] = hexc(col)
    d = ImageDraw.Draw(img)
    d.ellipse((cx - r - 1, cy - r - 1, cx + r + 1, cy + r + 1), fill=hexc("#8a7fcf"))
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r, cx + r + 1):
            dd = math.hypot(x - cx, y - cy)
            if dd <= r:
                shade = (x - cx) * 0.4 + (y - cy) * 0.5  # lit from upper left
                base = mix(hexc("#fff2c4"), hexc("#d7c590"), max(0, min(1, (shade + 12) / 30)))
                px[x, y] = base
    for x, y, rr in [(-7, -5, 4), (7, 4, 5), (-3, 10, 3)]:
        for yy in range(-rr, rr + 1):
            for xx in range(-rr, rr + 1):
                if xx * xx + yy * yy <= rr * rr and math.hypot(x + xx, y + yy) < r - 1 and dith(cx + x + xx, cy + y + yy, 0.95):
                    px[cx + x + xx, cy + y + yy] = hexc("#dccb98")


def cloud(img, cx, cy, w, h, col_hi, col_lo):
    px = img.load()
    n = noise1(int(cx * 7 + cy), 12)
    for y in range(cy - h, cy + h):
        for x in range(cx - w, cx + w):
            u = (x - cx) / w
            v = (y - cy) / h
            edge = 1 - (u * u + v * v * 1.6) + (n((x - cx + w) / 6) - 0.5) * 0.7
            if edge > 0.05 and 0 <= x < W and 0 <= y < H:
                px[x, y] = col_hi if (v < -0.1 or edge > 0.6 and dith(x, y, 0.5)) else col_lo


def mountain(img, seed, base, amp, col, haze, haze_h, scale=70, bump=None, trees=None):
    px = img.load()
    n = noise1(seed, 40)
    n2 = noise1(seed + 1, 200)

    def top_at(x):
        b = bump[1] * math.exp(-((x - bump[0]) / bump[2]) ** 2) if bump else 0.0
        return int(base - amp * (0.7 * n(x / scale) + 0.3 * n2(x / 11)) - b)
    tops = [top_at(x) for x in range(W)]
    rim = mix(col, hexc("#8a7cd0"), 0.35)
    for x in range(W):
        for y in range(max(tops[x], 0), H):
            px[x, y] = rim if y - tops[x] < 1 else col
    # moonlit slopes: lighter facets on the side facing the moon
    for x in range(1, W):
        if tops[x] < tops[x - 1]:
            for k in range(1, 5):
                if dith(x, tops[x] + k, 0.5 - k * 0.1):
                    px[x, tops[x] + k] = mix(col, hexc("#7a6cc0"), 0.22)
    # mist hugging the foot of the range
    for x in range(W):
        for y in range(max(tops[x] + 6, base - 14), base + haze_h):
            t = (y - (base - 14)) / (haze_h + 14)
            if dith(x, y, 0.75 * math.sin(min(1, t) * math.pi)):
                px[x, y] = mix(px[x, y], haze, 0.55)
    if trees:
        r = random.Random(seed)
        x = 2
        while x < W:
            hh = r.randint(6, 10)
            pine(img, x, tops[x] + 3, hh, 3, trees, trees, mix(trees, hexc("#6a5cb0"), 0.3), shaded=False)
            x += r.randint(4, 8)
    return lambda x: tops[x]


def lake(img):
    px = img.load()
    stops = [hexc(c) for c in ("#4a3e98", "#352c78", "#241e56")]
    for y in range(158, 194):
        for x in range(180, 372):
            px[x, y] = ramp(stops, (y - 158) / 36, x, y)
    r = random.Random(3)
    for x in range(184, 368, 3):
        hh = r.randint(3, 8)
        for k in range(hh):
            if dith(x, 160 + k, 0.5):
                px[x, 160 + k] = hexc("#1c1646")
                px[x + 1, 160 + k] = hexc("#1c1646")
    for y in range(160, 190, 2):
        half = 3 + (y - 160) // 3
        x0 = 250 + r.randint(-3, 3)
        for x in range(x0 - half, x0 + half + 1):
            if r.random() < 0.55:
                px[x, y] = hexc("#cfc8f4") if abs(x - x0) < half * 0.5 else hexc("#8b80d4")
    d = ImageDraw.Draw(img)
    for y in range(162, 192, 3):
        for x in r.sample(range(190, 360), 6):
            d.line((x, y, x + r.randint(3, 9), y), fill=hexc("#5a4eb0"))


def pine(img, cx, base, h, w, dark, mid, rim, shaded=True):
    """Layered conifer with scalloped tiers: each tier is a row of needle tufts, lit from the right."""
    d = ImageDraw.Draw(img)
    r = random.Random(cx * 31 + base)
    tiers = max(3, h // 9)
    trunk_h = max(2, h // 8)
    d.rectangle((cx - 1, base - trunk_h, cx, base), fill=dark)
    body = h - trunk_h
    for i in range(tiers):
        t0 = i / tiers
        ty = base - trunk_h - int(body * t0 * 0.9)
        tw = max(2, int(w * (1 - t0 * 0.8)))
        th = max(5, int(body / tiers * 2.0))
        for k in range(th):
            y = ty - th + k
            frac = k / th
            half = max(0, int(tw * frac))
            d.line((cx - half, y, cx + half, y), fill=dark)
            if shaded and half > 1:
                d.point((cx + half, y), rim)
                if k % 2 == 0:
                    d.point((cx + half - 2, y), mid)
                if frac > 0.45 and k % 3 == 0:
                    d.point((cx - half + 1, y), mid)
        # scalloped hem: bumps of three pixels hanging under the tier
        for j in range(-tw, tw + 1, 3):
            if shaded:
                d.rectangle((cx + j, ty, cx + j + 1, ty + 1 + (r.random() < 0.5)), fill=dark)
                if j > 0:
                    d.point((cx + j + 1, ty), mid)
            else:
                d.point((cx + j, ty), dark)
        if shaded and i % 2 == 0:
            d.line((cx + tw // 3, ty - th // 2, cx + tw - 1, ty - 1), fill=mid)


def forest_layers(img):
    px = img.load()
    # far haze line where the land starts
    d = ImageDraw.Draw(img)
    d.rectangle((0, 192, W, H), fill=hexc("#1a2a3a"))
    # layer 1: tiny distant pines on the far shore
    for x in range(0, W, 5):
        if 205 < x < 345:
            continue
        pine(img, x + rnd.randint(-1, 1), 190 + rnd.randint(0, 3), rnd.randint(18, 34), 5, hexc("#1d2652"), hexc("#262f66"), hexc("#363d80"))
    # layer 2
    for x in range(-5, W + 10, 13):
        if 215 < x < 335:
            continue
        pine(img, x + rnd.randint(-2, 2), 196 + rnd.randint(-2, 3), rnd.randint(40, 64), 9, hexc("#1a2a3f"), hexc("#21394a"), hexc("#2f4e63"))
    # layer 3 (nearer, tall, greener) with gaps so the lake and hill still show
    spots = [58, 96, 126, 152, 184, 212, 358, 372, 405, 440, 470]
    for x in spots:
        hh = rnd.randint(58, 92)
        pine(img, x, 207 + rnd.randint(-2, 3), hh, int(hh * 0.19), hexc("#12302c"), hexc("#1a4338"), hexc("#2c6048"))
    # right side stays the darkest so the buttons read clearly
    for x in (360, 392, 430, 462):
        pine(img, x, 214, rnd.randint(60, 86), 14, hexc("#0f2327"), hexc("#16323a"), hexc("#234a52"))


def oak(img):
    d = ImageDraw.Draw(img)
    px = img.load()
    bark_tree(d, None, hexc("#1d1318"), hexc("#4e3224"), hexc("#8a5a34"))
    tones = [hexc(c) for c in ("#0b2326", "#103a36", "#185240", "#27704a", "#3f8e54")]
    r = random.Random(21)
    stamps = []
    for row in range(0, 19):
        cy = 30 + row * 5
        for col in range(-3, 13):
            cx = 4 + col * 6 + (3 if row % 2 else 0) + r.randint(-1, 1)
            ccy = cy + r.randint(-1, 1)
            # crown outline: rounded triangle widening downward
            u = (cx - 34) / 52.0
            v = (ccy - 30) / 92.0
            if v < 0 or v > 1:
                continue
            half = 0.30 + 0.78 * math.sqrt(v) if v < 0.9 else 1.05 - (v - 0.9) * 4
            if abs(u) > half + (r.random() - 0.5) * 0.15:
                continue
            lit = (u * 0.8 - (v - 0.35) * 1.1)
            lvl = 2 + (1 if lit > 0.1 else 0) + (1 if lit > 0.55 else 0) - (1 if lit < -0.35 else 0) - (1 if lit < -0.8 else 0)
            stamps.append((ccy, cx, max(0, min(4, lvl + r.choice((0, 0, 1, -1) if 0 < lvl < 4 else (0,))))))
    for cy, cx, lvl in sorted(stamps):
        leaf_stamp(px, cx, cy, tones, lvl)
    # trunk top and branches show through the lower crown: redraw them in front a little
    for pts, w in (([(28, 146), (16, 134)], 3), ([(30, 140), (44, 128)], 3)):
        limb(d, pts, w, hexc("#4e3224"), hexc("#1d1318"))
    # base: tufts and stones
    g = [hexc(c) for c in ("#12301f", "#1f5030", "#3a8048")]
    rr = random.Random(2)
    for x in range(2, 62, 3):
        y = 199 + rr.randint(-1, 1)
        h = rr.randint(3, 6)
        for k in range(h):
            d.point((x + (k // 2) * (1 if x % 2 else -1), y - k), g[1 if k < h - 1 else 2])
            d.point((x, y - k), g[0] if k < 2 else g[1])
    for x, y, w, h in ((28, 195, 8, 5), (40, 197, 5, 3), (12, 197, 5, 3)):
        rock(d, x, y, w, h)
    d.line((0, 200, 62, 200), fill=hexc("#0b1c1a"))


def lantern_post(layer, glow):
    d = ImageDraw.Draw(layer)
    wood, wood_d, wood_l = hexc("#3b2a22"), hexc("#241a1a"), hexc("#5c4333")
    d.rectangle((43, 140, 45, 198), fill=wood)
    d.line((43, 140, 43, 198), fill=wood_d)
    d.line((45, 140, 45, 198), fill=wood_l)
    d.rectangle((43, 137, 64, 139), fill=wood)
    d.line((43, 137, 64, 137), fill=wood_l)
    d.line((45, 149, 53, 139), fill=wood_d)
    d.line((60, 140, 60, 143), fill=hexc("#6a5a4a"))
    d.rectangle((56, 143, 64, 144), fill=wood_d)
    d.rectangle((57, 145, 63, 153), fill=hexc("#f6b845"))
    d.rectangle((58, 146, 62, 152), fill=hexc("#fff0b8"))
    d.line((60, 145, 60, 153), fill=hexc("#8a5a20"))
    d.rectangle((56, 154, 64, 155), fill=wood_d)
    d.line((56, 144, 56, 155), fill=wood_d)
    d.line((64, 144, 64, 155), fill=wood_d)
    g = ImageDraw.Draw(glow)
    for rr, a in ((46, 20), (34, 32), (24, 48), (14, 72)):
        for y in range(149 - rr, 149 + rr):
            for x in range(60 - rr, 60 + rr):
                if math.hypot(x - 60, (y - 149) * 1.1) <= rr and dith(x, y, 0.6):
                    g.point((x, y), (255, 190, 90, a))


def ground(img, glow):
    px = img.load()
    d = ImageDraw.Draw(img)
    gr = [hexc(c) for c in ("#12251f", "#173528", "#1f4630", "#2b5a37")]
    for y in range(196, H):
        for x in range(W):
            t = (y - 196) / 74
            # moonlit slopes: a bit brighter toward the middle foreground
            px[x, y] = ramp(gr, 0.15 + 0.8 * t * (0.6 + 0.4 * math.sin(x / 80)), x, y)
    # winding dirt path
    pts = [(40, 270), (74, 236), (118, 220), (170, 222), (215, 238), (262, 270)]
    def bez(t):
        n = len(pts) - 1
        i = min(int(t * n), n - 1)
        u = t * n - i
        a, b = pts[i], pts[i + 1]
        return a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u
    dirt = [hexc(c) for c in ("#3c2c26", "#5a4332", "#7a5c3c")]
    for s in range(0, 400):
        cx, cy = bez(s / 400)
        wid = 15 + (cy - 220) * 0.45
        for y in range(int(cy - 7), int(cy + 7)):
            for x in range(int(cx - wid), int(cx + wid)):
                if (x - cx) ** 2 / wid ** 2 + (y - cy) ** 2 / 49 <= 1 and 0 <= x < W and 0 <= y < H:
                    e = ((x - cx) ** 2 / wid ** 2 + (y - cy) ** 2 / 49)
                    lvl = 1 + (1 if e < 0.45 else 0) + (-1 if e > 0.82 else 0)
                    if dith(x, y, 0.3) and lvl < 2:
                        lvl += 1
                    px[x, y] = dirt[max(0, min(2, lvl))]
    # warm light pooling under the lantern
    for y in range(190, 235):
        for x in range(30, 120):
            if math.hypot(x - 62, (y - 200) * 1.8) < 34 and dith(x, y, 0.3):
                g = px[x, y]
                px[x, y] = mix(g, hexc("#c9a050"), 0.22)
    # grass tufts, flowers, rocks
    for _ in range(170):
        x, y = rnd.randint(0, W - 4), rnd.randint(200, H - 2)
        if px[x, y][:3] in [c[:3] for c in dirt]:
            continue
        c = hexc(rnd.choice(["#2f6b3d", "#3d8049", "#255a35"]))
        d.line((x, y, x - 1, y - 3), fill=c)
        d.line((x + 1, y, x + 2, y - 4), fill=c)
        d.point((x, y - 2), c)
    for x, y in [(212, 222), (196, 250), (228, 234), (62, 232), (310, 246)]:
        d.point((x, y), hexc("#b9a8f0"))
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            d.point((x + dx, y + dy), hexc("#e8e0ff"))
        d.point((x, y), hexc("#fff0a0"))
    for x, y, w, h in [(145, 218, 16, 9), (50, 242, 20, 11), (252, 250, 22, 12), (400, 255, 24, 13), (14, 204, 12, 7)]:
        rock(d, x, y, w, h)
    # broken wooden fence, bottom left
    wood, wood_d, wood_l = hexc("#4a3427"), hexc("#2a1d1d"), hexc("#6c4d37")
    for x, y0, hh in [(4, 236, 30), (46, 244, 24)]:
        d.rectangle((x, y0, x + 7, y0 + hh), fill=wood)
        d.line((x, y0, x, y0 + hh), fill=wood_d)
        d.line((x + 7, y0, x + 7, y0 + hh), fill=wood_l)
        d.rectangle((x, y0 - 1, x + 7, y0), fill=wood_l)
    d.polygon([(0, 248), (50, 256), (52, 262), (0, 256)], fill=wood)
    d.line((0, 248, 50, 256), fill=wood_l)
    d.polygon([(10, 238), (44, 240), (44, 244), (10, 242)], fill=wood_d)


def rock(d, x, y, w, h):
    cols = [hexc(c) for c in ("#1e1a38", "#352f5a", "#4c4478", "#6a6296")]
    d.ellipse((x, y, x + w, y + h), fill=cols[0])
    d.ellipse((x + 1, y + 1, x + w - 1, y + h - 1), fill=cols[1])
    d.ellipse((x + 2, y + 1, x + w - 3, y + h // 2), fill=cols[2])
    d.line((x + w // 2, y + 1, x + w - 4, y + 2), fill=cols[3])


def vignette(img):
    px = img.load()
    for y in range(H):
        for x in range(W):
            dx = (x - W / 2) / (W / 2)
            dy = (y - H / 2) / (H / 2)
            v = max(0.0, (dx * dx + dy * dy) - 0.55)
            if v > 0 and dith(x, y, min(0.55, v * 0.6)):
                r, g, b, a = px[x, y]
                px[x, y] = (int(r * 0.7), int(g * 0.7), int(b * 0.78), 255)


def font(name, size):
    return ImageFont.truetype(os.path.join(r"C:\Windows\Fonts", name), size)


def hard_text(text, fnt, fill_top, fill_bot, outline=None, shadow=None):
    """Render text with no antialiasing (alpha thresholded) and a vertical color ramp."""
    probe = Image.new("L", (800, 80), 0)
    ImageDraw.Draw(probe).text((10, 10), text, font=fnt, fill=255)
    probe = probe.point(lambda v: 255 if v > 110 else 0)
    bbox = probe.getbbox()
    m = probe.crop(bbox)
    w, h = m.size
    out = Image.new("RGBA", (w + 4, h + 5), (0, 0, 0, 0))
    mpx, opx = m.load(), out.load()
    for y in range(h):
        for x in range(w):
            if mpx[x, y]:
                opx[x + 2, y + 2] = mix(fill_top, fill_bot, y / max(1, h - 1))
    if outline:
        ring = Image.new("RGBA", out.size, (0, 0, 0, 0))
        rp = ring.load()
        for y in range(out.height):
            for x in range(out.width):
                if opx[x, y][3] == 0:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
                        xx, yy = x + dx, y + dy
                        if 0 <= xx < out.width and 0 <= yy < out.height and opx[xx, yy][3] and opx[xx, yy][:3] != outline[:3]:
                            rp[x, y] = outline
        ring.alpha_composite(out)
        out = ring
    if shadow:
        sh = Image.new("RGBA", (out.width, out.height + 1), (0, 0, 0, 0))
        sp = sh.load()
        op = out.load()
        for y in range(out.height):
            for x in range(out.width):
                if op[x, y][3]:
                    sp[x, y + 1] = shadow
        sh.alpha_composite(out)
        out = sh
    return out


def make_title():
    big, small = font("georgiab.ttf", 34), font("georgiab.ttf", 23)
    top, bot, line = hexc("#f3edff"), hexc("#a99be0"), hexc("#1a1440")
    parts = []
    for word in ("ISLA", "ESPEJO"):
        letters = []
        for i, ch in enumerate(word):
            letters.append(hard_text(ch, big if i == 0 else small, top, bot, line))
        parts.append(letters)
    gap = 9
    widths = [sum(l.width - 3 for l in w) for w in parts]
    total = sum(widths) + gap + 6
    img = Image.new("RGBA", (total, 44), (0, 0, 0, 0))
    x = 2
    base = 41
    for wi, word in enumerate(parts):
        for l in word:
            img.alpha_composite(l, (x, base - l.height + 3))
            x += l.width - 3
        x += gap
    return img.crop(img.getbbox())


def divider(width=196):
    img = Image.new("RGBA", (width, 11), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cy, cx = 5, width // 2
    lav, lav_d = hexc("#a79be0"), hexc("#6a5eb0")
    for x in range(2, cx - 10):
        d.point((x, cy), lav if x > 12 else lav_d)
    for x in range(cx + 10, width - 2):
        d.point((x, cy), lav if x < width - 13 else lav_d)
    for side in (0, 1):
        ex = 2 if side == 0 else width - 3
        d.point((ex, cy - 1), lav)
        d.point((ex, cy + 1), lav)
        d.point((ex + (1 if side == 0 else -1), cy), lav)
    for ex in (cx - 13, cx + 13):
        d.point((ex, cy - 1), lav)
        d.point((ex, cy + 1), lav)
    d.polygon([(cx, cy - 5), (cx + 5, cy), (cx, cy + 5), (cx - 5, cy)], fill=hexc("#150f33"), outline=lav)
    d.polygon([(cx, cy - 2), (cx + 2, cy), (cx, cy + 2), (cx - 2, cy)], fill=hexc("#e6deff"))
    return img


def button(selected, w=128, h=26):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if selected:
        fill_t, fill_b = hexc("#3a3068"), hexc("#241d4a")
        edge, inner, stud = hexc("#f4d98a"), hexc("#a98a4c"), hexc("#fff0b8")
    else:
        fill_t, fill_b = hexc("#26204f"), hexc("#1a1538")
        edge, inner, stud = hexc("#6a60a4"), hexc("#3a3270"), hexc("#a89ce0")
    d.rounded_rectangle((0, 0, w - 1, h - 1), 2, fill=hexc("#0b0820"))
    for y in range(2, h - 2):
        d.line((2, y, w - 3, y), fill=mix(fill_t, fill_b, (y - 2) / (h - 5)))
    d.rectangle((1, 1, w - 2, h - 2), outline=edge)
    d.rectangle((3, 3, w - 4, h - 4), outline=inner)
    # carve the corners and put a small stud in each, like a framed plaque
    for (cx, cy, sx, sy) in ((0, 0, 1, 1), (w - 1, 0, -1, 1), (0, h - 1, 1, -1), (w - 1, h - 1, -1, -1)):
        for ox, oy in ((0, 0), (1, 0), (0, 1)):
            d.point((cx + ox * sx, cy + oy * sy), (0, 0, 0, 0))
        d.point((cx + sx * 3, cy + sy * 3), stud)
        d.point((cx + sx * 2, cy + sy * 2), edge)
        d.point((cx + sx * 4, cy + sy * 1), edge)
        d.point((cx + sx * 1, cy + sy * 4), edge)
    if selected:
        d.line((5, 4, w - 6, 4), fill=hexc("#5a4a96"))      # top sheen
    return img


def arrow():
    img = Image.new("RGBA", (7, 9), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(0, 0), (6, 4), (0, 8)], fill=hexc("#f6dc8e"))
    d.line((0, 0, 0, 8), fill=hexc("#fff3c4"))
    return img


def footer(w=300, h=15):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle((0, 1, w - 1, h - 2), fill=hexc("#0b0920", 190))
    d.line((0, 1, w - 1, 1), fill=hexc("#2e2766", 220))
    lav = hexc("#8e82d6")
    for cx, sx in ((8, 1), (w - 9, -1)):
        d.polygon([(cx, 3), (cx + 4, 7), (cx, 11), (cx - 4, 7)], outline=lav)
        d.point((cx, 7), hexc("#e6deff"))
        d.line((cx + sx * 7, 7, cx + sx * 14, 7), fill=lav)
    return img


def px_text(txt, fnt, color, shadow=hexc("#0a0820")):
    return hard_text(txt, fnt, color, mix(color, hexc("#a8a0d8"), 0.35), None, shadow)


def build():
    bg = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    sky(bg)
    moon(bg)
    cloud(bg, 30, 28, 40, 7, hexc("#4a3e92"), hexc("#372d78"))
    cloud(bg, 455, 78, 40, 9, hexc("#4a3e92"), hexc("#372d78"))
    cloud(bg, 300, 20, 30, 4, hexc("#3b3184"), hexc("#2b2368"))
    cloud(bg, 190, 120, 70, 8, hexc("#54489e"), hexc("#41388a"))
    mountain(bg, 3, 158, 78, hexc("#3a3080"), hexc("#6a5cb4"), 18, 95, bump=(345, 28, 55))
    mountain(bg, 9, 172, 54, hexc("#2c2565"), hexc("#5a4cac"), 16, 60, trees=hexc("#221c52"))
    mountain(bg, 14, 184, 34, hexc("#221c52"), hexc("#4a3e98"), 12, 45, trees=hexc("#191443"))
    lake(bg)
    forest_layers(bg)
    oak(bg)
    ground(bg, None)
    return bg


def main():
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bg = build()
    lantern = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    lantern_post(lantern, glow)
    bg.alpha_composite(lantern)
    foreground(bg)
    vig = bg.copy()
    vignette(vig)
    vig.save(os.path.join(HERE, "background.png"))
    glow.save(os.path.join(HERE, "lantern_glow.png"))

    title, div = make_title(), divider(196)
    title.save(os.path.join(HERE, "title.png"))
    div.save(os.path.join(HERE, "divider.png"))
    btn_n, btn_s, arr, foot = button(False), button(True), arrow(), footer(340)
    btn_n.save(os.path.join(HERE, "button_normal.png"))
    btn_s.save(os.path.join(HERE, "button_selected.png"))
    arr.save(os.path.join(HERE, "arrow.png"))
    foot.save(os.path.join(HERE, "footer.png"))

    bat = Image.open(BAT).convert("RGBA").crop((0, 0, 64, 64))
    nico, nock, grip = make_archer()
    bat.save(os.path.join(HERE, "bat.png"))
    nico.save(os.path.join(HERE, "nico.png"))
    pv = vig.copy()
    pv.alpha_composite(glow)
    bb = nico.getbbox()
    nx, ny = 58, 218 - bb[3]
    ImageDraw.Draw(pv).ellipse((nx + 14, 216, nx + 64, 223), fill=hexc("#0c1a16"))
    pv.alpha_composite(nico, (nx, ny))
    bat_pos = (318, 44)
    bat_center = (bat_pos[0] + 32, bat_pos[1] + 34)
    gl = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gp = gl.load()
    for yy in range(bat_center[1] - 40, bat_center[1] + 40):
        for xx in range(bat_center[0] - 60, bat_center[0] + 60):
            dd = math.hypot((xx - bat_center[0]) / 1.5, yy - bat_center[1]) / 40
            if dd < 1 and dith(xx, yy, (1 - dd) ** 1.5 * 0.55):
                gp[xx, yy] = (255, 230, 170, 60)
    pv.alpha_composite(gl)
    pv.alpha_composite(bat, bat_pos)
    bow_c = (nx + int(os.environ.get("BX", 54)), ny + int(os.environ.get("BY", 32)))
    fly_arrow(pv, (nx + grip[0], ny + grip[1]), bat_center)
    pv.alpha_composite(title, (80, 28))
    pv.alpha_composite(div, (77, 66))
    sub = px_text("Un camino de vuelta a casa", font("constan.ttf", 15), hexc("#cfc6f5"))
    pv.alpha_composite(sub, (98 + (176 - sub.width) // 2 - 4, 76))
    labels = ["Comenzar viaje", "Continuar", "Configuración", "Créditos", "Salir"]
    x0, y0, step = 308, 110, 26
    lf = font("constanb.ttf", 13)
    for i, name in enumerate(labels):
        y = y0 + i * step
        pv.alpha_composite(btn_s if i == 0 else btn_n, (x0, y))
        t = px_text(name, lf, hexc("#fff0c2") if i == 0 else hexc("#cbc4ee"))
        pv.alpha_composite(t, (x0 + (128 - t.width) // 2 + (4 if i == 0 else 0), y + (26 - t.height) // 2))
    pv.alpha_composite(arr, (x0 + 10, y0 + 9))
    pv.alpha_composite(foot, (70, 247))
    hf = font("constan.ttf", 10)
    ft = px_text("WASD Mover  ·  J Atacar  ·  ESPACIO Esquivar  ·  E Interactuar", hf, hexc("#b9b0e8"))
    pv.alpha_composite(ft, (70 + (340 - ft.width) // 2, 248))
    pv.save(os.path.join(HERE, "preview_x1.png"))
    pv.resize((W * 3, H * 3), Image.NEAREST).save(os.path.join(HERE, "preview_x3.png"))
    export_ui_kit()
    print("ok", nx, ny, bb)


REFS = os.path.join(HERE, "source")


BAT = os.path.join(ROOT, "assets", "sprites", "murcielago", "murcielago_idle.png")


def clump(px, cx, cy, r, tones):
    """A rounded leaf clump: dark body, mid body, light crescent on the moon side (upper right)."""
    for y in range(cy - r, cy + r + 1):
        for x in range(cx - r - 1, cx + r + 2):
            if not (0 <= x < W and 0 <= y < H):
                continue
            dd = math.hypot(x - cx, (y - cy) * 1.1)
            if dd > r:
                continue
            lit = ((x - cx) * 0.55 - (y - cy) * 0.75) / r
            lvl = 1 + (1 if lit > -0.1 else 0) + (1 if lit > 0.35 and dith(x, y, 0.8) else 0)
            if dd > r - 1.2 and lit < 0:
                lvl = 0
            if lit > 0.6 and dd > r - 2:
                lvl = 4 if dith(x, y, 0.6) else 3
            px[x, y] = tones[min(4, lvl)]


def foreground(img):
    """Dark ferns framing the bottom corners, plus fireflies."""
    d = ImageDraw.Draw(img)
    r = random.Random(11)
    cols = [hexc(c) for c in ("#0b1c1a", "#10281f", "#173a2a")]
    for cx, cy, n in ((0, 268, 16), (480, 268, 20), (330, 270, 8), (214, 272, 6)):
        for _ in range(n):
            x = cx + r.randint(-26, 26)
            y = cy + r.randint(-8, 4)
            ln = r.randint(10, 22)
            c = r.choice(cols)
            for side in (-1, 1):
                for k in range(ln):
                    d.point((x + side * (k // 2), y - k + (k * k) // 28), c)
            d.line((x, y, x, y - ln // 2), fill=c)
    for _ in range(14):
        x, y = r.randint(120, 360), r.randint(150, 238)
        d.point((x, y), hexc("#f2ee8a"))
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if r.random() < 0.7:
                d.point((x + dx, y + dy), hexc("#6a7a46"))


OUT = hexc("#060000")


SKIN, SKIN_D = hexc("#e5ae8a"), hexc("#b7886c")


BLUE, BLUE_L, BLUE_D = hexc("#0b7ed4"), hexc("#3aa0f0"), hexc("#0e5899")


PANT, PANT_L = hexc("#161b34"), hexc("#1c2b4a")


BOOT, BOOT_D, BOOT_L = hexc("#723f24"), hexc("#482413"), hexc("#8a5230")


BOW, BOW_D, BOW_L = hexc("#8a5428"), hexc("#4a2a14"), hexc("#c98a4a")


def thick(d, a, b, w, fill):
    d.line((a, b), fill=fill, width=w)
    for p in (a, b):
        d.ellipse((p[0] - w // 2, p[1] - w // 2, p[0] + w // 2, p[1] + w // 2), fill=fill)


def limb(d, pts, w, fill, edge=OUT, light=None):
    """A limb with a 1 px outline: draw wide in the outline color, then narrower in fill."""
    for a, b in zip(pts, pts[1:]):
        thick(d, a, b, w + 2, edge)
    for a, b in zip(pts, pts[1:]):
        thick(d, a, b, w, fill)
    if light:
        for a, b in zip(pts, pts[1:]):
            d.line(((a[0] - 1, a[1] - 1), (b[0] - 1, b[1] - 1)), fill=light, width=1)


def make_archer():
    """Nico (head, pack and torso from the team's reference) drawing the bow. Returns (image, nock, grip)."""
    src = Image.open(os.path.join(REFS, "nico_east.png")).convert("RGBA")
    ox, oy = 6, 12
    img = Image.new("RGBA", (104, 76), (0, 0, 0, 0))
    base = src.copy()
    # remove the hanging arm, the compass hand and the legs; torso is redrawn below
    bp = base.load()
    for y in range(28, 64):
        for x in range(30, 64):
            bp[x, y] = (0, 0, 0, 0)
    for y in range(45, 64):
        for x in range(0, 64):
            bp[x, y] = (0, 0, 0, 0)
    img.alpha_composite(base, (ox, oy))
    d = ImageDraw.Draw(img)

    def P(x, y):
        return (x + ox, y + oy)

    # torso block turned a little toward the target (replaces the arm-hung torso)
    d.rectangle((P(30, 28), P(44, 43)), fill=BLUE)
    d.rectangle((P(38, 28), P(44, 43)), fill=BLUE_D)
    d.line((P(44, 28), P(44, 43)), fill=OUT)
    d.line((P(30, 44), P(44, 44)), fill=OUT)
    d.line((P(31, 29), P(31, 40)), fill=BLUE_L)
    # belt with the compass
    d.rectangle((P(30, 39), P(44, 41)), fill=hexc("#482413"))
    d.rectangle((P(33, 38), P(37, 43)), fill=hexc("#d9b46a"))
    d.rectangle((P(34, 39), P(36, 42)), fill=hexc("#f4ecd0"))
    d.point(P(35, 40), hexc("#c0392b"))
    # scarf
    d.rectangle((P(32, 25), P(44, 28)), fill=hexc("#a33438"))
    d.line((P(32, 28), P(44, 28)), fill=hexc("#6e1c24"))
    d.polygon([P(30, 27), P(25, 33), P(27, 36), P(31, 31)], fill=hexc("#a33438"), outline=OUT)

    # legs: wide archer stance. Back leg straight, front leg bent at the knee, both boots pointing at the target
    d.rectangle((P(30, 43), P(44, 48)), fill=PANT)
    d.line((P(30, 44), P(30, 48)), fill=OUT)
    d.line((P(44, 44), P(44, 48)), fill=OUT)
    limb(d, [P(34, 46), P(27, 53), P(21, 59)], 7, PANT, OUT, PANT_L)
    limb(d, [P(39, 46), P(47, 52), P(46, 59)], 7, PANT, OUT, PANT_L)
    d.line((P(30, 48), P(44, 48)), fill=PANT)
    d.line((P(41, 50), P(47, 54)), fill=hexc("#0c1024"))      # fold of the bent knee
    for x0, y0 in ((12, 59), (44, 60)):                        # boots with toes forward
        d.polygon([P(x0, y0 + 4), P(x0, y0 - 3), P(x0 + 7, y0 - 3), P(x0 + 9, y0), P(x0 + 11, y0 + 1), P(x0 + 11, y0 + 4)], fill=BOOT, outline=OUT)
        d.line((P(x0 + 1, y0 - 2), P(x0 + 6, y0 - 2)), fill=BOOT_L)
        d.line((P(x0 + 1, y0 + 3), P(x0 + 10, y0 + 3)), fill=BOOT_D)
        d.line((P(x0 + 1, y0), P(x0 + 6, y0)), fill=hexc("#a8743c"))

    # aim geometry: string hand at the chin, bow hand out front
    nock = P(45, 24)
    grip = P(60, 15)
    dx, dy = grip[0] - nock[0], grip[1] - nock[1]
    ln = math.hypot(dx, dy)
    dx, dy = dx / ln, dy / ln
    px_, py_ = -dy, dx          # perpendicular (pointing down-right)

    # bow arm: shoulder -> hand (outstretched)
    limb(d, [P(40, 30), P(50, 22), (grip[0] - 1, grip[1] + 1)], 5, BLUE, OUT, BLUE_L)
    # bow
    half, bulge = 21, 8
    prev = None
    pts = []
    for i in range(-16, 17):
        s = i / 16
        pts.append((grip[0] + px_ * s * half + dx * bulge * (1 - s * s) - dx * 2,
                    grip[1] + py_ * s * half + dy * bulge * (1 - s * s) - dy * 2))
    for a, b in zip(pts, pts[1:]):
        d.line((a, b), fill=BOW_D, width=4)
    for a, b in zip(pts, pts[1:]):
        d.line((a, b), fill=BOW, width=2)
    for a, b in zip(pts[2:15], pts[3:16]):
        d.line(((a[0] + 1, a[1] - 1), (b[0] + 1, b[1] - 1)), fill=BOW_L, width=1)
    top, bot = pts[0], pts[-1]
    d.rectangle((grip[0] - 2, grip[1] - 3, grip[0] + 1, grip[1] + 3), fill=hexc("#6a4a3a"))  # wrapped grip
    # string pulled back to the nock
    d.line((top, nock), fill=hexc("#f0ead8"))
    d.line((bot, nock), fill=hexc("#f0ead8"))
    # arrow: shaft, steel head, feathers
    head = (grip[0] + dx * 15, grip[1] + dy * 15)
    d.line((nock, head), fill=hexc("#d8b070"), width=1)
    d.line(((nock[0], nock[1] - 1), (head[0], head[1] - 1)), fill=hexc("#8a5a2a"))
    d.polygon([(head[0] + dx * 5, head[1] + dy * 5), (head[0] + px_ * 2, head[1] + py_ * 2), (head[0] - px_ * 2, head[1] - py_ * 2)], fill=hexc("#e8ecf8"), outline=hexc("#6a7288"))
    for off in (0, 3):
        for side in (-1, 1):
            d.line((nock[0] + dx * off, nock[1] + dy * off,
                    nock[0] + dx * off - dx * 3 + px_ * side * 3, nock[1] + dy * off - dy * 3 + py_ * side * 3),
                   fill=hexc("#ff7a6a") if off == 0 else hexc("#ffb0a0"))

    # drawing arm: shoulder -> elbow (back) -> hand at the chin, over the lower face
    limb(d, [P(35, 31), P(27, 30), (nock[0] - 1, nock[1] + 1)], 4, BLUE, OUT, BLUE_L)
    d.rectangle((nock[0] - 3, nock[1] - 2, nock[0] + 1, nock[1] + 2), fill=SKIN, outline=OUT)
    d.point((nock[0] - 1, nock[1] - 1), SKIN_D)
    d.rectangle((grip[0] - 3, grip[1] - 2, grip[0] + 1, grip[1] + 2), fill=SKIN, outline=OUT)   # bow hand
    return img, nock, grip


def fly_arrow(img, start, aim_to, t=0.62):
    d = ImageDraw.Draw(img)
    sx, sy = start
    ang = math.atan2(aim_to[1] - sy, aim_to[0] - sx)
    dx, dy = math.cos(ang), math.sin(ang)
    px_, py_ = -dy, dx
    ax, ay = sx + (aim_to[0] - sx) * t, sy + (aim_to[1] - sy) * t
    tail = (ax - dx * 22, ay - dy * 22)
    for k in range(1, 10):
        if k % 2 == 0:
            d.point((round(ax - dx * (22 + k * 3)), round(ay - dy * (22 + k * 3))), hexc("#9a90e0"))
    d.line((tail, (ax, ay)), fill=hexc("#d8b070"))
    d.polygon([(ax + dx * 5, ay + dy * 5), (ax + px_ * 2, ay + py_ * 2), (ax - px_ * 2, ay - py_ * 2)], fill=hexc("#e8ecf8"))
    for off in (0, 3):
        for side in (-1, 1):
            d.line((tail[0] + dx * off, tail[1] + dy * off,
                    tail[0] + dx * off - dx * 3 + px_ * side * 3, tail[1] + dy * off - dy * 3 + py_ * side * 3),
                   fill=hexc("#ff7a6a") if off == 0 else hexc("#ffb0a0"))


LEAF = ["..X.X..", ".XXXXX.", "XXXXXXX", ".XXXXX.", "XXXXXXX", ".XXXXX.", "..X.X.."]


def leaf_stamp(px, cx, cy, tones, lvl):
    cells = {(x - 3, y - 3) for y, row in enumerate(LEAF) for x, c in enumerate(row) if c == "X"}
    for (x, y) in cells:
        edge = any((x + a, y + b) not in cells for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        t = lvl
        if edge and (x < 0 or y > 0):
            t = max(0, lvl - 1)                       # shaded lower-left rim
        elif edge and x > 0 and y < 0:
            t = min(len(tones) - 1, lvl + 1)          # moonlit upper-right rim
        X, Y = cx + x, cy + y
        if 0 <= X < W and 0 <= Y < H:
            px[X, Y] = tones[t]


def bark_tree(d, trunk, t_d, t_m, t_l):
    """Twisting trunk with flared roots and bare branches under the crown."""
    def seg(a, b, w):
        limb(d, [a, b], w, t_m, t_d)
    seg((28, 199), (30, 176), 21)
    seg((30, 176), (27, 150), 16)
    seg((27, 150), (30, 126), 12)
    # flared roots
    for a, b in (((16, 199), (24, 186)), ((40, 199), (34, 186)), ((8, 199), (20, 190)), ((50, 199), (38, 190))):
        limb(d, [a, b], 4, t_m, t_d)
    # branches
    for pts, w in (([(28, 146), (16, 134), (4, 122)], 4), ([(30, 140), (44, 128), (60, 118)], 4),
                   ([(28, 130), (22, 112), (14, 98)], 3), ([(30, 128), (38, 110), (48, 98)], 3),
                   ([(16, 134), (8, 140)], 2), ([(44, 128), (56, 132)], 2)):
        limb(d, pts, w, t_m, t_d)
    # light stripes twisting along the trunk (moon from the right)
    for y in range(128, 197, 2):
        x = 29 + int(2 * math.sin(y / 9)) + (4 if y > 150 else 2)
        d.point((x, y), t_l)
        d.point((x + 1, y + 1), t_l)
    for y in range(132, 190, 7):
        x = 23 + int(2 * math.cos(y / 8))
        d.line((x, y, x + 2, y + 2), fill=t_d)


def panel_sprite(size=32):
    """9-slice frame for windows (options, credits, pause): the buttons' ornament around a flat dark fill."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    edge, inner, stud = hexc("#6a60a4"), hexc("#3a3270"), hexc("#a89ce0")
    d.rounded_rectangle((0, 0, size - 1, size - 1), 2, fill=hexc("#0b0820", 245))
    d.rectangle((2, 2, size - 3, size - 3), fill=hexc("#16123a", 245))
    d.rectangle((1, 1, size - 2, size - 2), outline=edge)
    d.rectangle((3, 3, size - 4, size - 4), outline=inner)
    for (cx, cy, sx, sy) in ((0, 0, 1, 1), (size - 1, 0, -1, 1), (0, size - 1, 1, -1), (size - 1, size - 1, -1, -1)):
        for ox, oy in ((0, 0), (1, 0), (0, 1)):
            d.point((cx + ox * sx, cy + oy * sy), (0, 0, 0, 0))
        d.point((cx + sx * 3, cy + sy * 3), stud)
        d.point((cx + sx * 2, cy + sy * 2), edge)
        d.point((cx + sx * 4, cy + sy * 1), edge)
        d.point((cx + sx * 1, cy + sy * 4), edge)
    return img


def grabber(selected=False):
    """Slider handle: a gold diamond."""
    img = Image.new("RGBA", (9, 13), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    fill = hexc("#f4d98a") if not selected else hexc("#fff3c4")
    d.polygon([(4, 0), (8, 6), (4, 12), (0, 6)], fill=fill, outline=hexc("#0b0820"))
    d.polygon([(4, 3), (6, 6), (4, 9), (2, 6)], fill=hexc("#a98a4c"))
    d.point((3, 4), hexc("#fffbe6"))
    return img


def toggle(on):
    """Switch for the full-screen option."""
    img = Image.new("RGBA", (24, 12), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((0, 0, 23, 11), 3, fill=hexc("#0b0820"))
    d.rounded_rectangle((1, 1, 22, 10), 2, fill=hexc("#3b2f72") if on else hexc("#1c1740"), outline=hexc("#f4d98a") if on else hexc("#4a4290"))
    x = 13 if on else 3
    d.rectangle((x, 3, x + 7, 8), fill=hexc("#f4d98a") if on else hexc("#8e82d6"), outline=hexc("#0b0820"))
    d.line((x + 1, 4, x + 6, 4), fill=hexc("#fff3c4") if on else hexc("#c9c0f4"))
    return img


def shot_arrow():
    """The arrow that flies at the bat (horizontal; the menu rotates it)."""
    img = Image.new("RGBA", (34, 7), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for k in range(1, 5):
        if k % 2 == 0:
            d.point((2 - k + 4, 3), hexc("#9a90e0"))
    d.line((6, 3, 28, 3), fill=hexc("#d8b070"))
    d.line((6, 2, 28, 2), fill=hexc("#8a5a2a"))
    d.polygon([(33, 3), (28, 0), (28, 6)], fill=hexc("#e8ecf8"), outline=hexc("#6a7288"))
    for off in (0, 3):
        d.line((6 + off, 3, 3 + off, 0), fill=hexc("#ff7a6a") if off == 0 else hexc("#ffb0a0"))
        d.line((6 + off, 3, 3 + off, 6), fill=hexc("#ff7a6a") if off == 0 else hexc("#ffb0a0"))
    return img


def bat_halo():
    img = Image.new("RGBA", (120, 80), (0, 0, 0, 0))
    gp = img.load()
    for yy in range(80):
        for xx in range(120):
            dd = math.hypot((xx - 60) / 1.5, yy - 40) / 40
            if dd < 1 and dith(xx, yy, (1 - dd) ** 1.5 * 0.55):
                gp[xx, yy] = (255, 230, 170, 60)
    return img


def export_ui_kit():
    panel_sprite().save(os.path.join(HERE, "panel.png"))
    grabber().save(os.path.join(HERE, "grabber.png"))
    grabber(True).save(os.path.join(HERE, "grabber_hover.png"))
    toggle(True).save(os.path.join(HERE, "toggle_on.png"))
    toggle(False).save(os.path.join(HERE, "toggle_off.png"))
    shot_arrow().save(os.path.join(HERE, "shot.png"))
    bat_halo().save(os.path.join(HERE, "bat_halo.png"))


if __name__ == "__main__":
    main()
