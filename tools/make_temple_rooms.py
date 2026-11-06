"""Generates the Templo del Eclipse room scenes in scenes/levels/rooms/temple/.
Run from the repo root: python tools/make_temple_rooms.py [--show]

Each room is a scene inheriting room_base.tscn with a TempleShape node (the island's plan as 18 lines
of 30 characters, see scripts/world/temple_plan.gd for the alphabet: lava, floors of three heights,
stairs, bridges, masonry, pillar slots), TempleProp nodes (pillars, statues, braziers, urns, vines,
lava falls, geysers...) and the spawn markers. The plans are drawn by hand below, as islands of stone
over lava with real height tiers, bridges and rooms reached only by one bridge; the props are composed
(a focal piece, mirrored pairs, moss and vines on the cliffs), never scattered.

The design rules are the game's own: this script never ports them. It hands every plan to Godot
(tools/validate_temple_plans.gd, which runs TemplePlan.validate with the room's surge stages and
answers which cells are spawn_ok and which are reached at each level) and refuses to write a room
whose plan has a problem, whose solid prop stands off the floor of its level, on a lane or on a cell
nobody reaches, or whose markers are not on spawn_ok cells. GODOT names the executable (or `godot`
in the PATH). `--show` prints every plan.

Coordinates are in TILES (16 px). A prop's cell is the one its foot stands in; its `level` is the
height of that cell. The center cross (columns 13..16, rows 7..10) holds no solid prop of the base
height, so every door keeps a straight way to the middle (the boss room's face gate, on the north
lane the boss cell never opens, is the one exception).
"""
import json
import math
import os
import random
import shutil
import subprocess
import sys
import tempfile
import zlib

OUT = "scenes/levels/rooms/temple"
SHOW = "--show" in sys.argv
TILE = 16
COLUMNS, ROWS = 30, 18
LANE_COLUMNS = range(13, 17)
LANE_ROWS = range(7, 11)
FLOOR_HEIGHT = {".": 0, "1": 1, "2": 2}
STAIRS = "^><v"
DECKS = "=|bB"

# TempleProp.Kind (keep in sync with scripts/world/temple_prop.gd).
(PILLAR_CARVED, PILLAR_BLOCK, COLUMN_LOW, COLUMN_BROKEN, STATUE_GUARDIAN, BRAZIER, BRAZIER_PEDESTAL,
 TORCH_WALL, URN, VASE, BARREL, RUBBLE, ROCK_SMOKING, PLANT, VINES, BANNER, LAVA_FALL, GEYSER,
 FACE_GATE, ALTAR_RUNE, EMBER_VENT, SPIKES, SAW, ROLLING_ROCK) = range(24)
STRIP = {
    PILLAR_CARVED: "pillar_carved", PILLAR_BLOCK: "pillar_block", COLUMN_LOW: "column_low",
    COLUMN_BROKEN: "column_broken", STATUE_GUARDIAN: "statue_guardian", BRAZIER: "brazier",
    BRAZIER_PEDESTAL: "brazier_pedestal", TORCH_WALL: "torch_wall", URN: "urn", VASE: "vase",
    BARREL: "barrel", RUBBLE: "rubble", ROCK_SMOKING: "rock_smoking", PLANT: "plant", VINES: "vines",
    BANNER: "banner", LAVA_FALL: "lava_fall", GEYSER: "geyser", FACE_GATE: "face_gate",
    ALTAR_RUNE: "altar_rune", EMBER_VENT: "ember_vent", SPIKES: "spikes", SAW: "saw", ROLLING_ROCK: "rolling_rock",
}
SOLID = {PILLAR_CARVED, PILLAR_BLOCK, COLUMN_LOW, COLUMN_BROKEN, STATUE_GUARDIAN, BRAZIER_PEDESTAL, URN,
         BARREL, ROCK_SMOKING, FACE_GATE, ALTAR_RUNE}
# Kinds that hang from a cliff or rise from the lava: their foot is the bottom edge of their cell.
HANGING = {VINES, TORCH_WALL, LAVA_FALL}
# Kinds that may stand on a lava cell (they are the lava's own: vents, geysers, falls, smoking rocks, vines on a face).
ON_LAVA = {VINES, LAVA_FALL, GEYSER, EMBER_VENT, ROCK_SMOKING, TORCH_WALL}
# Traps: they always hurt (through a Hitbox, on a rhythm), never block, and may lie on a lane, since
# the lane stays walkable between their beats. A saw's track and a rock's lane run `track` cells from
# the prop's cell along `direction`; every cell of it is kept free of other props and spawns.
TRAPS = {SPIKES, SAW, ROLLING_ROCK}

with open("assets/sprites/temple_props/props.json", encoding="utf-8") as f:
    PROPS_META = json.load(f)


def mirror(x, width=1):
    """The column that mirrors `x` across the room's vertical axis (a prop `width` cells wide)."""
    return COLUMNS - 1 - x - (width - 1)


