class_name Level
extends Node2D
## Builds a playable scenario from a ScenarioData and a seed: generates the layout, places the
## rooms in world space, joins connected rooms with corridors, fills them with enemies and puts the
## player in the start room. The camera simply follows the player through the continuous world.

signal generated(layout: MapLayout)

const CELL_SIZE := Vector2(480, 288)
const CORRIDOR_LENGTH := 48.0
const STRIDE := CELL_SIZE + Vector2(CORRIDOR_LENGTH, CORRIDOR_LENGTH)
const CORRIDOR_COLOR := Color(0.15, 0.22, 0.17)

@export var scenario: ScenarioData
@export var player_scene: PackedScene
## 0 picks a random seed.
@export var seed_value := 0
## Lets the island's director adapt the map to the player's profile.
@export var use_director := true
## Pause between taking the exit and the next map, so the closing text can be read.
@export var completion_delay := 3.5

## Extra room tag -> weight multiplier, applied on top of the director's plan (debugging).
var weight_modifiers := {}
## What the director decided for the current map.
var plan: DirectorPlan = DirectorPlan.neutral()
var layout: MapLayout
var current_seed := 0
## Grid coordinate -> Room node.
var rooms := {}
var player: Node2D
## World rectangle covering the whole map.
var bounds := Rect2()

var _map: Node2D


func _ready() -> void:
	if scenario == null:
		push_error("Level has no ScenarioData assigned.")
		return
	Events.scenario_completed.connect(_on_scenario_completed)
	Events.boss_defeated.connect(func(_id: StringName) -> void: _announce_objective())
	# "Continue" in the main menu resumes the chapter that was saved.
	var saved := SaveGame.take_pending_scenario()
	if saved != null:
		scenario = saved
	generate(seed_value)


## Builds (or rebuilds) the map. Pass 0 for a random seed.
func generate(new_seed := 0) -> void:
	current_seed = new_seed if new_seed != 0 else randi_range(1, 2147483646)
	# First close the previous run (the profile learns from it), then let the director read the result.
	Events.level_started.emit(scenario.id, current_seed)
	plan = Director.make_plan() if use_director else DirectorPlan.neutral()
	layout = MapGenerator.generate(scenario, current_seed, _room_weights())
	var problems := layout.validate()
	if not problems.is_empty():
		push_error("Invalid map (seed %d): %s" % [current_seed, ", ".join(problems)])

	_clear()
	_map = Node2D.new()
	_map.name = "Map"
	add_child(_map)
	move_child(_map, 0)

	var rng := RandomNumberGenerator.new()
	rng.seed = current_seed + 1
	_build_rooms(rng)
	_build_corridors()
	_compute_bounds()
	_place_player()
	generated.emit(layout)
	if scenario.chapter_title != "":
		Events.message_requested.emit(scenario.chapter_title)
	_announce_objective()


## Tells the HUD what to do now: the objective, or the follow-up once the boss is down.
func _announce_objective() -> void:
	var done := scenario.objective_flag != &"" and GameState.has_flag(scenario.objective_flag)
	Events.objective_changed.emit(scenario.objective_done if done else scenario.objective)


## The director's room weights combined with any manual ones.
func _room_weights() -> Dictionary:
	var weights := plan.room_weights.duplicate()
	for tag in weight_modifiers:
		weights[tag] = weights.get(tag, 1.0) * weight_modifiers[tag]
	return weights


## The player left through the exit: tell the story and start the next chapter (or a new map).
func _on_scenario_completed(_scenario_id: StringName) -> void:
	if scenario.completion_text != "":
		Events.message_requested.emit(scenario.completion_text)
	await get_tree().create_timer(completion_delay).timeout
	if scenario.next_scenario != null:
		scenario = scenario.next_scenario
	generate(0)


func room_at(coord: Vector2i) -> Room:
	return rooms.get(coord)


func cell_origin(coord: Vector2i) -> Vector2:
	return Vector2(coord) * STRIDE


func _clear() -> void:
	rooms.clear()
	if _map != null:
		remove_child(_map)
		_map.queue_free()
		_map = null


func _build_rooms(rng: RandomNumberGenerator) -> void:
	for coord: Vector2i in layout.cells:
		var cell := layout.get_cell(coord)
		var room: Room = cell.room_data.scene.instantiate()
		room.theme = scenario.theme
		room.setup(cell.room_data, cell.doors)
		room.position = cell_origin(coord)
		_map.add_child(room)
		rooms[coord] = room
		_populate(room, cell, rng)


