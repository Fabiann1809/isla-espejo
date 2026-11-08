extends SceneTree
## Rooms of different sizes in a bigger grid cell: a synthetic temple scenario with cells of 48x32 tiles,
## corridors of 2 tiles and rooms of 42x28, 34x24 and 26x20 (simple temple plans of those sizes). Every room
## is centred in its cell, neighbouring doors line up, each corridor exactly fills the gap between the two
## facing doors, Nico walks through it with real physics, the room reports its own size, TemplePlan
## validates plans of every size and a plan that is not its room's size raises an error.
## Run: godot --headless --path . --script res://tests/test_room_sizes.gd

const CELL_TILES := Vector2i(48, 32)
const CORRIDOR_TILES := 2
const SIZES: Array[Vector2i] = [Vector2i(42, 28), Vector2i(34, 24), Vector2i(26, 20)]
const TILE := 16
const DOOR_WIDTH := 64
const WALL := 16
const SEEDS := 8

var _ok := true


func _initialize() -> void:
	create_timer(170.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var scenario := _scenario()
	await _check_plans()
	await _check_level(scenario)
	await _check_mismatch()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


# --- the synthetic scenario -------------------------------------------------------------------------
func _scenario() -> ScenarioData:
	var scenario := ScenarioData.new()
	scenario.id = &"room_sizes"
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
	scenario.start_room = _room_data(&"sized_start", RoomData.RoomType.START, SIZES[1])
	scenario.boss_room = _room_data(&"sized_boss", RoomData.RoomType.BOSS, SIZES[0])
	var combat: Array[RoomData] = []
	for size in SIZES:
		combat.append(_room_data(StringName("sized_%dx%d" % [size.x, size.y]), RoomData.RoomType.COMBAT, size))
	scenario.rooms = combat
	return scenario


func _room_data(id: StringName, type: RoomData.RoomType, size: Vector2i, plan_size := Vector2i.ZERO) -> RoomData:
	var data := RoomData.new()
	data.id = id
	data.type = type
	data.size_tiles = size
	data.min_enemies = 0
	data.max_enemies = 0
	data.scene = _room_scene(plan_size if plan_size != Vector2i.ZERO else size)
	return data


## A room scene with a TempleShape of the given plan size and a player spawn in the middle.
func _room_scene(plan_size: Vector2i) -> PackedScene:
	var room: Node2D = load("res://scenes/levels/rooms/room_base.tscn").instantiate()
	var shape := Node2D.new()
	shape.set_script(load("res://scripts/world/temple_shape.gd"))
	shape.name = "Shape"
	shape.set("rows", "\n".join(_sized_rows(plan_size)))
	room.add_child(shape)
	shape.owner = room
	var spawn := Marker2D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector2(plan_size * TILE) / 2.0
	room.add_child(spawn)
	spawn.owner = room
	var packed := PackedScene.new()
	packed.pack(room)
	room.free()
	return packed


## The wall ring with its four doors, floor inside and a block of lava in each quadrant clear of the lanes.
func _sized_rows(size: Vector2i) -> Array:
	var rows := []
	var first_column := size.x / 2 - 2
	var first_row := size.y / 2 - 2
	for y in size.y:
		var line := ""
		for x in size.x:
			var c := "."
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


# --- plans ------------------------------------------------------------------------------------------
func _check_plans() -> void:
	for size in SIZES:
		var plan := TemplePlan.parse("\n".join(_sized_rows(size)))
		_check(plan.errors.is_empty() and plan.size_cells() == size and plan.validate().is_empty(),
				"a %dx%d temple plan reads its size and validates (%s %s)" % [size.x, size.y, plan.errors, plan.validate()])


# --- the level --------------------------------------------------------------------------------------
func _check_level(scenario: ScenarioData) -> void:
	var level = load("res://scenes/levels/temple_level.tscn").instantiate()
	level.use_director = false
	level.scenario = scenario
	level.seed_value = 1
	root.add_child(level)
	await _frames(2)
	_check(level.cell_size() == Vector2(CELL_TILES * TILE) and level.stride() == Vector2((CELL_TILES + Vector2i.ONE * CORRIDOR_TILES) * TILE),
			"the cell is 768x512 px and the stride 832x544 px")
	var big := RoomData.new()
	big.size_tiles = Vector2i(50, 28)
	var odd := RoomData.new()
	odd.size_tiles = Vector2i(33, 28)
	_check(level.room_fit_problem(big) != "" and level.room_fit_problem(odd) != "" and level.room_fit_problem(scenario.boss_room) == "",
			"a room larger than the cell or off by an odd number of tiles is reported, a fitting one is not")

	var bad := {"centered": 0, "doors": 0, "corridor": 0, "walk": 0, "control": 0, "size": 0, "bounds": 0, "start": 0}
	var connections := 0
	var mixed := 0
	var sizes_seen := {}
	for map_seed in range(1, SEEDS + 1):
		level.generate(map_seed)
		await _frames(2)
		_check_rooms(level, bad, sizes_seen)
		var space: PhysicsDirectSpaceState2D = level.get_world_2d().direct_space_state
		for coord: Vector2i in level.layout.cells:
			for dir in [Vector2i.RIGHT, Vector2i.DOWN]:
				var next: Vector2i = coord + dir
				if not level.layout.are_connected(coord, next):
					continue
				connections += 1
				if level.room_size(coord) != level.room_size(next):
					mixed += 1
				_check_connection(level, space, coord, dir, bad)
	_check(sizes_seen.size() == 3, "rooms of all three sizes were built (%s)" % [sizes_seen.keys()])
	_check(connections > 20 and mixed > 5, "%d connections, %d of them between rooms of different sizes" % [connections, mixed])
	_check(bad["centered"] == 0, "every room is centred in its cell on whole tiles (bad: %d)" % bad["centered"])
	_check(bad["size"] == 0, "Room.pixel_size, center and home_rect match the room's size (bad: %d)" % bad["size"])
	_check(bad["doors"] == 0, "the doors of neighbouring rooms line up (bad: %d)" % bad["doors"])
	_check(bad["corridor"] == 0, "each corridor exactly fills the gap between its two doors (bad: %d)" % bad["corridor"])
	_check(bad["walk"] == 0, "Nico can walk from room to room through every corridor (blocked: %d)" % bad["walk"])
	_check(bad["control"] == 0, "the walk test does see walls: a path off the doors is blocked (open: %d)" % bad["control"])
	_check(bad["bounds"] == 0, "the map's bounds enclose every room (bad: %d)" % bad["bounds"])
	_check(bad["start"] == 0, "Nico starts inside the start room (bad: %d)" % bad["start"])
	level.queue_free()
	await _frames(2)


func _check_rooms(level: Node, bad: Dictionary, sizes_seen: Dictionary) -> void:
	for coord: Vector2i in level.layout.cells:
		var room = level.rooms[coord]
		var size: Vector2i = level.layout.get_cell(coord).room_data.size_tiles
		sizes_seen[size] = true
		var px := Vector2(size * TILE)
		var expected: Vector2 = level.cell_origin(coord) + Vector2((CELL_TILES - size) / 2 * TILE)
		var cell_center: Vector2 = level.cell_origin(coord) + Vector2(CELL_TILES * TILE) / 2.0
		if room.global_position != expected or room.global_position + px / 2.0 != cell_center \
				or room.global_position.x != floorf(room.global_position.x / TILE) * TILE \
				or room.global_position.y != floorf(room.global_position.y / TILE) * TILE:
			bad["centered"] += 1
		if room.size_tiles != size or room.pixel_size() != px or room.center() != px / 2.0 \
				or room.home_rect() != Rect2(room.global_position, px):
			bad["size"] += 1
		if not level.bounds.encloses(Rect2(room.global_position, px)):
			bad["bounds"] += 1
	var start = level.rooms[level.layout.start_cell]
	if not Rect2(start.global_position, start.pixel_size()).grow(-float(TILE)).has_point(level.player.global_position):
		bad["start"] += 1


## One corridor: the doors line up, the floor spans the gap between the rooms and Nico crosses it.
func _check_connection(level: Node, space: PhysicsDirectSpaceState2D, coord: Vector2i, dir: Vector2i, bad: Dictionary) -> void:
	var a = level.rooms[coord]
	var b = level.rooms[coord + dir]
	var a_rect := Rect2(a.global_position, a.pixel_size())
	var b_rect := Rect2(b.global_position, b.pixel_size())
	var horizontal := dir == Vector2i.RIGHT
	# Doors: the middle 4 cells of the facing edges, on the same line.
	var a_door := a_rect.get_center().y if horizontal else a_rect.get_center().x
	var b_door := b_rect.get_center().y if horizontal else b_rect.get_center().x
	if a_door != b_door:
		bad["doors"] += 1
	var half := DOOR_WIDTH / 2.0
	var floor_rect: Rect2
	var walls: Array[Rect2] = []
	if horizontal:
		floor_rect = Rect2(a_rect.end.x, a_door - half, b_rect.position.x - a_rect.end.x, DOOR_WIDTH)
		walls = [Rect2(floor_rect.position.x, floor_rect.position.y - WALL, floor_rect.size.x, WALL),
				Rect2(floor_rect.position.x, floor_rect.end.y, floor_rect.size.x, WALL)]
	else:
		floor_rect = Rect2(a_door - half, a_rect.end.y, DOOR_WIDTH, b_rect.position.y - a_rect.end.y)
		walls = [Rect2(floor_rect.position.x - WALL, floor_rect.position.y, WALL, floor_rect.size.y),
				Rect2(floor_rect.end.x, floor_rect.position.y, WALL, floor_rect.size.y)]
	var gap := (b_rect.position.x - a_rect.end.x) if horizontal else (b_rect.position.y - a_rect.end.y)
	# The corridor between the cells plus what each room leaves free of its own cell.
	var axis := 0 if horizontal else 1
	var margin_a: int = (CELL_TILES[axis] - int(a_rect.size[axis] / TILE)) / 2
	var margin_b: int = (CELL_TILES[axis] - int(b_rect.size[axis] / TILE)) / 2
	var expected_gap := float((CORRIDOR_TILES + margin_a + margin_b) * TILE)
	if gap <= 0.0 or gap != expected_gap or not level._corridor_floors.has(floor_rect) \
			or not level._corridor_walls.has(walls[0]) or not level._corridor_walls.has(walls[1]) \
			or level.corridor_floor(coord, dir) != floor_rect:
		bad["corridor"] += 1
	# Nico-sized body from inside A's doorway to inside B's, and a control off the doors.
	var margin := 14.0
	var from: Vector2
	var to: Vector2
	var off := Vector2.ZERO
	if horizontal:
		from = Vector2(a_rect.end.x - margin, a_door)
		to = Vector2(b_rect.position.x + margin, b_door)
		off = Vector2(0, 112)
	else:
		from = Vector2(a_door, a_rect.end.y - margin)
		to = Vector2(b_door, b_rect.position.y + margin)
		off = Vector2(112, 0)
	if not _passes(space, from, to):
		bad["walk"] += 1
	if _passes(space, from + off, to + off):
		bad["control"] += 1


func _passes(space: PhysicsDirectSpaceState2D, from: Vector2, to: Vector2) -> bool:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 12)
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, from)
	params.motion = to - from
	params.collision_mask = 69  # Nico's: world, enemies' layer bit and water
	var result := space.cast_motion(params)
	return result.size() == 2 and result[0] >= 1.0


