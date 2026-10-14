extends SceneTree
## Validates every hand-made room of every scenario with real physics, so a badly placed tree or
## spawn is caught the moment it is added (also for rooms made later by anyone):
##   - with all four doors open, each door must reach the middle of the room and every other door
##     with a player-sized body (nothing solid may block the central lanes);
##   - spawn markers (player, enemies, NPC, chest, boss, special) must not be inside a solid prop;
##   - rooms are the standard 30x18 tiles.
## Run: godot --headless --path . --script res://tests/test_room_designs.gd
## `Room` must not be referenced as a type here (autoload compile order).

const ROOM_SIZE := Vector2(480, 288)
const DOOR_MARGIN := 14.0
const MARKER_CONTAINERS := ["EnemySpawns", "NpcSpawn", "BossSpawn", "ChestSpawn", "SpecialSpawn"]
const ALL_DOORS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var _ok := true


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))

	var designs: Array = []
	var dir := DirAccess.open("res://data/scenarios")
	for file in dir.get_files():
		if not file.ends_with(".tres"):
			continue
		var scenario: ScenarioData = load("res://data/scenarios/" + file)
		var rooms: Array[RoomData] = [scenario.start_room, scenario.boss_room]
		rooms.append_array(scenario.rooms)
		for data in rooms:
			if not designs.any(func(d: Array) -> bool: return d[1] == data):
				designs.append([file.get_basename(), data])

	# Every room in its own corner of the world, all doors open.
	var holder := Node2D.new()
	root.add_child(holder)
	var instances: Array = []
	for i in designs.size():
		var room = designs[i][1].scene.instantiate()
		room.setup(designs[i][1], ALL_DOORS.duplicate())
		room.position = Vector2(i % 6, i / 6) * 700.0
		holder.add_child(room)
		instances.append(room)
	for i in 3:
		await physics_frame

	var space := holder.get_world_2d().direct_space_state
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 12)
	var checked_lanes := 0
	var checked_markers := 0
	var bad_lanes := 0
	var bad_markers := 0
	var bad_size := 0

	for i in designs.size():
		var label: String = "%s/%s" % [designs[i][0], designs[i][1].id]
		var room = instances[i]
		if room.pixel_size() != ROOM_SIZE:
			bad_size += 1
			printerr("%s is %s px, expected %s" % [label, room.pixel_size(), ROOM_SIZE])
		var origin: Vector2 = room.position
		var center := origin + ROOM_SIZE / 2.0
		var doors := {
			Vector2i.UP: origin + Vector2(ROOM_SIZE.x / 2.0, DOOR_MARGIN),
			Vector2i.DOWN: origin + Vector2(ROOM_SIZE.x / 2.0, ROOM_SIZE.y - DOOR_MARGIN),
			Vector2i.LEFT: origin + Vector2(DOOR_MARGIN, ROOM_SIZE.y / 2.0),
			Vector2i.RIGHT: origin + Vector2(ROOM_SIZE.x - DOOR_MARGIN, ROOM_SIZE.y / 2.0),
		}
		# Door to centre, and door to the opposite door.
		for dir_key in doors:
			checked_lanes += 1
			if not _free_path(space, shape, doors[dir_key], center):
				bad_lanes += 1
				printerr("%s: the %s door cannot reach the middle of the room" % [label, dir_key])
		for pair in [[Vector2i.UP, Vector2i.DOWN], [Vector2i.LEFT, Vector2i.RIGHT]]:
			checked_lanes += 1
			if not _free_path(space, shape, doors[pair[0]], doors[pair[1]]):
				bad_lanes += 1
				printerr("%s: the %s and %s doors are not connected" % [label, pair[0], pair[1]])

		# Spawn markers must be on free ground.
		var points: Array[Vector2] = []
		points.append(room.player_spawn())
		for container in MARKER_CONTAINERS:
			points.append_array(room.spawn_points(container))
		for point in points:
			checked_markers += 1
			if not _is_free_spot(space, shape, origin + point):
				bad_markers += 1
				printerr("%s: a spawn marker at %s is inside a solid object" % [label, point])

	print("Rooms checked: ", designs.size())
	_check(designs.size() >= 10, "there are rooms to check (%d)" % designs.size())
	_check(bad_size == 0, "every room is the standard 30x18 tiles")
	_check(bad_lanes == 0, "every door of every room reaches the middle and the opposite door (%d paths)" % checked_lanes)
	_check(bad_markers == 0, "no spawn marker is inside a solid object (%d markers)" % checked_markers)

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _free_path(space: PhysicsDirectSpaceState2D, shape: Shape2D, from: Vector2, to: Vector2) -> bool:
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, from)
	params.motion = to - from
	params.collision_mask = 1
	var result := space.cast_motion(params)
	return result.size() == 2 and result[0] >= 1.0


func _is_free_spot(space: PhysicsDirectSpaceState2D, shape: Shape2D, at: Vector2) -> bool:
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, at)
	params.collision_mask = 1
	return space.intersect_shape(params, 1).is_empty()


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
