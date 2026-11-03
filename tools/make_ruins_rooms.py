"""Generates the ruins room scenes in scenes/levels/rooms/ruins/.
Run from the repo root: python tools/make_ruins_rooms.py [--show]

Each room is a scene inheriting room_base.tscn with a RuinShape node (the room's outline as text:
rock, floor, river, bridge, waterfall) and RuinProp nodes (crystals, pillars, platforms...), plus spawn
markers. The shapes are drawn by this script with a seed per room (blobs of rock bitten out of the
rectangle, rivers that wind, pools under waterfalls), so every room is an irregular cave and not a
box; after generating, the .tscn files are normal scenes you can edit by hand in Godot (the shape is
18 lines of 30 characters, see scripts/world/ruin_shape.gd). `--show` prints every shape.

Rooms are 30x18 tiles (16 px); coordinates below are in TILES. The script checks the design:
  - the central lanes (columns 13..16 and rows 7..10) are walkable and free of solid props, so every
    door is reachable from every other door;
  - every walkable cell can be reached from the middle of the room;
  - solid props stand on floor and spawn markers on walkable cells outside any solid prop;
  - the tiles in front of a platform's stairs stay free, so the stairs can be reached;
  - a raised room (RoomData.height 1, see tools/make_ruins_data.gd) has no water, terraces or alcoves.
"""
import math
import os
import random
import sys
import zlib
from collections import deque

OUT = "scenes/levels/rooms/ruins"
os.makedirs(OUT, exist_ok=True)
SHOW = "--show" in sys.argv

TILE = 16
COLUMNS, ROWS = 30, 18
LANE_COLUMNS = range(13, 17)
LANE_ROWS = range(7, 11)
CENTER = (14, 8)

# RuinProp.Kind values (keep in sync with scripts/world/ruin_prop.gd)
ROCKS, STALAGMITE, BOULDER, PILLAR, CRYSTAL, STELE, BRAZIER, TORCH, BANNER, CRATE, BARREL, BRIDGE, WATERFALL, TERRACE, ALCOVE, RIVER, SPIKES = range(17)
SOLID = {ROCKS, STALAGMITE, BOULDER, PILLAR, CRYSTAL, STELE, BRAZIER, TORCH, CRATE, BARREL, TERRACE, ALCOVE}
TALL = {PILLAR, CRYSTAL, STELE, BANNER}
AREAS = {ROCKS, TERRACE, ALCOVE}
PLATFORMS = {TERRACE, ALCOVE}


def footprint(kind, x, y, size=(1, 1)):
    """Tiles covered by a prop (tall ones cover crown and base)."""
    if kind in TALL:
        size = (1, 2)
    elif kind not in AREAS:
        size = (1, 1)
    return [(x + i, y + j) for i in range(size[0]) for j in range(size[1])]


