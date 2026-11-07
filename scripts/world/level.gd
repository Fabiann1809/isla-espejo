class_name Level
extends Node2D
## Builds a playable scenario from a ScenarioData and a seed: generates the layout, places the
## rooms in world space, joins connected rooms with corridors, fills them with enemies and puts the
## player in the start room. The camera simply follows the player through the continuous world.

signal generated(layout: MapLayout)
## The exit of the last chapter was taken (only with `end_after_last_chapter`): the journey is over.
signal journey_ended

const CORRIDOR_COLOR := Color(0.15, 0.22, 0.17)
## The forest shade's sort point: below every room, so it is drawn after all their floors.
const SHADE_SORT_Y := 1000000.0

@export var scenario: ScenarioData
@export var player_scene: PackedScene
## 0 picks a random seed.
@export var seed_value := 0
## Lets the island's director adapt the map to the player's profile.
@export var use_director := true
## Pause between taking the exit and the next map, so the closing text can be read.
@export var completion_delay := 3.5
## After the last chapter (no `next_scenario`) the journey ends (`journey_ended`) instead of building
## a new map of the same scenario. The real game turns it on; the sandboxes keep looping.
@export var end_after_last_chapter := false

## Extra room tag -> weight multiplier, applied on top of the director's plan (debugging).
var weight_modifiers := {}
## What the director decided for the current map.
var plan: DirectorPlan = DirectorPlan.neutral()
## The enemies this map fields (`EnemyRoster`: the whole pool unless the scenario has a `roster_size`).
var roster: Array[PackedScene] = []
var layout: MapLayout
var current_seed := 0
## Grid coordinate -> Room node.
var rooms := {}
var player: Node2D
## World rectangle covering the whole map.
var bounds := Rect2()

var _map: Node2D
var _drops: DropSpawner
## Cell of the room that holds the mini boss (none = (-1, -1)).
var _guard_cell := Vector2i(-1, -1)
## Black cover hiding the hitch of building a map (a full-screen rect under the HUD).
var _veil: ColorRect
## True from taking the exit until the next map is built (the portal can be used again meanwhile).
var _completing := false
## Floor and wall rectangles of the corridors of the current map (world px), for the backdrop.
var _corridor_floors: Array[Rect2] = []
var _corridor_walls: Array[Rect2] = []
## The temple's bridges of the current map (`TempleBridge`), in the corridors' order: their landings
## are stone the backdrop keeps clear.
var _bridges: Array = []
var _boundary: Node2D


func _ready() -> void:
	if scenario == null:
		push_error("Level has no ScenarioData assigned.")
		return
	# Nico (a child of the level) is y-sorted with the rooms' enemies and props (see Room).
	y_sort_enabled = true
	Events.scenario_completed.connect(_on_scenario_completed)
	Events.player_died.connect(_on_player_died)
	_drops = DropSpawner.new()
	_drops.name = "Drops"
	add_child(_drops)
	Events.boss_defeated.connect(func(_id: StringName) -> void: _announce_objective())
	# "Continue" in the main menu resumes the chapter that was saved.
	var saved := SaveGame.take_pending_scenario()
	if saved != null:
		scenario = saved
	_build_veil()
	var feel := GameFeel.new()
	feel.name = "GameFeel"
	add_child(feel)
	# Right after the veil: its red flash covers the world but not the HUD.
	move_child(feel, 1)
	var canopy := CanopyFade.new()
	canopy.name = "CanopyFade"
	add_child(canopy)
	_veil.color.a = 1.0
	generate(seed_value)
	_lift_veil()


