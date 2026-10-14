"""Generates the forest room scenes in scenes/levels/rooms/forest/.
Run from the repo root: python tools/make_forest_rooms.py

Each room is a scene inheriting room_base.tscn with RoomProp nodes (trees, ponds...) and spawn
markers. After generating, the .tscn files are normal scenes you can edit by hand in Godot.

Rooms are 30x18 tiles (16 px). Coordinates below are in TILES. The generator checks the design:
  - nothing solid may cross the central lanes (columns 13..16 and rows 7..10), so every door is
    reachable from every other door;
  - spawn markers must be inside the room and not inside a solid prop.
"""
import os
import random
import zlib

OUT = "scenes/levels/rooms/forest"
os.makedirs(OUT, exist_ok=True)

TILE = 16
COLUMNS, ROWS = 30, 18
LANE_COLUMNS = range(13, 17)
LANE_ROWS = range(7, 11)

# RoomProp.Kind values (keep in sync with scripts/world/room_prop.gd)
PINE, TALL_PINE, ROUND_TREE, TALL_ROUND_TREE, BUSH, POND, PLANKS, DIRT_PATCH, CAMPFIRE, LOGS, TUFT = range(11)
SOLID = {PINE, TALL_PINE, ROUND_TREE, TALL_ROUND_TREE, BUSH, POND, CAMPFIRE, LOGS}
TALL = {TALL_PINE, TALL_ROUND_TREE}


def footprint(kind, x, y, size=(1, 1)):
    """Tiles covered by a prop (tall trees cover crown and trunk)."""
    if kind in TALL:
        size = (1, 2)
    elif kind not in (POND, PLANKS, DIRT_PATCH):
        size = (1, 1)
    return [(x + i, y + j) for i in range(size[0]) for j in range(size[1])]