class Room:
    def __init__(self, filename, node_name, rows, surge_stages=0):
        self.filename, self.node_name = filename, node_name
        self.rows = rows
        self.surge_stages = surge_stages
        self.rng = random.Random(zlib.crc32(filename.encode()))
        self.props = []
        self.spawns = {}        # container -> list of px points
        self.wants = {}         # container -> (count, options) picked from spawn_ok cells
        self.player_spawn = None
        self.result = None
        self.boss = False
        assert len(rows) == ROWS, f"{filename}: {len(rows)} rows"
        for y, row in enumerate(rows):
            assert len(row) == COLUMNS, f"{filename}: row {y} has {len(row)} characters: {row!r}"

    # --- reading the plan ------------------------------------------------------------------------------------
    def at(self, x, y):
        return self.rows[y][x] if 0 <= x < COLUMNS and 0 <= y < ROWS else "#"

    def inside(self, x, y):
        return 1 <= x <= COLUMNS - 2 and 1 <= y <= ROWS - 2

    def height(self, x, y):
        return self.result["heights"][y][x]

    @property
    def base(self):
        return self.result["base_height"]

    def is_lane(self, x, y):
        return x in LANE_COLUMNS or y in LANE_ROWS

    def face_into_lava_cells(self):
        """Lava cells right under a floor cell: the island's cliff drops into the lava there."""
        return [(x, y) for y in range(1, ROWS - 1) for x in range(1, COLUMNS - 1)
                if self.at(x, y) == "~" and self.at(x, y - 1) in FLOOR_HEIGHT]

    def face_cells(self, drop_to=None):
        """Floor cells right under a higher floor cell (the cliff face of a platform)."""
        cells = []
        for y in range(1, ROWS - 1):
            for x in range(1, COLUMNS - 1):
                c, n = self.at(x, y), self.at(x, y - 1)
                if c in FLOOR_HEIGHT and n in FLOOR_HEIGHT and FLOOR_HEIGHT[n] > FLOOR_HEIGHT[c]:
                    if drop_to is None or FLOOR_HEIGHT[c] == drop_to:
                        cells.append((x, y))
        return cells

    # --- props -----------------------------------------------------------------------------------------------
    def prop(self, kind, x, y, flip=False, hazard=False, level=None, track=None, direction=None):
        c = self.at(x, y)
        if level is None:
            level = FLOOR_HEIGHT.get(c, 0)
        self.props.append({"kind": kind, "cell": (x, y), "flip": flip, "hazard": hazard, "level": level,
                           "track": track, "direction": direction})
        return self.props[-1]

    def trap(self, kind, x, y, track=None, direction=(1, 0)):
        """A trap at (x, y): spikes in that cell, a saw whose track or a rock whose lane starts there
        and runs `track` cells (the strip's default when None) toward `direction`."""
        return self.prop(kind, x, y, track=track, direction=direction if kind != SPIKES else None)

    def track_cells(self, prop):
        """The cells a trap covers: its own, plus its track or lane."""
        x, y = prop["cell"]
        if prop["kind"] == SPIKES:
            return [(x, y)]
        track = prop["track"] or PROPS_META[STRIP[prop["kind"]]].get("track_cells", 1)
        dx, dy = prop["direction"] or (1, 0)
        return [(x + dx * i, y + dy * i) for i in range(track)]

    def pair(self, kind, x, y, width=1, hazard=False):
        """The same prop twice, mirrored across the vertical axis, the second one facing the first."""
        self.prop(kind, x, y, hazard=hazard)
        self.prop(kind, mirror(x, width), y, flip=True, hazard=hazard)

    def vines(self, count, among=None):
        """Vines hanging down cliff faces, spread by the room's seed (never two on the same face)."""
        cells = list(among if among is not None else self.face_into_lava_cells() + self.face_cells())
        taken = {p["cell"] for p in self.props}
        cells = [c for c in cells if c not in taken and not self.is_lane(*c)]
        self.rng.shuffle(cells)
        chosen = []
        for cell in cells:
            if len(chosen) == count:
                break
            if all(abs(cell[0] - o[0]) > 2 or cell[1] != o[1] for o in chosen):
                chosen.append(cell)
                self.prop(VINES, *cell, flip=self.rng.random() < 0.5)

    def plants(self, count, levels=(0, 1, 2)):
        """Moss and small plants on floor cells by the lava's edge, off the lanes."""
        cells = [(x, y) for y in range(1, ROWS - 1) for x in range(1, COLUMNS - 1)
                 if self.at(x, y) in FLOOR_HEIGHT and FLOOR_HEIGHT[self.at(x, y)] in levels
                 and not self.is_lane(x, y) and self.near(x, y, "~")]
        taken = {p["cell"] for p in self.props}
        cells = [c for c in cells if c not in taken]
        self.rng.shuffle(cells)
        chosen = []
        for cell in cells:
            if len(chosen) == count:
                break
            if all(math.hypot(cell[0] - o[0], cell[1] - o[1]) >= 4 for o in chosen):
                chosen.append(cell)
                self.prop(PLANT, *cell, flip=self.rng.random() < 0.5)

    def near(self, x, y, chars, d=1):
        return any(self.at(x + dx, y + dy) in chars for dx in range(-d, d + 1) for dy in range(-d, d + 1) if dx or dy)

    def foot(self, prop):
        x, y = prop["cell"]
        if prop["kind"] in HANGING:
            return (x * TILE + TILE // 2, (y + 1) * TILE)
        # The body (footprint) sits inside the cell: the foot is half its height above the cell's bottom.
        h = PROPS_META[STRIP[prop["kind"]]]["footprint"][1]
        return (x * TILE + TILE // 2, y * TILE + TILE - max(4, h // 2))

    def blocks(self, prop):
        """The cells a prop's body (or a hazard geyser's eruption) covers, like TempleProp.blocks_cells."""
        kind = prop["kind"]
        if kind in TRAPS:
            return self.track_cells(prop)
        if not (kind in SOLID or (kind == GEYSER and prop["hazard"])):
            return []
        w, h = PROPS_META[STRIP[kind]]["footprint"]
        if w <= 0 or h <= 0:
            return []
        fx, fy = self.foot(prop)
        x0, y0 = fx - w / 2.0, fy - h / 2.0
        x1, y1 = x0 + w - 0.01, y0 + h - 0.01
        return [(x, y) for x in range(int(x0 // TILE), int(x1 // TILE) + 1) for y in range(int(y0 // TILE), int(y1 // TILE) + 1)]

    # --- markers ---------------------------------------------------------------------------------------------
    def want(self, container, count, levels=(0, 1, 2), region=None, first=None):
        """`count` markers in `container`, picked after Godot says which cells are spawn_ok: on those
        levels, inside `region` (x0, y0, x1, y1) if given, spread as far apart as possible from `first`."""
        self.wants[container] = (count, {"levels": levels, "region": region, "first": first})

    def marker(self, container, x, y):
        self.spawns.setdefault(container, []).append((x * TILE + TILE // 2, y * TILE + TILE // 2))

    def _pick_spawns(self, blocked):
        ok = {tuple(c) for c in self.result["spawn_ok"]}
        for container, (count, options) in self.wants.items():
            region = options["region"]
            candidates = [c for c in ok if self.height(*c) in options["levels"] and c not in blocked
                          and not any((c[0] + dx, c[1] + dy) in blocked for dx in (-1, 0, 1) for dy in (-1, 0, 1))
                          and (region is None or (region[0] <= c[0] <= region[2] and region[1] <= c[1] <= region[3]))]
            off_lane = [c for c in candidates if not self.is_lane(*c)]
            if len(off_lane) >= count:
                candidates = off_lane
            assert len(candidates) >= count, f"{self.filename}: only {len(candidates)} cells for {count} {container} markers"
            candidates.sort()
            first = options["first"]
            chosen = [min(candidates, key=lambda c: math.hypot(c[0] - first[0], c[1] - first[1]))] if first \
                else [candidates[self.rng.randrange(len(candidates))]]
            while len(chosen) < count:
                chosen.append(max(candidates, key=lambda c: min(math.hypot(c[0] - o[0], c[1] - o[1]) for o in chosen)))
            for x, y in chosen:
                self.marker(container, x, y)

    # --- check and write -------------------------------------------------------------------------------------
    def finish(self):
        self.__class__.pending.append(self)

    pending = []

    def check_and_write(self):
        problems = list(self.result["problems"])
        reached = {(x, y, level) for x, y, level in self.result["reached"]}
        blocked = {}
        for prop in self.props:
            kind, (x, y) = prop["kind"], prop["cell"]
            c = self.at(x, y)
            if not self.inside(x, y):
                problems.append(f"prop {STRIP[kind]} outside the room at {(x, y)}")
                continue
            if c == "#":
                problems.append(f"prop {STRIP[kind]} on masonry at {(x, y)}")
            elif c == "~" and kind not in ON_LAVA:
                problems.append(f"prop {STRIP[kind]} in lava at {(x, y)}")
            elif c in STAIRS or c in DECKS:
                problems.append(f"prop {STRIP[kind]} on a stair or a bridge at {(x, y)}")
            elif c in FLOOR_HEIGHT and FLOOR_HEIGHT[c] != prop["level"]:
                problems.append(f"prop {STRIP[kind]} at {(x, y)} is level {prop['level']} on floor of height {FLOOR_HEIGHT[c]}")
            for bx, by in self.blocks(prop):
                bc = self.at(bx, by)
                if not self.inside(bx, by) or bc not in FLOOR_HEIGHT or FLOOR_HEIGHT[bc] != prop["level"]:
                    if not (bc == "~" and kind in ON_LAVA):
                        problems.append(f"prop {STRIP[kind]} at {(x, y)} blocks {(bx, by)} ({bc!r}), not floor of its level")
                if (bx, by) in blocked:
                    problems.append(f"props {STRIP[kind]} and {STRIP[blocked[(bx, by)]]} overlap at {(bx, by)}")
                blocked[(bx, by)] = kind
                gate_lane = self.boss and kind == FACE_GATE and bx in LANE_COLUMNS and by < LANE_ROWS[0]
                if prop["level"] == self.base and self.is_lane(bx, by) and not gate_lane and kind not in TRAPS:
                    problems.append(f"prop {STRIP[kind]} at {(x, y)} blocks the lane cell {(bx, by)}")
                if bc in FLOOR_HEIGHT and (bx, by, FLOOR_HEIGHT[bc]) not in reached and bc != "~":
                    problems.append(f"prop {STRIP[kind]} at {(x, y)} stands on {(bx, by)}, which nobody reaches")
        if not problems:
            self._pick_spawns(set(blocked))
        ok = {tuple(c) for c in self.result["spawn_ok"]}
        for container, points in self.spawns.items():
            for px, py in points:
                cell = (px // TILE, py // TILE)
                if cell not in ok:
                    problems.append(f"{container} marker {(px, py)} is not on a spawn_ok cell")
                if cell in blocked:
                    problems.append(f"{container} marker {(px, py)} is inside a prop")
        if self.player_spawn:
            cell = (self.player_spawn[0] // TILE, self.player_spawn[1] // TILE)
            if cell not in ok:
                problems.append(f"the player spawn {self.player_spawn} is not on a spawn_ok cell")
        if problems:
            for problem in problems:
                print(f"  {self.filename}: {problem}")
            return False
        self.write()
        return True

    def rows_text(self):
        return "\n".join(self.rows)

    def write(self):
        if SHOW:
            print(f"--- {self.filename}")
            print(self.rows_text())
        text = ['[gd_scene load_steps=4 format=3]\n',
                '[ext_resource type="PackedScene" path="res://scenes/levels/rooms/room_base.tscn" id="1"]',
                '[ext_resource type="Script" path="res://scripts/world/temple_prop.gd" id="2"]',
                '[ext_resource type="Script" path="res://scripts/world/temple_shape.gd" id="3"]\n',
                f'[node name="{self.node_name}" instance=ExtResource("1")]\n',
                '[node name="Shape" type="Node2D" parent="."]\nscript = ExtResource("3")\nrows = "' + self.rows_text() + '"\n']
        for number, prop in enumerate(self.props, start=1):
            fx, fy = self.foot(prop)
            block = [f'[node name="Prop{number}" type="Node2D" parent="."]',
                     f'position = Vector2({fx}, {fy})',
                     'script = ExtResource("2")']
            if prop["kind"] != 0:
                block.append(f'kind = {prop["kind"]}')
            if prop["flip"]:
                block.append('flip = true')
            if prop["level"]:
                block.append(f'level = {prop["level"]}')
            if prop["hazard"]:
                block.append('hazard = true')
            if prop["track"]:
                block.append(f'track = {prop["track"]}')
            if prop["direction"]:
                block.append(f'direction = Vector2i({prop["direction"][0]}, {prop["direction"][1]})')
            text.append("\n".join(block) + "\n")
        if self.player_spawn:
            text.append(f'[node name="PlayerSpawn" type="Marker2D" parent="."]\nposition = Vector2{self.player_spawn}\n')
        for container, points in self.spawns.items():
            text.append(f'[node name="{container}" type="Node2D" parent="."]\n')
            for i, (px, py) in enumerate(points):
                text.append(f'[node name="P{i + 1}" type="Marker2D" parent="{container}"]\nposition = Vector2({px}, {py})\n')
        with open(f"{OUT}/{self.filename}.tscn", "w", newline="\n", encoding="utf-8") as f:
            f.write("\n".join(text))


def validate_all(rooms):
    """Hands every plan to Godot (TemplePlan is the only judge) and keeps its answers on each room."""
    godot = os.environ.get("GODOT") or shutil.which("godot")
    if not godot or not os.path.exists(godot):
        sys.exit("GODOT must point to the Godot executable (or `godot` must be in the PATH) to validate the plans")
    with tempfile.TemporaryDirectory() as folder:
        in_path, out_path = os.path.join(folder, "plans.json"), os.path.join(folder, "results.json")
        with open(in_path, "w", encoding="utf-8") as f:
            json.dump({r.filename: {"rows": r.rows_text(), "surge_stages": r.surge_stages, "height": r.height_hint}
                       for r in rooms}, f)
        run = subprocess.run([godot, "--headless", "--path", ".", "--script", "res://tools/validate_temple_plans.gd",
                              "--", in_path, out_path], capture_output=True, text=True, encoding="utf-8", errors="replace")
        if not os.path.exists(out_path):
            sys.exit("the Godot validator wrote nothing:\n" + run.stdout + run.stderr)
        with open(out_path, encoding="utf-8") as f:
            results = json.load(f)
    for room in rooms:
        room.result = results[room.filename]


def room(filename, node_name, rows, height=0, surge_stages=0):
    r = Room(filename, node_name, rows, surge_stages)
    r.height_hint = height
    return r


#             x: 0123456789012345678901234567890 (30 columns, cell = 16 px; rows 0..17)
# The outer ring is the room's wall (lava in the temple) and the doors are the 4 middle cells of each
# edge, at the room's base height. Lanes: columns 13..16 and rows 7..10.

# --- Start: a wide island with a lit landing at the south door and two small galleries up north ---------------
r = room("start", "TempleStart", [
    "#############....#############",  # 0
    "#~~~~~~~~~~~.......~~~~~~~~~~#",  # 1
    "#~~~~~~~..............~~~~~~~#",  # 2
    "#~~~.11111..........11111.~~~#",  # 3
    "#~~..11111..........11111..~~#",  # 4
    "#~...^^11............11^^...~#",  # 5
    "#~..........................~#",  # 6
    "..............................",  # 7
    "..............................",  # 8
    "..............................",  # 9
    "..............................",  # 10
    "#~..........................~#",  # 11
    "#~~~......................~~~#",  # 12
    "#~~~~~..................~~~~~#",  # 13
    "#~~~~~~~..............~~~~~~~#",  # 14
    "#~~~~~~~~~..........~~~~~~~~~#",  # 15
    "#~~~~~~~~~~~........~~~~~~~~~#",  # 16
    "#############....#############",  # 17
])
r.player_spawn = (240, 232)
r.pair(BRAZIER_PEDESTAL, 11, 15)          # the landing's fires
r.pair(STATUE_GUARDIAN, 9, 2)             # guardians watching the way north
r.pair(URN, 6, 3)                         # on the galleries
r.pair(TORCH_WALL, 7, 6)                  # sconces on the galleries' faces
r.prop(COLUMN_BROKEN, 3, 11)
r.prop(RUBBLE, 4, 12)
r.prop(BANNER, 12, 1)
r.prop(BANNER, 17, 1, flip=True)
r.vines(4)
r.plants(4)
r.finish()

# --- Boss: a raised arena over the sea, the face gate at its north end, braziers and pillars in a ring -----------
r = room("boss", "TempleBoss", [
    "#############1111#############",  # 0
    "#~~~~~~~~~~11111111~~~~~~~~~~#",  # 1
    "#~~~~~~~11111111111111~~~~~~~#",  # 2
    "#~~~~~111111111111111111~~~~~#",  # 3
    "#~~~11111111111111111111~~~~~#",  # 4
    "#~~1111111111111111111111~~~~#",  # 5
    "#~11111111111111111111111~~~~#",  # 6
    "1111111111111111111111111~1111",  # 7
    "111111111111111111111111111111",  # 8
    "111111111111111111111111111111",  # 9
    "111~11111111111111111111111111",  # 10
    "#~1111111111111111111111111~~#",  # 11
    "#~~111111111111111111111111~~#",  # 12
    "#~~~1111111111111111111111~~~#",  # 13
    "#~~~~11111111111111111111~~~~#",  # 14
    "#~~~~~~111111111111111~~~~~~~#",  # 15
    "#~~~~~~~~~1111111111~~~~~~~~~#",  # 16
    "#############1111#############",  # 17
], height=1)
r.boss = True
r.player_spawn = (240, 232)
r.marker("BossSpawn", 15, 8)
r.marker("ExitSpawn", 15, 4)
r.prop(FACE_GATE, 15, 2)                  # the temple's face, over the north edge of the arena
r.pair(BRAZIER_PEDESTAL, 7, 4)
r.pair(BRAZIER_PEDESTAL, 4, 11)
r.pair(BRAZIER_PEDESTAL, 8, 15)
r.prop(BRAZIER_PEDESTAL, 3, 6)
r.prop(BRAZIER_PEDESTAL, 25, 13, flip=True)
r.pair(PILLAR_CARVED, 6, 6)
r.pair(PILLAR_CARVED, 6, 13)
r.pair(STATUE_GUARDIAN, 9, 3)
r.pair(URN, 11, 16)
r.prop(RUBBLE, 23, 5)
r.prop(RUBBLE, 5, 14)
r.vines(5)
r.plants(3, levels=(1,))
r.finish()

# --- Pillar court: the reference's court, four pillars, two level-1 galleries up a flight of stairs ------------
r = room("pillar_court", "TemplePillarCourt", [
    "#############....#############",  # 0
    "#~~1111111111....1111111111~~#",  # 1
    "#~.1111111111....1111111111.~#",  # 2
    "#..1111111111....1111111111..#",  # 3
    "#....^^...........^^.........#",  # 4
    "#~..........................~#",  # 5
    "#~.......p..........p.......~#",  # 6
    "..............................",  # 7
    "..............................",  # 8
    "..............................",  # 9
    "..............................",  # 10
    "#~..........................~#",  # 11
    "#~.......p..........p.......~#",  # 12
    "#~~........................~~#",  # 13
    "#~~~......................~~~#",  # 14
    "#~~~~~..................~~~~~#",  # 15
    "#~~~~~~~~~..........~~~~~~~~~#",  # 16
    "#############....#############",  # 17
])
r.want("EnemySpawns", 7, region=(3, 5, 26, 14))
r.prop(ALTAR_RUNE, 6, 2)                  # the altar on the west gallery
r.pair(STATUE_GUARDIAN, 10, 2)            # guardians over the sunken way
r.pair(BRAZIER_PEDESTAL, 11, 14)          # fires by the south way
r.pair(URN, 24, 1)
r.pair(TORCH_WALL, 4, 4)
r.pair(TORCH_WALL, 9, 4)
r.pair(BANNER, 12, 3)
r.prop(COLUMN_BROKEN, 3, 13)
r.prop(RUBBLE, 26, 13)
r.vines(4)
r.plants(4)
r.finish()

# --- Isles: a spine of stone with isles on both sides and one up north, joined only by bridges ----------------
r = room("isles", "TempleIsles", [
    "#############....#############",  # 0
    "#~~~~~~~~~~~.......~~~.....~~#",  # 1
    "#~~~~~~~~~~.........~~......~#",  # 2
    "#~~.....~~~.........~~~.....~#",  # 3
    "#~.......~~~.......~~~~~||~~~#",  # 4
    "#~.......~~~.......~~~~~||~~~#",  # 5
    "#~.......~~~.......~~~.......#",  # 6
    ".........~~~.......~~.........",  # 7
    ".........===.......==.........",  # 8
    ".........===.......==.........",  # 9
    ".........~~~.......~~.........",  # 10
    "#~.......~~~.......~~~.......#",  # 11
    "#~~~~...~~~~.......~~~.......#",  # 12
    "#~~~~~~~~~~~........~~~.....~#",  # 13
    "#~~~~~~~~~~.........~~~~~~~~~#",  # 14
    "#~~~~~~~~~~~........~~~~~~~~~#",  # 15
    "#~~~~~~~~~~~~.....~~~~~~~~~~~#",  # 16
    "#############....#############",  # 17
])
r.want("EnemySpawns", 7, region=(2, 2, 27, 14))
r.prop(ALTAR_RUNE, 25, 2)                 # the altar on the isle nobody reaches but by the bridge
r.pair(BRAZIER_PEDESTAL, 12, 5)
r.pair(BRAZIER_PEDESTAL, 12, 13)
r.prop(STATUE_GUARDIAN, 4, 4)
r.prop(URN, 24, 12)
r.prop(COLUMN_BROKEN, 3, 11)
r.prop(COLUMN_LOW, 26, 6)
r.prop(ROCK_SMOKING, 10, 14)
r.prop(GEYSER, 5, 14)
r.prop(RUBBLE, 23, 7)
r.vines(5)
r.plants(5)
r.finish()

# --- Terraces: two tiered wings up north (0 -> 1 -> 2), two daises down south, a valley between ---------------
r = room("terraces", "TempleTerraces", [
    "#############....#############",  # 0
    "#~~2222221111....11112222221~#",  # 1
    "#~12222221111....11112222221~#",  # 2
    "#~111^^111111....111111^^111~#",  # 3
    "#~11111111111....11111111111~#",  # 4
    "#~11111111111....11111111111~#",  # 5
    "#~...^^...............^^....~#",  # 6
    "..............................",  # 7
    "..............................",  # 8
    "..............................",  # 9
    "..............................",  # 10
    "#~~........................~~#",  # 11
    "#~~.1111111........1111111.~~#",  # 12
    "#~~.1111111<......>1111111.~~#",  # 13
    "#~~~1111111<......>1111111~~~#",  # 14
    "#~~~1111111........1111111~~~#",  # 15
    "#~~~~~~~~~~~.......~~~~~~~~~~#",  # 16
    "#############....#############",  # 17
])
r.want("EnemySpawns", 8, region=(2, 1, 27, 15))
r.pair(BRAZIER_PEDESTAL, 4, 2)            # fires on the high blocks
r.pair(URN, 8, 2)
r.pair(STATUE_GUARDIAN, 9, 4)             # guardians on the wings
r.pair(COLUMN_LOW, 5, 12)                 # on the daises
r.pair(COLUMN_LOW, 5, 15)
r.pair(BANNER, 12, 2)
r.pair(TORCH_WALL, 4, 3)
r.pair(TORCH_WALL, 8, 6)
r.prop(RUBBLE, 3, 11)
r.vines(5)
r.plants(4)
r.finish()

# --- Trap walk: bridges over the sea to three landings; a rolling rock, spikes, saws and geysers on the way -------
r = room("trap_walk", "TempleTrapWalk", [
    "#############....#############",  # 0
    "#~~~~~~~~~~~~||||~~~~~~~~~~~~#",  # 1
    "#~~~~~~~~~~~~||||~~~~~~~~~~~~#",  # 2
    "#~~~~~~~~~~.........~~~~~~~~~#",  # 3
    "#~~~~~~~~~...........~~~~~~~~#",  # 4
    "#~~~~~~~~~~.........~~~~~~~~~#",  # 5
    "#~~~~~~~~~~~~||||~~~~~~~~~~~~#",  # 6
    ".====~~~~............~~~~====.",  # 7
    ".====....................====.",  # 8
    ".====....................====.",  # 9
    ".====~~~~............~~~~====.",  # 10
    "#~~~~~~~~~...........~~~~~~~~#",  # 11
    "#~~~~~~~~~~~~||||~~~~~~~~~~~~#",  # 12
    "#~~~~~~~~~~.........~~~~~~~~~#",  # 13
    "#~~~~~~~~~...........~~~~~~~~#",  # 14
    "#~~~~~~~~~~.........~~~~~~~~~#",  # 15
    "#~~~~~~~~~~~~||||~~~~~~~~~~~~#",  # 16
    "#############....#############",  # 17
])
r.want("EnemySpawns", 7, region=(6, 3, 23, 15))
# The traps, each with a visible warning and a rhythm that leaves the way open between beats: a rock
# rolls across the north landing (dust rumbles where it will rise), a band of spikes guards the step
# down from it and the step down to the south bridge (the slots glow before they rise), two saws
# sweep the walk's wings beside the west and east bridges, and geysers erupt beside the way.
r.trap(ROLLING_ROCK, 10, 4, track=11, direction=(1, 0))
for x in range(13, 17):
    r.trap(SPIKES, x, 5)
    r.trap(SPIKES, x, 11)
r.trap(SAW, 9, 7, track=4, direction=(0, 1))
r.trap(SAW, 20, 10, track=4, direction=(0, -1))
r.pair(GEYSER, 11, 11, hazard=True)
r.pair(GEYSER, 11, 14, hazard=True)
r.pair(GEYSER, 11, 1)                     # ambient ones in the sea by the bridges
r.pair(GEYSER, 7, 12)
r.pair(ROCK_SMOKING, 5, 3)
r.pair(ROCK_SMOKING, 7, 15)
r.pair(BRAZIER_PEDESTAL, 11, 3)
r.prop(COLUMN_BROKEN, 20, 14)
r.prop(URN, 11, 15)
r.prop(VASE, 18, 15)
r.prop(RUBBLE, 16, 13)
r.vines(4)
r.plants(3)
r.finish()

# --- Lava falls (raised): a ridge of masonry up north pours lava into pools, a level-2 dais south-west --------
r = room("lava_falls", "TempleLavaFalls", [
    "#############1111#############",  # 0
    "#~##########~1111~##########~#",  # 1
    "#~##########~1111~##########~#",  # 2
    "#~~~~~~~~~~~~1111~~~~~~~~~~~~#",  # 3
    "#~~~~~~~~~~~~1111~~~~~~~~~~~~#",  # 4
    "#~~~11111111111111111111111~~#",  # 5
    "#~11111111111111111111111111~#",  # 6
    "11~~11111111111111111111111111",  # 7
    "111111111111111111111111111111",  # 8
    "111111111111111111111111111111",  # 9
    "1111111111111111111111111~~~11",  # 10
    "#~111111111111111111111~~~~~~#",  # 11
    "#~2222222111111111111~~~~~~~~#",  # 12
    "#~2222222<1111111111~~~~~~~~~#",  # 13
    "#~2222222<111111111~~~~~~~~~~#",  # 14
    "#~2222222111111111~~~~~~~~~~~#",  # 15
    "#~~~~~~~~~~~~1111~~~~~~~~~~~~#",  # 16
    "#############1111#############",  # 17
], height=1)
r.want("EnemySpawns", 7, region=(3, 5, 26, 15))
for x in (4, 7, 10):                      # the falls, down the ridge's face into the pools
    r.prop(LAVA_FALL, x, 4)
    r.prop(LAVA_FALL, mirror(x), 4, flip=True)
r.prop(STATUE_GUARDIAN, 5, 13)            # the guardian on the high dais
r.pair(BRAZIER_PEDESTAL, 12, 5)           # fires at the causeway's end
r.pair(URN, 2, 6)
r.prop(GEYSER, 25, 13)
r.prop(ROCK_SMOKING, 27, 12)
r.prop(COLUMN_BROKEN, 17, 15)
r.prop(RUBBLE, 20, 11)
r.vines(4, among=[(x, 3) for x in (5, 6, 8, 9, 20, 21, 23, 24)] + r.face_into_lava_cells())
r.plants(4, levels=(1, 2))
r.finish()

# --- Surge basin (1 stage): a sunken basin inside a level-1 walk; every door climbs onto the walk -------------
r = room("surge_basin", "TempleSurgeBasin", [
    "#############....#############",  # 0
    "#~~~111111111....111111111~~~#",  # 1
    "#~1111111111~.vv.~1111111111~#",  # 2
    "#1111111111111111111111111111#",  # 3
    "#11111.^^^^..^^....^^^^.11111#",  # 4
    "#1111<..................>1111#",  # 5
    "#~111<.p................>111~#",  # 6
    "....1....................1....",  # 7
    "...>1....................1<...",  # 8
    "...>1....................1<...",  # 9
    "....1....................1....",  # 10
    "#~111<.p..........~~~...>111~#",  # 11
    "#1111<.............~~~..>1111#",  # 12
    "#11111.vvvv..vv....vvvv.11111#",  # 13
    "#1111111111111111111111111111#",  # 14
    "#~1111111111~.^^.~1111111111~#",  # 15
    "#~~~111111111....111111111~~~#",  # 16
    "#############....#############",  # 17
], surge_stages=1)
r.want("EnemySpawns", 6, levels=(1,))
r.pair(BRAZIER_PEDESTAL, 3, 3)            # fires on the four corners of the walk
r.pair(BRAZIER_PEDESTAL, 3, 14)
r.pair(STATUE_GUARDIAN, 9, 1)
r.pair(URN, 10, 16)
r.pair(COLUMN_LOW, 2, 5)
r.pair(COLUMN_LOW, 2, 12)
r.prop(GEYSER, 20, 11)
r.prop(RUBBLE, 10, 6)
r.vines(4)
r.plants(3)
r.finish()

# --- Surge tiers (2 stages): three concentric tiers, the level-2 top is where the fight ends -------------------
r = room("surge_tiers", "TempleSurgeTiers", [
    "#############....#############",  # 0
    "#~~~.....................~~~~#",  # 1
    "#~...vv.......vv........vv..~#",  # 2
    "#..>1111111111111111111111<..#",  # 3
    "#..>1111111111vv1111111111<..#",  # 4
    "#...11112222222222222222111..#",  # 5
    "#...11112222222222222222111..#",  # 6
    "....11112222222222222222111...",  # 7
    "...>111>2222222222222222<111<.",  # 8
    "...>111>2222222222222222<111<.",  # 9
    "....11112222222222222222111...",  # 10
    "#...11112222222222222222111..#",  # 11
    "#...11112222222222222222111..#",  # 12
    "#..>1111111111^^1111111111<..#",  # 13
    "#..>1111111111111111111111<..#",  # 14
    "#~...^^.......^^.......^^...~#",  # 15
    "#~~~.....................~~~~#",  # 16
    "#############....#############",  # 17
], surge_stages=2)
r.want("EnemySpawns", 6, levels=(2,))
r.pair(BRAZIER_PEDESTAL, 9, 5)            # fires on the top
r.pair(BRAZIER_PEDESTAL, 9, 12)
r.pair(URN, 5, 3)
r.pair(URN, 5, 14)
r.pair(COLUMN_LOW, 1, 6)
r.pair(COLUMN_LOW, 1, 11)
r.pair(TORCH_WALL, 9, 13)
r.pair(TORCH_WALL, 7, 15)
r.prop(ALTAR_RUNE, 15, 11, level=2)
r.prop(RUBBLE, 27, 5)
r.vines(4)
r.plants(3)
r.finish()

# --- Surge bridges (2 stages): towers with decks to the ring, the level-2 isle in the middle -------------------
r = room("surge_bridges", "TempleSurgeBridges", [
    "#############....#############",  # 0
    "#~~~......................~~~#",  # 1
    "#~~........vv.vv...vv......~~#",  # 2
    "#.111bbb11111111111111bbb111.#",  # 3
    "#.111...111111vv111111...111.#",  # 4
    "#.^^....1122222222222211..^^.#",  # 5
    "#.......1122222222222211.....#",  # 6
    "........1122222222222211......",  # 7
    "........1>222222222222<1......",  # 8
    "........1>222222222222<1......",  # 9
    "........1122222222222211......",  # 10
    "#..~~...1122222222222211.~~..#",  # 11
    "#.vv....1122222222222211..vv.#",  # 12
    "#.111...111111^^111111...111.#",  # 13
    "#.111bbb11111111111111bbb111.#",  # 14
    "#~~........^^.^^...^^......~~#",  # 15
    "#~~~......................~~~#",  # 16
    "#############....#############",  # 17
], surge_stages=2)
r.want("EnemySpawns", 6, levels=(2,))
r.pair(BRAZIER_PEDESTAL, 11, 6)           # fires on the isle's corners
r.pair(BRAZIER_PEDESTAL, 11, 10)
r.pair(URN, 2, 4)
r.pair(URN, 2, 13)
r.pair(TORCH_WALL, 9, 13)
r.pair(COLUMN_BROKEN, 3, 6)
r.prop(STATUE_GUARDIAN, 15, 6, level=2)
r.prop(GEYSER, 4, 11)
r.prop(RUBBLE, 23, 1)
r.vines(4)
r.plants(3)
r.finish()

# --- Sanctum (reward): a cross of stone, the chest on an isle reached by one bridge -----------------------------
r = room("sanctum", "TempleSanctum", [
    "#############....#############",  # 0
    "#~~~~~~~~~~........~~.......~#",  # 1
    "#~~##~~~~~~........~........~#",  # 2
    "#~~##~~~~~~........~~.......~#",  # 3
    "#~~~~~~~~~~~.......~~~~||~~~~#",  # 4
    "#~~~~~~~~~~~.......~~~~||~~~~#",  # 5
    "#~~~.......................~~#",  # 6
    "..............................",  # 7
    "..............................",  # 8
    "..............................",  # 9
    "..............................",  # 10
    "#~~.......................~~~#",  # 11
    "#~~~~~~~~~~.........~~~~~~~~~#",  # 12
    "#~~~~~~~~~~.........~~~~~##~~#",  # 13
    "#~~~~~~~~~~~.......~~~~~~##~~#",  # 14
    "#~~~~~~~~~~~.......~~~~~~~~~~#",  # 15
    "#~~~~~~~~~~~~.....~~~~~~~~~~~#",  # 16
    "#############....#############",  # 17
])
r.marker("ChestSpawn", 23, 2)
r.pair(BRAZIER_PEDESTAL, 12, 6)
r.pair(BRAZIER_PEDESTAL, 12, 11)
r.pair(STATUE_GUARDIAN, 5, 6)
r.prop(URN, 21, 1)
r.prop(URN, 26, 3, flip=True)
r.prop(COLUMN_BROKEN, 12, 12)
r.prop(COLUMN_LOW, 17, 15)
r.prop(GEYSER, 6, 14)
r.prop(ROCK_SMOKING, 8, 3)
r.prop(RUBBLE, 22, 3)
r.vines(4)
r.plants(4)
r.finish()

# --- Event: a quiet shrine on a raised step, a lava channel crossed by a bridge on the way east ----------------
r = room("event", "TempleEvent", [
    "#############....#############",  # 0
    "#~~~~~~~~~~~.......~~~~~~~~~~#",  # 1
    "#~~111111..........~~~......~#",  # 2
    "#~.111111...........~~~.....~#",  # 3
    "#~.111111...........~~~.....~#",  # 4
    "#~.111111............~~~....~#",  # 5
    "#....^^..............~~~.....#",  # 6
    ".....................~~~......",  # 7
    ".....................===......",  # 8
    ".....................===......",  # 9
    ".....................~~~......",  # 10
    "#~..................~~~......#",  # 11
    "#~~~.................~~~....~#",  # 12
    "#~~~~~..............~~~....~~#",  # 13
    "#~~~~~~~~..........~~~~...~~~#",  # 14
    "#~~~~~~~~~~........~~~~~~~~~~#",  # 15
    "#~~~~~~~~~~~........~~~~~~~~~#",  # 16
    "#############....#############",  # 17
])
r.marker("NpcSpawn", 8, 9)
r.prop(ALTAR_RUNE, 5, 3)                  # the shrine's altar
r.prop(BRAZIER_PEDESTAL, 3, 4)
r.prop(BRAZIER_PEDESTAL, 7, 4, flip=True)
r.prop(STATUE_GUARDIAN, 10, 3)
r.prop(URN, 25, 3)
r.prop(URN, 26, 12, flip=True)
r.prop(COLUMN_BROKEN, 18, 2)
r.prop(COLUMN_LOW, 26, 6)
r.prop(BRAZIER, 11, 14)
r.prop(BRAZIER, 17, 14, flip=True)
r.prop(TORCH_WALL, 3, 6)
r.prop(TORCH_WALL, 8, 6, flip=True)
r.prop(BANNER, 4, 2)
r.prop(RUBBLE, 2, 11)
r.vines(4)
r.plants(4)
r.finish()

# --- Special: a ziggurat up north, three tiers to the altar, a pool on each side ------------------------------
r = room("special", "TempleSpecial", [
    "#############....#############",  # 0
    "#~~~.........................#",  # 1
    "#~~......2222222222222.......#",  # 2
    "#~.....11222222222222211....~#",  # 3
    "#~.....11222222222222211....~#",  # 4
    "#......11111111^^11111111....#",  # 5
    "#......11111111111111111....~#",  # 6
    "..............^^..............",  # 7
    "..............................",  # 8
    "..............................",  # 9
    "..............................",  # 10
    "#~~........................~~#",  # 11
    "#~~~~.....~~~......~~~....~~~#",  # 12
    "#~~~~~...~~~~~....~~~~~..~~~~#",  # 13
    "#~~~~~~...~~~......~~~...~~~~#",  # 14
    "#~~~~~~~~...............~~~~~#",  # 15
    "#~~~~~~~~~~~........~~~~~~~~~#",  # 17
    "#############....#############",  # 17
])
r.marker("SpecialSpawn", 15, 11)
r.prop(ALTAR_RUNE, 15, 3, level=2)        # the altar on the top of the ziggurat
r.pair(BRAZIER_PEDESTAL, 10, 3)
r.pair(STATUE_GUARDIAN, 8, 6)
r.pair(URN, 12, 1)
r.pair(COLUMN_LOW, 2, 5)
r.pair(TORCH_WALL, 11, 5)
r.pair(TORCH_WALL, 11, 7)
r.pair(BANNER, 10, 2)
r.prop(GEYSER, 11, 13)
r.prop(GEYSER, 20, 13, flip=True)
r.prop(RUBBLE, 3, 10)
r.vines(4)
r.plants(4)
r.finish()


def main():
    os.makedirs(OUT, exist_ok=True)
    rooms = Room.pending
    validate_all(rooms)
    written = 0
    for r in rooms:
        if r.check_and_write():
            written += 1
    if written != len(rooms):
        sys.exit(f"{len(rooms) - written} of {len(rooms)} temple rooms are invalid: nothing written for them")
    print(f"{written} temple rooms written and validated")


if __name__ == "__main__":
    main()
