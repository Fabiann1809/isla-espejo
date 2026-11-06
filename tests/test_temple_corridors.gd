extends SceneTree
## The temple's level-wide look: a same-height corridor is a stone bridge over lava (deck, rails,
## posts, lava under the whole corridor), a corridor between rooms of different height is a
## staircase with a StairZone whose `low_level` is the lower room's height (0<->1 and 1<->2) and a
## brazier on each rail at its top, Nico crosses a bridge and its rails keep him out of the lava,
## and the lava sea (LavaBackdrop) covers everything outside the rooms with animated lava, islets
## and lava falls, never reaching over a room.
## Run: godot --headless --path . --script res://tests/test_temple_corridors.gd
## `Level`/`Room` must not be referenced as types here (autoload compile order).

const ROOM_TILES := Vector2i(30, 18)
const TILE := 16

var _ok := true
var _level: Node2D
## [coord, dir, from_height, to_height, floor_rect], in the order Level builds the corridors.
var _corridors: Array = []


func _initialize() -> void:
	create_timer(170.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	root.get_node("PlayerProfile").persistence_enabled = false

	var scenario := _scenario()
	var map_seed := _seed_with_every_corridor_kind(scenario)
	_check(map_seed > 0, "a small temple map has a flat corridor, a 0<->1 staircase and a 1<->2 staircase (seed %d)" % map_seed)
	if map_seed <= 0:
		_finish()
		return
	_level = load("res://scenes/levels/forest_level.tscn").instantiate()
	_level.scenario = scenario
	_level.seed_value = map_seed
	_level.use_director = false
	root.add_child(_level)
	for i in 6:
		await physics_frame
	_collect_corridors()
	print("Temple test map (seed %d):\n%s" % [map_seed, _level.layout.to_ascii()])

	_check_bridges()
	_check_stairs()
	await _check_crossing()
	await _check_climbing()
	_check_backdrop()
	_check_boundary()
	_level.free()
	_finish()


# --- scenario ---------------------------------------------------------------------------------------
func _scenario() -> ScenarioData:
	var scenario: ScenarioData = load("res://data/scenarios/test.tres").duplicate()
	scenario.theme = load("res://data/themes/temple.tres")
	scenario.grid_size = Vector2i(3, 2)
	scenario.min_main_path = 3
	scenario.max_main_path = 5
	scenario.side_rooms = 1
	scenario.event_rooms = 0
	scenario.reward_rooms = 0
	scenario.special_rooms = 0
	scenario.start_room = scenario.start_room.duplicate()
	scenario.start_room.height = 0
	scenario.boss_room = scenario.boss_room.duplicate()
	scenario.boss_room.height = 1
	var heights := [1, 2, 1, 2]
	var rooms: Array[RoomData] = []
	for data in scenario.rooms:
		if data.type != RoomData.RoomType.COMBAT:
			continue
		var copy: RoomData = data.duplicate()
		copy.height = heights[rooms.size() % heights.size()]
		# Nobody shoves Nico while he walks the bridges (enemies' heights: test_stairs_corridor).
		copy.min_enemies = 0
		copy.max_enemies = 0
		rooms.append(copy)
	scenario.rooms = rooms
	return scenario


## The first seed whose layout joins rooms of the same height, of heights 0 and 1 and of 1 and 2.
func _seed_with_every_corridor_kind(scenario: ScenarioData) -> int:
	for map_seed in range(1, 400):
		var layout := MapGenerator.generate(scenario, map_seed)
		if not layout.validate().is_empty():
			continue
		var kinds := {}
		for coord: Vector2i in layout.cells:
			for dir in [Vector2i.RIGHT, Vector2i.DOWN]:
				if not layout.are_connected(coord, coord + dir):
					continue
				var a: int = layout.get_cell(coord).room_data.height
				var b: int = layout.get_cell(coord + dir).room_data.height
				kinds[[mini(a, b), maxi(a, b)]] = true
		if kinds.has([0, 1]) and kinds.has([1, 2]) and (kinds.has([0, 0]) or kinds.has([1, 1]) or kinds.has([2, 2])):
			return map_seed
	return 0


## The corridors as Level built them (same order as its `_corridor_floors`).
func _collect_corridors() -> void:
	var layout = _level.layout
	var floors: Array = _level._corridor_floors
	for coord: Vector2i in layout.cells:
		for dir in [Vector2i.RIGHT, Vector2i.DOWN]:
			if layout.are_connected(coord, coord + dir):
				var from_height: int = layout.get_cell(coord).room_data.height
				var to_height: int = layout.get_cell(coord + dir).room_data.height
				_corridors.append([coord, dir, from_height, to_height, floors[_corridors.size()]])


func _flat_corridors() -> Array:
	return _corridors.filter(func(c: Array) -> bool: return c[2] == c[3])


func _stair_corridors() -> Array:
	return _corridors.filter(func(c: Array) -> bool: return c[2] != c[3])


# --- bridges ----------------------------------------------------------------------------------------
func _check_bridges() -> void:
	var corridors: Node = _level.get_node("Map/Corridors")
	var deck_h := TileArt.coords(&"bridge_stone_deck_h")
	var deck_v := TileArt.coords(&"bridge_stone_deck_v")
	var post := TileArt.coords(&"bridge_stone_post")
	var rails := {
		&"n": TileArt.coords(&"bridge_stone_rail_n"), &"e": TileArt.coords(&"bridge_stone_rail_e"),
		&"w": TileArt.coords(&"bridge_stone_rail_w"),
	}
	var bridges := 0
	var with_lava := 0
	var with_rails := 0
	var with_posts := 0
	var near_rail_upright := 0
	for corridor in _flat_corridors():
		var floor_rect: Rect2 = corridor[4]
		var horizontal: bool = corridor[1] == Vector2i.RIGHT
		var floor_cells := _cells(floor_rect)
		var walls := _walls_of(floor_rect, horizontal)
		var deck := _layer_with(corridors, "Corridor", floor_cells, [deck_h if horizontal else deck_v])
		if deck == null:
			continue
		bridges += 1
		# Animated lava under the whole corridor rectangle (floor and both walls).
		var lava := _layer_with(corridors, "CorridorLava", floor_cells, [])
		var lava_ok := lava != null and _animated(lava, floor_cells.position, 8)
		for wall in walls:
			lava_ok = lava_ok and _covers(lava, _cells(wall), [])
		with_lava += 1 if lava_ok else 0
		# The flat rails (with a post at each end) lie on the deck's layer; on a horizontal bridge the
		# south rail stands upright, y-sorted with the actors by its foot.
		var flat_walls: Array = walls if not horizontal else [walls[0]]
		var rails_ok := true
		var posts_ok := true
		for wall in flat_walls:
			var role: StringName = &"n" if horizontal else (&"w" if wall.position.x < floor_rect.position.x else &"e")
			var cells := _cells(wall)
			rails_ok = rails_ok and _covers(deck, cells, [rails[role], post])
			var first := deck.get_cell_atlas_coords(cells.position - _offset(deck))
			var last := deck.get_cell_atlas_coords(cells.end - Vector2i.ONE - _offset(deck))
			posts_ok = posts_ok and first == post and last == post
		with_rails += 1 if rails_ok else 0
		with_posts += 1 if posts_ok else 0
		if horizontal:
			var south: Rect2 = walls[1]
			for node in corridors.get_children():
				if node is Node2D and String(node.name).begins_with("BridgeRail") and south.has_point(node.global_position) \
						and node.z_index == 0 and node.get_child_count() == int(south.size.x / TILE):
					near_rail_upright += 1
					break
	var expected := _flat_corridors().size()
	var horizontal_flat: int = _flat_corridors().filter(func(c: Array) -> bool: return c[1] == Vector2i.RIGHT).size()
	_check(expected > 0 and bridges == expected and with_lava == expected,
			"a same-height corridor is a bridge with lava under it (%d of %d, %d with lava)" % [bridges, expected, with_lava])
	_check(with_rails == expected and with_posts == expected, "every bridge has stone rails with a post at each end (%d, %d of %d)" % [with_rails, with_posts, expected])
	_check(near_rail_upright == horizontal_flat, "the south rail of a horizontal bridge stands upright and y-sorted (%d of %d)" % [near_rail_upright, horizontal_flat])


# --- stairs -----------------------------------------------------------------------------------------
func _check_stairs() -> void:
	var corridors: Node = _level.get_node("Map/Corridors")
	var zones: Array = corridors.find_children("*", "Area2D", false, false).filter(
			func(node: Node) -> bool: return node.get_script() != null and node.get_script().get_global_name() == &"StairZone")
	var braziers: Array = corridors.get_children().filter(func(node: Node) -> bool:
			return node.get_script() != null and node.get_script().get_global_name() == &"TempleProp")
	var pedestal: int = 0
	if not braziers.is_empty():
		pedestal = braziers[0].get_script().get_script_constant_map()["Kind"]["BRAZIER_PEDESTAL"]
	var steps_up := TileArt.coords(&"stairs_up_steps")
	var steps_side := TileArt.coords(&"stairs_side_steps")
	var low0 := 0
	var low1 := 0
	var expected0 := 0
	var expected1 := 0
	var with_steps := 0
	var with_braziers := 0
	var with_direction := 0
	for corridor in _stair_corridors():
		var floor_rect: Rect2 = corridor[4]
		var vertical: bool = corridor[1] == Vector2i.DOWN
		var low: int = mini(corridor[2], corridor[3])
		var uphill: Vector2 = Vector2(corridor[1]) if corridor[3] > corridor[2] else -Vector2(corridor[1])
		if low == 0:
			expected0 += 1
		else:
			expected1 += 1
		for zone in zones:
			if floor_rect.has_point(zone.global_position) and zone.low_level == low:
				if low == 0:
					low0 += 1
				else:
					low1 += 1
				if zone.direction == uphill:
					with_direction += 1
				break
		if _layer_with(corridors, "Stairs", _cells(floor_rect), [steps_up if vertical else steps_side]) != null:
			with_steps += 1
		# A brazier on a pedestal at the top end of the stairs on each side: just past the end, on the
		# high room's wall beside its door.
		var top_end: Vector2 = floor_rect.get_center() + uphill * (floor_rect.size.dot(uphill.abs()) / 2.0)
		var half_width: float = floor_rect.size.dot(Vector2(uphill.y, uphill.x).abs()) / 2.0
		var count := 0
		for brazier in braziers:
			var at: Vector2 = brazier.global_position
			var along: float = (at - top_end).dot(uphill)
			var across: float = absf((at - floor_rect.get_center()).dot(Vector2(uphill.y, uphill.x)))
			if brazier.kind == pedestal and along > 0.0 and along <= TILE and across > half_width and across < half_width + TILE:
				count += 1
		with_braziers += 1 if count == 2 else 0
	var expected := expected0 + expected1
	_check(expected0 > 0 and low0 == expected0, "a height-changing corridor has a StairZone with low_level 0 (%d of %d)" % [low0, expected0])
	_check(expected1 > 0 and low1 == expected1, "a 1<->2 corridor has a StairZone with low_level 1 (%d of %d)" % [low1, expected1])
	_check(with_direction == expected and zones.size() == expected, "every StairZone points uphill and there is one per staircase (%d, %d of %d)" % [with_direction, zones.size(), expected])
	_check(with_steps == expected, "every staircase is drawn with the temple's stair tiles (%d of %d)" % [with_steps, expected])
	_check(with_braziers == expected, "every staircase has a brazier on a pedestal on each rail at its top (%d of %d)" % [with_braziers, expected])


# --- walking ----------------------------------------------------------------------------------------
func _check_crossing() -> void:
	var flat := _flat_corridors()
	if flat.is_empty():
		_check(false, "Nico crosses the bridge (no flat corridor)")
		return
	var corridor: Array = flat[0]
	var floor_rect: Rect2 = corridor[4]
	var dir := Vector2(corridor[1])
	var player: Node2D = _level.player
	var level: int = corridor[2]
	var action: String = "move_right" if corridor[1] == Vector2i.RIGHT else "move_down"
	var length: float = floor_rect.size.dot(dir.abs())
	player.global_position = floor_rect.get_center() - dir * (length / 2.0 + 6.0)
	Heights.set_level(player, level)
	Input.action_press(action)
	for i in 60:
		await physics_frame
	Input.action_release(action)
	var crossed := (player.global_position - floor_rect.get_center()).dot(dir) > length / 2.0
	_check(crossed and Heights.level_of(player) == level, "Nico crosses the bridge and stays on its level (%s)" % player.global_position)
	# Sideways he runs into the rails: the bridge keeps him out of the lava.
	var across := Vector2(dir.y, dir.x)
	var side_action: String = "move_down" if corridor[1] == Vector2i.RIGHT else "move_right"
	var half: float = floor_rect.size.dot(across.abs()) / 2.0
	player.global_position = floor_rect.get_center()
	Input.action_press(side_action)
	for i in 40:
		await physics_frame
	Input.action_release(side_action)
	var drift: float = (player.global_position - floor_rect.get_center()).dot(across)
	_check(drift > 4.0 and drift < half + 1.0, "and cannot step off it into lava (moved %.1f px of %.1f)" % [drift, half])


func _check_climbing() -> void:
	var stairs: Array = _stair_corridors().filter(func(c: Array) -> bool: return mini(c[2], c[3]) == 1)
	if stairs.is_empty():
		_check(false, "Nico climbs a 1<->2 staircase (none)")
		return
	var corridor: Array = stairs[0]
	var floor_rect: Rect2 = corridor[4]
	var uphill: Vector2 = Vector2(corridor[1]) if corridor[3] > corridor[2] else -Vector2(corridor[1])
	var action: String = {Vector2.RIGHT: "move_right", Vector2.LEFT: "move_left", Vector2.DOWN: "move_down", Vector2.UP: "move_up"}[uphill]
	var player: Node2D = _level.player
	var length: float = floor_rect.size.dot(uphill.abs())
	player.global_position = floor_rect.get_center() - uphill * (length / 2.0 + 14.0)
	Heights.set_level(player, 1)
	Input.action_press(action)
	for i in 70:
		await physics_frame
	Input.action_release(action)
	_check(Heights.level_of(player) == 2, "walking up a 1<->2 staircase corridor takes Nico to level 2 (%s)" % player.global_position)
	var back: String = {"move_right": "move_left", "move_left": "move_right", "move_down": "move_up", "move_up": "move_down"}[action]
	Input.action_press(back)
	for i in 70:
		await physics_frame
	Input.action_release(back)
	_check(Heights.level_of(player) == 1, "and walking back down leaves him on level 1 (%s)" % player.global_position)


# --- backdrop ---------------------------------------------------------------------------------------
func _check_backdrop() -> void:
	var backdrop: Node = _level.get_node_or_null("Map/Backdrop")
	_check(backdrop != null and backdrop.z_index < RoomTheme.FLOOR_Z, "the map has a backdrop drawn below the floors")
	if backdrop == null:
		return
	var lava := backdrop.get_node_or_null("Lava") as TileMapLayer
	var rooms := {}
	for room in _level.rooms.values():
		for y in ROOM_TILES.y:
			for x in ROOM_TILES.x:
				rooms[Vector2i(room.global_position) / TILE + Vector2i(x, y)] = true
	var corridor_cells := {}
	for corridor in _corridors:
		var floor_rect: Rect2 = corridor[4]
		for rect in [floor_rect] + _walls_of(floor_rect, corridor[1] == Vector2i.RIGHT):
			var cells := _cells(rect)
			for y in range(cells.position.y, cells.end.y):
				for x in range(cells.position.x, cells.end.x):
					corridor_cells[Vector2i(x, y)] = true
	var bounds: Rect2 = _level.bounds
	var area := Rect2i(Vector2i(bounds.position) / TILE, Vector2i(bounds.size) / TILE).grow(Tuning.TEMPLE_BACKDROP_MARGIN_TILES)
	var missing := 0
	var over_rooms := 0
	var animated := lava != null
	if lava != null:
		var used := {}
		for cell in lava.get_used_cells():
			used[cell + _offset(lava)] = true
		for y in range(area.position.y, area.end.y):
			for x in range(area.position.x, area.end.x):
				var cell := Vector2i(x, y)
				if rooms.has(cell) or corridor_cells.has(cell):
					over_rooms += 1 if used.has(cell) else 0
				elif not used.has(cell):
					missing += 1
		animated = _animated(lava, area.position, 8)
	_check(lava != null and missing == 0 and over_rooms == 0 and animated,
			"the backdrop covers the outside with animated lava and never overlaps a room (%d missing, %d over rooms)" % [missing, over_rooms])
	# Islets of rock with cliff faces, never touching a room or a corridor.
	var islets := backdrop.get_node_or_null("Islets") as TileMapLayer
	var islet_cells := 0
	var touching := 0
	var faces := 0
	var foot_coords := TileArt.coords(&"cliff_foot_lava_m")
	var glow := backdrop.get_node_or_null("Glow") as TileMapLayer
	if islets != null:
		for cell in islets.get_used_cells():
			islet_cells += 1
			var at: Vector2i = cell + _offset(islets)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if rooms.has(at + Vector2i(dx, dy)) or corridor_cells.has(at + Vector2i(dx, dy)):
						touching += 1
	if glow != null:
		for cell in glow.get_used_cells():
			if glow.get_cell_atlas_coords(cell) == foot_coords:
				faces += 1
	_check(islets != null and islet_cells > 0 and touching == 0 and faces > 0,
			"the sea has islets of rock with lava-lit cliff faces that never touch a room or corridor (%d cells, %d faces, %d touching)" % [islet_cells, faces, touching])
	var props: Array = backdrop.find_children("*", "Node2D", true, false).filter(func(node: Node) -> bool:
			return node.get_script() != null and node.get_script().get_global_name() == &"TempleProp")
	var falls := 0
	var rocks := 0
	var vents := 0
	for prop in props:
		var kinds: Dictionary = prop.get_script().get_script_constant_map()["Kind"]
		if prop.kind == kinds["LAVA_FALL"]:
			falls += 1
		elif prop.kind == kinds["ROCK_SMOKING"]:
			rocks += 1
		elif prop.kind == kinds["EMBER_VENT"]:
			vents += 1
	_check(falls > 0 and rocks > 0 and vents > 0, "lava falls, smoking rocks and ember vents dress the sea (%d, %d, %d)" % [falls, rocks, vents])
	var shade := backdrop.get_node_or_null("Crust")
	_check(shade != null, "the sea darkens into crust away from the rooms")


func _check_boundary() -> void:
	var boundary: Node = _level.get_node_or_null("LavaBoundary")
	var shapes := 0
	if boundary != null:
		shapes = boundary.find_children("*", "CollisionShape2D", true, false).size()
	_check(boundary != null and shapes == 4, "solid collision closes the map around its bounds (%d walls)" % shapes)


# --- helpers ----------------------------------------------------------------------------------------
func _cells(rect: Rect2) -> Rect2i:
	return Rect2i(Vector2i(rect.position) / TILE, Vector2i(rect.size) / TILE)


## The two wall rectangles of a corridor, as Level lays them out (first north/west, then south/east).
func _walls_of(floor_rect: Rect2, horizontal: bool) -> Array:
	if horizontal:
		return [Rect2(floor_rect.position.x, floor_rect.position.y - TILE, floor_rect.size.x, TILE),
				Rect2(floor_rect.position.x, floor_rect.end.y, floor_rect.size.x, TILE)]
	return [Rect2(floor_rect.position.x - TILE, floor_rect.position.y, TILE, floor_rect.size.y),
			Rect2(floor_rect.end.x, floor_rect.position.y, TILE, floor_rect.size.y)]


func _offset(layer: TileMapLayer) -> Vector2i:
	return Vector2i(layer.global_position) / TILE


## True if `layer` has a tile on every cell of `cells` (world tiles), each one of `allowed` (any if empty).
func _covers(layer: TileMapLayer, cells: Rect2i, allowed: Array) -> bool:
	if layer == null:
		return false
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			var coords := layer.get_cell_atlas_coords(Vector2i(x, y) - _offset(layer))
			if coords == Vector2i(-1, -1) or (not allowed.is_empty() and not allowed.has(coords)):
				return false
	return true


## The TileMapLayer child of `parent` named `prefix<n>` that covers `cells` with `allowed` tiles.
func _layer_with(parent: Node, prefix: String, cells: Rect2i, allowed: Array) -> TileMapLayer:
	for child in parent.get_children():
		var layer := child as TileMapLayer
		if layer == null or not String(layer.name).begins_with(prefix):
			continue
		if prefix == "Corridor" and String(layer.name).begins_with("CorridorLava"):
			continue
		if _covers(layer, cells, allowed):
			return layer
	return null


## True if the tile `layer` draws at world cell `cell` is animated with `frames` frames.
func _animated(layer: TileMapLayer, cell: Vector2i, frames: int) -> bool:
	var coords := layer.get_cell_atlas_coords(cell - _offset(layer))
	if coords == Vector2i(-1, -1):
		return false
	var source := layer.tile_set.get_source(layer.get_cell_source_id(cell - _offset(layer))) as TileSetAtlasSource
	return source != null and source.get_tile_animation_frames_count(coords) == frames


func _finish() -> void:
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