## Builds (or rebuilds) the map. Pass 0 for a random seed.
func generate(new_seed := 0) -> void:
	current_seed = new_seed if new_seed != 0 else randi_range(1, 2147483646)
	# First close the previous run (the profile learns from it), then let the director read the result.
	Events.level_started.emit(scenario.id, current_seed)
	plan = Director.make_plan() if use_director else DirectorPlan.neutral()
	roster = EnemyRoster.pick(scenario.enemy_pool, scenario.roster_size, current_seed, scenario.enemy_weights, plan)
	layout = MapGenerator.generate(scenario, current_seed, _room_weights())
	var problems := layout.validate()
	if not problems.is_empty():
		push_error("Invalid map (seed %d): %s" % [current_seed, ", ".join(problems)])

	# The look follows the scenario being played (a themed chapter after a plain one, or back).
	Ambience.apply(self, scenario.theme != null, scenario.theme.world_tint if scenario.theme != null else Tuning.WORLD_TINT)
	AmbientLife.apply(self, scenario.theme != null and scenario.theme.ambient_life and Tuning.AMBIENT_LIFE_ENABLED)
	_clear()
	# Rooms, corridors and props are drawn with the scenario's pack (the default one without a theme).
	TileArt.use_profile(scenario.theme.tileset if scenario.theme != null else null)
	_drops.drops = scenario.drops
	_drops.rng.seed = current_seed + 2
	_map = Node2D.new()
	_map.name = "Map"
	_map.y_sort_enabled = true
	add_child(_map)
	move_child(_map, 0)

	var rng := RandomNumberGenerator.new()
	rng.seed = current_seed + 1
	_use_shadow_style()
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
	var done := not _has_boss() or (scenario.objective_flag != &"" and GameState.has_flag(scenario.objective_flag))
	Events.objective_changed.emit(scenario.objective_done if done else scenario.objective)


## A chapter without its boss yet (the ruins, for now) has nothing to defeat: its exit is open and
## its objective is to cross it.
func _has_boss() -> bool:
	return scenario.boss_scene != null


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
	if scenario.next_scenario == null and end_after_last_chapter:
		# Stays "completing": the exit cannot be used again behind the ending screen.
		journey_ended.emit()
		return
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


## Dying ends the whole journey: everything is lost (resources, skills, fragments, defeated bosses)
## except what the island learned, which lives in the profile. The next attempt starts the first
## island again (the death screen then reloads the scene).
func _on_player_died() -> void:
	if player != null:
		player.clear_run_resources()
	GameState.reset()
	SaveGame.scenario_id = &""
	SaveGame.save(true)


func room_at(coord: Vector2i) -> Room:
	return rooms.get(coord)


# --- geometry ------------------------------------------------------------------------------------------------------
## The map is a grid of cells of `scenario.cell_tiles`, `scenario.corridor_tiles` apart. Each room is
## centred in its cell, so a room smaller than the cell leaves a margin on every side and the corridor
## that joins two neighbours spans the gap between their facing doors (the doors are the middle of each
## room, which is the middle of the cell: neighbours always line up). All sizes are in world px.

## Size of a grid cell.
func cell_size() -> Vector2:
	return Vector2(scenario.cell_tiles * TileArt.TILE)


## Distance between the origins of two neighbouring cells.
func stride() -> Vector2:
	return cell_size() + Vector2.ONE * float(scenario.corridor_tiles * TileArt.TILE)


## Top-left of the grid cell (not of its room: see `room_origin`).
func cell_origin(coord: Vector2i) -> Vector2:
	return Vector2(coord) * stride()


## Size of the room of a cell, from its RoomData.
func room_size(coord: Vector2i) -> Vector2:
	return Vector2(layout.get_cell(coord).room_data.size_tiles * TileArt.TILE)


## Top-left of the room of a cell: centred in the cell, on whole tiles.
func room_origin(coord: Vector2i) -> Vector2:
	var slack: Vector2i = scenario.cell_tiles - layout.get_cell(coord).room_data.size_tiles
	return cell_origin(coord) + Vector2(slack / 2 * TileArt.TILE)


## The room of a cell, walls included, in world px.
func room_rect(coord: Vector2i) -> Rect2:
	return Rect2(room_origin(coord), room_size(coord))


## The floor of the corridor from the room at `coord` to its neighbour to the RIGHT or DOWN: from the
## first room's edge to the second room's, one door wide.
func corridor_floor(coord: Vector2i, dir: Vector2i) -> Rect2:
	var from := room_rect(coord)
	var to := room_rect(coord + dir)
	var half_door := Room.DOOR_WIDTH / 2.0
	if dir == Vector2i.RIGHT:
		var y := cell_origin(coord).y + cell_size().y / 2.0
		return Rect2(from.end.x, y - half_door, to.position.x - from.end.x, Room.DOOR_WIDTH)
	var x := cell_origin(coord).x + cell_size().x / 2.0
	return Rect2(x - half_door, from.end.y, Room.DOOR_WIDTH, to.position.y - from.end.y)


