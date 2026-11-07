"""Generates the Templo del Eclipse room scenes in scenes/levels/rooms/temple/.
Run from the repo root: python tools/make_temple_rooms.py [--show]

Each room is a scene inheriting room_base.tscn with a TempleShape node (the island's plan as one line
of characters per tile row, see scripts/world/temple_plan.gd for the alphabet: lava, floors of three
heights, stairs, bridges, masonry, pillar slots), TempleProp nodes (pillars, statues, braziers, vines,
lava falls, geysers, traps...) and the spawn markers. The temple's rooms come in three sizes, as
docs/superpowers/specs/2026-11-07-templo-escala-design.md decides: large 42x28 (the boss arena, the
pillar court and the two-stage surge rooms), medium 34x24 and small 26x20 (the sanctum, the event and
the special room); the plan's size is the room's `size_tiles`. The plans are drawn by hand below, as
in docs/referencias/templo_mapa.jpg: wide islands of stone over lava with organic outlines, real
height tiers with clear flights of stairs, isles reached only by a bridge, and one focal piece per
room on the axis of its main door (the face gate, the altar, the chest's isle, the ziggurat) framed
by mirrored pairs of pillars, braziers or statues. Few props: no posts on the shores, no urns,
vines and moss only on the cliffs, and generous open floor for the fights.

The design rules are the game's own: this script never ports them. It hands every plan to Godot
(tools/validate_temple_plans.gd, which runs TemplePlan.validate with the room's surge stages and
answers which cells are spawn_ok and which are reached at each level) and refuses to write a room
whose plan has a problem, whose solid prop stands off the floor of its level, on a lane or on a cell
nobody reaches, or whose markers are not on spawn_ok cells. GODOT names the executable (or `godot`
in the PATH). `--show` prints every plan.

Coordinates are in TILES (16 px). A prop's cell is the one its foot stands in; its `level` is the
height of that cell. The center cross (the 4 middle columns and the 4 middle rows) holds no solid prop
of the base height, so every door keeps a straight way to the middle (the boss room's face gate, on
the north lane the boss cell never opens, is the one exception).
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
LANE_WIDTH = 4
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
        # The plan's size is the room's: any even size of at least 8 (TemplePlan.MIN_SIZE).
        self.height_cells = len(rows)
        self.width = len(rows[0]) if rows else 0
        assert self.height_cells >= 8 and self.height_cells % 2 == 0, f"{filename}: {self.height_cells} rows"
        assert self.width >= 8 and self.width % 2 == 0, f"{filename}: {self.width} columns"
        for y, row in enumerate(rows):
            assert len(row) == self.width, f"{filename}: row {y} has {len(row)} characters, not {self.width}: {row!r}"
        self.lane_columns = range(self.width // 2 - LANE_WIDTH // 2, self.width // 2 + LANE_WIDTH // 2)
        self.lane_rows = range(self.height_cells // 2 - LANE_WIDTH // 2, self.height_cells // 2 + LANE_WIDTH // 2)

    # --- reading the plan ------------------------------------------------------------------------------------
    def at(self, x, y):
        return self.rows[y][x] if 0 <= x < self.width and 0 <= y < self.height_cells else "#"

    def inside(self, x, y):
        return 1 <= x <= self.width - 2 and 1 <= y <= self.height_cells - 2

    def inner_cells(self):
        return [(x, y) for y in range(1, self.height_cells - 1) for x in range(1, self.width - 1)]

    def height(self, x, y):
        return self.result["heights"][y][x]

    @property
    def base(self):
        return self.result["base_height"]

    def is_lane(self, x, y):
        return x in self.lane_columns or y in self.lane_rows

    def mirror(self, x, width=1):
        """The column that mirrors `x` across the room's vertical axis (a prop `width` cells wide)."""
        return self.width - 1 - x - (width - 1)

    def face_into_lava_cells(self):
        """Lava cells right under a floor cell: the island's cliff drops into the lava there."""
        return [(x, y) for x, y in self.inner_cells() if self.at(x, y) == "~" and self.at(x, y - 1) in FLOOR_HEIGHT]

    def face_cells(self, drop_to=None):
        """Floor cells right under a higher floor cell (the cliff face of a platform)."""
        cells = []
        for x, y in self.inner_cells():
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

    def pair(self, kind, x, y, width=1, hazard=False, level=None):
        """The same prop twice, mirrored across the vertical axis, the second one facing the first."""
        self.prop(kind, x, y, hazard=hazard, level=level)
        self.prop(kind, self.mirror(x, width), y, flip=True, hazard=hazard, level=level)

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
        """Moss and small plants on floor cells by the lava's edge (the island's corners), off the lanes."""
        cells = [(x, y) for x, y in self.inner_cells()
                 if self.at(x, y) in FLOOR_HEIGHT and FLOOR_HEIGHT[self.at(x, y)] in levels
                 and not self.is_lane(x, y) and self.near(x, y, "~")]
        taken = {p["cell"] for p in self.props}
        cells = [c for c in cells if c not in taken]
        self.rng.shuffle(cells)
        chosen = []
        for cell in cells:
            if len(chosen) == count:
                break
            if all(math.hypot(cell[0] - o[0], cell[1] - o[1]) >= 5 for o in chosen):
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

    def spawn_at(self, x, y):
        """Nico's spawn in the middle of cell (x, y)."""
        self.player_spawn = (x * TILE + TILE // 2, y * TILE + TILE // 2)

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
                gate_lane = self.boss and kind == FACE_GATE and bx in self.lane_columns and by < self.lane_rows[0]
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
        if not problems:
            # The props in place: Godot rebuilds the reachability with every solid footprint blocked.
            solid = sorted({(bx, by, prop["level"]) for prop in self.props if prop["kind"] in SOLID
                            for bx, by in self.blocks(prop)})
            markers = {(px // TILE, py // TILE) for points in self.spawns.values() for px, py in points}
            if self.player_spawn:
                markers.add((self.player_spawn[0] // TILE, self.player_spawn[1] // TILE))
            reply = run_godot({self.filename: self.spec() | {"blocked": solid, "markers": sorted(markers)}})[self.filename]
            problems.extend(reply["problems"])
        if problems:
            for problem in problems:
                print(f"  {self.filename}: {problem}")
            return False
        self.write()
        return True

    def spec(self):
        """What the validator needs: the plan, its surge stages, base height and size."""
        return {"rows": self.rows_text(), "surge_stages": self.surge_stages, "height": self.height_hint,
                "size_tiles": [self.width, self.height_cells]}

    def rows_text(self):
        return "\n".join(self.rows)

    def write(self):
        if SHOW:
            print(f"--- {self.filename} ({self.width}x{self.height_cells})")
            print(self.rows_text())
        text = ['[gd_scene load_steps=4 format=3]\n',
                '[ext_resource type="PackedScene" path="res://scenes/levels/rooms/room_base.tscn" id="1"]',
                '[ext_resource type="Script" path="res://scripts/world/temple_prop.gd" id="2"]',
                '[ext_resource type="Script" path="res://scripts/world/temple_shape.gd" id="3"]\n',
                f'[node name="{self.node_name}" instance=ExtResource("1")]\nsize_tiles = Vector2i({self.width}, {self.height_cells})\n',
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


def run_godot(specs):
    """Hands plans (and, when a spec has `blocked` and `markers`, the props in place) to Godot, where
    TemplePlan is the only judge, and returns its answer for each."""
    godot = os.environ.get("GODOT") or shutil.which("godot")
    if not godot or not os.path.exists(godot):
        sys.exit("GODOT must point to the Godot executable (or `godot` must be in the PATH) to validate the plans")
    with tempfile.TemporaryDirectory() as folder:
        in_path, out_path = os.path.join(folder, "plans.json"), os.path.join(folder, "results.json")
        with open(in_path, "w", encoding="utf-8") as f:
            json.dump(specs, f)
        run = subprocess.run([godot, "--headless", "--path", ".", "--script", "res://tools/validate_temple_plans.gd",
                              "--", in_path, out_path], capture_output=True, text=True, encoding="utf-8", errors="replace")
        if not os.path.exists(out_path):
            sys.exit("the Godot validator wrote nothing:\n" + run.stdout + run.stderr)
        with open(out_path, encoding="utf-8") as f:
            return json.load(f)


def validate_all(rooms):
    """Hands every plan to Godot (TemplePlan is the only judge) and keeps its answers on each room."""
    results = run_godot({r.filename: r.spec() for r in rooms})
    for room in rooms:
        room.result = results[room.filename]


def room(filename, node_name, rows, height=0, surge_stages=0):
    r = Room(filename, node_name, rows, surge_stages)
    r.height_hint = height
    return r


# The outer ring is the room's wall (lava in the temple) and the doors are the 4 middle cells of each
# edge, at the room's base height. Lanes: the 4 middle columns and the 4 middle rows.
#   large  42x28: lane columns 19..22, lane rows 12..15
#   medium 34x24: lane columns 15..18, lane rows 10..13
#   small  26x20: lane columns 11..14, lane rows 8..11

# --- Start (34x24): a wide esplanade, Nico's landing lit at the south door, two galleries flanking the way north ---
#            x: 0123456789012345678901234567890123
r = room("start", "TempleStart", [
    "###############....###############",  # 0
    "#~~~~~~~~~~~~.........~~~~~~~~~~~#",  # 1
    "#~~~~~~~~................~~~~~~~~#",  # 2
    "#~~~~~......................~~~~~#",  # 3
    "#~~~..1111111........1111111..~~~#",  # 4
    "#~~...1111111........1111111...~~#",  # 5
    "#~....1111111........1111111....~#",  # 6
    "#~....11^^111........111^^11....~#",  # 7
    "#................................#",  # 8
    "#................................#",  # 9
    "..................................",  # 10
    "..................................",  # 11
    "..................................",  # 12
    "..................................",  # 13
    "#~..............................~#",  # 14
    "#~~............................~~#",  # 15
    "#~~~~........................~~~~#",  # 16
    "#~~~~~~....................~~~~~~#",  # 17
    "#~~~~~~~~................~~~~~~~~#",  # 18
    "#~~~~~~~~~~............~~~~~~~~~~#",  # 19
    "#~~~~~~~~~~~..........~~~~~~~~~~~#",  # 20
    "#~~~~~~~~~~~~........~~~~~~~~~~~~#",  # 21
    "#~~~~~~~~~~~~~......~~~~~~~~~~~~~#",  # 22
    "###############....###############",  # 23
])
r.spawn_at(17, 19)
# The Mercader: one cell on the landing's east side, off the lanes and the props, close to Nico's start.
r.want("NpcSpawn", 1, levels=(0,), region=(21, 14, 27, 18), first=(23, 16))
r.pair(BRAZIER_PEDESTAL, 14, 20)         # the landing's fires, framing the way in
r.pair(PILLAR_CARVED, 13, 9)             # a pair of pillars framing the way north
r.pair(STATUE_GUARDIAN, 13, 3)           # guardians watching the north door
r.pair(COLUMN_LOW, 11, 5, level=1)       # on the galleries, off the stairs' heads
r.pair(BANNER, 6, 8)                     # on the galleries' faces
r.vines(4)
r.plants(2)
r.finish()

# --- Boss (42x28, raised): a wide arena, the face gate on a dais up a wide flight of stairs at its north end -------
#            x: 012345678901234567890123456789012345678901
r = room("boss", "TempleBoss", [
    "###################1111###################",  # 0
    "#~~~~~~~~~~~111111111111111111~~~~~~~~~~~#",  # 1
    "#~~~~~~~~~1112222222222222222111~~~~~~~~~#",  # 2
    "#~~~~~~~~111122222222222222221111~~~~~~~~#",  # 3
    "#~~~~~~~11111222222222222222211111~~~~~~~#",  # 4
    "#~~~~~~1111112222222222222222111111~~~~~~#",  # 5
    "#~~~~~1111111111111^^^^1111111111111~~~~~#",  # 6
    "#~~~~11111111111111111111111111111111~~~~#",  # 7
    "#~~~1111111111111111111111111111111111~~~#",  # 8
    "#~~11111111111111111111111111111111111~~~#",  # 9
    "#~11111111111111111111111111111111111111~#",  # 10
    "#~11111111111111111111111111111111111111~#",  # 11
    "111111111111111111111111111111111111111111",  # 12
    "111111111111111111111111111111111111111111",  # 13
    "111111111111111111111111111111111111111111",  # 14
    "111111111111111111111111111111111111111111",  # 15
    "#~1111111111111111111111111111111111111~~#",  # 16
    "#~11111111111111111111111111111111111111~#",  # 17
    "#~~111111111111111111111111111111111111~~#",  # 18
    "#~~~~111111111111111111111111111111111~~~#",  # 19
    "#~~~~11111111111111111111111111111111~~~~#",  # 20
    "#~~~~~~1111111111111111111111111111~~~~~~#",  # 21
    "#~~~~~~~~111111111111111111111111~~~~~~~~#",  # 22
    "#~~~~~~~~~~11111111111111111111~~~~~~~~~~#",  # 23
    "#~~~~~~~~~~~~1111111111111111~~~~~~~~~~~~#",  # 24
    "#~~~~~~~~~~~~~~111111111111~~~~~~~~~~~~~~#",  # 25
    "#~~~~~~~~~~~~~~~~11111111~~~~~~~~~~~~~~~~#",  # 26
    "###################1111###################",  # 27
], height=1)
r.boss = True
r.spawn_at(20, 24)
r.marker("BossSpawn", 20, 13)
r.marker("ExitSpawn", 20, 4)             # the portal opens on the dais, in front of the gate
r.prop(FACE_GATE, 20, 2, level=2)        # the temple's face, over the north edge of the dais
r.pair(BRAZIER_PEDESTAL, 16, 4, level=2) # fires flanking the gate
r.pair(STATUE_GUARDIAN, 11, 4, level=1)  # guardians on the dais' wings
r.pair(PILLAR_CARVED, 15, 9)             # pillars framing the arena's axis
r.pair(PILLAR_CARVED, 15, 20)
r.pair(BANNER, 16, 6)                    # on the dais' face
r.vines(4)
r.finish()

# --- Pillar court (42x28): the reference's court, two rows of pillars framing the way to the altar's dais ----------
#            x: 012345678901234567890123456789012345678901
r = room("pillar_court", "TemplePillarCourt", [
    "###################....###################",  # 0
    "#~~~~~~~~~~~..................~~~~~~~~~~~#",  # 1
    "#~~~~~~~~~......................~~~~~~~~~#",  # 2
    "#~~~~~~~.....1111111111111111.....~~~~~~~#",  # 3
    "#~~~~~~......1111111111111111......~~~~~~#",  # 4
    "#~~~~~.......1111111111111111.......~~~~~#",  # 5
    "#~~~~..............^^^^..............~~~~#",  # 6
    "#~~~..................................~~~#",  # 7
    "#~~....................................~~#",  # 8
    "#~......................................~#",  # 9
    "#~~.....................................~#",  # 10
    "#........................................#",  # 11
    "..........................................",  # 12
    "..........................................",  # 13
    "..........................................",  # 14
    "..........................................",  # 15
    "#........................................#",  # 16
    "#~.....................................~~#",  # 17
    "#~......................................~#",  # 18
    "#~~....................................~~#",  # 19
    "#~~~..................................~~~#",  # 20
    "#~~~~................................~~~~#",  # 21
    "#~~~~~~............................~~~~~~#",  # 22
    "#~~~~~~~~........................~~~~~~~~#",  # 23
    "#~~~~~~~~~~....................~~~~~~~~~~#",  # 24
    "#~~~~~~~~~~~~................~~~~~~~~~~~~#",  # 25
    "#~~~~~~~~~~~~~~............~~~~~~~~~~~~~~#",  # 26
    "###################....###################",  # 27
])
r.want("EnemySpawns", 9, region=(4, 7, 37, 23))
r.prop(ALTAR_RUNE, 20, 3, level=1)       # the altar on the dais, behind the stairs' head
r.pair(BRAZIER_PEDESTAL, 16, 4, level=1) # fires flanking the altar
r.pair(PILLAR_CARVED, 14, 11)            # two pairs of tall pillars framing the axis, 8 rows apart
r.pair(PILLAR_CARVED, 14, 19)            # (a pillar stands about 6 rows tall, so closer ones would overlap)
r.pair(STATUE_GUARDIAN, 17, 24)          # guardians at the south door
r.vines(4)
r.plants(2)
r.finish()

# --- Isles (34x24): a spine of stone, a west isle with a knoll, an east isle and the altar's isle, joined by bridges --
#            x: 0123456789012345678901234567890123
r = room("isles", "TempleIsles", [
    "###############....###############",  # 0
    "#~~~~~~~~~~~~.........~~~~......~#",  # 1
    "#~~~~~~~~~~...........~~~.......~#",  # 2
    "#~~~~~~~~~.............~~~......~#",  # 3
    "#~~11111.~~~...........~~~~.....~#",  # 4
    "#~.11111.~~~...........~~~~||~~~~#",  # 5
    "#~.11111.~~~...........~~~~||~~~~#",  # 6
    "#~.1^^11.~~~~.........~~~~......~#",  # 7
    "#~........~~~.........~~~.......~#",  # 8
    "#~........~~~.........~~........~#",  # 9
    "..........~~~.........~~..........",  # 10
    "..........===.........==..........",  # 11
    "..........===.........==..........",  # 12
    "..........~~~.........~~..........",  # 13
    "#~........~~~.........~~~.......~#",  # 14
    "#~~.......~~~~.......~~~~......~~#",  # 15
    "#~~~~....~~~~~.........~~~~~~~~~~#",  # 16
    "#~~~~~~~~~~~...........~~~~~~~~~~#",  # 17
    "#~~~~~~~~~~~...........~~~~~~~~~~#",  # 18
    "#~~~~~~~~~~~~.........~~~~~~~~~~~#",  # 19
    "#~~~~~~~~~~~~.........~~~~~~~~~~~#",  # 20
    "#~~~~~~~~~~~~~.......~~~~~~~~~~~~#",  # 21
    "#~~~~~~~~~~~~~~.....~~~~~~~~~~~~~#",  # 22
    "###############....###############",  # 23
])
r.want("EnemySpawns", 7)
r.prop(ALTAR_RUNE, 29, 2)                # the altar on the isle nobody reaches but by its bridge
r.pair(BRAZIER_PEDESTAL, 14, 9)          # fires framing the crossing of the spine
r.pair(BRAZIER_PEDESTAL, 14, 14)
r.prop(STATUE_GUARDIAN, 6, 4, level=1)   # the knoll's guardian, looking over the west bridge
r.prop(ROCK_SMOKING, 28, 20)
r.prop(GEYSER, 6, 19)
r.vines(4)
r.plants(2)
r.finish()

# --- Terraces (34x24): two tiered wings up north (0 -> 1 -> 2), two daises down south, the valley between ----------
#            x: 0123456789012345678901234567890123
r = room("terraces", "TempleTerraces", [
    "###############....###############",  # 0
    "#~~~~~~~~~~~..........~~~~~~~~~~~#",  # 1
    "#~22222221111........11112222222~#",  # 2
    "#~22222221111........11112222222~#",  # 3
    "#~22222221111........11112222222~#",  # 4
    "#~22^^2221111<......>1111222^^22~#",  # 5
    "#~11111111111<......>11111111111~#",  # 6
    "#~11111111111........11111111111~#",  # 7
    "#~11111111111........11111111111~#",  # 8
    "#~..............................~#",  # 9
    "..................................",  # 10
    "..................................",  # 11
    "..................................",  # 12
    "..................................",  # 13
    "#................................#",  # 14
    "#~~111111111..........111111111~~#",  # 15
    "#~~111111111<........>111111111~~#",  # 16
    "#~~111111111<........>111111111~~#",  # 17
    "#~~111111111..........111111111~~#",  # 18
    "#~~~11111111..........11111111~~~#",  # 19
    "#~~~~~~~~~~............~~~~~~~~~~#",  # 20
    "#~~~~~~~~~~~..........~~~~~~~~~~~#",  # 21
    "#~~~~~~~~~~~~........~~~~~~~~~~~~#",  # 22
    "###############....###############",  # 23
])
r.want("EnemySpawns", 8)
r.pair(BRAZIER_PEDESTAL, 13, 2)          # fires at the north door, between the wings
r.pair(STATUE_GUARDIAN, 11, 3, level=1)  # guardians on the wings, over the way in
r.pair(BRAZIER_PEDESTAL, 3, 3, level=2)  # fires on the high blocks
r.pair(COLUMN_LOW, 5, 16, level=1)       # on the daises
r.pair(COLUMN_LOW, 9, 19, level=1)
r.pair(BANNER, 7, 9)                     # on the wings' faces
r.pair(TORCH_WALL, 7, 6)                 # sconces on the high blocks' faces
r.vines(4)
r.plants(2)
r.finish()

# --- Trap walk (34x24): bridges from every door to a walk of three landings; rocks, spikes, saws and geysers on it --
#            x: 0123456789012345678901234567890123
r = room("trap_walk", "TempleTrapWalk", [
    "###############....###############",  # 0
    "#~~~~~~~~~~~~~~||||~~~~~~~~~~~~~~#",  # 1
    "#~~~~~~~~~~~~~~||||~~~~~~~~~~~~~~#",  # 2
    "#~~~~~~....................~~~~~~#",  # 3
    "#~~~~~......................~~~~~#",  # 4
    "#~~~~~......................~~~~~#",  # 5
    "#~~~~~~....................~~~~~~#",  # 6
    "#~~~~~~~~~~~~~~||||~~~~~~~~~~~~~~#",  # 7
    "#~~~..........................~~~#",  # 8
    "#~~............................~~#",  # 9
    ".~~............................~~.",  # 10
    ".==............................==.",  # 11
    ".==............................==.",  # 12
    ".~~............................~~.",  # 13
    "#~~............................~~#",  # 14
    "#~~~..........................~~~#",  # 15
    "#~~~~~~~~~~~~~~||||~~~~~~~~~~~~~~#",  # 16
    "#~~~~~~....................~~~~~~#",  # 17
    "#~~~~~......................~~~~~#",  # 18
    "#~~~~~......................~~~~~#",  # 19
    "#~~~~~~....................~~~~~~#",  # 20
    "#~~~~~~~~~~~~~~||||~~~~~~~~~~~~~~#",  # 21
    "#~~~~~~~~~~~~~~||||~~~~~~~~~~~~~~#",  # 22
    "###############....###############",  # 23
])
r.want("EnemySpawns", 7)
# The traps, each with a visible warning and a rhythm that leaves the way open between beats: a rock
# rolls across each outer landing (dust rumbles where it will rise), a band of spikes guards the step
# from each of them onto the bridge (the slots glow before they rise), two saws sweep the central
# landing's wings beside the west and east bridges, and geysers erupt beside the way south.
r.trap(ROLLING_ROCK, 7, 4, track=20, direction=(1, 0))
r.trap(ROLLING_ROCK, 26, 19, track=20, direction=(-1, 0))
for x in r.lane_columns:
    r.trap(SPIKES, x, 6)
    r.trap(SPIKES, x, 17)
r.trap(SAW, 5, 9, track=6, direction=(0, 1))
r.trap(SAW, 28, 14, track=6, direction=(0, -1))
r.pair(GEYSER, 10, 18, hazard=True)
r.pair(GEYSER, 3, 4)                     # ambient ones in the sea
r.pair(ROCK_SMOKING, 3, 20)
r.pair(BRAZIER_PEDESTAL, 12, 6)          # fires at the landings' steps
r.pair(BRAZIER_PEDESTAL, 12, 17)
r.pair(STATUE_GUARDIAN, 10, 9)           # guardians at the central landing's north edge
r.pair(PILLAR_CARVED, 10, 14)
r.vines(4)
r.plants(2)
r.finish()

# --- Lava falls (34x24, raised): a carved ridge up north pours lava into the moat, a level-2 dais south-west ---------
#            x: 0123456789012345678901234567890123
r = room("lava_falls", "TempleLavaFalls", [
    "###############1111###############",  # 0
    "#~############~1111~############~#",  # 1
    "#~############~1111~############~#",  # 2
    "#~############~1111~############~#",  # 3
    "#~~~~~~~~~~~~~~1111~~~~~~~~~~~~~~#",  # 4
    "#~~~~~~~~~~~~~~1111~~~~~~~~~~~~~~#",  # 5
    "#~~~11111111111111111111111111~~~#",  # 6
    "#~111111111111111111111111111111~#",  # 7
    "#~111111111111111111111111111111~#",  # 8
    "#11111111111111111111111111111111#",  # 9
    "1111111111111111111111111111111111",  # 10
    "1111111111111111111111111111111111",  # 11
    "1111111111111111111111111111111111",  # 12
    "1111111111111111111111111111111111",  # 13
    "#11111111111111111111111111111111#",  # 14
    "#~22222222<111111111111111~~~~~~~#",  # 15
    "#~22222222<111111111111111~~~~~~~#",  # 16
    "#~222222221111111111111111~~~~~~~#",  # 17
    "#~222222221111111111111111~~~~~~~#",  # 18
    "#~~2222222111111111111111~~~~~~~~#",  # 19
    "#~~~~~~~~~1111111111111~~~~~~~~~~#",  # 20
    "#~~~~~~~~~~~1111111111~~~~~~~~~~~#",  # 21
    "#~~~~~~~~~~~~~~1111~~~~~~~~~~~~~~#",  # 22
    "###############1111###############",  # 23
], height=1)
r.want("EnemySpawns", 8, levels=(1, 2), region=(3, 6, 24, 19))
for x in (3, 7, 11):                     # the falls, down the ridge's carved face into the moat
    r.prop(LAVA_FALL, x, 4)
    r.prop(LAVA_FALL, r.mirror(x), 4, flip=True)
r.prop(STATUE_GUARDIAN, 5, 17, level=2)  # the guardian on the high dais
r.pair(BRAZIER_PEDESTAL, 13, 6, level=1) # fires at the causeways' ends
r.pair(BRAZIER_PEDESTAL, 13, 21, level=1)
r.pair(PILLAR_CARVED, 10, 8, level=1)    # pillars framing the way from the ridge
r.prop(GEYSER, 28, 17)
r.prop(ROCK_SMOKING, 28, 19)
r.vines(4, among=[(x, 4) for x in (5, 9, 24, 28)] + r.face_into_lava_cells())
r.plants(2, levels=(1, 2))
r.finish()

# --- Surge basin (34x24, 1 stage): a sunken basin inside a level-1 walk; every door climbs onto the walk -----------
#            x: 0123456789012345678901234567890123
r = room("surge_basin", "TempleSurgeBasin", [
    "###############....###############",  # 0
    "#~~~111111111~......~111111111~~~#",  # 1
    "#~11111111111~.vvvv.~11111111111~#",  # 2
    "#11111111111111111111111111111111#",  # 3
    "#11111111111111111111111111111111#",  # 4
    "#11111.^^^^....^^^^....^^^^.11111#",  # 5
    "#11111......................11111#",  # 6
    "#11111......................11111#",  # 7
    "#11111<....................>11111#",  # 8
    "#11111<....................>11111#",  # 9
    "....11......................11....",  # 10
    "...>11......................11<...",  # 11
    "...>11......................11<...",  # 12
    "....11......................11....",  # 13
    "#11111......................11111#",  # 14
    "#11111<....................>11111#",  # 15
    "#11111<....................>11111#",  # 16
    "#11111......................11111#",  # 17
    "#11111.vvvv....vvvv....vvvv.11111#",  # 18
    "#11111111111111111111111111111111#",  # 19
    "#11111111111111111111111111111111#",  # 20
    "#~11111111111~.^^^^.~11111111111~#",  # 21
    "#~~~111111111~......~111111111~~~#",  # 22
    "###############....###############",  # 23
], surge_stages=1)
r.want("EnemySpawns", 6, levels=(1,))
r.pair(BRAZIER_PEDESTAL, 3, 3, level=1)  # fires on the four corners of the walk
r.pair(BRAZIER_PEDESTAL, 3, 20, level=1)
r.pair(STATUE_GUARDIAN, 12, 3, level=1)  # guardians over the north door's stair
r.pair(COLUMN_LOW, 2, 7, level=1)        # on the side walks
r.pair(COLUMN_LOW, 2, 16, level=1)
r.vines(4)
r.plants(2)
r.finish()

# --- Surge tiers (42x28, 2 stages): a ziggurat of three tiers, the altar on the level-2 top where the fight ends ----
#            x: 012345678901234567890123456789012345678901
r = room("surge_tiers", "TempleSurgeTiers", [
    "###################....###################",  # 0
    "#~~~..................................~~~#",  # 1
    "#~......................................~#",  # 2
    "#.....vv...........vvvv...........vv.....#",  # 3
    "#...1111111111111111111111111111111111...#",  # 4
    "#...1111111111111111111111111111111111...#",  # 5
    "#...1111111111111111111111111111111111...#",  # 6
    "#...111111111111111vvvv111111111111111...#",  # 7
    "#...1111222222222222222222222222221111...#",  # 8
    "#...1111222222222222222222222222221111...#",  # 9
    "#...1111222222222222222222222222221111...#",  # 10
    "#...1111222222222222222222222222221111...#",  # 11
    "...>111>22222222222222222222222222<111<...",  # 12
    "...>111>22222222222222222222222222<111<...",  # 13
    "...>111>22222222222222222222222222<111<...",  # 14
    "...>111>22222222222222222222222222<111<...",  # 15
    "#...1111222222222222222222222222221111...#",  # 16
    "#...1111222222222222222222222222221111...#",  # 17
    "#...1111222222222222222222222222221111...#",  # 18
    "#...1111222222222222222222222222221111...#",  # 19
    "#...111111111111111^^^^111111111111111...#",  # 20
    "#...1111111111111111111111111111111111...#",  # 21
    "#...1111111111111111111111111111111111...#",  # 22
    "#...1111111111111111111111111111111111...#",  # 23
    "#.....^^...........^^^^...........^^.....#",  # 24
    "#~......................................~#",  # 25
    "#~~~..................................~~~#",  # 26
    "###################....###################",  # 27
], surge_stages=2)
r.want("EnemySpawns", 7, levels=(2,))
r.prop(ALTAR_RUNE, 20, 13, level=2)      # the focal piece, in the middle of the top
r.pair(BRAZIER_PEDESTAL, 10, 9, level=2) # fires on the top's corners
r.pair(BRAZIER_PEDESTAL, 10, 18, level=2)
r.pair(COLUMN_LOW, 5, 5, level=1)        # on the first tier's corners
r.pair(COLUMN_LOW, 5, 22, level=1)
r.pair(TORCH_WALL, 12, 20)               # sconces on the top's south face
r.vines(4)
r.plants(2)
r.finish()

# --- Surge bridges (42x28, 2 stages): a moat crossed by decks from every stair, the level-2 isle in the middle -------
#            x: 012345678901234567890123456789012345678901
r = room("surge_bridges", "TempleSurgeBridges", [
    "###################....###################",  # 0
    "#~~....................................~~#",  # 1
    "#~......................................~#",  # 2
    "#.....vv...........vvvv...........vv.....#",  # 3
    "#...~~bb~~~~~~~~~~~bbbb~~~~~~~~~~~bb~~...#",  # 4
    "#...~~bb~~~~~~~~~~~bbbb~~~~~~~~~~~bb~~...#",  # 5
    "#...~~111111111111111111111111111111~~...#",  # 6
    "#...~~111111111111111111111111111111~~...#",  # 7
    "#...~~1111111111111vvvv1111111111111~~...#",  # 8
    "#...~~111222222222222222222222222111~~...#",  # 9
    "#...~~111222222222222222222222222111~~...#",  # 10
    "#...~~111222222222222222222222222111~~...#",  # 11
    "...>bb11>222222222222222222222222<11bb<...",  # 12
    "...>bb11>222222222222222222222222<11bb<...",  # 13
    "...>bb11>222222222222222222222222<11bb<...",  # 14
    "...>bb11>222222222222222222222222<11bb<...",  # 15
    "#...~~111222222222222222222222222111~~...#",  # 16
    "#...~~111222222222222222222222222111~~...#",  # 17
    "#...~~111222222222222222222222222111~~...#",  # 18
    "#...~~1111111111111^^^^1111111111111~~...#",  # 19
    "#...~~111111111111111111111111111111~~...#",  # 20
    "#...~~111111111111111111111111111111~~...#",  # 21
    "#...~~bb~~~~~~~~~~~bbbb~~~~~~~~~~~bb~~...#",  # 22
    "#...~~bb~~~~~~~~~~~bbbb~~~~~~~~~~~bb~~...#",  # 23
    "#.....^^...........^^^^...........^^.....#",  # 24
    "#~......................................~#",  # 25
    "#~~....................................~~#",  # 26
    "###################....###################",  # 27
], surge_stages=2)
r.want("EnemySpawns", 7, levels=(2,))
r.pair(STATUE_GUARDIAN, 17, 10, level=2) # the isle's guardians, flanking the north stair's head
r.pair(BRAZIER_PEDESTAL, 10, 10, level=2) # fires on the isle's corners
r.pair(BRAZIER_PEDESTAL, 10, 17, level=2)
r.pair(COLUMN_LOW, 12, 7, level=1)       # on the ring, by the north decks
r.pair(TORCH_WALL, 14, 19)               # sconces on the isle's south face
r.vines(4)
r.plants(2)
r.finish()

# --- Sanctum (26x20, reward): a wide floor, the chest's shrine on an isle reached by one bridge --------------------
#            x: 01234567890123456789012345
r = room("sanctum", "TempleSanctum", [
    "###########....###########",  # 0
    "#~~~~~~~........~~......~#",  # 1
    "#~~~~~~.........~~......~#",  # 2
    "#~~~~~..........~~......~#",  # 3
    "#~~~~...........~~~~||~~~#",  # 4
    "#~~~............~~~~||~~~#",  # 5
    "#~~......................#",  # 6
    "#~.......................#",  # 7
    "..........................",  # 8
    "..........................",  # 9
    "..........................",  # 10
    "..........................",  # 11
    "#~......................~#",  # 12
    "#~~~...........~~~.....~~#",  # 13
    "#~~~~..........~~~~...~~~#",  # 14
    "#~~~~~~............~~~~~~#",  # 15
    "#~~~~~~~..........~~~~~~~#",  # 16
    "#~~~~~~~~........~~~~~~~~#",  # 17
    "#~~~~~~~~~......~~~~~~~~~#",  # 18
    "###########....###########",  # 19
])
r.marker("ChestSpawn", 20, 2)
r.prop(BRAZIER_PEDESTAL, 18, 2)          # the shrine's fires
r.prop(BRAZIER_PEDESTAL, 23, 2, flip=True)
r.prop(STATUE_GUARDIAN, 18, 6)           # the guardians flank the bridge's foot, never on it
r.prop(STATUE_GUARDIAN, 23, 6, flip=True)
r.pair(PILLAR_CARVED, 6, 12)             # pillars framing the way east
r.prop(COLUMN_BROKEN, 7, 3)
r.prop(GEYSER, 20, 16)
r.prop(ROCK_SMOKING, 3, 15)
r.vines(3)
r.plants(2)
r.finish()

# --- Event (26x20): a quiet shrine on a raised step, a lava channel crossed by a bridge on the way east -------------
#            x: 01234567890123456789012345
r = room("event", "TempleEvent", [
    "###########....###########",  # 0
    "#~~~~~~~~~.......~~~~~~~~#",  # 1
    "#~~111111........~~~....~#",  # 2
    "#~.111111.........~~~...~#",  # 3
    "#~.111111..........~~~..~#",  # 4
    "#..111111..........~~~...#",  # 5
    "#....^^.............~~~..#",  # 6
    "#...................~~~..#",  # 7
    "....................~~~...",  # 8
    "....................===...",  # 9
    "....................===...",  # 10
    "....................~~~...",  # 11
    "#..................~~~...#",  # 12
    "#~~...............~~~...~#",  # 13
    "#~~~~.............~~~..~~#",  # 14
    "#~~~~~~..........~~~~~~~~#",  # 15
    "#~~~~~~~~........~~~~~~~~#",  # 16
    "#~~~~~~~~~......~~~~~~~~~#",  # 17
    "#~~~~~~~~~~....~~~~~~~~~~#",  # 18
    "###########....###########",  # 19
])
r.marker("NpcSpawn", 9, 7)
r.prop(ALTAR_RUNE, 6, 3, level=1)        # the shrine's altar
r.prop(BRAZIER_PEDESTAL, 3, 4, level=1)
r.prop(BRAZIER_PEDESTAL, 8, 4, flip=True, level=1)
r.prop(STATUE_GUARDIAN, 6, 13)           # a guardian across the way, facing the shrine
r.pair(BRAZIER_PEDESTAL, 9, 15)          # fires at the south landing
r.prop(COLUMN_BROKEN, 22, 4)
r.prop(BANNER, 4, 2, level=1)
r.prop(TORCH_WALL, 4, 6)
r.prop(TORCH_WALL, 7, 6, flip=True)
r.prop(GEYSER, 19, 13)
r.vines(3)
r.plants(2)
r.finish()

# --- Special (26x20): a ziggurat up north, three tiers to the altar, a pool on each side down south -----------------
#            x: 01234567890123456789012345
r = room("special", "TempleSpecial", [
    "###########....###########",  # 0
    "#~~....................~~#",  # 1
    "#~....11122222222111....~#",  # 2
    "#.....11122222222111.....#",  # 3
    "#.....11122222222111.....#",  # 4
    "#.....111111^^111111.....#",  # 5
    "#.....11111111111111.....#",  # 6
    "#..........^^^^..........#",  # 7
    "..........................",  # 8
    "..........................",  # 9
    "..........................",  # 10
    "..........................",  # 11
    "#~......................~#",  # 12
    "#~.....~~~......~~~.....~#",  # 13
    "#~~....~~~~....~~~~....~~#",  # 14
    "#~~~...~~~......~~~...~~~#",  # 15
    "#~~~~~..............~~~~~#",  # 16
    "#~~~~~~~..........~~~~~~~#",  # 17
    "#~~~~~~~~~......~~~~~~~~~#",  # 18
    "###########....###########",  # 19
])
r.marker("SpecialSpawn", 12, 12)
r.prop(ALTAR_RUNE, 12, 2, level=2)       # the altar on the top of the ziggurat, behind the stair's head
r.pair(BRAZIER_PEDESTAL, 9, 3, level=2)  # fires on the top tier
r.pair(STATUE_GUARDIAN, 7, 2, level=1)   # guardians on the first tier's top corners
r.pair(COLUMN_LOW, 3, 7)                 # by the way in
r.pair(TORCH_WALL, 8, 7)                 # sconces on the first tier's face
r.prop(GEYSER, 8, 14)
r.prop(GEYSER, 17, 14, flip=True)
r.vines(3)
r.plants(2)
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