# --- a plan that is not its room's size ---------------------------------------------------------------
func _check_mismatch() -> void:
	var holder := Node2D.new()
	root.add_child(holder)
	var matching := _room_data(&"fit", RoomData.RoomType.COMBAT, SIZES[1])
	var wrong := _room_data(&"wrong", RoomData.RoomType.COMBAT, SIZES[1], SIZES[0])
	var rooms := []
	for data in [matching, wrong]:
		var room = data.scene.instantiate()
		var no_doors: Array[Vector2i] = []
		room.setup(data, no_doors)
		holder.add_child(room)
		rooms.append(room)
	await _frames(2)
	var shape_script = load("res://scripts/world/temple_shape.gd")
	var fit_plan = rooms[0].get_node("Shape").plan
	var wrong_plan = rooms[1].get_node("Shape").plan
	_check(fit_plan.errors.is_empty(), "a plan of its room's size raises nothing (%s)" % [fit_plan.errors])
	_check(wrong_plan.errors.size() == 1 and wrong_plan.errors[0].contains("42 x 28") and wrong_plan.errors[0].contains("34 x 24"),
			"a 42x28 plan in a 34x24 room raises the size error (%s)" % [wrong_plan.errors])
	var big_plan := TemplePlan.parse("\n".join(_sized_rows(SIZES[0])))
	_check(shape_script.size_problem(fit_plan, rooms[0]) == "" and shape_script.size_problem(big_plan, rooms[0]) != "",
			"TempleShape.size_problem compares a plan with its room")
	holder.queue_free()
	await _frames(1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