## What is wrong with a room in this scenario's cell ("" when nothing): it is larger than the cell, or
## the difference is odd, so it cannot be centred on whole tiles.
func room_fit_problem(room_data: RoomData) -> String:
	var slack: Vector2i = scenario.cell_tiles - room_data.size_tiles
	if slack.x < 0 or slack.y < 0:
		return "Room '%s' (%s tiles) is larger than the cell (%s tiles) of scenario '%s'" % [room_data.id, room_data.size_tiles, scenario.cell_tiles, scenario.id]
	if slack.x % 2 != 0 or slack.y % 2 != 0:
		return "Room '%s' (%s tiles) cannot be centred on whole tiles in the cell (%s tiles): sizes must be even" % [room_data.id, room_data.size_tiles, scenario.cell_tiles]
	return ""


func _check_room_fits(room_data: RoomData) -> void:
	var problem := room_fit_problem(room_data)
	if problem != "":
		push_error(problem)
	var slack: Vector2i = scenario.cell_tiles - room_data.size_tiles
	assert(slack.x % 2 == 0 and slack.y % 2 == 0, "room and cell sizes must have an even difference")


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
		_check_room_fits(cell.room_data)
		room.position = room_origin(coord)
		_map.add_child(room)
		rooms[coord] = room
		_populate(room, cell, rng)


func _populate(room: Room, cell: MapLayout.Cell, rng: RandomNumberGenerator) -> void:
	match cell.type:
		RoomData.RoomType.COMBAT:
			# Debug: `-- --no-enemies` walks the map empty (to look at the rooms).
			if OS.get_cmdline_user_args().has("--no-enemies"):
				return
			if cell.coord == _guard_cell:
				_spawn_at(room, scenario.miniboss_scene, room.center())
				return
			var data := cell.room_data
			var count := rng.randi_range(data.min_enemies, maxi(data.min_enemies, data.max_enemies))
			var weights := EnemyRoster.room_weights(scenario.enemy_weights, data.enemy_affinity)
			room.spawn_enemies(roster, plan.adjust_count(count), rng, plan, weights, _attach_surge_spawn_points(room, weights))
		RoomData.RoomType.BOSS:
			_spawn_single(room, scenario.boss_scene, "BossSpawn")
			var portal := _spawn_single(room, scenario.exit_scene, "ExitSpawn")
			if portal != null:
				portal.scenario_id = scenario.id
				if portal.has_method("seal_with"):
					# A chapter whose boss is not built yet keeps its way out open.
					portal.seal_with(scenario.objective_flag if _has_boss() else &"")
		RoomData.RoomType.EVENT:
			_spawn_single(room, scenario.npc_scene, "NpcSpawn")
		RoomData.RoomType.SPECIAL:
			_spawn_single(room, scenario.special_npc_scene, "SpecialSpawn")
		RoomData.RoomType.REWARD:
			if not scenario.chest_scenes.is_empty():
				_spawn_single(room, scenario.chest_scenes[rng.randi_range(0, scenario.chest_scenes.size() - 1)], "ChestSpawn")
	RoomDressing.dress(room)


## Attaches the LavaSurge to a surge room (RoomData.surge_stages > 0, the temple) and returns its spawn
## points. The room gets its LavaSurge, fed with the map's roster,
## the director's plan and the room's weights; its own enemies are born only on the cells that stay
## safe when the lava is highest, so the fight is always reachable. Empty for any other room: the
## room's markers are used.
func _attach_surge_spawn_points(room: Room, weights: Dictionary) -> Array[Vector2]:
	var points: Array[Vector2] = []
	if room.data.surge_stages <= 0 or not Tuning.TEMPLE_SURGE_ENABLED:
		return points
	var surge := LavaSurge.attach_to(room, roster, scenario.enemy_pool, current_seed)
	if surge == null:
		return points
	surge.director_plan = plan
	surge.base_weights = weights
	for cell in surge.safe_spawn_cells():
		points.append(Vector2(cell) * TileArt.TILE + Vector2.ONE * TileArt.TILE / 2.0)
	if points.is_empty():
		push_warning("Surge room '%s' has no safe spawn cells: its enemies fall back to the editor markers" % room.data.id)
	return points


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
	_bridges.clear()
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
	var floor_rect := corridor_floor(coord, dir)
	if floor_rect.size.x <= 0.0 or floor_rect.size.y <= 0.0:
		push_error("No corridor between %s and %s: the rooms touch or overlap" % [coord, coord + dir])
	var walls := _corridor_walls_of(floor_rect, dir)
	_corridor_floors.append(floor_rect)
	_corridor_walls.append_array(walls)

	if scenario.theme != null:
		if scenario.theme.wall_style == RoomTheme.WallStyle.LAVA:
			_build_bridge(parent, floor_rect, walls, coord, dir)
		else:
			_paint_corridor(parent, floor_rect, walls)
			_dress_stairs(parent, floor_rect, coord, dir)
		return
	var floor_visual := ColorRect.new()
	floor_visual.color = CORRIDOR_COLOR
	floor_visual.z_index = RoomTheme.FLOOR_Z
	floor_visual.position = floor_rect.position
	floor_visual.size = floor_rect.size
	floor_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(floor_visual)
	WallBuilder.add_walls(parent, walls)


