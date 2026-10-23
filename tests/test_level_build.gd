extends SceneTree
## Level build test: rooms, corridors, doors, enemies, player spawn, camera limits and room events.
## Do not reference `Level`/`Room` types here (they compile scripts before autoloads exist).
## Run: godot --headless --path . --script res://tests/test_level_build.gd

const SEED := 777

var _ok := true
var _log := {"entered": [], "exited": [], "cleared": []}
var _level: Node2D


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	var events: Node = root.get_node("Events")
	events.room_entered.connect(func(room: Node) -> void: _log.entered.append(room))
	events.room_exited.connect(func(room: Node) -> void: _log.exited.append(room))
	events.room_cleared.connect(func(room: Node) -> void: _log.cleared.append(room))

	var scene: PackedScene = load("res://scenes/levels/test_level.tscn")
	_level = scene.instantiate()
	_level.seed_value = SEED
	# These checks are about the map itself; the director has its own test (test_director.gd).
	_level.use_director = false
	root.add_child(_level)
	await _frames(5)

	var layout = _level.layout
	var cell_count: int = layout.cells.size()
	print("Level map (seed %d):\n%s" % [SEED, layout.to_ascii()])

	# --- Structure
	_check(_level.current_seed == SEED, "level uses the requested seed")
	_check(layout.validate().is_empty(), "generated layout is valid")
	_check(_level.rooms.size() == cell_count, "one room node per cell (%d)" % cell_count)
	_check(_level.get_node("Map").get_child_count() == cell_count + 1, "map holds the rooms plus one corridors node")
	# Enemies are children of their own room, so a floor on the same z layer would be painted over
	# an enemy that walks into a room (or corridor) built later. Reproduced with a screenshot.
	var floors_low := true
	var floor_nodes := 0
	for layer in _level.get_node("Map").find_children("*", "TileMapLayer", true, false):
		floor_nodes += 1
		floors_low = floors_low and layer.z_index < 0
	for coord: Vector2i in layout.cells:
		var floor_rect = _level.rooms[coord].get_node_or_null("Floor")
		if floor_rect != null:
			floor_nodes += 1
			floors_low = floors_low and floor_rect.z_index < 0
	_check(floor_nodes > 0 and floors_low, "every floor and corridor (%d) is drawn below the actors" % floor_nodes)
	_check(_level.player != null, "player is created")
	# Pixel art moves in whole viewport pixels; the screen stays 640x360 with integer scaling.
	_check(ProjectSettings.get_setting("rendering/2d/snap/snap_2d_transforms_to_pixel") == true
			and ProjectSettings.get_setting("display/window/size/viewport_width") == 640
			and ProjectSettings.get_setting("display/window/size/viewport_height") == 360
			and ProjectSettings.get_setting("display/window/stretch/scale_mode") == "integer",
			"2D transforms snap to pixels at 640x360 with integer scaling")
	_check(_level.player.get_node("Camera2D").zoom == Vector2(2, 2), "the camera keeps its zoom of 2")

	var start_room = _level.rooms[layout.start_cell]
	var spawn: Vector2 = start_room.global_position + start_room.player_spawn()
	_check(_level.player.global_position.distance_to(spawn) < 1.0, "player starts at the start room spawn")
	var cam: Camera2D = _level.player.get_node("Camera2D")
	_check(cam.limit_left == int(_level.bounds.position.x) and cam.limit_bottom == int(_level.bounds.end.y),
			"camera limits cover the whole map")

	# --- Every connection is physically walkable by a player-sized body; closed sides are walls
	var report := _walkability()
	_check(report.walkable == report.connections, "all %d connections can be walked through" % report.connections)
	_check(report.blocked_ok == report.blocked_total,
			"doors that are not connected are walls (%d/%d)" % [report.blocked_ok, report.blocked_total])

	# --- Population
	var population_ok := true
	var combat_rooms := 0
	for coord: Vector2i in layout.cells:
		var room = _level.rooms[coord]
		var enemies := 0
		for child in room.get_children():
			if child.is_in_group("enemy_test_marker") or child.has_signal("player_detected"):
				enemies += 1
		var data: RoomData = layout.get_cell(coord).room_data
		if layout.get_cell(coord).type == RoomData.RoomType.COMBAT:
			combat_rooms += 1
			if enemies < data.min_enemies or enemies > data.max_enemies or enemies != room.enemies_alive:
				population_ok = false
				printerr("room %s has %d enemies (expected %d..%d)" % [coord, enemies, data.min_enemies, data.max_enemies])
		elif enemies != 0:
			population_ok = false
			printerr("non-combat room %s has %d enemies" % [coord, enemies])
	_check(population_ok, "combat rooms have the right number of enemies and the others none (%d combat)" % combat_rooms)

	# --- Room events: enter, clear, exit
	var target_coord := Vector2i.ZERO
	for coord: Vector2i in layout.cells:
		if layout.get_cell(coord).type == RoomData.RoomType.COMBAT:
			target_coord = coord
			break
	var target = _level.rooms[target_coord]
	_log.entered.clear()
	_level.player.global_position = target.global_position + target.center() + Vector2(0, 40)
	await _frames(4)
	_check(_log.entered.size() == 1 and _log.entered[0] == target, "Events.room_entered emitted for the room entered")
	_check(target.visited and target.player_inside, "room tracks that the player is inside")

	for child in target.get_children():
		if child.has_signal("player_detected"):
			child.get_node("Hurtbox").receive_hit(999, target.global_position)
	await _frames(4)
	_check(_log.cleared.size() == 1 and _log.cleared[0] == target, "Events.room_cleared emitted when every enemy dies")

	_level.player.global_position = start_room.global_position + start_room.player_spawn()
	await _frames(4)
	_check(_log.exited.has(target), "Events.room_exited emitted when leaving the room")
	_check(not target.player_inside, "room no longer tracks the player")

	# --- Regenerating replaces the map and keeps the player
	var player_before = _level.player
	_level.generate(SEED + 1)
	await _frames(3)
	_check(_level.player == player_before, "regenerating keeps the same player")
	_check(_level.get_node("Map").get_child_count() == _level.layout.cells.size() + 1, "old map is removed on regenerate")
	_check(_level.layout.map_seed == SEED + 1, "regenerating with a new seed builds another map")

	# --- Walkability over many different maps
	var total_connections := 0
	var total_walkable := 0
	var total_blocked := 0
	var total_blocked_ok := 0
	for map_seed in range(1, 13):
		_level.generate(map_seed)
		await _frames(2)
		var many := _walkability()
		total_connections += many.connections
		total_walkable += many.walkable
		total_blocked += many.blocked_total
		total_blocked_ok += many.blocked_ok
	_check(total_walkable == total_connections,
			"12 maps: every connection is walkable (%d/%d)" % [total_walkable, total_connections])
	_check(total_blocked_ok == total_blocked,
			"12 maps: every unconnected side is a wall (%d/%d)" % [total_blocked_ok, total_blocked])

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


