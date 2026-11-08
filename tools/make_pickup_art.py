"""Art of the two pickups that were drawn with circles: the heart and the arrow orb. Run from the project root:
    python tools/make_pickup_art.py
Writes assets/sprites/pickups/heart.png (11x10) and arrow_orb.png (13x13). The gold coin is NOT touched: it keeps
the drawn design it already has (the HUD's coin copies it). Same look as the coin: a dark rim, the color, a highlight."""
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "sprites", "pickups")
OUTLINE = (40, 8, 20, 255)


def heart():
    rows = [
        ".OOO...OOO.",
        "OrRRO.ORRrO",
        "ORwRRORRRrO",
        "ORRRRRRRRrO",
        "ORRRRRRRrrO",
        ".ORRRRRRrO.",
        "..ORRRRrO..",
        "...ORRrO...",
        "....OrO....",
        ".....O.....",
    ]
    palette = {"O": OUTLINE, "R": (232, 56, 74, 255), "r": (170, 28, 52, 255), "w": (255, 214, 220, 255)}
    img = Image.new("RGBA", (11, 10), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in palette:
                img.putpixel((x, y), palette[ch])
    return img


def arrow_orb():
    size = 13
    cx = cy = 6
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    rim, body, light = (14, 70, 96, 255), (89, 204, 242, 255), (200, 244, 255, 255)
    for y in range(size):
        for x in range(size):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if d <= 6.2:
                img.putpixel((x, y), rim)
            if d <= 5.0:
                img.putpixel((x, y), body if (x - cx) + (y - cy) < 4 else (60, 160, 206, 255))
    for x, y in ((3, 3), (4, 3), (3, 4)):
        img.putpixel((x, y), light)
    # three small arrows flying up and to the right, as the buff shoots them
    for dx, dy in ((0, 0), (1, 2), (-1, 2)):
        for k in range(5):
            img.putpixel((3 + k + dx + (2 if dy else 0) - (2 if dy else 0), 8 - k + dy - 1), (255, 255, 255, 255))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    heart().save(os.path.join(OUT, "heart.png"))
    arrow_orb().save(os.path.join(OUT, "arrow_orb.png"))
    sheet = Image.new("RGBA", (40, 18), (40, 70, 40, 255))
    sheet.alpha_composite(heart(), (3, 4))
    sheet.alpha_composite(arrow_orb(), (22, 2))
    sheet.resize((sheet.width * 8, sheet.height * 8), Image.NEAREST).save(os.path.join(OUT, "preview.png"))
    print("ok")


if __name__ == "__main__":
    main()
