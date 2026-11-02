"""Brings the temple enemies' art (island 3) into the game's scale.

The source is the team's bestiary pack (`Isla_Espejo_Nivel3_10_Enemigos_FIEL_Godot`): per enemy, one
strip per animation facing right, 128x128 px per frame. Those right-facing strips are kept as the
source next to the game's art (`assets/sprites/<id>/source/`), and this script turns them into the
strips the game uses: each frame scaled down (area average, then a hard alpha edge so it stays pixel
art) into `assets/sprites/<id>/<id>_<animation>.png`.

    python tools/make_temple_enemy_art.py                 # from the kept sources
    python tools/make_temple_enemy_art.py <pack folder>   # first copy the sources from the pack
Needs Pillow.
"""
import os
import shutil
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
SOURCE_CELL = 128
ANIMATIONS = ["idle", "walk", "attack", "special", "hurt", "death"]
## Enemy id -> scale of the art (0.5 = a 64 px cell, about Nico's size; the Verdugo is huge).
ENEMIES = {
    "centinela_obsidiana": 0.5,
    "carcelero_cadenas": 0.5,
    "acolito_brasero": 0.5,
    "verdugo_piedra": 0.625,
    "duelista_maldito": 0.5,
    "salamandra_cristal": 0.5,
    "gusano_puentes": 0.5,
    "caracol_escoria": 0.5,
    "carnero_basalto": 0.5,
    "manta_hollin": 0.5,
}
## Pixels at least this opaque after scaling are kept (fully opaque); the rest become transparent.
ALPHA_CUT = 110


def copy_sources(pack):
    for enemy in ENEMIES:
        target = os.path.join(ROOT, enemy, "source")
        os.makedirs(target, exist_ok=True)
        for anim in ANIMATIONS:
            shutil.copyfile(os.path.join(pack, enemy, "sprites", "%s_right.png" % anim),
                            os.path.join(target, "%s_right.png" % anim))


def scale_frame(frame, cell):
    small = frame.resize((cell, cell), Image.BOX)
    pixels = small.load()
    for y in range(cell):
        for x in range(cell):
            r, g, b, a = pixels[x, y]
            if a < ALPHA_CUT:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                # Undo the darkening of edge pixels averaged with transparent ones.
                k = 255.0 / a
                pixels[x, y] = (min(255, int(r * k)), min(255, int(g * k)), min(255, int(b * k)), 255)
    return small


def build(enemy, scale):
    cell = int(round(SOURCE_CELL * scale))
    for anim in ANIMATIONS:
        strip = Image.open(os.path.join(ROOT, enemy, "source", "%s_right.png" % anim)).convert("RGBA")
        count = strip.width // SOURCE_CELL
        # Average in premultiplied space so transparent pixels do not bleed black into the edges.
        out = Image.new("RGBA", (cell * count, cell), (0, 0, 0, 0))
        for i in range(count):
            frame = strip.crop((i * SOURCE_CELL, 0, (i + 1) * SOURCE_CELL, SOURCE_CELL))
            premultiplied = Image.new("RGBA", frame.size)
            src = frame.load()
            dst = premultiplied.load()
            for y in range(frame.height):
                for x in range(frame.width):
                    r, g, b, a = src[x, y]
                    dst[x, y] = (r * a // 255, g * a // 255, b * a // 255, a)
            out.paste(scale_frame(premultiplied, cell), (i * cell, 0))
        out.save(os.path.join(ROOT, enemy, "%s_%s.png" % (enemy, anim)))
    return cell


if __name__ == "__main__":
    if len(sys.argv) > 1:
        copy_sources(sys.argv[1])
    for enemy, scale in ENEMIES.items():
        print(enemy, build(enemy, scale))
