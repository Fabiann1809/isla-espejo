"""Generates the ruins room scenes in scenes/levels/rooms/ruins/.
Run from the repo root: python tools/make_ruins_rooms.py

Each room is a scene inheriting room_base.tscn with RuinProp nodes (rock outcrops, pillars, crystals,
platforms, a bridge, rivers...), plus spawn markers. After generating, the .tscn files are
normal scenes you can edit by hand in Godot (and tests/test_room_designs.gd checks them with real
physics). Rooms are 30x18 tiles (16 px); coordinates below are in TILES.

The generator checks the design:
  - nothing solid may cross the central lanes (columns 13..16 and rows 7..10), so every door is
    reachable from every other door;
  - spawn markers must be inside the room and not inside a solid prop;
  - the tiles in front of a platform's stairs stay free, so the stairs can be reached;
  - a raised room (RoomData.height 1, see tools/make_ruins_data.gd) has no water, terraces or alcoves.
"""
import os

OUT = "scenes/levels/rooms/ruins"
os.makedirs(OUT, exist_ok=True)

TILE = 16
COLUMNS, ROWS = 30, 18
LANE_COLUMNS = range(13, 17)
LANE_ROWS = range(7, 11)

# RuinProp.Kind values (keep in sync with scripts/world/ruin_prop.gd)
ROCKS, STALAGMITE, BOULDER, PILLAR, CRYSTAL, STELE, BRAZIER, TORCH, BANNER, CRATE, BARREL, BRIDGE, WATERFALL, TERRACE, ALCOVE, RIVER = range(16)
POND = RIVER
SOLID = {ROCKS, STALAGMITE, BOULDER, PILLAR, CRYSTAL, STELE, BRAZIER, TORCH, CRATE, BARREL, TERRACE, ALCOVE, POND}
TALL = {PILLAR, CRYSTAL, STELE, BANNER}
AREAS = {ROCKS, BRIDGE, WATERFALL, TERRACE, ALCOVE, POND}
PLATFORMS = {TERRACE, ALCOVE}


def footprint(kind, x, y, size=(1, 1)):
    """Tiles covered by a prop (tall ones cover crown and base)."""
    if kind in TALL:
        size = (1, 2)
    elif kind not in AREAS:
        size = (1, 1)
    return [(x + i, y + j) for i in range(size[0]) for j in range(size[1])]