## The two wall rectangles of a corridor, one tile thick, along its floor (first north or west).
func _corridor_walls_of(floor_rect: Rect2, dir: Vector2i) -> Array[Rect2]:
	var walls: Array[Rect2] = []
	if dir == Vector2i.RIGHT:
		walls.append(Rect2(floor_rect.position.x, floor_rect.position.y - Room.WALL, floor_rect.size.x, Room.WALL))
		walls.append(Rect2(floor_rect.position.x, floor_rect.end.y, floor_rect.size.x, Room.WALL))
	else:
		walls.append(Rect2(floor_rect.position.x - Room.WALL, floor_rect.position.y, Room.WALL, floor_rect.size.y))
		walls.append(Rect2(floor_rect.end.x, floor_rect.position.y, Room.WALL, floor_rect.size.y))
	return walls


## A corridor between rooms of different height is a staircase: steps on its floor and a StairZone
## that changes the level of whoever crosses it, in the direction from the low room to the high one,
## from the lower room's level to the one above it (the Ruinas climb 0 to 1; the temple also 1 to 2).
## The temple's corridors are bridges, flat or climbing, and are built whole by `_build_bridge`.
func _dress_stairs(parent: Node, floor_rect: Rect2, coord: Vector2i, dir: Vector2i) -> void:
	var style := scenario.theme.wall_style
	if style == RoomTheme.WallStyle.LAVA:
		_build_bridge(parent, floor_rect, _corridor_walls_of(floor_rect, dir), coord, dir)
		return
	if style != RoomTheme.WallStyle.ROCKS:
		return
	var from_height := layout.get_cell(coord).room_data.height
	var to_height := layout.get_cell(coord + dir).room_data.height
	if from_height == to_height:
		return
	if absi(from_height - to_height) > 1:
		# A staircase climbs one level: the generator never joins rooms two levels apart (MapLayout.validate).
		push_error("No staircase between %s (height %d) and %s (height %d): two levels apart" % [coord, from_height, coord + dir, to_height])
		return
	var uphill := Vector2(dir) if to_height > from_height else Vector2(-dir)
	var vertical := dir == Vector2i.DOWN
	_dress_ruin_stairs(parent, floor_rect, uphill, vertical)
	var zone := StairZone.new()
	zone.direction = uphill
	zone.low_level = mini(from_height, to_height)
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = floor_rect.size
	shape.shape = rectangle
	zone.add_child(shape)
	zone.position = floor_rect.get_center()
	parent.add_child(zone)


## A temple corridor: a stone causeway over the lava (`TempleBridge`), with a landing at mid-span when
## it is long and one stretch of steps when its rooms are one level apart. Two levels apart is a
## layout error (the generator never makes it): nothing is built.
func _build_bridge(parent: Node, floor_rect: Rect2, walls: Array[Rect2], coord: Vector2i, dir: Vector2i) -> void:
	var from_height := layout.get_cell(coord).room_data.height
	var to_height := layout.get_cell(coord + dir).room_data.height
	if absi(from_height - to_height) > 1:
		push_error("No staircase between %s (height %d) and %s (height %d): two levels apart" % [coord, from_height, coord + dir, to_height])
		return
	var bridge := TempleBridge.new(scenario.theme, floor_rect, walls, from_height, to_height, dir, _bridges.size())
	bridge.build(parent)
	_bridges.append(bridge)