func _populate(room: Room, cell: MapLayout.Cell, rng: RandomNumberGenerator) -> void:
	match cell.type:
		RoomData.RoomType.COMBAT:
			var data := cell.room_data
			var count := rng.randi_range(data.min_enemies, maxi(data.min_enemies, data.max_enemies))
			room.spawn_enemies(scenario.enemy_pool, plan.adjust_count(count), rng, plan)
		RoomData.RoomType.BOSS:
			_spawn_single(room, scenario.boss_scene, "BossSpawn")
			var portal := _spawn_single(room, scenario.exit_scene, "ExitSpawn")
			if portal != null:
				portal.scenario_id = scenario.id
		RoomData.RoomType.EVENT:
			_spawn_single(room, scenario.npc_scene, "NpcSpawn")
		RoomData.RoomType.SPECIAL:
			_spawn_single(room, scenario.special_npc_scene, "SpecialSpawn")
		RoomData.RoomType.REWARD:
			if not scenario.chest_scenes.is_empty():
				_spawn_single(room, scenario.chest_scenes[rng.randi_range(0, scenario.chest_scenes.size() - 1)], "ChestSpawn")


func _spawn_single(room: Room, scene: PackedScene, container: String) -> Node2D:
	var points := room.spawn_points(container)
	if scene == null or points.is_empty():
		return null
	var node: Node2D = scene.instantiate()
	node.position = points[0]
	room.add_child(node)
	Placement.reset(node)
	if node.has_signal("died"):
		room.register_enemy(node)
	return node


func _build_corridors() -> void:
	var corridors := Node2D.new()
	corridors.name = "Corridors"
	_map.add_child(corridors)
	for coord: Vector2i in layout.cells:
		# Each connection is built once, from its top/left cell.
		for dir in [Vector2i.RIGHT, Vector2i.DOWN]:
			if layout.are_connected(coord, coord + dir):
				_add_corridor(corridors, coord, dir)


func _add_corridor(parent: Node, coord: Vector2i, dir: Vector2i) -> void:
	var origin := cell_origin(coord)
	var half_door := Room.DOOR_WIDTH / 2.0
	var floor_rect: Rect2
	var walls: Array[Rect2] = []
	if dir == Vector2i.RIGHT:
		var y := origin.y + CELL_SIZE.y / 2.0
		var x := origin.x + CELL_SIZE.x
		floor_rect = Rect2(x, y - half_door, CORRIDOR_LENGTH, Room.DOOR_WIDTH)
		walls.append(Rect2(x, y - half_door - Room.WALL, CORRIDOR_LENGTH, Room.WALL))
		walls.append(Rect2(x, y + half_door, CORRIDOR_LENGTH, Room.WALL))
	else:
		var x := origin.x + CELL_SIZE.x / 2.0
		var y := origin.y + CELL_SIZE.y
		floor_rect = Rect2(x - half_door, y, Room.DOOR_WIDTH, CORRIDOR_LENGTH)
		walls.append(Rect2(x - half_door - Room.WALL, y, Room.WALL, CORRIDOR_LENGTH))
		walls.append(Rect2(x + half_door, y, Room.WALL, CORRIDOR_LENGTH))

	if scenario.theme != null:
		_paint_corridor(parent, floor_rect, walls)
		return
	var floor_visual := ColorRect.new()
	floor_visual.color = CORRIDOR_COLOR
	floor_visual.z_index = RoomTheme.FLOOR_Z
	floor_visual.position = floor_rect.position
	floor_visual.size = floor_rect.size
	floor_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(floor_visual)
	WallBuilder.add_walls(parent, walls)


## A themed corridor: path tiles on the floor and the border tile (trees) along its walls.
## Only collision comes from the wall rectangles.
func _paint_corridor(parent: Node, floor_rect: Rect2, walls: Array[Rect2]) -> void:
	var layer := scenario.theme.new_layer(parent, "Corridor")
	scenario.theme.fill(layer, _cells(floor_rect), scenario.theme.path_tile)
	for wall in walls:
		scenario.theme.fill(layer, _cells(wall), scenario.theme.border_tile)
	WallBuilder.add_walls(parent, walls, WallBuilder.WALL_COLOR, false)


func _cells(rect: Rect2) -> Rect2i:
	return Rect2i(Vector2i(rect.position / TileArt.TILE), Vector2i(rect.size / TileArt.TILE))


func _compute_bounds() -> void:
	bounds = Rect2()
	var first := true
	for coord: Vector2i in layout.cells:
		var rect := Rect2(cell_origin(coord), CELL_SIZE)
		bounds = rect if first else bounds.merge(rect)
		first = false


func _place_player() -> void:
	if player_scene == null:
		return
	if player == null:
		player = player_scene.instantiate()
		add_child(player)
	# Idempotent: whatever the player has earned (skills) is on the player for every map.
	GameState.apply_to_player(player)
	var start_room: Room = rooms[layout.start_cell]
	Placement.teleport(player, start_room.global_position + start_room.player_spawn())
	if player.has_method("set_camera_limits"):
		player.set_camera_limits(bounds)
	# A new map starts somewhere else: the camera jumps there instead of gliding across the world.
	if player.has_method("snap_camera"):
		player.snap_camera()
