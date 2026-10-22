class_name ScenarioData
extends Resource
## Parameters of one scenario (chapter). One `.tres` per scenario in `data/scenarios/`.
## The map is a grid of rooms: the start is on the bottom row and the boss on the top row.

@export var id: StringName = &"scenario"
## Player-facing name (Spanish).
@export var display_name := "Escenario"
## Shown when the chapter starts (Spanish), e.g. "El bosque despierta."
@export var chapter_title := ""

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

@export_group("Flow")
## The chapter that follows. Without one the same scenario starts over (new map).
@export var next_scenario: ScenarioData
## Shown when the player leaves through the exit (Spanish).
@export var completion_text := ""

@export_group("Objective")
## What the HUD asks of the player (Spanish) until `objective_flag` is set, and afterwards.
@export var objective := ""
@export var objective_done := ""
## Story flag that marks the objective as done (the boss's `defeated_flag`).
@export var objective_flag: StringName = &""

@export_group("Look")
## Tiles that dress the rooms and corridors. Without a theme the rooms are flat-colored placeholders.
@export var theme: RoomTheme

@export_group("Rooms")
@export var start_room: RoomData
@export var boss_room: RoomData
@export var rooms: Array[RoomData] = []

@export_group("Population")
@export var enemy_pool: Array[PackedScene] = []
@export var boss_scene: PackedScene
## The doorway to the next chapter, placed in the boss room (marker ExitSpawn).
@export var exit_scene: PackedScene
@export var npc_scene: PackedScene
## Optional character waiting in the special room (marker SpecialSpawn), e.g. the Mercader.
@export var special_npc_scene: PackedScene
## Chests that fill the reward rooms (one is picked for each).
@export var chest_scenes: Array[PackedScene] = []
