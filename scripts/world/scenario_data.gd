class_name ScenarioData
extends Resource
## Parameters of one scenario (chapter). One `.tres` per scenario in `data/scenarios/`.
## The map is a grid of rooms: the start is on the bottom row and the boss on the top row.

@export var id: StringName = &"scenario"
## Player-facing name (Spanish).
@export var display_name := "Escenario"

@export_group("Layout")
@export var grid_size := Vector2i(5, 5)
## Length limits of the start-to-boss path, counting both ends.
@export var min_main_path := 6
@export var max_main_path := 11
## Dead-end rooms hanging off the rest of the map.
@export var side_rooms := 3
## Chance of an extra door between two adjacent rooms (creates loops).
@export_range(0.0, 1.0) var loop_chance := 0.1

@export_group("Special rooms")
@export var event_rooms := 1
@export var reward_rooms := 1
@export var special_rooms := 1

@export_group("Rooms")
@export var start_room: RoomData
@export var boss_room: RoomData
@export var rooms: Array[RoomData] = []

@export_group("Population")
@export var enemy_pool: Array[PackedScene] = []
@export var boss_scene: PackedScene
@export var npc_scene: PackedScene