## The Ruinas' staircase: steps between two stone parapets (the outermost cells of the corridor's
## width, solid) with a torch on each at the top.
func _dress_ruin_stairs(parent: Node, floor_rect: Rect2, uphill: Vector2, vertical: bool) -> void:
	var steps: StringName = &"stairs_steps" if vertical else &"stairs_steps_h"
	var tile := float(TileArt.TILE)
	var stairs := Node2D.new()
	stairs.name = "Stairs%d" % parent.get_child_count()
	stairs.z_index = RoomTheme.FLOOR_Z
	parent.add_child(stairs)
	# The staircase fills the corridor between two stone parapets (the outermost cells of its width).
	var cells_x := int(floor_rect.size.x / tile)
	var cells_y := int(floor_rect.size.y / tile)
	for iy in cells_y:
		for ix in cells_x:
			var edge_first := ix == 0 if vertical else iy == 0
			var edge_last := ix == cells_x - 1 if vertical else iy == cells_y - 1
			var role := steps
			if edge_first:
				role = &"stairs_rail_l" if vertical else &"stairs_rail_t"
			elif edge_last:
				role = &"stairs_rail_r" if vertical else &"stairs_rail_b"
			stairs.add_child(TileArt.sprite(role, floor_rect.position + Vector2(ix, iy) * tile))
	# The parapets stop everybody and leave a staircase two cells wide.
	var rail_rects: Array[Rect2] = []
	if vertical:
		rail_rects.append(Rect2(floor_rect.position, Vector2(tile, floor_rect.size.y)))
		rail_rects.append(Rect2(floor_rect.position + Vector2(floor_rect.size.x - tile, 0), Vector2(tile, floor_rect.size.y)))
	else:
		rail_rects.append(Rect2(floor_rect.position, Vector2(floor_rect.size.x, tile)))
		rail_rects.append(Rect2(floor_rect.position + Vector2(0, floor_rect.size.y - tile), Vector2(floor_rect.size.x, tile)))
	WallBuilder.add_walls(parent, rail_rects, WallBuilder.WALL_COLOR, false)
	# A torch on each parapet at the top of the stairs, so the way up is lit.
	for rail in rail_rects:
		var torch := RuinProp.new()
		torch.kind = RuinProp.Kind.TORCH
		var top: Vector2
		if vertical:
			top = Vector2(rail.position.x, floor_rect.position.y if uphill.y < 0.0 else floor_rect.end.y - tile)
		else:
			top = Vector2(floor_rect.position.x if uphill.x < 0.0 else floor_rect.end.x - tile, rail.position.y)
		torch.position = top
		parent.add_child(torch)


## A themed corridor: path tiles on the floor and the border tile (trees) along its walls.
## Only collision comes from the wall rectangles.
func _paint_corridor(parent: Node, floor_rect: Rect2, walls: Array[Rect2]) -> void:
	# Numbered names: siblings with the same name would be renamed by the engine.
	var number := parent.get_child_count()
	# Grass under the whole corridor: the trees of its walls and the rounded path edges have
	# transparent corners.
	var ground := scenario.theme.new_layer(parent, "CorridorGround%d" % number)
	scenario.theme.fill(ground, _cells(floor_rect), scenario.theme.floor_tile)
	for wall in walls:
		scenario.theme.fill(ground, _cells(wall), scenario.theme.floor_tile)
	var layer := scenario.theme.new_layer(parent, "Corridor%d" % number)
	scenario.theme.fill(layer, _cells(floor_rect), scenario.theme.path_tile)
	for wall in walls:
		if scenario.theme.wall_style == RoomTheme.WallStyle.ROCKS:
			_plant_corridor_rocks(parent, wall)
		elif scenario.theme.forest_art_details:
			_plant_corridor_trees(parent, wall)
		else:
			scenario.theme.fill(layer, _cells(wall), scenario.theme.border_tile)
	WallBuilder.add_walls(parent, walls, WallBuilder.WALL_COLOR, false)