def scatter_props(filename, props, spawns, player_spawn, counts):
    """Adds `counts` = [(kind, how_many)] extra props at deterministic random free spots: never on
    the central lanes, never next to another prop, never on or next to a spawn marker."""
    rng = random.Random(zlib.crc32(filename.encode()))
    taken = set()
    for prop in props:
        size = prop[3] if len(prop) > 3 else (1, 1)
        for tx, ty in footprint(prop[0], prop[1], prop[2], size):
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    taken.add((tx + dx, ty + dy))
    markers = [p for points in spawns.values() for p in points]
    if player_spawn:
        markers.append(player_spawn)
    for px, py in markers:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                taken.add((px // TILE + dx, py // TILE + dy))

    extra = []
    for kind, how_many in counts:
        placed = 0
        for _ in range(400):
            if placed == how_many:
                break
            x = rng.randint(1, COLUMNS - 2)
            y = rng.randint(1, ROWS - 2)
            tiles = footprint(kind, x, y)
            if any(not (1 <= tx <= COLUMNS - 2 and 1 <= ty <= ROWS - 2) or tx in LANE_COLUMNS or ty in LANE_ROWS
                   or (tx, ty) in taken for tx, ty in tiles):
                continue
            extra.append((kind, x, y))
            for tx, ty in tiles:
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        taken.add((tx + dx, ty + dy))
            placed += 1
    return props + extra


def build(filename, node_name, props, spawns=None, player_spawn=None, scatter=None):
    """props: [(kind, x, y)] or [(kind, x, y, (w, h))]; spawns: {container: [(x_px, y_px)]};
    scatter: [(kind, count)] extra decoration placed automatically (see scatter_props)."""
    spawns = spawns or {}
    if scatter:
        props = scatter_props(filename, props, spawns, player_spawn, scatter)
    solid_tiles = set()
    for prop in props:
        kind, x, y = prop[0], prop[1], prop[2]
        size = prop[3] if len(prop) > 3 else (1, 1)
        tiles = footprint(kind, x, y, size)
        if kind in SOLID:
            for tx, ty in tiles:
                assert 1 <= tx <= COLUMNS - 2 and 1 <= ty <= ROWS - 2, f"{filename}: prop outside the room at {(tx, ty)}"
                assert tx not in LANE_COLUMNS and ty not in LANE_ROWS, f"{filename}: solid prop {kind} blocks a lane at {(tx, ty)}"
            solid_tiles.update(tiles)
    for container, points in spawns.items():
        for px, py in points:
            tile = (px // TILE, py // TILE)
            assert 1 <= tile[0] <= COLUMNS - 2 and 1 <= tile[1] <= ROWS - 2, f"{filename}: {container} marker outside the room {px, py}"
            assert tile not in solid_tiles, f"{filename}: {container} marker {px, py} is inside a solid prop"

    text = ['[gd_scene load_steps=3 format=3]\n',
            '[ext_resource type="PackedScene" path="res://scenes/levels/rooms/room_base.tscn" id="1"]',
            '[ext_resource type="Script" path="res://scripts/world/room_prop.gd" id="2"]\n',
            f'[node name="{node_name}" instance=ExtResource("1")]\n']
    counts = {}
    for prop in props:
        kind, x, y = prop[0], prop[1], prop[2]
        size = prop[3] if len(prop) > 3 else None
        counts[kind] = counts.get(kind, 0) + 1
        name = f"Prop{sum(counts.values())}"
        block = [f'[node name="{name}" type="Node2D" parent="."]',
                 f'position = Vector2({x * TILE}, {y * TILE})',
                 'script = ExtResource("2")']
        if kind != PINE:
            block.append(f'kind = {kind}')
        if size:
            block.append(f'size_tiles = Vector2i({size[0]}, {size[1]})')
        text.append("\n".join(block) + "\n")
    if player_spawn:
        text.append(f'[node name="PlayerSpawn" type="Marker2D" parent="."]\nposition = Vector2{player_spawn}\n')
    for container, points in spawns.items():
        text.append(f'[node name="{container}" type="Node2D" parent="."]\n')
        for i, (px, py) in enumerate(points):
            text.append(f'[node name="P{i + 1}" type="Marker2D" parent="{container}"]\nposition = Vector2({px}, {py})\n')
    with open(f"{OUT}/{filename}.tscn", "w", newline="\n") as f:
        f.write("\n".join(text))


# --- Start: a clearing with a patch of bare earth --------------------------------------------------
build("start", "ForestStart",
      props=[(DIRT_PATCH, 11, 6, (8, 6)),
             (PINE, 3, 3), (PINE, 5, 2), (PINE, 25, 3), (PINE, 26, 5), (PINE, 3, 14), (PINE, 2, 12),
             (PINE, 25, 14), (PINE, 27, 12), (BUSH, 7, 4), (BUSH, 22, 4), (BUSH, 8, 13), (BUSH, 21, 13),
             (TALL_ROUND_TREE, 4, 5), (TALL_ROUND_TREE, 24, 12)],
      player_spawn=(240, 144), scatter=[(PINE, 8), (TALL_PINE, 3), (BUSH, 4)])

# --- Boss: a wide circle of bare earth ringed by trees ------------------------------------------------
build("boss", "ForestBoss",
      props=[(DIRT_PATCH, 8, 4, (14, 10)),
             (TALL_PINE, 3, 2), (TALL_PINE, 26, 2), (TALL_PINE, 3, 13), (TALL_PINE, 26, 13),
             (PINE, 6, 2), (PINE, 23, 2), (PINE, 6, 15), (PINE, 23, 15), (BUSH, 2, 5), (BUSH, 27, 5),
             (BUSH, 2, 12), (BUSH, 27, 12)],
      spawns={"BossSpawn": [(240, 88)], "ExitSpawn": [(240, 40)]}, player_spawn=(240, 232), scatter=[(PINE, 6), (BUSH, 4)])

# --- Combat: clearing with groves in the four corners ---------------------------------------------------
build("clearing_a", "ForestClearingA",
      props=[(TALL_PINE, 5, 2), (TALL_PINE, 8, 3), (TALL_PINE, 3, 4), (BUSH, 6, 5),
             (TALL_PINE, 23, 2), (TALL_PINE, 20, 3), (TALL_PINE, 26, 4), (BUSH, 22, 5),
             (TALL_ROUND_TREE, 5, 12), (TALL_ROUND_TREE, 8, 13), (BUSH, 3, 14),
             (TALL_ROUND_TREE, 23, 12), (TALL_ROUND_TREE, 20, 13), (BUSH, 26, 14)],
      spawns={"EnemySpawns": [(100, 120), (380, 120), (100, 180), (380, 180), (240, 50), (240, 236)]},
      scatter=[(PINE, 6), (BUSH, 5)])

# --- Combat: open meadow with fallen logs and bushes ---------------------------------------------------
build("clearing_b", "ForestClearingB",
      props=[(LOGS, 6, 4), (LOGS, 22, 12), (LOGS, 9, 13), (LOGS, 20, 4),
             (BUSH, 4, 2), (BUSH, 5, 2), (BUSH, 24, 15), (BUSH, 25, 15),
             (PINE, 2, 5), (PINE, 27, 12), (TALL_ROUND_TREE, 11, 2), (TALL_ROUND_TREE, 18, 14)],
      spawns={"EnemySpawns": [(70, 70), (410, 70), (70, 220), (410, 220), (330, 100)]},
      scatter=[(PINE, 7), (TALL_ROUND_TREE, 3), (BUSH, 5)])

# --- Combat: a river with a bridge (west bank to the east) -----------------------------------------------
build("river", "ForestRiver",
      props=[(POND, 6, 1, (3, 6)), (POND, 6, 11, (3, 6)), (PLANKS, 6, 7, (3, 4)),
             (TALL_PINE, 20, 2), (TALL_PINE, 24, 3), (TALL_PINE, 21, 12), (TALL_PINE, 25, 13),
             (BUSH, 11, 3), (BUSH, 11, 14), (BUSH, 18, 5), (BUSH, 18, 12), (PINE, 3, 3), (PINE, 3, 14)],
      spawns={"EnemySpawns": [(56, 70), (56, 220), (204, 56), (204, 244), (350, 110), (350, 190)]},
      scatter=[(PINE, 6), (BUSH, 5)])

# --- Combat (ambush): thick woods, enemies come out from between the trees ---------------------------
build("dense", "ForestDense",
      props=[(PINE, 3, 2), (PINE, 5, 3), (PINE, 7, 2), (PINE, 9, 4), (PINE, 4, 5), (PINE, 8, 6), (PINE, 11, 3),
             (PINE, 18, 3), (PINE, 20, 2), (PINE, 22, 4), (PINE, 24, 3), (PINE, 26, 5), (PINE, 21, 6), (PINE, 12, 5),
             (PINE, 3, 12), (PINE, 5, 14), (PINE, 7, 12), (PINE, 9, 15), (PINE, 4, 15), (PINE, 8, 13), (PINE, 11, 14),
             (PINE, 18, 14), (PINE, 20, 12), (PINE, 22, 15), (PINE, 24, 13), (PINE, 26, 15), (PINE, 21, 13), (PINE, 12, 12),
             (BUSH, 2, 6), (BUSH, 27, 6), (BUSH, 2, 11), (BUSH, 27, 11)],
      spawns={"EnemySpawns": [(120, 90), (360, 90), (136, 176), (360, 200), (60, 144), (420, 144)]},
      scatter=[(BUSH, 6), (TALL_PINE, 3)])

# --- Combat (watch): two lines of bushes make lanes, enemies stand guard ---------------------------------------------
build("watch", "ForestWatch",
      props=[(BUSH, 5, 5), (BUSH, 6, 5), (BUSH, 7, 5), (BUSH, 8, 5), (BUSH, 9, 5), (BUSH, 10, 5),
             (BUSH, 19, 5), (BUSH, 20, 5), (BUSH, 21, 5), (BUSH, 22, 5), (BUSH, 23, 5), (BUSH, 24, 5),
             (BUSH, 5, 12), (BUSH, 6, 12), (BUSH, 7, 12), (BUSH, 8, 12), (BUSH, 9, 12), (BUSH, 10, 12),
             (BUSH, 19, 12), (BUSH, 20, 12), (BUSH, 21, 12), (BUSH, 22, 12), (BUSH, 23, 12), (BUSH, 24, 12),
             (TALL_PINE, 2, 2), (TALL_PINE, 27, 2), (TALL_PINE, 2, 14), (TALL_PINE, 27, 14)],
      spawns={"EnemySpawns": [(60, 80), (60, 210), (420, 80), (420, 210), (240, 50), (240, 240), (120, 144), (360, 144)]},
      scatter=[(PINE, 6), (TALL_ROUND_TREE, 2)])

# --- Event: a small camp with a fire (the Anciano lives here) ---------------------------------------------------------------
build("event", "ForestEvent",
      props=[(DIRT_PATCH, 6, 3, (6, 4)), (CAMPFIRE, 8, 4), (LOGS, 10, 5), (LOGS, 6, 5),
             (TALL_PINE, 3, 2), (TALL_PINE, 24, 2), (TALL_ROUND_TREE, 4, 12), (TALL_ROUND_TREE, 24, 12),
             (BUSH, 18, 4), (BUSH, 20, 14), (PINE, 26, 4), (PINE, 12, 15)],
      spawns={"NpcSpawn": [(104, 108)]}, scatter=[(PINE, 9), (BUSH, 4), (TALL_ROUND_TREE, 2)])

# --- Reward: a quiet glade with a chest ---------------------------------------------------------------------------------------------
build("reward", "ForestReward",
      props=[(DIRT_PATCH, 13, 7, (4, 4)),
             (TALL_ROUND_TREE, 4, 2), (TALL_ROUND_TREE, 24, 2), (TALL_ROUND_TREE, 4, 13), (TALL_ROUND_TREE, 24, 13),
             (BUSH, 8, 4), (BUSH, 20, 4), (BUSH, 8, 13), (BUSH, 20, 13), (PINE, 11, 2), (PINE, 18, 15)],
      spawns={"ChestSpawn": [(248, 152)]}, scatter=[(PINE, 8), (BUSH, 6)])

# --- Special: a ring of round trees around a stump of logs -------------------------------------------------------------------
build("special", "ForestSpecial",
      props=[(LOGS, 8, 5), (LOGS, 20, 5), (LOGS, 8, 12), (LOGS, 20, 12),
             (TALL_ROUND_TREE, 4, 3), (TALL_ROUND_TREE, 25, 3), (TALL_ROUND_TREE, 4, 12), (TALL_ROUND_TREE, 25, 12),
             (TUFT, 12, 5), (TUFT, 17, 5), (TUFT, 12, 12), (TUFT, 17, 12)],
      spawns={"SpecialSpawn": [(240, 144)]}, scatter=[(PINE, 8), (BUSH, 4)])

print("forest rooms written and validated")
