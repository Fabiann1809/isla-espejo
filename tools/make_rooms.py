"""Generates the test room scenes in scenes/levels/rooms/.
Run from the repo root: python tools/make_rooms.py
The generated .tscn files are normal scenes: after generating them you can edit them by hand in Godot.
Cell is 480x288 px (30x18 tiles). Keep the center cross (x 208..272 and y 112..176) free of obstacles (tests/test_room_designs.gd checks it).
"""
import os

OUT = "scenes/levels/rooms"
os.makedirs(OUT, exist_ok=True)

with open(f"{OUT}/room_base.tscn", "w", newline="\n") as f:
    f.write('''[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/world/room.gd" id="1"]

[node name="Room" type="Node2D"]
script = ExtResource("1")
''')


def room(filename, node_name, pillars=(), bars=(), markers=None, color=(0.1, 0.12, 0.12)):
    """pillars: (cx, cy, size); bars: (x, y, w, h) top-left; markers: {container: [(x, y), ...]}"""
    markers = markers or {}
    subs, nodes = [], []
    count = 0

    def box(w, h):
        nonlocal count
        count += 1
        subs.append(f'[sub_resource type="RectangleShape2D" id="s{count}"]\nsize = Vector2({w}, {h})\n')
        return f"s{count}"

    rects = [(cx - s / 2, cy - s / 2, s, s, f"Pillar{i + 1}") for i, (cx, cy, s) in enumerate(pillars)]
    rects += [(x, y, w, h, f"Bar{i + 1}") for i, (x, y, w, h) in enumerate(bars)]
    for x, y, w, h, name in rects:
        sid = box(w, h)
        nodes.append(f'''[node name="{name}" type="StaticBody2D" parent="."]
position = Vector2({x + w / 2}, {y + h / 2})

[node name="CollisionShape2D" type="CollisionShape2D" parent="{name}"]
shape = SubResource("{sid}")

[node name="Visual" type="ColorRect" parent="{name}"]
offset_left = {-w / 2}
offset_top = {-h / 2}
offset_right = {w / 2}
offset_bottom = {h / 2}
color = Color({color[0]}, {color[1]}, {color[2]}, 1)
''')
    for container, points in markers.items():
        if container == "PlayerSpawn":
            x, y = points[0]
            nodes.append(f'[node name="PlayerSpawn" type="Marker2D" parent="."]\nposition = Vector2({x}, {y})\n')
            continue
        nodes.append(f'[node name="{container}" type="Node2D" parent="."]\n')
        for i, (x, y) in enumerate(points):
            nodes.append(f'[node name="P{i + 1}" type="Marker2D" parent="{container}"]\nposition = Vector2({x}, {y})\n')

    text = (f'[gd_scene load_steps={2 + len(subs)} format=3]\n\n'
            '[ext_resource type="PackedScene" path="res://scenes/levels/rooms/room_base.tscn" id="1"]\n\n')
    text += "\n".join(subs) + f'\n[node name="{node_name}" instance=ExtResource("1")]\n\n' + "\n".join(nodes)
    with open(f"{OUT}/{filename}.tscn", "w", newline="\n") as f:
        f.write(text)


room("start", "Start", markers={"PlayerSpawn": [(240, 144)]})
room("boss", "Boss", pillars=[(80, 60, 32), (400, 60, 32), (80, 228, 32), (400, 228, 32)],
     markers={"PlayerSpawn": [(240, 230)], "BossSpawn": [(240, 90)]}, color=(0.2, 0.1, 0.25))
room("combat_a", "CombatA", pillars=[(120, 70, 24), (360, 70, 24), (120, 218, 24), (360, 218, 24)],
     markers={"EnemySpawns": [(90, 100), (390, 100), (90, 190), (390, 190), (240, 60), (240, 230)]})
room("combat_b", "CombatB", bars=[(96, 80, 96, 16), (288, 192, 96, 16)],
     markers={"EnemySpawns": [(70, 70), (410, 70), (70, 220), (410, 220), (330, 100)]})
room("combat_c", "CombatC",
     markers={"EnemySpawns": [(60, 60), (420, 60), (60, 230), (420, 230), (150, 144), (330, 144)]})
room("combat_d", "CombatD", bars=[(140, 96, 64, 16), (276, 96, 64, 16), (140, 176, 64, 16), (276, 176, 64, 16)],
     markers={"EnemySpawns": [(60, 80), (60, 210), (420, 80), (420, 210), (240, 50), (240, 240), (120, 144), (360, 144)]})
room("event", "Event", pillars=[(110, 90, 20), (370, 90, 20), (110, 200, 20), (370, 200, 20)],
     markers={"NpcSpawn": [(240, 100)]})
room("reward", "Reward", markers={"ChestSpawn": [(240, 144)]})
room("special", "Special", pillars=[(130, 96, 28), (350, 96, 28), (130, 192, 28), (350, 192, 28)], markers={"SpecialSpawn": [(240, 144)]})
print("rooms written")