## For the current map: how many connections a player-sized body can cross, and how many adjacent
## but unconnected cell pairs are really sealed.
func _walkability() -> Dictionary:
	var layout = _level.layout
	var space := _level.get_world_2d().direct_space_state
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 12)
	var report := {"connections": 0, "walkable": 0, "blocked_total": 0, "blocked_ok": 0}
	for coord: Vector2i in layout.cells:
		for dir in [Vector2i.RIGHT, Vector2i.DOWN]:
			var neighbour: Vector2i = coord + dir
			if not layout.has_cell(neighbour):
				continue
			var from := _door_point(coord, dir, true)
			var to := _door_point(neighbour, -dir, true)
			var free := _is_free(space, shape, from, to)
			if layout.are_connected(coord, neighbour):
				report.connections += 1
				if free:
					report.walkable += 1
				else:
					printerr("blocked connection %s -> %s" % [coord, neighbour])
			else:
				report.blocked_total += 1
				if not free:
					report.blocked_ok += 1
	return report


## Point just inside room `coord`, on the side of `dir`, in the middle of its door.
func _door_point(coord: Vector2i, dir: Vector2i, inside: bool) -> Vector2:
	var origin: Vector2 = _level.cell_origin(coord)
	var cell_size := Vector2(480, 288)
	var margin := 14.0
	match dir:
		Vector2i.RIGHT:
			return origin + Vector2(cell_size.x - margin, cell_size.y / 2.0)
		Vector2i.LEFT:
			return origin + Vector2(margin, cell_size.y / 2.0)
		Vector2i.DOWN:
			return origin + Vector2(cell_size.x / 2.0, cell_size.y - margin)
		_:
			return origin + Vector2(cell_size.x / 2.0, margin)


## True if a player-sized body can move from `from` to `to` without touching the world layer.
func _is_free(space: PhysicsDirectSpaceState2D, shape: Shape2D, from: Vector2, to: Vector2) -> bool:
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.transform = Transform2D(0.0, from)
	params.motion = to - from
	params.collision_mask = 1
	var result := space.cast_motion(params)
	return result.size() == 2 and result[0] >= 1.0


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
