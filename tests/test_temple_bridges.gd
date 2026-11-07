extends SceneTree
## The temple's long bridges (TempleBridge): in a synthetic temple of 48x32 cells with rooms of 42x28,
## 34x24 and 26x20 the corridors run from 4 to 22 tiles. A corridor longer than
## Tuning.TEMPLE_LANDING_MIN_TILES gets a landing at mid-span and a shorter one does not; Nico walks a
## long bridge with real physics and can step onto the landing but never into the lava; a corridor
## between rooms one level apart has exactly one StairZone over its stair stretch (across the landing,
## or at the high room's door) with `low_level` the lower room's height, its decks keep out the
## actors of the wrong level and Nico walks from the low room to the high one ending on its level;
## no landing overlaps a room or another corridor; the sea paints no islet and no lava over a landing
## and rims it.
## Run: godot --headless --path . --script res://tests/test_temple_bridges.gd
## `Level`/`Room`/`TempleBridge` must not be referenced as types here (autoload compile order).

const CELL_TILES := Vector2i(48, 32)
const CORRIDOR_TILES := 2
const TILE := 16
const LANE := 4
const BIG := Vector2i(42, 28)
const MEDIUM := Vector2i(34, 24)
const SMALL := Vector2i(26, 20)

var _ok := true
var _level: Node2D
## [coord, dir, from_height, to_height, floor_rect, bridge], in the order Level builds the corridors.
var _corridors: Array = []