class Room:
    def __init__(self, filename, node_name, raised=False, seed=0):
        self.filename, self.node_name, self.raised = filename, node_name, raised
        self.rng = random.Random(zlib.crc32(filename.encode()) + seed)
        self.g = [["#"] * COLUMNS for _ in range(ROWS)]
        for y in range(1, ROWS - 1):
            for x in range(1, COLUMNS - 1):
                self.g[y][x] = "."
        self.props = []
        self.spawns = {}
        self.player_spawn = None
        self.reserved = set()   # cells that must stay floor (lanes, stairs fronts)
        self.lanes()

    # --- the plan ------------------------------------------------------------------------------------------------
    def inside(self, x, y):
        return 1 <= x <= COLUMNS - 2 and 1 <= y <= ROWS - 2

    def lanes(self):
        for y in range(1, ROWS - 1):
            for x in LANE_COLUMNS:
                self.reserved.add((x, y))
        for x in range(1, COLUMNS - 1):
            for y in LANE_ROWS:
                self.reserved.add((x, y))

    def blob(self, cx, cy, rx, ry, char="#", rough=0.35, only_on="."):
        """An irregular ellipse of `char`, never over a reserved cell and only over `only_on` cells."""
        for y in range(1, ROWS - 1):
            for x in range(1, COLUMNS - 1):
                if (x, y) in self.reserved or (only_on and self.g[y][x] not in only_on):
                    continue
                d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if d <= 1.0 + self.rng.uniform(-rough, rough) * (1.0 if d > 0.4 else 0.0):
                    self.g[y][x] = char

    def fill(self, char, only_on=".", keep_reserved=True):
        for y in range(1, ROWS - 1):
            for x in range(1, COLUMNS - 1):
                if keep_reserved and (x, y) in self.reserved:
                    continue
                if self.g[y][x] in only_on:
                    self.g[y][x] = char

    def edge_blobs(self, count, size=(2.0, 4.5)):
        """Rock bitten into the room from its four walls."""
        for _ in range(count):
            side = self.rng.choice("tblr")
            r1, r2 = self.rng.uniform(*size), self.rng.uniform(*size)
            if side == "t":
                self.blob(self.rng.uniform(2, COLUMNS - 3), 0.5, r1 * 1.3, r2)
            elif side == "b":
                self.blob(self.rng.uniform(2, COLUMNS - 3), ROWS - 1.5, r1 * 1.3, r2)
            elif side == "l":
                self.blob(0.5, self.rng.uniform(2, ROWS - 3), r2 * 0.8, r1)
            else:
                self.blob(COLUMNS - 1.5, self.rng.uniform(2, ROWS - 3), r2 * 0.8, r1)

    def islands(self, spots, radius=(1.2, 2.4)):
        """Rock columns standing in the room (the plan's pillars of rock)."""
        for cx, cy in spots:
            self.blob(cx + self.rng.uniform(-1.5, 1.5), cy + self.rng.uniform(-1, 1), self.rng.uniform(*radius), self.rng.uniform(*radius))

    def smooth(self, rounds=2):
        """Rounds the corners: a floor cell with five or more rock neighbours becomes rock, a rock cell
        with five or more floor neighbours becomes floor."""
        for _ in range(rounds):
            nxt = [row[:] for row in self.g]
            for y in range(1, ROWS - 1):
                for x in range(1, COLUMNS - 1):
                    if (x, y) in self.reserved or self.g[y][x] not in ".#":
                        continue
                    rock = sum(1 for dx in (-1, 0, 1) for dy in (-1, 0, 1) if (dx or dy) and self.g[y + dy][x + dx] == "#")
                    if self.g[y][x] == "." and rock >= 6:
                        nxt[y][x] = "#"
                    elif self.g[y][x] == "#" and rock <= 2 and self.inside(x, y):
                        nxt[y][x] = "."
            self.g = nxt

    def walkable(self, x, y):
        return self.g[y][x] in ".="

    def connect(self):
        """Rock over every floor pocket the lanes cannot reach."""
        seen = {CENTER}
        queue = deque([CENTER])
        while queue:
            x, y = queue.popleft()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if self.inside(nx, ny) and (nx, ny) not in seen and self.walkable(nx, ny):
                    seen.add((nx, ny))
                    queue.append((nx, ny))
        for y in range(1, ROWS - 1):
            for x in range(1, COLUMNS - 1):
                if self.g[y][x] == "." and (x, y) not in seen:
                    self.g[y][x] = "#"
        return seen

    def thin_water(self):
        """Water needs two cells of width in both directions, or its shore tiles look wrong."""
        changed = True
        while changed:
            changed = False
            for y in range(1, ROWS - 1):
                for x in range(1, COLUMNS - 1):
                    if self.g[y][x] != "~":
                        continue
                    wet = lambda cx, cy: self.g[cy][cx] in "~=rw"
                    if not (wet(x - 1, y) or wet(x + 1, y)) or not (wet(x, y - 1) or wet(x, y + 1)):
                        self.g[y][x] = "."
                        changed = True

    def river(self, x_center, phase, width=3, amplitude=1.8, period=3.0):
        """A river that winds from the north wall to the south wall, crossed by a bridge on the lane."""
        for y in range(1, ROWS - 1):
            # Straight where the bridge crosses, so its planks line up.
            bend = min(1.0, max(0.0, (abs(y - 8.5) - 2.5) / 2.0))
            xc = round(x_center + bend * amplitude * math.sin(y / period + phase) + (1 - bend) * amplitude * math.sin(8.5 / period + phase))
            for x in range(1, COLUMNS - 1):
                if abs(x - xc) <= width / 2.0 and self.g[y][x] != "#" or (abs(x - xc) <= width / 2.0 and self.g[y][x] == "#" and y in (1, ROWS - 2)):
                    if (x, y) in self.reserved and y not in LANE_ROWS:
                        continue
                    self.g[y][x] = "~"
        for y in LANE_ROWS:
            for x in range(1, COLUMNS - 1):
                if self.g[y][x] == "~":
                    self.g[y][x] = "r" if y in (7, 10) else "="

    # --- props ---------------------------------------------------------------------------------------------------
    def cells(self, char="."):
        return [(x, y) for y in range(1, ROWS - 1) for x in range(1, COLUMNS - 1) if self.g[y][x] == char]

    def near(self, x, y, chars="#~w", d=1):
        return any(self.g[y + dy][x + dx] in chars for dx in range(-d, d + 1) for dy in range(-d, d + 1)
                   if 0 <= y + dy < ROWS and 0 <= x + dx < COLUMNS)

    def occupied(self):
        taken = set()
        for prop in self.props:
            size = prop[3] if len(prop) > 3 else (1, 1)
            for tx, ty in footprint(prop[0], prop[1], prop[2], size):
                taken.add((tx, ty))
        for points in self.spawns.values():
            for px, py in points:
                taken.add((px // TILE, py // TILE))
        if self.player_spawn:
            taken.add((self.player_spawn[0] // TILE, self.player_spawn[1] // TILE))
        return taken

    def can_put(self, kind, x, y, size=(1, 1), margin=0):
        taken = self.occupied()
        for tx, ty in footprint(kind, x, y, size):
            if not self.inside(tx, ty) or self.g[ty][tx] != ".":
                return False
            if kind in SOLID and (tx, ty) in self.reserved:
                return False
            for dx in range(-margin, margin + 1):
                for dy in range(-margin, margin + 1):
                    if (tx + dx, ty + dy) in taken:
                        return False
        return True

    def put(self, kind, x, y, size=None, margin=0):
        if self.can_put(kind, x, y, size or (1, 1), margin):
            self.props.append((kind, x, y, size) if size else (kind, x, y))
            return True
        return False

    def scatter(self, kind, count, near_rock=None, min_dist=4, margin=1, region=None, tries=500):
        """Props at free floor cells chosen by the room's seed: near a rock edge (True), away from
        every wall (False) or anywhere (None); never closer than `min_dist` to another of their kind."""
        placed = []
        for _ in range(tries):
            if len(placed) == count:
                break
            x = self.rng.randint(1, COLUMNS - 2)
            y = self.rng.randint(1, ROWS - 2)
            if region and not (region[0] <= x <= region[2] and region[1] <= y <= region[3]):
                continue
            if near_rock is True and not self.near(x, y):
                continue
            if near_rock is False and self.near(x, y, d=2):
                continue
            if any(math.hypot(x - px, y - py) < min_dist for px, py in placed):
                continue
            if self.put(kind, x, y, margin=margin):
                placed.append((x, y))
        return placed

    def put_near(self, kind, wanted, size=None, radius=3, margin=0):
        """The prop at the free spot closest to `wanted` (a plan that moved the floor around it)."""
        for r in range(radius + 1):
            for dx in range(-r, r + 1):
                for dy in range(-r, r + 1):
                    if max(abs(dx), abs(dy)) == r and self.put(kind, wanted[0] + dx, wanted[1] + dy, size, margin):
                        return True
        return False

    def platform(self, kind, x, y, size):
        """A terrace or alcove: its footprint and the tiles in front of its stairs are floor."""
        w, h = size
        for tx in range(x, x + w):
            for ty in range(y, y + h):
                self.g[ty][tx] = "."
        stairs = x + w // 2 - 1
        for tx in range(stairs - 2, stairs + 4):
            for ty in range(y + h, y + h + 3):
                if self.inside(tx, ty):
                    self.g[ty][tx] = "."
                    self.reserved.add((tx, ty))
        self.props.append((kind, x, y, size))

    def marker_near(self, wanted, radius=6):
        """The pixel position of the free floor cell closest to the tile `wanted`."""
        taken = self.occupied()
        best = None
        for x, y in self.cells():
            if (x, y) in taken or self.near(x, y, "#~wr=", 1):
                continue
            d = math.hypot(x - wanted[0], y - wanted[1])
            if d <= radius and (best is None or d < best[0]):
                best = (d, x, y)
        assert best is not None, f"{self.filename}: no floor near {wanted}"
        return (best[1] * TILE + 8, best[2] * TILE + 8)

    def spawn_points(self, count, avoid_edge=2):
        """Enemy spots spread over the room (farthest point first), away from rock and water."""
        candidates = [(x, y) for x, y in self.cells() if not self.near(x, y, "#~wr=", avoid_edge) and (x, y) not in self.occupied()]
        if not candidates:
            candidates = [(x, y) for x, y in self.cells() if (x, y) not in self.occupied()]
        chosen = [self.rng.choice(candidates)]
        while len(chosen) < count and len(chosen) < len(candidates):
            best = max(candidates, key=lambda c: min(math.hypot(c[0] - o[0], c[1] - o[1]) for o in chosen))
            chosen.append(best)
        return [(x * TILE + 8, y * TILE + 8) for x, y in chosen]

    # --- check and write --------------------------------------------------------------------------------------------
    def finish(self):
        self.smooth_done = True
        solid = set()
        for prop in self.props:
            kind, x, y = prop[0], prop[1], prop[2]
            size = prop[3] if len(prop) > 3 else (1, 1)
            if self.raised:
                assert kind not in (TERRACE, ALCOVE), f"{self.filename}: a raised room has no platforms"
            for tx, ty in footprint(kind, x, y, size):
                assert self.inside(tx, ty), f"{self.filename}: prop outside the room at {(tx, ty)}"
                if kind in (BANNER,):
                    continue
                if kind in SOLID:
                    assert self.g[ty][tx] == ".", f"{self.filename}: solid prop {kind} on {self.g[ty][tx]!r} at {(tx, ty)}"
                    assert (tx, ty) not in self.reserved or kind in PLATFORMS, f"{self.filename}: solid prop {kind} blocks a lane at {(tx, ty)}"
                    solid.add((tx, ty))
        for kind_prop in self.props:
            if kind_prop[0] in PLATFORMS:
                x, y, (w, h) = kind_prop[1], kind_prop[2], kind_prop[3]
                stairs = x + w // 2 - 1
                for tx in range(stairs - 1, stairs + 3):
                    for ty in (y + h, y + h + 1):
                        assert self.g[ty][tx] == "." and (tx, ty) not in solid, f"{self.filename}: stairs of {(x, y)} blocked at {(tx, ty)}"
        for y in range(1, ROWS - 1):
            for x in range(1, COLUMNS - 1):
                if (x in LANE_COLUMNS or y in LANE_ROWS) and self.g[y][x] in "#w":
                    raise AssertionError(f"{self.filename}: lane blocked by rock at {(x, y)}")
        walk = self.connect()
        for x in range(1, COLUMNS - 1):
            assert any((x, y) in walk for y in LANE_ROWS), f"{self.filename}: the lane rows are cut at x={x}"
        for y in range(1, ROWS - 1):
            assert any((x, y) in walk for x in LANE_COLUMNS), f"{self.filename}: the lane columns are cut at y={y}"
        platform_tops = set()
        for prop in self.props:
            if prop[0] in PLATFORMS:
                x, y, (w, h) = prop[1], prop[2], prop[3]
                platform_tops.update((x + i, y + j) for i in range(1, w - 1) for j in range(1, h - 2))
        for container, points in self.spawns.items():
            for px, py in points:
                tile = (px // TILE, py // TILE)
                assert self.inside(*tile) and (self.walkable(*tile) or tile in platform_tops), f"{self.filename}: {container} marker {px, py} is not on the floor"
                assert tile not in (solid - platform_tops), f"{self.filename}: {container} marker {px, py} is inside a solid prop"
        if self.player_spawn:
            tile = (self.player_spawn[0] // TILE, self.player_spawn[1] // TILE)
            assert self.walkable(*tile), f"{self.filename}: the player spawn is not on the floor"
        self.write()

    def rows_text(self):
        return "\n".join("".join(row) for row in self.g)

    def write(self):
        if SHOW:
            print(f"--- {self.filename}")
            print(self.rows_text())
        text = ['[gd_scene load_steps=4 format=3]\n',
                '[ext_resource type="PackedScene" path="res://scenes/levels/rooms/room_base.tscn" id="1"]',
                '[ext_resource type="Script" path="res://scripts/world/ruin_prop.gd" id="2"]',
                '[ext_resource type="Script" path="res://scripts/world/ruin_shape.gd" id="3"]\n',
                f'[node name="{self.node_name}" instance=ExtResource("1")]\n',
                '[node name="Shape" type="Node2D" parent="."]\nscript = ExtResource("3")\nrows = "' + self.rows_text() + '"\n']
        for number, prop in enumerate(self.props, start=1):
            kind, x, y = prop[0], prop[1], prop[2]
            size = prop[3] if len(prop) > 3 else None
            block = [f'[node name="Prop{number}" type="Node2D" parent="."]',
                     f'position = Vector2({x * TILE}, {y * TILE})',
                     'script = ExtResource("2")']
            if kind != 0:
                block.append(f'kind = {kind}')
            if size:
                block.append(f'size_tiles = Vector2i({size[0]}, {size[1]})')
            text.append("\n".join(block) + "\n")
        if self.player_spawn:
            text.append(f'[node name="PlayerSpawn" type="Marker2D" parent="."]\nposition = Vector2{self.player_spawn}\n')
        for container, points in self.spawns.items():
            text.append(f'[node name="{container}" type="Node2D" parent="."]\n')
            for i, (px, py) in enumerate(points):
                text.append(f'[node name="P{i + 1}" type="Marker2D" parent="{container}"]\nposition = Vector2({px}, {py})\n')
        with open(f"{OUT}/{self.filename}.tscn", "w", newline="\n") as f:
            f.write("\n".join(text))


def lit(room, crystals, torches, braziers=0):
    """The lights of a room: crystals and torches against the rock, braziers in the open."""
    room.scatter(CRYSTAL, crystals, near_rock=True, min_dist=7)
    room.scatter(TORCH, torches, near_rock=True, min_dist=6)
    if braziers:
        room.scatter(BRAZIER, braziers, near_rock=False, min_dist=7)


# --- Start: a cavern with a lit landing ------------------------------------------------------------------------------
r = Room("start", "RuinsStart")
r.edge_blobs(10)
r.islands([(6, 5), (23, 5), (6, 12), (23, 12)])
r.smooth()
r.connect()
r.player_spawn = (240, 144)
lit(r, 4, 3)
r.scatter(STELE, 2, near_rock=True, min_dist=10)
r.scatter(BOULDER, 3, min_dist=5)
r.scatter(STALAGMITE, 3, min_dist=5)
r.finish()

# --- Boss (raised): a round arena in the rock, ringed by pillars, crystals and braziers ------------------------
r = Room("boss", "RuinsBoss", raised=True)
r.fill("#")
r.blob(14.5, 8.5, 12.5, 7.2, char=".", only_on="#", rough=0.12)
for y in (1, 2):
    r.g[y][15] = r.g[y][14] = "."
r.smooth(1)
r.connect()
r.player_spawn = (240, 232)
r.spawns = {"BossSpawn": [(240, 88)], "ExitSpawn": [(240, 40)]}
r.scatter(CRYSTAL, 4, near_rock=True, min_dist=8)
r.scatter(PILLAR, 4, near_rock=True, min_dist=8)
r.scatter(BRAZIER, 4, near_rock=False, min_dist=7)
r.scatter(BOULDER, 2, min_dist=6)
for x in range(3, 27):
    if r.g[1][x] == "." and r.g[0][x] == "#" or (r.g[2][x] == "." and r.g[1][x] == "#"):
        pass
r.finish()

# --- Combat: two winding rivers crossed by bridges on the way to the doors ------------------------------------------
r = Room("river", "RuinsRiver")
r.edge_blobs(6, size=(1.5, 3.2))
r.river(6.5, 0.4)
r.river(23.5, 2.6)
r.smooth(1)
r.thin_water()
r.connect()
lit(r, 4, 4)
r.scatter(STALAGMITE, 4, near_rock=False, min_dist=5)
r.scatter(BOULDER, 2, min_dist=5)
r.spawns = {"EnemySpawns": r.spawn_points(6)}
r.finish()

# --- Combat (ambush): blocks of rock leave narrow passages, enemies jump out of them ----------------------------------
r = Room("narrow", "RuinsNarrow")
r.edge_blobs(9, size=(2.2, 5.0))
r.islands([(8, 4), (21, 4), (8, 13), (21, 13), (11, 6), (18, 11)], radius=(1.6, 3.0))
r.smooth()
r.connect()
lit(r, 4, 2)
r.scatter(STALAGMITE, 5, min_dist=4)
for cell in r.scatter(SPIKES, 3, near_rock=False, min_dist=6, margin=2):
    pass
r.spawns = {"EnemySpawns": r.spawn_points(6)}
r.finish()

# --- Combat: two raised platforms with their stairs on the south side ------------------------------------------------
r = Room("terraces", "RuinsTerraces")
r.edge_blobs(10, size=(2.0, 4.0))
r.islands([(14.5, 13.5)], radius=(1.0, 1.6))
r.platform(TERRACE, 2, 2, (10, 5))
r.platform(TERRACE, 18, 2, (10, 5))
r.smooth(1)
r.connect()
lit(r, 3, 2, 1)
r.scatter(PILLAR, 2, near_rock=False, min_dist=8, region=(2, 11, 27, 16))
r.scatter(BARREL, 1, region=(10, 3, 12, 6))
r.scatter(CRATE, 1, region=(10, 3, 12, 6))
r.spawns = {"EnemySpawns": r.spawn_points(6)}
r.finish()

# --- Combat (raised): a wide plateau with pillars and braziers ---------------------------------------------------------
r = Room("plateau", "RuinsPlateau", raised=True)
r.edge_blobs(8, size=(1.8, 3.6))
r.islands([(8, 5), (21, 5), (8, 12), (21, 12)], radius=(1.0, 1.8))
r.smooth()
r.connect()
r.scatter(PILLAR, 4, near_rock=False, min_dist=6)
r.scatter(BRAZIER, 4, near_rock=False, min_dist=7)
r.scatter(BOULDER, 3, min_dist=5)
r.scatter(STALAGMITE, 3, min_dist=5)
r.spawns = {"EnemySpawns": r.spawn_points(6)}
r.finish()

# --- Combat (watch): two waterfalls feed pools in a cave; enemies stand guard around them -------------------------
r = Room("falls", "RuinsFalls")
r.edge_blobs(7, size=(1.8, 3.8))
for fall_x, pool in ((4, (5.0, 7.0)), (24, (25.0, 7.0))):
    for y in (1, 2, 3):
        for x in (fall_x, fall_x + 1):
            r.g[y][x] = "w"
    for y in (1, 2, 3, 4):
        for x in (fall_x - 1, fall_x + 2):
            if r.g[y][x] == ".":
                r.g[y][x] = "#"
    r.blob(pool[0], 5.2, 3.2, 2.2, char="~", rough=0.2)
    for x in (fall_x, fall_x + 1):
        if r.g[4][x] == ".":
            r.g[4][x] = "~"
r.smooth(1)
r.thin_water()
r.connect()
lit(r, 4, 3)
r.scatter(BOULDER, 3, near_rock=False, min_dist=5)
r.scatter(STALAGMITE, 3, min_dist=5)
r.scatter(SPIKES, 3, near_rock=False, min_dist=6, margin=2)
r.spawns = {"EnemySpawns": r.spawn_points(7)}
r.finish()

# --- Event: the Viajera's camp ---------------------------------------------------------------------------------------------------
r = Room("event", "RuinsEvent")
r.edge_blobs(8, size=(1.8, 3.6))
r.islands([(7, 5), (23, 13)], radius=(1.0, 1.8))
r.smooth()
r.connect()
r.scatter(BRAZIER, 2, near_rock=False, min_dist=7)
lit(r, 2, 3)
r.put_near(CRATE, (24, 12))
r.put_near(CRATE, (25, 12))
r.put_near(BARREL, (24, 13))
r.scatter(STELE, 2, near_rock=True, min_dist=8)
r.scatter(BOULDER, 2, min_dist=5)
r.spawns = {"NpcSpawn": [r.marker_near((7, 6))]}
r.finish()

# --- Reward: an alcove (a small room) with the chest, reached by its own stairs --------------------------------------
r = Room("reward", "RuinsReward")
r.edge_blobs(10, size=(2.0, 4.0))
r.platform(ALCOVE, 2, 2, (8, 5))
r.smooth(1)
r.connect()
lit(r, 3, 2, 1)
r.scatter(PILLAR, 1, near_rock=False, min_dist=8, region=(18, 2, 27, 6))
r.scatter(STALAGMITE, 3, min_dist=5)
r.spawns = {"ChestSpawn": [(88, 56)]}
r.finish()

# --- Special: a shrine of crystals around the middle -----------------------------------------------------------------------
r = Room("special", "RuinsSpecial")
r.edge_blobs(10, size=(2.0, 4.2))
r.smooth()
r.connect()
for wanted in ((8, 4), (21, 4), (8, 12), (21, 12)):
    r.put_near(CRYSTAL, wanted, radius=4)
for wanted in ((11, 6), (18, 6), (11, 11), (18, 11)):
    r.put_near(BRAZIER, wanted, radius=3)
r.scatter(STELE, 2, near_rock=True, min_dist=8)
r.scatter(BOULDER, 2, min_dist=5)
r.spawns = {"SpecialSpawn": [(240, 144)]}
r.finish()

print("ruins rooms written and validated")
