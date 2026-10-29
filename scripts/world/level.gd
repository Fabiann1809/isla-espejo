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
## Cell of the room that holds the mini boss (none = (-1, -1)).
var _guard_cell := Vector2i(-1, -1)
## Black cover hiding the hitch of building a map (a full-screen rect under the HUD).
var _veil: ColorRect
## True from taking the exit until the next map is built (the portal can be used again meanwhile).
var _completing := false
## Floor and wall rectangles of the corridors of the current map (world px), for the backdrop.
var _corridor_floors: Array[Rect2] = []
var _corridor_walls: Array[Rect2] = []
var _boundary: Node2D


func _ready() -> void:
	if scenario == null:
		push_error("Level has no ScenarioData assigned.")
		return
	# Nico (a child of the level) is y-sorted with the rooms' enemies and props (see Room).
	y_sort_enabled = true
	Events.scenario_completed.connect(_on_scenario_completed)
	Events.boss_defeated.connect(func(_id: StringName) -> void: _announce_objective())
	# "Continue" in the main menu resumes the chapter that was saved.
	var saved := SaveGame.take_pending_scenario()
	if saved != null:
		scenario = saved
	_build_veil()
	_veil.color.a = 1.0
	generate(seed_value)
	_lift_veil()


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

	# The look follows the scenario being played (a themed chapter after a plain one, or back).
	Ambience.apply(self, scenario.theme != null)
	AmbientLife.apply(self, scenario.theme != null and Tuning.AMBIENT_LIFE_ENABLED)
	_clear()
	# Rooms, corridors and props are drawn with the scenario's pack (the default one without a theme).
	TileArt.use_profile(scenario.theme.tileset if scenario.theme != null else null)
	_map = Node2D.new()
	_map.name = "Map"
	_map.y_sort_enabled = true
	add_child(_map)
	move_child(_map, 0)

	var rng := RandomNumberGenerator.new()
	rng.seed = current_seed + 1
	_build_rooms(rng)
	_build_corridors()
	_compute_bounds()
	_build_backdrop()
	_soften_paths()
	_build_boundary()
	_place_player()
	_add_shadows()
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
	if _completing:
		return
	_completing = true
	if scenario.completion_text != "":
		Events.message_requested.emit(scenario.completion_text)
	await get_tree().create_timer(completion_delay).timeout
	await _fade_veil(1.0, Tuning.MAP_VEIL_FADE_OUT)
	if scenario.next_scenario != null:
		scenario = scenario.next_scenario
	generate(0)
	_completing = false
	_lift_veil()


func _build_veil() -> void:
	var layer := CanvasLayer.new()
	layer.name = "MapVeil"
	add_child(layer)
	# First among the level's children: drawn after the world but before the HUD, so the chapter
	# text stays readable over it.
	move_child(layer, 0)
	_veil = ColorRect.new()
	_veil.name = "Veil"
	_veil.color = Color(0, 0, 0, 0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_veil)


## Waits for the new map's first, slowest frames under the veil, then fades it out.
func _lift_veil() -> void:
	for i in Tuning.MAP_VEIL_HOLD_FRAMES:
		await get_tree().process_frame
	await _fade_veil(0.0, Tuning.MAP_VEIL_FADE_IN)


func _fade_veil(alpha: float, seconds: float) -> void:
	if _veil == null:
		return
	if seconds <= 0.0:
		_veil.color.a = alpha
		return
	var tween := create_tween()
	tween.tween_property(_veil, "color:a", alpha, seconds)
	await tween.finished


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
	if _boundary != null:
		remove_child(_boundary)
		_boundary.queue_free()
		_boundary = null


func _build_rooms(rng: RandomNumberGenerator) -> void:
	_guard_cell = _find_guard_cell()
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
			if cell.coord == _guard_cell:
				_spawn_at(room, scenario.miniboss_scene, room.center())
				return
			var data := cell.room_data
			var count := rng.randi_range(data.min_enemies, maxi(data.min_enemies, data.max_enemies))
			room.spawn_enemies(scenario.enemy_pool, plan.adjust_count(count), rng, plan, scenario.enemy_weights)
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
	RoomDressing.dress(room)


## The last combat room on the way to the boss, if the scenario has a mini boss.
func _find_guard_cell() -> Vector2i:
	if scenario.miniboss_scene == null:
		return Vector2i(-1, -1)
	for i in range(layout.main_path.size() - 2, 0, -1):
		if layout.get_cell(layout.main_path[i]).type == RoomData.RoomType.COMBAT:
			return layout.main_path[i]
	return Vector2i(-1, -1)


