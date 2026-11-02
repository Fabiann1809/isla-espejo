"""Brings the temple enemies' art (island 3) into the game's scale.

The source is the team's bestiary pack (`Isla_Espejo_Nivel3_10_Enemigos_FIEL_Godot`): per enemy, one
strip per animation facing right, 128x128 px per frame. Those right-facing strips are kept as the
source next to the game's art (`assets/sprites/<id>/source/`), and this script turns them into the
strips the game uses: each frame scaled down (area average, then a hard alpha edge so it stays pixel
art) into `assets/sprites/<id>/<id>_<animation>.png`.

The second pack (`Isla_Espejo_14_Enemigos_Godot`, drawn animations, feet on row 112) has its strips
in `<pack>/<id>/spritesheets/<animation>.png`, with `move` for the walk.

    python tools/make_temple_enemy_art.py                          # from the kept sources
    python tools/make_temple_enemy_art.py <pack folder>            # first copy the first pack
    python tools/make_temple_enemy_art.py --second <pack folder>   # first copy the second pack
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
    # The second pack draws its figures smaller inside the cell: 0.75 brings them to Nico's size.
    "arana_talladora": 0.75,
    "baldosa_hambrienta": 0.5,
    "campanero_bronce": 0.75,
    "custodio_sello": 0.75,
    "forjador_condenado": 0.75,
    "manos_abismo": 0.75,
    "mascara_parasita": 0.5,
    "monje_sin_rostro": 0.75,
    "nucleo_cria": 0.75,
    "ojo_sol": 0.75,
    "oraculo_ceniza": 0.75,
    "relojero_trampas": 0.75,
    "rueda_devoradora": 0.75,
    "vasija_poseida": 0.75,
}
SECOND_PACK = [
    "arana_talladora", "baldosa_hambrienta", "campanero_bronce", "custodio_sello",
    "forjador_condenado", "manos_abismo", "mascara_parasita", "monje_sin_rostro", "nucleo_cria",
    "ojo_sol", "oraculo_ceniza", "relojero_trampas", "rueda_devoradora", "vasija_poseida",
]
## Pixels at least this opaque after scaling are kept (fully opaque); the rest become transparent.
ALPHA_CUT = 110
## Animations whose frames carry scraps of other poses (the pack cut them from a sheet): only the
## frame's biggest piece and what touches its box are kept. Elsewhere separate pieces are meant
## (the acolyte's flame, sparks, dust), so nothing is cut.
CLEAN_ALL = ["idle", "walk", "attack", "special", "hurt"]
SCRAPPY = {
    "manta_hollin": CLEAN_ALL,
    "salamandra_cristal": CLEAN_ALL,
    "gusano_puentes": CLEAN_ALL,
    "caracol_escoria": CLEAN_ALL,
    "carnero_basalto": CLEAN_ALL,
}
## The pack's idle and walk alternate two or three unrelated drawings (not steps), so the figure pops
## between poses. Until real cycles are drawn, both are rebuilt from the first idle drawing with a
## small bob (source px per frame; 2 source px = 1 game px). Enemies in REAL_ART have properly drawn
## animations (the second pack: centered, feet on row 108) and keep them as they are.
REAL_ART = {"carcelero_cadenas", "centinela_obsidiana"} | set(SECOND_PACK)
STEADY = {
    "idle": [0, 0, 0, -2, -2, -2],
    "walk": [0, -2, -2, 0, 0, -2, -2, 0],
}


## Specials that flip between unrelated drawings: only these frames (the move's own pose) are used,
## repeated to the strip's length. Empty these when the pack has real animations.
HELD_FRAMES = {
    ("carnero_basalto", "special"): [1, 2, 6],
    ("salamandra_cristal", "special"): [0, 3, 4, 5, 7],
    ("gusano_puentes", "special"): [1, 2],
}


def copy_sources(pack):
    for enemy in ENEMIES:
        target = os.path.join(ROOT, enemy, "source")
        os.makedirs(target, exist_ok=True)
        for anim in ANIMATIONS:
            shutil.copyfile(os.path.join(pack, enemy, "sprites", "%s_right.png" % anim),
                            os.path.join(target, "%s_right.png" % anim))


def copy_second_pack(pack):
    for enemy in SECOND_PACK:
        target = os.path.join(ROOT, enemy, "source")
        os.makedirs(target, exist_ok=True)
        for anim in ANIMATIONS:
            name = "move" if anim == "walk" else anim
            shutil.copyfile(os.path.join(pack, enemy, "spritesheets", "%s.png" % name),
                            os.path.join(target, "%s_right.png" % anim))


def keep_main_piece(frame):
    """Clears every piece of the frame but the biggest and those touching its box."""
    width, height = frame.size
    pixels = frame.load()
    seen = [[False] * width for _ in range(height)]
    pieces = []
    for sy in range(height):
        for sx in range(width):
            if seen[sy][sx] or pixels[sx, sy][3] == 0:
                continue
            piece = []
            stack = [(sx, sy)]
            seen[sy][sx] = True
            while stack:
                x, y = stack.pop()
                piece.append((x, y))
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < width and 0 <= ny < height and not seen[ny][nx] and pixels[nx, ny][3] > 0:
                            seen[ny][nx] = True
                            stack.append((nx, ny))
            pieces.append(piece)
    if not pieces:
        return 0
    main = max(pieces, key=len)
    x0 = min(x for x, _ in main)
    x1 = max(x for x, _ in main)
    y0 = min(y for _, y in main)
    y1 = max(y for _, y in main)
    dropped = 0
    for piece in pieces:
        if piece is main or any(x0 <= x <= x1 and y0 <= y <= y1 for x, y in piece):
            continue
        for x, y in piece:
            pixels[x, y] = (0, 0, 0, 0)
        dropped += 1
    return dropped


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


def steady_strip(enemy, bob):
    """A strip of the first idle drawing, moved up and down by `bob` (one offset per frame)."""
    idle = Image.open(os.path.join(ROOT, enemy, "source", "idle_right.png")).convert("RGBA")
    pose = idle.crop((0, 0, SOURCE_CELL, SOURCE_CELL))
    if "idle" in SCRAPPY.get(enemy, []):
        keep_main_piece(pose)
    strip = Image.new("RGBA", (SOURCE_CELL * len(bob), SOURCE_CELL), (0, 0, 0, 0))
    for i, offset in enumerate(bob):
        strip.paste(pose, (i * SOURCE_CELL, offset), pose)
    return strip


def held_strip(strip, frames):
    """The strip with only `frames` (indices), repeated in order to its original length."""
    count = strip.width // SOURCE_CELL
    held = Image.new("RGBA", strip.size, (0, 0, 0, 0))
    for i in range(count):
        index = frames[i % len(frames)]
        held.paste(strip.crop((index * SOURCE_CELL, 0, (index + 1) * SOURCE_CELL, SOURCE_CELL)), (i * SOURCE_CELL, 0))
    return held


def build(enemy, scale):
    cell = int(round(SOURCE_CELL * scale))
    scraps = [0]
    for anim in ANIMATIONS:
        strip = Image.open(os.path.join(ROOT, enemy, "source", "%s_right.png" % anim)).convert("RGBA")
        if anim in STEADY and enemy not in REAL_ART:
            strip = steady_strip(enemy, STEADY[anim])
        elif (enemy, anim) in HELD_FRAMES:
            strip = held_strip(strip, HELD_FRAMES[(enemy, anim)])
        count = strip.width // SOURCE_CELL
        # Average in premultiplied space so transparent pixels do not bleed black into the edges.
        out = Image.new("RGBA", (cell * count, cell), (0, 0, 0, 0))
        for i in range(count):
            frame = strip.crop((i * SOURCE_CELL, 0, (i + 1) * SOURCE_CELL, SOURCE_CELL))
            if anim in SCRAPPY.get(enemy, []):
                scraps[0] += keep_main_piece(frame)
            premultiplied = Image.new("RGBA", frame.size)
            src = frame.load()
            dst = premultiplied.load()
            for y in range(frame.height):
                for x in range(frame.width):
                    r, g, b, a = src[x, y]
                    dst[x, y] = (r * a // 255, g * a // 255, b * a // 255, a)
            out.paste(scale_frame(premultiplied, cell), (i * cell, 0))
        out.save(os.path.join(ROOT, enemy, "%s_%s.png" % (enemy, anim)))
    return cell, scraps[0]


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "--second":
        copy_second_pack(sys.argv[2])
    elif len(sys.argv) > 1:
        copy_sources(sys.argv[1])
    for enemy, scale in ENEMIES.items():
        print(enemy, build(enemy, scale))