## A corridor wall as a row of rock columns, like the rooms' walls (y-sorted with the actors).
func _plant_corridor_rocks(parent: Node, wall: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([current_seed, wall.position])
	var feet: Array[Vector2]
	if wall.size.x > wall.size.y:
		feet = RockWall.feet_along(Vector2(wall.position.x, wall.end.y - 1.0), Vector2(wall.end.x, wall.end.y - 1.0), rng)
	else:
		var x := wall.get_center().x
		feet = RockWall.feet_along(Vector2(x, wall.position.y), Vector2(x, wall.end.y), rng)
	for foot in feet:
		parent.add_child(RockWall.column(foot, rng))


## A corridor wall as a row of trees, like the rooms' walls (y-sorted with the actors).
func _plant_corridor_trees(parent: Node, wall: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([current_seed, wall.position])
	var feet: Array[Vector2]
	if wall.size.x > wall.size.y:
		feet = TreeWall.feet_along(Vector2(wall.position.x, wall.end.y - 1.0), Vector2(wall.end.x, wall.end.y - 1.0), rng)
	else:
		var x := wall.get_center().x
		feet = TreeWall.feet_along(Vector2(x, wall.position.y), Vector2(x, wall.end.y), rng)
	for foot in feet:
		parent.add_child(TreeWall.tree(foot, rng))


## The deep forest around and between the rooms (themed scenarios only): rock for the Ruinas, the
## lava sea for the temple.
func _build_backdrop() -> void:
	if scenario.theme == null or not Tuning.BACKDROP_ENABLED:
		return
	var walkable := {}
	for coord: Vector2i in layout.cells:
		_mark(walkable, _cells(room_rect(coord)))
	var taken := {}
	for rect in _corridor_walls:
		_mark(taken, _cells(rect))
	var area := _cells(bounds).grow(_backdrop_margin())
	if scenario.theme.wall_style == RoomTheme.WallStyle.LAVA:
		# A bridge is lava too: the sea runs open under it, so the corridors are "taken", not islands;
		# a landing is stone of its own, rimmed by the sea and kept clear of its islets.
		for rect in _corridor_floors:
			_mark(taken, _cells(rect))
		var landings := {}
		for bridge in _bridges:
			for cell: Vector2i in bridge.taken_cells():
				taken[cell] = true
			for cell: Vector2i in bridge.stone_cells():
				landings[cell] = true
		# The islands are the rooms' stone, not their rectangles: the sea's crust and shores measure
		# from the shapes' cells, so no rectangle shows around a room.
		var stone := {}
		for coord: Vector2i in layout.cells:
			var room: Room = rooms[coord]
			var shape := room.get_node_or_null("Shape")
			var origin := Vector2i(room_origin(coord)) / TileArt.TILE
			if shape != null and shape.has_method("island_cells"):
				for cell: Vector2i in shape.island_cells():
					stone[origin + cell] = true
			else:
				_mark(stone, _cells(room_rect(coord)))
		stone.merge(landings)
		LavaBackdrop.build(_map, area, stone, taken, current_seed, walkable)
		return
	for rect in _corridor_floors:
		_mark(walkable, _cells(rect))
	if scenario.theme.wall_style == RoomTheme.WallStyle.ROCKS:
		RockBackdrop.build(_map, area, walkable, taken, current_seed)
		return
	ForestBackdrop.build(_map, area, walkable, taken, current_seed)
	if scenario.theme.forest_art_details:
		_build_forest_shade(area)


## The forest's darker floor: everything but the clearings (rooms' insides, door gaps, corridor
## floors) is shaded, and the shade creeps a tile or two into the clearings with a wobbly edge, so
## no straight line marks where a room ends. One pixel per tile, stretched with linear filtering.
func _build_forest_shade(area: Rect2i) -> void:
	var clearing := {}
	for coord: Vector2i in layout.cells:
		var room: Room = rooms[coord]
		var origin := Vector2i(room_origin(coord)) / TileArt.TILE
		for y in room.size_tiles.y:
			for x in room.size_tiles.x:
				if not room.is_wall_cell(Vector2i(x, y)):
					clearing[origin + Vector2i(x, y)] = true
	for rect in _corridor_floors:
		_mark(clearing, _cells(rect))
	# Tiles from each clearing tile to the forest (breadth first from the forest's edge).
	var depth := {}
	var frontier: Array[Vector2i] = []
	for cell: Vector2i in clearing:
		for step in MapLayout.DIRS:
			if not clearing.has(cell + step):
				depth[cell] = 1
				frontier.append(cell)
				break
	var head := 0
	while head < frontier.size():
		var cell := frontier[head]
		head += 1
		for step in MapLayout.DIRS:
			var next: Vector2i = cell + step
			if clearing.has(next) and not depth.has(next):
				depth[next] = depth[cell] + 1
				frontier.append(next)
	var noise := FastNoiseLite.new()
	noise.seed = current_seed
	noise.frequency = Tuning.FOREST_SHADE_FREQUENCY
	var picture := Image.create_empty(area.size.x, area.size.y, false, Image.FORMAT_RGBA8)
	for y in area.size.y:
		for x in area.size.x:
			var cell := area.position + Vector2i(x, y)
			var alpha := Tuning.FOREST_SHADE_ALPHA
			if clearing.has(cell):
				var inside: float = depth.get(cell, 99) - 1 + noise.get_noise_2d(cell.x, cell.y) * Tuning.FOREST_SHADE_WOBBLE
				alpha = Tuning.FOREST_SHADE_EDGE_ALPHA * (1.0 - smoothstep(0.0, Tuning.FOREST_SHADE_DEPTH, inside))
			picture.set_pixel(x, y, Color(Tuning.FOREST_SHADE_COLOR, alpha))
	# Over every floor (sorted after all the rooms by its far-down origin), under every actor.
	var shade := Node2D.new()
	shade.name = "ForestShade"
	shade.z_index = RoomTheme.FLOOR_Z
	shade.position = Vector2(0, SHADE_SORT_Y)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = ImageTexture.create_from_image(picture)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = Vector2.ONE * TileArt.TILE
	sprite.position = Vector2(area.position * TileArt.TILE) - shade.position
	shade.add_child(sprite)
	_map.add_child(shade)


## Dirt paths (doors and corridors) drawn with the rounded edges of the dirt patch instead of
## square tiles. Rooms and corridors are separate layers, so the edges are decided on the whole map.
func _soften_paths() -> void:
	# The temple has no earth paths: its floors are stone and its corridors are bridges.
	if scenario.theme == null or not Tuning.SOFT_PATH_EDGES or scenario.theme.wall_style == RoomTheme.WallStyle.LAVA:
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
	# The forest's earth stays in the forest: a rock-walled theme (the ruins) keeps its own worn
	# stone paths from the tileset.
	if DirtArt.available() and scenario.theme.wall_style != RoomTheme.WallStyle.ROCKS:
		_paint_dirt(layers, path, path_tile, floor_tile)
		return
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


## The paths with the forest's own earth (DirtArt): every path cell keeps the floor's grass (a
## corridor's own grass is the layer below it) and gets the earth on a layer just above, so its frayed
## edge shows grass. The dirt patches of the rooms are part of the same earth: a path runs into one
## with no edge between them.
func _paint_dirt(layers: Array[TileMapLayer], path: Dictionary, path_tile: Vector2i, floor_tile: Vector2i) -> void:
	var earth := path.duplicate()
	var patches: Array[RoomProp] = []
	for coord: Vector2i in layout.cells:
		for child in rooms[coord].get_children():
			if child is RoomProp and child.kind == RoomProp.Kind.DIRT_PATCH:
				patches.append(child)
				earth.merge(DirtArt.patch_cells(child))
	for layer in layers:
		var offset := Vector2i(layer.global_position) / TileArt.TILE
		var cells := layer.get_used_cells_by_id(0, path_tile)
		if cells.is_empty():
			continue
		var corridor := String(layer.name).begins_with("Corridor")
		# Numbered like the corridor it belongs to: siblings with the same name are renamed.
		var dirt := DirtArt.new_layer("CorridorPath%s" % String(layer.name).trim_prefix("Corridor") if corridor else "Paths")
		dirt.z_index = RoomTheme.FLOOR_Z
		dirt.position = layer.position
		layer.get_parent().add_child(dirt)
		# Right above the path's layer (a room's grass patches stay under the earth).
		var patches_layer := layer.get_parent().get_node_or_null("Patches")
		var below: Node = patches_layer if not corridor and patches_layer != null else layer
		layer.get_parent().move_child(dirt, below.get_index() + 1)
		for cell in cells:
			if corridor:
				layer.erase_cell(cell)
			else:
				layer.set_cell(cell, 0, floor_tile)
			dirt.set_cell(cell, 0, Vector2i(0, AreaArt.row(earth, cell + offset)))
	for patch in patches:
		DirtArt.repaint_patch(patch, earth)


## How far the backdrop (and the camera) reach past the rooms, in tiles: the temple's sea shows wider.
func _backdrop_margin() -> int:
	if scenario.theme != null and scenario.theme.wall_style == RoomTheme.WallStyle.LAVA:
		return Tuning.TEMPLE_BACKDROP_MARGIN_TILES
	return Tuning.BACKDROP_MARGIN_TILES


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
		var rect := room_rect(coord)
		bounds = rect if first else bounds.merge(rect)
		first = false


func _add_shadows() -> void:
	for node in get_tree().get_nodes_in_group("enemies") + get_tree().get_nodes_in_group("npcs"):
		if _map.is_ancestor_of(node):
			ActorShadow.attach_styled(node)
	if player != null:
		ActorShadow.attach_styled(player)


## The map's shadow style, set before the rooms are built so every actor (also those that appear
## later, see Room.register_enemy) gets the same shadow.
func _use_shadow_style() -> void:
	var alpha := -1.0
	var size_scale := 1.0
	var drop := 0.0
	var bottom := -1.0
	if scenario.theme != null and scenario.theme.wall_style == RoomTheme.WallStyle.ROCKS:
		alpha = Tuning.RUIN_SHADOW_ALPHA
	elif scenario.theme != null and scenario.theme.wall_style == RoomTheme.WallStyle.LAVA:
		# The temple's platforms need everyone plainly on the ground: a stronger shadow, anchored under
		# the feet so it never sticks out below them.
		alpha = Tuning.TEMPLE_SHADOW_ALPHA
		size_scale = Tuning.TEMPLE_SHADOW_SCALE
		drop = Tuning.TEMPLE_SHADOW_DROP
		bottom = Tuning.TEMPLE_SHADOW_BOTTOM
	ActorShadow.use_style(alpha, size_scale, drop, bottom)


## The dark outer forest of `diseño-de-paisajes` (its own art), over the backdrop's void; for the
## temple, solid collision around the sea, so nothing ever leaves the map.
func _build_boundary() -> void:
	if scenario.theme != null and scenario.theme.wall_style == RoomTheme.WallStyle.LAVA:
		_build_lava_boundary()
		return
	if scenario.theme == null or not Tuning.FOREST_BOUNDARY_ENABLED 			or scenario.theme.wall_style == RoomTheme.WallStyle.ROCKS:
		return
	var boundary_script = load("res://scripts/world/forest_boundary.gd")
	if boundary_script == null:
		return
	_boundary = boundary_script.new()
	_boundary.name = "ForestBoundary"
	add_child(_boundary)
	move_child(_boundary, 0)
	_boundary.generate(layout, bounds, current_seed, self)


## Four invisible walls just outside the sea's area (the camera's limits).
func _build_lava_boundary() -> void:
	var area := bounds.grow(_backdrop_margin() * TileArt.TILE)
	var thick := float(TileArt.TILE)
	var rects: Array[Rect2] = [
		Rect2(area.position.x - thick, area.position.y - thick, area.size.x + 2.0 * thick, thick),
		Rect2(area.position.x - thick, area.end.y, area.size.x + 2.0 * thick, thick),
		Rect2(area.position.x - thick, area.position.y, thick, area.size.y),
		Rect2(area.end.x, area.position.y, thick, area.size.y),
	]
	_boundary = Node2D.new()
	_boundary.name = "LavaBoundary"
	add_child(_boundary)
	move_child(_boundary, 0)
	WallBuilder.add_walls(_boundary, rects, WallBuilder.WALL_COLOR, false)


func _place_player() -> void:
	if player_scene == null:
		return
	if player == null:
		player = player_scene.instantiate()
		add_child(player)
	# Idempotent: whatever the player has earned (skills) is on the player for every map.
	GameState.apply_to_player(player)
	# What only mattered on the map just left (a pull, a slow, cooldowns) is forgotten.
	if player.has_method("reset_for_new_map"):
		player.reset_for_new_map()
	if "camera_look_ahead" in player:
		var lead: float = scenario.theme.camera_look_ahead if scenario.theme != null else -1.0
		player.camera_look_ahead = lead if lead >= 0.0 else Tuning.CAMERA_LOOK_AHEAD
	var start_room: Room = rooms[layout.start_cell]
	Placement.teleport(player, start_room.global_position + start_room.player_spawn())
	# Nico starts on the height of the start room (the ground, everywhere so far).
	Heights.set_level(player, start_room.height)
	if player.has_method("set_camera_limits"):
		# The backdrop is painted this far past the rooms: the camera may show the top wall's crowns
		# and the side walls of the edge rooms instead of cutting them at the room's line.
		player.set_camera_limits(bounds.grow(_backdrop_margin() * TileArt.TILE))
	# A new map starts somewhere else: the camera jumps there instead of gliding across the world.
	if player.has_method("snap_camera"):
		player.snap_camera()