def build(filename, node_name, props, spawns=None, player_spawn=None, raised=False):
    """props: [(kind, x, y)] or [(kind, x, y, (w, h))]; spawns: {container: [(x_px, y_px)]}."""
    spawns = spawns or {}
    solid_tiles = set()
    for prop in props:
        kind, x, y = prop[0], prop[1], prop[2]
        size = prop[3] if len(prop) > 3 else (1, 1)
        if raised:
            assert kind not in (POND, TERRACE, ALCOVE, BRIDGE, WATERFALL), f"{filename}: a raised room has no {kind}"
        tiles = footprint(kind, x, y, size)
        for tx, ty in tiles:
            assert 0 <= tx <= COLUMNS - 1 and 0 <= ty <= ROWS - 1, f"{filename}: prop outside the room at {(tx, ty)}"
        if kind in SOLID:
            for tx, ty in tiles:
                assert 1 <= tx <= COLUMNS - 2 and 1 <= ty <= ROWS - 2, f"{filename}: solid prop outside the walls at {(tx, ty)}"
                assert tx not in LANE_COLUMNS and ty not in LANE_ROWS, f"{filename}: solid prop {kind} blocks a lane at {(tx, ty)}"
            solid_tiles.update(tiles)
    for prop in props:
        kind, x, y = prop[0], prop[1], prop[2]
        if kind in PLATFORMS:
            w, h = prop[3]
            stairs = x + w // 2 - 1
            for tx in range(stairs - 1, stairs + 3):
                for ty in (y + h, y + h + 1):
                    assert (tx, ty) not in solid_tiles, f"{filename}: the stairs of the platform at {(x, y)} are blocked at {(tx, ty)}"
    # The surface of a platform is walkable ground for whoever stands on it (a chest in an alcove).
    walkable_tops = set()
    for prop in props:
        if prop[0] in PLATFORMS:
            x, y, (w, h) = prop[1], prop[2], prop[3]
            walkable_tops.update((x + i, y + j) for i in range(1, w - 1) for j in range(1, h - 2))
    solid_tiles -= walkable_tops
    for container, points in spawns.items():
        for px, py in points:
            tile = (px // TILE, py // TILE)
            assert 1 <= tile[0] <= COLUMNS - 2 and 1 <= tile[1] <= ROWS - 2, f"{filename}: {container} marker outside the room {px, py}"
            assert tile not in solid_tiles, f"{filename}: {container} marker {px, py} is inside a solid prop"

    text = ['[gd_scene load_steps=3 format=3]\n',
            '[ext_resource type="PackedScene" path="res://scenes/levels/rooms/room_base.tscn" id="1"]',
            '[ext_resource type="Script" path="res://scripts/world/ruin_prop.gd" id="2"]\n',
            f'[node name="{node_name}" instance=ExtResource("1")]\n']
    for number, prop in enumerate(props, start=1):
        kind, x, y = prop[0], prop[1], prop[2]
        size = prop[3] if len(prop) > 3 else None
        block = [f'[node name="Prop{number}" type="Node2D" parent="."]',
                 f'position = Vector2({x * TILE}, {y * TILE})']
        block.append('script = ExtResource("2")')
        if kind != 0:
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


# --- Start: a lit landing, outcrops in the corners ------------------------------------------------------------
build("start", "RuinsStart",
      props=[(ROCKS, 2, 2, (4, 2)), (ROCKS, 24, 2, (4, 2)), (ROCKS, 2, 13, (4, 2)), (ROCKS, 24, 13, (4, 2)),
             (CRYSTAL, 8, 4), (CRYSTAL, 21, 4), (CRYSTAL, 8, 12), (CRYSTAL, 21, 12),
             (TORCH, 11, 3), (TORCH, 18, 3), (STELE, 6, 5), (STELE, 23, 5),
             (BOULDER, 11, 14), (BOULDER, 18, 14), (STALAGMITE, 5, 11), (STALAGMITE, 24, 11)],
      player_spawn=(240, 144))

# --- Boss (raised): the arena, ringed by pillars, crystals and braziers -----------------------------------------
build("boss", "RuinsBoss",
      props=[(CRYSTAL, 7, 3), (CRYSTAL, 22, 3), (CRYSTAL, 7, 12), (CRYSTAL, 22, 12),
             (PILLAR, 10, 2), (PILLAR, 19, 2), (PILLAR, 10, 14), (PILLAR, 19, 14),
             (BRAZIER, 12, 4), (BRAZIER, 17, 4), (BRAZIER, 12, 13), (BRAZIER, 17, 13),
             (ROCKS, 2, 2, (3, 3)), (ROCKS, 25, 2, (3, 3)), (ROCKS, 2, 12, (3, 3)), (ROCKS, 25, 12, (3, 3)),
             (BANNER, 5, 1), (BANNER, 24, 1)],
      spawns={"BossSpawn": [(240, 88)], "ExitSpawn": [(240, 40)]}, player_spawn=(240, 232), raised=True)

# --- Combat: a river on each side, crossed by a bridge on the way to the doors ------------------------------------
build("river", "RuinsRiver",
      props=[(POND, 6, 1, (3, 6)), (POND, 6, 11, (3, 6)), (BRIDGE, 5, 7, (5, 4)),
             (POND, 21, 1, (3, 6)), (POND, 21, 11, (3, 6)), (BRIDGE, 20, 7, (5, 4)),
             (ROCKS, 11, 3, (2, 2)), (ROCKS, 17, 3, (2, 2)), (ROCKS, 11, 13, (2, 2)), (ROCKS, 17, 13, (2, 2)),
             (STALAGMITE, 3, 4), (STALAGMITE, 26, 4), (STALAGMITE, 3, 13), (STALAGMITE, 26, 13),
             (TORCH, 12, 2), (TORCH, 17, 2)],
      spawns={"EnemySpawns": [(40, 100), (40, 190), (440, 100), (440, 190), (240, 60), (240, 236)]})

# --- Combat (ambush): blocks of rock leave narrow passages, enemies jump out of them ---------------------------------
build("narrow", "RuinsNarrow",
      props=[(ROCKS, 4, 3, (5, 3)), (ROCKS, 21, 3, (5, 3)), (ROCKS, 4, 12, (5, 3)), (ROCKS, 21, 12, (5, 3)),
             (ROCKS, 10, 5, (2, 2)), (ROCKS, 18, 5, (2, 2)), (ROCKS, 10, 11, (2, 2)), (ROCKS, 18, 11, (2, 2)),
             (CRYSTAL, 12, 3), (CRYSTAL, 17, 3), (CRYSTAL, 12, 14), (CRYSTAL, 17, 14)],
      spawns={"EnemySpawns": [(150, 100), (330, 100), (150, 200), (330, 200), (60, 144), (420, 144)]})

# --- Combat: two raised platforms with their stairs on the north side ------------------------------------------------
build("terraces", "RuinsTerraces",
      props=[(TERRACE, 2, 2, (10, 5)), (TERRACE, 18, 2, (10, 5)),
             (ROCKS, 2, 12, (3, 3)), (ROCKS, 25, 12, (3, 3)), (PILLAR, 10, 12), (PILLAR, 19, 12),
             (BARREL, 12, 5), (CRATE, 12, 6), (BRAZIER, 17, 5), (BOULDER, 12, 14), (BOULDER, 17, 14)],
      spawns={"EnemySpawns": [(100, 160), (380, 160), (150, 230), (330, 230), (240, 56), (240, 236)]})

# --- Combat (raised): a flat plateau with pillars and braziers -------------------------------------------------------
build("plateau", "RuinsPlateau",
      props=[(PILLAR, 6, 3), (PILLAR, 23, 3), (PILLAR, 6, 13), (PILLAR, 23, 13),
             (BRAZIER, 9, 5), (BRAZIER, 20, 5), (BRAZIER, 9, 12), (BRAZIER, 20, 12),
             (BANNER, 4, 1), (BANNER, 11, 1), (BANNER, 18, 1), (BANNER, 25, 1),
             (BOULDER, 3, 5), (BOULDER, 26, 5), (BOULDER, 3, 13), (BOULDER, 26, 13),
             (STALAGMITE, 11, 14), (STALAGMITE, 18, 14), (STALAGMITE, 11, 3), (STALAGMITE, 18, 3)],
      spawns={"EnemySpawns": [(120, 90), (360, 90), (120, 200), (360, 200), (60, 144), (420, 144)]}, raised=True)

# --- Combat (watch): two waterfalls feed pools in a cave; enemies stand guard around them ------------------------------
build("falls", "RuinsFalls",
      props=[(WATERFALL, 3, 1, (2, 3)), (POND, 2, 4, (4, 3)), (WATERFALL, 25, 1, (2, 3)), (POND, 24, 4, (4, 3)),
             (ROCKS, 8, 2, (2, 2)), (ROCKS, 20, 2, (2, 2)), (ROCKS, 8, 13, (3, 3)), (ROCKS, 19, 13, (3, 3)),
             (BOULDER, 5, 12), (BOULDER, 24, 12), (CRYSTAL, 10, 12), (CRYSTAL, 19, 11), (STALAGMITE, 12, 4), (STALAGMITE, 17, 4)],
      spawns={"EnemySpawns": [(60, 130), (420, 130), (60, 220), (420, 220), (240, 56), (240, 236), (120, 144), (360, 144)]})

# --- Event: the Viajera's camp (braziers, crates, a stele) ------------------------------------------------------------------
build("event", "RuinsEvent",
      props=[(BRAZIER, 8, 5), (BRAZIER, 20, 5), (STELE, 5, 3), (STELE, 24, 3),
             (CRATE, 24, 12), (CRATE, 25, 12), (BARREL, 24, 13), (TORCH, 4, 12), (TORCH, 9, 13),
             (ROCKS, 2, 2, (2, 2)), (ROCKS, 26, 14, (2, 2)), (BOULDER, 12, 14), (BOULDER, 18, 3)],
      spawns={"NpcSpawn": [(112, 100)]})

# --- Reward: an alcove (a small room) with the chest, reached by its own stairs ------------------------------------------
build("reward", "RuinsReward",
      props=[(ALCOVE, 2, 2, (8, 5)), (CRYSTAL, 21, 3), (CRYSTAL, 25, 3), (BRAZIER, 12, 3), (BRAZIER, 17, 3),
             (ROCKS, 2, 12, (5, 3)), (ROCKS, 22, 12, (5, 3)), (PILLAR, 20, 5), (STALAGMITE, 12, 14), (STALAGMITE, 17, 14)],
      spawns={"ChestSpawn": [(88, 56)]})

# --- Special: a shrine of crystals around the middle ----------------------------------------------------------------------
build("special", "RuinsSpecial",
      props=[(CRYSTAL, 8, 4), (CRYSTAL, 21, 4), (CRYSTAL, 8, 12), (CRYSTAL, 21, 12),
             (BRAZIER, 11, 6), (BRAZIER, 18, 6), (BRAZIER, 11, 11), (BRAZIER, 18, 11),
             (STELE, 5, 3), (STELE, 24, 3), (ROCKS, 2, 13, (3, 2)), (ROCKS, 25, 13, (3, 2)), (BOULDER, 3, 5), (BOULDER, 26, 5)],
      spawns={"SpecialSpawn": [(240, 144)]})

print("ruins rooms written and validated")