func _spawn_at(room: Room, scene: PackedScene, at: Vector2) -> Node2D:
	var node: Node2D = scene.instantiate()
	node.position = at
	room.add_child(node)
	Placement.reset(node)
	room.register_enemy(node)
	return node


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
	_corridor_floors.clear()
	_corridor_walls.clear()
	var corridors := Node2D.new()
	corridors.name = "Corridors"
	corridors.y_sort_enabled = true
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
	_corridor_floors.append(floor_rect)
	_corridor_walls.append_array(walls)

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
	# Grass under the whole corridor: the trees of its walls and the rounded path edges have
	# transparent corners.
	# Numbered names: siblings with the same name would be renamed by the engine.
	var number := parent.get_child_count()
	var ground := scenario.theme.new_layer(parent, "CorridorGround%d" % number)
	scenario.theme.fill(ground, _cells(floor_rect), scenario.theme.floor_tile)
	for wall in walls:
		scenario.theme.fill(ground, _cells(wall), scenario.theme.floor_tile)
	var layer := scenario.theme.new_layer(parent, "Corridor%d" % number)
	scenario.theme.fill(layer, _cells(floor_rect), scenario.theme.path_tile)
	for wall in walls:
		scenario.theme.fill(layer, _cells(wall), scenario.theme.border_tile)
	WallBuilder.add_walls(parent, walls, WallBuilder.WALL_COLOR, false)


## The deep forest around and between the rooms (themed scenarios only).
func _build_backdrop() -> void:
	if scenario.theme == null or not Tuning.BACKDROP_ENABLED:
		return
	var walkable := {}
	for coord: Vector2i in layout.cells:
		_mark(walkable, _cells(Rect2(cell_origin(coord), CELL_SIZE)))
	for rect in _corridor_floors:
		_mark(walkable, _cells(rect))
	var taken := {}
	for rect in _corridor_walls:
		_mark(taken, _cells(rect))
	var area := _cells(bounds).grow(Tuning.BACKDROP_MARGIN_TILES)
	ForestBackdrop.build(_map, area, walkable, taken, current_seed)


## Dirt paths (doors and corridors) drawn with the rounded edges of the dirt patch instead of
## square tiles. Rooms and corridors are separate layers, so the edges are decided on the whole map.
func _soften_paths() -> void:
	if scenario.theme == null or not Tuning.SOFT_PATH_EDGES:
		return
	var path_tile := TileArt.coords(scenario.theme.path_tile)
	var path_center := TileArt.pattern(TileArt.DIRT_PATCH)[4]
	var floor_tile := TileArt.coords(scenario.theme.floor_tile)
	# Path layer -> the layer that gets the edge tiles, over grass (a room's patch layer; a
	# corridor's own layer, which has grass below it).
	var layers: Array[TileMapLayer] = []
	var overlays := {}
	for coord: Vector2i in layout.cells:
		var ground := rooms[coord].get_node_or_null("Ground") as TileMapLayer
		var patches := rooms[coord].get_node_or_null("Patches") as TileMapLayer
		if ground != null and patches != null:
			layers.append(ground)
			overlays[ground] = patches
	for child in _map.get_node("Corridors").get_children():
		if child is TileMapLayer and child.name.begins_with("Corridor") and not child.name.begins_with("CorridorGround"):
			layers.append(child)
			overlays[child] = child
	var path := {}
	for layer in layers:
		var offset := Vector2i(layer.global_position) / TileArt.TILE
		for cell in layer.get_used_cells_by_id(0, path_tile):
			path[cell + offset] = true
	var on_path := func(cell: Vector2i) -> bool: return path.has(cell)
	for layer in layers:
		var offset := Vector2i(layer.global_position) / TileArt.TILE
		for cell in layer.get_used_cells_by_id(0, path_tile):
			var tile := TileArt.blob_tile(TileArt.DIRT_PATCH, TileArt.DIRT_PATCH_INNER, on_path, cell + offset)
			if tile == path_center:
				continue
			var overlay: TileMapLayer = overlays[layer]
			if overlay != layer:
				layer.set_cell(cell, 0, floor_tile)
			overlay.set_cell(cell, 0, tile)


static func _mark(cells: Dictionary, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			cells[Vector2i(x, y)] = true


func _cells(rect: Rect2) -> Rect2i:
	return Rect2i(Vector2i(rect.position / TileArt.TILE), Vector2i(rect.size / TileArt.TILE))


func _compute_bounds() -> void:
	bounds = Rect2()
	var first := true
	for coord: Vector2i in layout.cells:
		var rect := Rect2(cell_origin(coord), CELL_SIZE)
		bounds = rect if first else bounds.merge(rect)
		first = false


func _add_shadows() -> void:
	for node in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("npcs"):
		if _map.is_ancestor_of(node):
			ActorShadow.attach(node)
	if player != null:
		ActorShadow.attach(player)
## The dark outer forest of `diseño-de-paisajes` (its own art), over the backdrop's void.
func _build_boundary() -> void:
	if scenario.theme == null or not Tuning.FOREST_BOUNDARY_ENABLED:
		return
	var boundary_script = load("res://scripts/world/forest_boundary.gd")
	if boundary_script == null:
		return
	_boundary = boundary_script.new()
	_boundary.name = "ForestBoundary"
	add_child(_boundary)
	move_child(_boundary, 0)
	_boundary.generate(layout, bounds, current_seed)


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