func _initialize() -> void:
	create_timer(170.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	root.get_node("PlayerProfile").persistence_enabled = false
	var scenario := _scenario()
	var map_seed := _seed_with_every_kind(scenario)
	_check(map_seed > 0, "a map has a short and a long flat bridge and a short and a long staircase (seed %d)" % map_seed)
	if map_seed <= 0:
		_finish()
		return
	_level = load("res://scenes/levels/temple_level.tscn").instantiate()
	_level.scenario = scenario
	_level.seed_value = map_seed
	_level.use_director = false
	root.add_child(_level)
	for i in 6:
		await physics_frame
	_collect_corridors()
	print("Bridges test map (seed %d):\n%s" % [map_seed, _level.layout.to_ascii()])
	_check_landings()
	_check_stairs()
	_check_overlaps()
	_check_backdrop()
	await _check_crossing()
	await _check_climbing()
	_level.free()
	_finish()


# --- scenario ---------------------------------------------------------------------------------------
func _scenario() -> ScenarioData:
	var scenario := ScenarioData.new()
	scenario.id = &"temple_bridges"
	scenario.grid_size = Vector2i(4, 4)
	scenario.min_main_path = 5
	scenario.max_main_path = 7
	scenario.side_rooms = 2
	scenario.loop_chance = 0.0
	scenario.event_rooms = 0
	scenario.reward_rooms = 0
	scenario.special_rooms = 0
	scenario.cell_tiles = CELL_TILES
	scenario.corridor_tiles = CORRIDOR_TILES
	scenario.theme = load("res://data/themes/temple.tres")
	scenario.start_room = _room_data(&"bridges_start", RoomData.RoomType.START, MEDIUM, 0)
	scenario.boss_room = _room_data(&"bridges_boss", RoomData.RoomType.BOSS, BIG, 1)
	var combat: Array[RoomData] = [
		_room_data(&"bridges_big", RoomData.RoomType.COMBAT, BIG, 0),
		_room_data(&"bridges_medium", RoomData.RoomType.COMBAT, MEDIUM, 1),
		_room_data(&"bridges_small", RoomData.RoomType.COMBAT, SMALL, 0),
	]
	scenario.rooms = combat
	return scenario


func _room_data(id: StringName, type: RoomData.RoomType, size: Vector2i, height: int) -> RoomData:
	var data := RoomData.new()
	data.id = id
	data.type = type
	data.size_tiles = size
	data.height = height
	data.min_enemies = 0
	data.max_enemies = 0
	data.scene = _room_scene(size, height)
	return data


## A room scene with a TempleShape of a plain plan (the wall ring with its doors and floor of the room's height inside)
## and a player spawn in the middle.
func _room_scene(size: Vector2i, height: int) -> PackedScene:
	var room: Node2D = load("res://scenes/levels/rooms/room_base.tscn").instantiate()
	var shape := Node2D.new()
	shape.set_script(load("res://scripts/world/temple_shape.gd"))
	shape.name = "Shape"
	shape.set("rows", "\n".join(_plain_rows(size, height)))
	room.add_child(shape)
	shape.owner = room
	var spawn := Marker2D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector2(size * TILE) / 2.0
	room.add_child(spawn)
	spawn.owner = room
	var packed := PackedScene.new()
	packed.pack(room)
	room.free()
	return packed


func _plain_rows(size: Vector2i, height: int) -> Array:
	var rows := []
	var first_column := size.x / 2 - 2
	var first_row := size.y / 2 - 2
	var floor := "." if height == 0 else str(height)
	for y in size.y:
		var line := ""
		for x in size.x:
			var c := floor
			var ring := x == 0 or y == 0 or x == size.x - 1 or y == size.y - 1
			var on_column := x >= first_column and x < first_column + 4
			var on_row := y >= first_row and y < first_row + 4
			if ring:
				if not ((y == 0 or y == size.y - 1) and on_column) and not ((x == 0 or x == size.x - 1) and on_row):
					c = "#"
			else:
				var dx := mini(x, size.x - 1 - x)
				var dy := mini(y, size.y - 1 - y)
				if dx >= 2 and dx <= size.x / 2 - 4 and dy >= 2 and dy <= size.y / 2 - 4:
					c = "~"
			line += c
		rows.append(line)
	return rows


## Tiles between the facing doors of two neighbouring cells, from their room sizes alone.
func _gap(layout: MapLayout, coord: Vector2i, dir: Vector2i) -> int:
	var axis := 0 if dir == Vector2i.RIGHT else 1
	var a: Vector2i = layout.get_cell(coord).room_data.size_tiles
	var b: Vector2i = layout.get_cell(coord + dir).room_data.size_tiles
	return CORRIDOR_TILES + (CELL_TILES[axis] - a[axis]) / 2 + (CELL_TILES[axis] - b[axis]) / 2


## The first seed whose layout has a flat corridor and a staircase both short (no landing) and long.
func _seed_with_every_kind(scenario: ScenarioData) -> int:
	var threshold := Tuning.TEMPLE_LANDING_MIN_TILES
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
				kinds[[a != b, _gap(layout, coord, dir) > threshold]] = true
		if kinds.size() == 4:
			return map_seed
	return 0


func _collect_corridors() -> void:
	var layout = _level.layout
	var floors: Array = _level._corridor_floors
	var bridges: Array = _level._bridges
	for coord: Vector2i in layout.cells:
		for dir in [Vector2i.RIGHT, Vector2i.DOWN]:
			if layout.are_connected(coord, coord + dir):
				var i := _corridors.size()
				var from_height: int = layout.get_cell(coord).room_data.height
				var to_height: int = layout.get_cell(coord + dir).room_data.height
				_corridors.append([coord, dir, from_height, to_height, floors[i], bridges[i]])


func _length(corridor: Array) -> int:
	var floor_rect: Rect2 = corridor[4]
	return int((floor_rect.size.x if corridor[1] == Vector2i.RIGHT else floor_rect.size.y) / TILE)


func _is_long(corridor: Array) -> bool:
	return _length(corridor) > Tuning.TEMPLE_LANDING_MIN_TILES


func _is_flat(corridor: Array) -> bool:
	return corridor[2] == corridor[3]


func _first(flat: bool, long: bool) -> Array:
	for corridor in _corridors:
		if _is_flat(corridor) == flat and _is_long(corridor) == long:
			return corridor
	return []


# --- landings ---------------------------------------------------------------------------------------
func _check_landings() -> void:
	var long_with := 0
	var long_total := 0
	var short_with := 0
	var short_total := 0
	var shaped := 0
	var corridors: Node = _level.get_node("Map/Corridors")
	for corridor in _corridors:
		var bridge = corridor[5]
		var landing: Rect2i = bridge.landing
		if _is_long(corridor):
			long_total += 1
			long_with += 1 if landing != Rect2i() else 0
		else:
			short_total += 1
			short_with += 1 if landing != Rect2i() else 0
		if landing == Rect2i():
			continue
		# The landing: the lane plus a parapet row on each side, TEMPLE_LANDING_TILES long at mid-span,
		# inside the corridor's length, with its cliff below it and a brazier on each side of the way.
		var floor_rect: Rect2 = corridor[4]
		var floor_cells := _cells(floor_rect)
		var horizontal: bool = corridor[1] == Vector2i.RIGHT
		var across_ok := landing.size.y == LANE + 2 and landing.position.y == floor_cells.position.y - 1 if horizontal \
				else landing.size.x == LANE + 2 and landing.position.x == floor_cells.position.x - 1
		var along_size: int = landing.size.x if horizontal else landing.size.y
		var along_start: int = landing.position.x if horizontal else landing.position.y
		var floor_start: int = floor_cells.position.x if horizontal else floor_cells.position.y
		var middle := floor_start + (_length(corridor) - along_size) / 2
		var faces: Array = bridge.face_cells
		var faces_ok := faces.size() == Tuning.TEMPLE_LANDING_FACE_ROWS * (along_size if horizontal else 2)
		for cell in faces:
			faces_ok = faces_ok and cell.y >= landing.end.y and cell.x >= landing.position.x and cell.x < landing.end.x
		var braziers := 0
		var landing_px := Rect2(Vector2(landing.position * TILE), Vector2(landing.size * TILE))
		for node in corridors.get_children():
			if node.get_script() != null and node.get_script().get_global_name() == &"TempleProp" \
					and landing_px.has_point(node.position):
				braziers += 1
		if across_ok and along_size == Tuning.TEMPLE_LANDING_TILES and along_start == middle and faces_ok \
				and braziers == (2 if Tuning.TEMPLE_LANDING_BRAZIERS else 0):
			shaped += 1
	_check(long_total > 0 and long_with == long_total, "every corridor over %d tiles has a landing (%d of %d)" % [Tuning.TEMPLE_LANDING_MIN_TILES, long_with, long_total])
	_check(short_total > 0 and short_with == 0, "no shorter corridor has one (%d of %d)" % [short_with, short_total])
	_check(shaped == long_total, "a landing is %d tiles long at mid-span, the lane and both parapet rows wide, with its cliff and two braziers (%d of %d)" % [Tuning.TEMPLE_LANDING_TILES, shaped, long_total])


# --- stairs -----------------------------------------------------------------------------------------
func _check_stairs() -> void:
	var corridors: Node = _level.get_node("Map/Corridors")
	var zones: Array = corridors.find_children("*", "Area2D", false, false).filter(
			func(node: Node) -> bool: return node.get_script() != null and node.get_script().get_global_name() == &"StairZone")
	var space: PhysicsDirectSpaceState2D = _level.get_world_2d().direct_space_state
	var expected := 0
	var one_zone := 0
	var placed := 0
	var guarded := 0
	var stepped := 0
	var steps_h := TileArt.coords(&"stairs_side_steps")
	var steps_v := TileArt.coords(&"stairs_up_steps")
	for corridor in _corridors:
		if _is_flat(corridor):
			continue
		expected += 1
		var bridge = corridor[5]
		var floor_rect: Rect2 = corridor[4]
		var stairs: Rect2i = bridge.stairs
		var stairs_px := Rect2(Vector2(stairs.position * TILE), Vector2(stairs.size * TILE))
		var low: int = mini(corridor[2], corridor[3])
		var high: int = low + 1
		var uphill: Vector2 = Vector2(corridor[1]) if corridor[3] > corridor[2] else -Vector2(corridor[1])
		var mine: Array = zones.filter(func(zone: Node2D) -> bool: return floor_rect.has_point(zone.global_position))
		if mine.size() == 1 and mine[0].low_level == low and mine[0].direction == uphill \
				and mine[0].global_position == stairs_px.get_center() \
				and mine[0].get_child(0).shape.size == stairs_px.size:
			one_zone += 1
		# The stretch: across the landing when there is one, else against the high room's door; never
		# the whole corridor, and the steps are drawn on it.
		var horizontal: bool = corridor[1] == Vector2i.RIGHT
		var along_size: int = stairs.size.x if horizontal else stairs.size.y
		var along_start: int = stairs.position.x if horizontal else stairs.position.y
		var floor_cells := _cells(floor_rect)
		var top_end: int = (floor_cells.end.x if horizontal else floor_cells.end.y) if (uphill.x > 0 or uphill.y > 0) \
				else (floor_cells.position.x if horizontal else floor_cells.position.y)
		var landing: Rect2i = bridge.landing
		var where_ok: bool
		if landing != Rect2i():
			where_ok = landing.encloses(stairs) and along_size == Tuning.TEMPLE_LANDING_STAIR_TILES
		else:
			where_ok = along_size == mini(Tuning.TEMPLE_BRIDGE_STAIR_TILES, _length(corridor)) \
					and (along_start + along_size == top_end or along_start == top_end)
		var cross_ok := stairs.size.y == LANE and stairs.position.y == floor_cells.position.y if horizontal \
				else stairs.size.x == LANE and stairs.position.x == floor_cells.position.x
		if where_ok and cross_ok and _length(corridor) > along_size:
			placed += 1
		var steps_layer := _layer_covering(corridors, "Stairs", stairs, [steps_h if horizontal else steps_v,
				TileArt.coords(&"stairs_side_steps_t"), TileArt.coords(&"stairs_side_steps_b"),
				TileArt.coords(&"stairs_up_steps_l"), TileArt.coords(&"stairs_up_steps_r")])
		if steps_layer != null:
			stepped += 1
		# A body of the low level may not walk onto the high deck, nor one of the high level onto the
		# low deck; each walks its own.
		var half: float = (floor_rect.size.x if horizontal else floor_rect.size.y) / 2.0 - 4.0
		var low_end: Vector2 = floor_rect.get_center() - uphill * half
		var high_end: Vector2 = floor_rect.get_center() + uphill * half
		var middle: Vector2 = stairs_px.get_center()
		var low_mask := 1 << (Heights.block_layer(low) - 1)
		var high_mask := 1 << (Heights.block_layer(high) - 1)
		# A flight at the high room's door has no high deck: the room's own rules take over there.
		var has_high_deck := landing != Rect2i()
		if not _passes(space, middle, low_end, high_mask) and _passes(space, middle, low_end, low_mask) \
				and _passes(space, middle, high_end, high_mask) \
				and (not has_high_deck or not _passes(space, middle, high_end, low_mask)):
			guarded += 1
	_check(expected > 0 and one_zone == expected, "a height-changing corridor has exactly one StairZone over its stair stretch, pointing uphill with low_level set (%d of %d)" % [one_zone, expected])
	_check(placed == expected, "the stretch is across the landing or at the high room's door, the lane wide, never the whole corridor (%d of %d)" % [placed, expected])
	_check(stepped == expected, "the stretch is drawn with the temple's steps (%d of %d)" % [stepped, expected])
	_check(guarded == expected, "the high deck keeps out the low level and the low deck the high one (%d of %d)" % [guarded, expected])


# --- overlaps ---------------------------------------------------------------------------------------
func _check_overlaps() -> void:
	var rooms := {}
	for room in _level.rooms.values():
		var origin := Vector2i(room.global_position) / TILE
		for y in room.size_tiles.y:
			for x in room.size_tiles.x:
				rooms[origin + Vector2i(x, y)] = true
	var overlaps := 0
	var landings := 0
	for corridor in _corridors:
		var bridge = corridor[5]
		if bridge.landing == Rect2i():
			continue
		landings += 1
		var footprint: Array = bridge.stone_cells()
		# Its outline (the solid ring one tile out) too: nothing else may stand there.
		var ring: Rect2i = bridge.landing.grow(1)
		for y in range(ring.position.y, ring.end.y):
			for x in range(ring.position.x, ring.end.x):
				footprint.append(Vector2i(x, y))
		for cell in footprint:
			if rooms.has(cell):
				overlaps += 1
			for other in _corridors:
				if other == corridor:
					continue
				var other_rect: Rect2 = other[4]
				var horizontal: bool = other[1] == Vector2i.RIGHT
				var whole := other_rect.grow_individual(0.0 if horizontal else TILE, TILE if horizontal else 0.0,
						0.0 if horizontal else TILE, TILE if horizontal else 0.0)
				if _cells(whole).has_point(cell):
					overlaps += 1
	_check(landings > 0 and overlaps == 0, "no landing, its cliff or its outline overlaps a room or another corridor (%d cells)" % overlaps)


# --- backdrop ---------------------------------------------------------------------------------------
func _check_backdrop() -> void:
	var backdrop: Node = _level.get_node_or_null("Map/Backdrop")
	_check(backdrop != null, "the map has a lava backdrop")
	if backdrop == null:
		return
	var islets := backdrop.get_node_or_null("Islets") as TileMapLayer
	var lava := backdrop.get_node_or_null("Lava") as TileMapLayer
	var rim := backdrop.get_node_or_null("Rim") as TileMapLayer
	var islet_cells := {}
	if islets != null:
		for cell in islets.get_used_cells():
			islet_cells[cell + _offset(islets)] = true
	var over := 0
	var sea_over := 0
	var rimmed := 0
	var landings := 0
	for corridor in _corridors:
		var bridge = corridor[5]
		if bridge.landing == Rect2i():
			continue
		landings += 1
		var stone: Array = bridge.stone_cells()
		for cell in stone:
			for dy in range(-Tuning.TEMPLE_BACKDROP_ISLET_CLEAR_TILES, Tuning.TEMPLE_BACKDROP_ISLET_CLEAR_TILES + 1):
				for dx in range(-Tuning.TEMPLE_BACKDROP_ISLET_CLEAR_TILES, Tuning.TEMPLE_BACKDROP_ISLET_CLEAR_TILES + 1):
					if islet_cells.has(cell + Vector2i(dx, dy)):
						over += 1
			if lava != null and lava.get_cell_atlas_coords(cell - _offset(lava)) != Vector2i(-1, -1):
				sea_over += 1
		# The sea's crust rims the landing: a rim tile on the open lava just outside its outline.
		var ring: Rect2i = bridge.landing.grow(2)
		var found := false
		if rim != null:
			for cell in rim.get_used_cells():
				if ring.has_point(cell + _offset(rim)) and not bridge.landing.has_point(cell + _offset(rim)):
					found = true
					break
		rimmed += 1 if found else 0
	_check(landings > 0 and over == 0, "the sea paints no islet over or beside a landing (%d cells)" % over)
	_check(sea_over == 0, "the sea paints no lava of its own under a landing (%d cells)" % sea_over)
	_check(rimmed == landings, "the sea rims every landing (%d of %d)" % [rimmed, landings])


# --- walking ----------------------------------------------------------------------------------------
func _check_crossing() -> void:
	var corridor := _first(true, true)
	if corridor.is_empty():
		_check(false, "Nico crosses a long bridge (none)")
		return
	var floor_rect: Rect2 = corridor[4]
	var bridge = corridor[5]
	var dir := Vector2(corridor[1])
	var player: Node2D = _level.player
	var level: int = corridor[2]
	var action: String = "move_right" if corridor[1] == Vector2i.RIGHT else "move_down"
	var length: float = floor_rect.size.dot(dir.abs())
	player.global_position = floor_rect.get_center() - dir * (length / 2.0 + 6.0)
	Heights.set_level(player, level)
	Input.action_press(action)
	var frames := 0
	while frames < 600 and (player.global_position - floor_rect.get_center()).dot(dir) <= length / 2.0:
		await physics_frame
		frames += 1
	Input.action_release(action)
	var crossed := (player.global_position - floor_rect.get_center()).dot(dir) > length / 2.0
	_check(crossed and Heights.level_of(player) == level, "Nico walks a long bridge end to end and stays on its level (%s, %d frames)" % [player.global_position, frames])
	# Sideways on the deck he runs into the parapet; on the landing he reaches its edge and no farther.
	var across := Vector2(dir.y, dir.x)
	var side_action: String = "move_down" if corridor[1] == Vector2i.RIGHT else "move_right"
	var lane_half: float = floor_rect.size.dot(across.abs()) / 2.0
	var landing: Rect2i = bridge.landing
	var landing_px := Rect2(Vector2(landing.position * TILE), Vector2(landing.size * TILE))
	var deck_start: Vector2 = floor_rect.get_center() - dir * (length / 2.0 - 2.0 * TILE)
	player.global_position = deck_start
	Input.action_press(side_action)
	for i in 40:
		await physics_frame
	Input.action_release(side_action)
	var drift: float = (player.global_position - deck_start).dot(across)
	_check(drift > 4.0 and drift < lane_half + 1.0, "on the deck he cannot step off into the lava (moved %.1f px of %.1f)" % [drift, lane_half])
	# A tile short of the landing's middle line, clear of the brazier that stands on it.
	var landing_spot: Vector2 = landing_px.get_center() - dir * (TILE + 4.0) - across * 2.0
	player.global_position = landing_spot
	Input.action_press(side_action)
	for i in 60:
		await physics_frame
	Input.action_release(side_action)
	var landing_half: float = landing_px.size.dot(across.abs()) / 2.0
	drift = (player.global_position - landing_px.get_center()).dot(across)
	_check(drift > lane_half + 2.0 and drift < landing_half + 1.0, "on the landing he steps past the deck's width and stops at its edge (moved %.1f px of %.1f)" % [drift, landing_half])
	# And back across the landing the other way.
	var back: String = "move_up" if corridor[1] == Vector2i.RIGHT else "move_left"
	Input.action_press(back)
	for i in 120:
		await physics_frame
	Input.action_release(back)
	drift = (player.global_position - landing_px.get_center()).dot(across)
	_check(drift < -lane_half - 2.0 and drift > -landing_half - 1.0, "and the same on its other side (moved %.1f px)" % drift)


func _check_climbing() -> void:
	for long in [true, false]:
		var corridor := _first(false, long)
		if corridor.is_empty():
			_check(false, "Nico climbs a %s staircase corridor (none)" % ("long" if long else "short"))
			continue
		var floor_rect: Rect2 = corridor[4]
		var uphill: Vector2 = Vector2(corridor[1]) if corridor[3] > corridor[2] else -Vector2(corridor[1])
		var action: String = {Vector2.RIGHT: "move_right", Vector2.LEFT: "move_left", Vector2.DOWN: "move_down", Vector2.UP: "move_up"}[uphill]
		var low: int = mini(corridor[2], corridor[3])
		var player: Node2D = _level.player
		var length: float = floor_rect.size.dot(uphill.abs())
		# From inside the low room's doorway to inside the high room's.
		var start: Vector2 = floor_rect.get_center() - uphill * (length / 2.0 + 10.0)
		var goal: float = length / 2.0 + 10.0
		player.global_position = start
		Heights.set_level(player, low)
		Input.action_press(action)
		var frames := 0
		while frames < 600 and (player.global_position - floor_rect.get_center()).dot(uphill) < goal - 1.0:
			await physics_frame
			frames += 1
		Input.action_release(action)
		var arrived := (player.global_position - floor_rect.get_center()).dot(uphill) >= goal - 1.0
		_check(arrived and Heights.level_of(player) == low + 1,
				"Nico walks a %s staircase corridor from the low room into the high one and ends on level %d (%s, level %d, %d frames; corridor %s stairs %s uphill %s)" % ["long" if long else "short", low + 1, player.global_position, Heights.level_of(player), frames, floor_rect, corridor[5].stairs, uphill])
		var back: String = {"move_right": "move_left", "move_left": "move_right", "move_down": "move_up", "move_up": "move_down"}[action]
		Input.action_press(back)
		frames = 0
		while frames < 600 and (player.global_position - floor_rect.get_center()).dot(uphill) > -goal + 1.0:
			await physics_frame
			frames += 1
		Input.action_release(back)
		_check(Heights.level_of(player) == low, "and walking back down leaves him on level %d (%d)" % [low, Heights.level_of(player)])


# --- helpers ----------------------------------------------------------------------------------------
func _cells(rect: Rect2) -> Rect2i:
	return Rect2i(Vector2i(rect.position) / TILE, Vector2i(rect.size) / TILE)


func _offset(layer: TileMapLayer) -> Vector2i:
	return Vector2i(layer.global_position) / TILE


## The TileMapLayer child of `parent` named `prefix<n>` with a tile of `allowed` on every cell of `cells`.
func _layer_covering(parent: Node, prefix: String, cells: Rect2i, allowed: Array) -> TileMapLayer:
	for child in parent.get_children():
		var layer := child as TileMapLayer
		if layer == null or not String(layer.name).begins_with(prefix):
			continue
		var covers := true
		for y in range(cells.position.y, cells.end.y):
			for x in range(cells.position.x, cells.end.x):
				var coords := layer.get_cell_atlas_coords(Vector2i(x, y) - _offset(layer))
				if coords == Vector2i(-1, -1) or not allowed.has(coords):
					covers = false
		if covers:
			return layer
	return null


## A Nico-sized box swept from `from` to `to` against `mask` passes without a hit.
func _passes(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2, mask: int) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 12)
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, from)
	params.motion = to - from
	params.collision_mask = mask
	var result := space.cast_motion(params)
	return result.size() == 2 and result[0] >= 1.0


func _finish() -> void:
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
