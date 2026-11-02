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
    python tools/make_temple_enemy_art.py --beasts <pack folder>   # first copy the volcanic beasts

The volcanic beasts pack (`Bestias_Volcanicas_5_Enemigos_Godot`) redraws five of the first pack's
enemies (drawn animations, feet on row 108, enlarged so the figure fills the cell): its strips are in
`<pack>/<Folder>/spritesheets/<animation>.png`.
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
    # Their figures are drawn 75-90 px tall: scaled to about Nico's height (28 px); the sentinel, the
    # worm and the executioner (a huge enemy) stay bigger.
    "centinela_obsidiana": 0.5,
    "carcelero_cadenas": 0.375,
    "acolito_brasero": 0.375,
    "verdugo_piedra": 0.625,
    "duelista_maldito": 0.375,
    "salamandra_cristal": 0.375,
    "gusano_puentes": 0.5,
    # The volcanic beasts are enlarged x2 in their pack (2x2 pixel blocks).
    "caracol_escoria": 0.25,
    "carnero_basalto": 0.3125,
    "manta_hollin": 0.3125,
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
BEASTS = {
    "salamandra_cristal": "Salamandra_de_Cristal",
    "gusano_puentes": "Gusano_de_los_Puentes",
    "caracol_escoria": "Caracol_de_Escoria",
    "carnero_basalto": "Carnero_de_Basalto",
    "manta_hollin": "Manta_de_Hollin",
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
## (The brood core's death: drips and debris of other frames float above its rubble.)
SCRAPPY = {"nucleo_cria": ["death"]}
## The pack's idle and walk alternate two or three unrelated drawings (not steps), so the figure pops
## between poses. Until real cycles are drawn, both are rebuilt from the first idle drawing with a
## small bob (source px per frame; 2 source px = 1 game px). Enemies in REAL_ART have properly drawn
## animations (the second pack: centered, feet on row 108) and keep them as they are.
REAL_ART = {"carcelero_cadenas", "centinela_obsidiana", "verdugo_piedra", "duelista_maldito",
            "acolito_brasero"} | set(SECOND_PACK) | set(BEASTS)
STEADY = {
    "idle": [0, 0, 0, -2, -2, -2],
    "walk": [0, -2, -2, 0, 0, -2, -2, 0],
}


## Specials that flip between unrelated drawings: only these frames (the move's own pose) are used,
## repeated to the strip's length. Empty these when the pack has real animations.
HELD_FRAMES = {
    ("manta_hollin", "special"): [0, 1, 2, 6],
    ("carnero_basalto", "special"): [0, 1, 2, 5, 6, 7],
}
## Specials drawn as an effect without the creature: the strip of another animation stands in for
## them. (None left: the salamander's second version draws its own.)
STRIP_FROM = {}
## The second pack cut some frames badly from its sheets: frames where only the effect is left (the
## creature gone), frames clipped to a rectangle, a different drawing (the oracle's first idle has no
## staff) or another creature (the sun eye's death ends on a spider). Only the listed frames are used,
## in order: an index into the animation's own strip, or (animation, index) for a frame of another.
## The brood core's idle, walk, hurt and death strips cut its hive in half: its special's whole hive
## stands in for them.
CORE = ("special", 0)
FRAMES = {
    ("arana_talladora", "special"): [0, 1, 2, 3, 4],
    ("baldosa_hambrienta", "idle"): [0, 1, 2, 3],
    ("baldosa_hambrienta", "attack"): [0, 1, 2, 4, 5, 6],
    ("baldosa_hambrienta", "death"): [0, 2, 3, 4, 5],
    ("campanero_bronce", "special"): [0, 1, 2, 3, 4],
    ("custodio_sello", "special"): [0, 1, 2, 3, 5],
    ("forjador_condenado", "special"): [0, 1, 2, 3],
    ("mascara_parasita", "special"): [0, 1, 2, 3, 6],
    ("monje_sin_rostro", "attack"): [0, 1, 2, 3, 4, 5],
    ("nucleo_cria", "idle"): [CORE],
    ("nucleo_cria", "walk"): [CORE],
    ("nucleo_cria", "attack"): [("special", i) for i in range(6)],
    ("nucleo_cria", "special"): [0, 1, 2, 3, 4, 5],
    ("nucleo_cria", "hurt"): [CORE, CORE, CORE, CORE],
    ("nucleo_cria", "death"): [CORE, 4, 5],
    ("ojo_sol", "attack"): [0, 1, 2, 3, 4, 5, 6],
    ("ojo_sol", "special"): [0, 1, 2, 3, 4, 5, 6],
    ("ojo_sol", "death"): [0, 1, 2],
    ("oraculo_ceniza", "idle"): [1, 2, 3, 4, 5],
    ("oraculo_ceniza", "attack"): [0, 1, 2, 3, 4, 5],
    ("oraculo_ceniza", "special"): [0, 1, 2, 3, 4, 5],
    ("relojero_trampas", "special"): [0, 1, 2, 3],
    # Its last two frames are the spirit alone: they go to their own strip (SPIRIT).
    ("vasija_poseida", "attack"): [0, 1, 2, 3, 4, 5],
}
## The fire spirit that leaps out of the vase: cut from the vase's attack into its own strip,
## `vasija_poseida_spirit.png` (tools/make_vasija_poseida.gd makes the spirit's animations from it).
SPIRIT = ("vasija_poseida", "attack", [6, 7])
## The second pack's frames carry thin strips of the frame drawn above them in the sheet: separate
## pieces at most this tall lying wholly above the figure are cleared.
SCRAP_HEIGHT = 8
## Strips whose scrap touches the figure (the clockmaker's feet from another strip sit on its head):
## every row above this one is cleared.
CUT_ABOVE = {
    ("relojero_trampas", "walk"): 81,
    ("relojero_trampas", "attack"): 77,
    ("relojero_trampas", "death"): 79,
}


def copy_sources(pack):
    for enemy in ENEMIES:
        target = os.path.join(ROOT, enemy, "source")
        os.makedirs(target, exist_ok=True)
        for anim in ANIMATIONS:
            shutil.copyfile(os.path.join(pack, enemy, "sprites", "%s_right.png" % anim),
                            os.path.join(target, "%s_right.png" % anim))


def copy_beasts(pack):
    for enemy, folder in BEASTS.items():
        target = os.path.join(ROOT, enemy, "source")
        for anim in ANIMATIONS:
            shutil.copyfile(os.path.join(pack, folder, "spritesheets", "%s.png" % anim),
                            os.path.join(target, "%s_right.png" % anim))


def copy_second_pack(pack):
    for enemy in SECOND_PACK:
        target = os.path.join(ROOT, enemy, "source")
        os.makedirs(target, exist_ok=True)
        for anim in ANIMATIONS:
            name = "move" if anim == "walk" else anim
            shutil.copyfile(os.path.join(pack, enemy, "spritesheets", "%s.png" % name),
                            os.path.join(target, "%s_right.png" % anim))


def pieces_of(frame):
    """The frame's separate pieces (8-connected opaque pixels), each a list of (x, y)."""
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
    return pieces


def keep_main_piece(frame):
    """Clears every piece of the frame but the biggest and those touching its box."""
    pieces = pieces_of(frame)
    if not pieces:
        return 0
    main = max(pieces, key=len)
    x0 = min(x for x, _ in main)
    x1 = max(x for x, _ in main)
    y0 = min(y for _, y in main)
    y1 = max(y for _, y in main)
    pixels = frame.load()
    dropped = 0
    for piece in pieces:
        if piece is main or any(x0 <= x <= x1 and y0 <= y <= y1 for x, y in piece):
            continue
        for x, y in piece:
            pixels[x, y] = (0, 0, 0, 0)
        dropped += 1
    return dropped


def drop_scrap_strips(frame):
    """Clears the thin pieces (SCRAP_HEIGHT) lying wholly above the frame's biggest piece."""
    pieces = pieces_of(frame)
    if not pieces:
        return 0
    main = max(pieces, key=len)
    top = min(y for _, y in main)
    pixels = frame.load()
    dropped = 0
    for piece in pieces:
        ys = [y for _, y in piece]
        if piece is main or max(ys) >= top or max(ys) - min(ys) + 1 > SCRAP_HEIGHT:
            continue
        for x, y in piece:
            pixels[x, y] = (0, 0, 0, 0)
        dropped += 1
    return dropped


def picked_strip(enemy, anim, frames):
    """A strip of the listed frames of the enemy's sources (see FRAMES)."""
    strip = Image.new("RGBA", (SOURCE_CELL * len(frames), SOURCE_CELL), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        source, index = frame if isinstance(frame, tuple) else (anim, frame)
        sheet = Image.open(os.path.join(ROOT, enemy, "source", "%s_right.png" % source)).convert("RGBA")
        strip.paste(sheet.crop((index * SOURCE_CELL, 0, (index + 1) * SOURCE_CELL, SOURCE_CELL)), (i * SOURCE_CELL, 0))
    return strip


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


def scaled_strip(enemy, anim, strip, cell, scraps):
    """The strip with each frame cleaned and scaled to `cell`; counts the pieces cleared in `scraps`."""
    count = strip.width // SOURCE_CELL
    # Average in premultiplied space so transparent pixels do not bleed black into the edges.
    out = Image.new("RGBA", (cell * count, cell), (0, 0, 0, 0))
    for i in range(count):
        frame = strip.crop((i * SOURCE_CELL, 0, (i + 1) * SOURCE_CELL, SOURCE_CELL))
        if anim in SCRAPPY.get(enemy, []):
            scraps[0] += keep_main_piece(frame)
        if enemy in SECOND_PACK:
            scraps[0] += drop_scrap_strips(frame)
        if (enemy, anim) in CUT_ABOVE:
            frame.paste((0, 0, 0, 0), (0, 0, SOURCE_CELL, CUT_ABOVE[(enemy, anim)]))
        premultiplied = Image.new("RGBA", frame.size)
        src = frame.load()
        dst = premultiplied.load()
        for y in range(frame.height):
            for x in range(frame.width):
                r, g, b, a = src[x, y]
                dst[x, y] = (r * a // 255, g * a // 255, b * a // 255, a)
        out.paste(scale_frame(premultiplied, cell), (i * cell, 0))
    return out


def build(enemy, scale):
    cell = int(round(SOURCE_CELL * scale))
    scraps = [0]
    for anim in ANIMATIONS:
        source = STRIP_FROM.get((enemy, anim), anim)
        strip = Image.open(os.path.join(ROOT, enemy, "source", "%s_right.png" % source)).convert("RGBA")
        if anim in STEADY and enemy not in REAL_ART:
            strip = steady_strip(enemy, STEADY[anim])
        elif (enemy, anim) in HELD_FRAMES:
            strip = held_strip(strip, HELD_FRAMES[(enemy, anim)])
        elif (enemy, anim) in FRAMES:
            strip = picked_strip(enemy, anim, FRAMES[(enemy, anim)])
        scaled_strip(enemy, anim, strip, cell, scraps).save(os.path.join(ROOT, enemy, "%s_%s.png" % (enemy, anim)))
    if enemy == SPIRIT[0]:
        strip = picked_strip(enemy, SPIRIT[1], SPIRIT[2])
        scaled_strip(enemy, SPIRIT[1], strip, cell, scraps).save(os.path.join(ROOT, enemy, "%s_spirit.png" % enemy))
    return cell, scraps[0]


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[1] == "--second":
        copy_second_pack(sys.argv[2])
    elif len(sys.argv) > 2 and sys.argv[1] == "--beasts":
        copy_beasts(sys.argv[2])
    elif len(sys.argv) > 1:
        copy_sources(sys.argv[1])
    for enemy, scale in ENEMIES.items():
        print(enemy, build(enemy, scale))
