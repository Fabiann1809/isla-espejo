extends SceneTree
## 30 forest maps, built for real: the layout is valid, every connection can be walked by a
## Nico-sized body, every combat room has its enemies, and nothing (enemies, the boss, NPCs, chests,
## the exit) is placed in a wall or outside its room or the map.
## Run: godot --headless --path . --script res://tests/test_forest_maps.gd

const SEEDS := 30
const CELL_SIZE := Vector2(480, 288)
const WALL := 16.0
const COMBAT := 1

var _ok := true


func _initialize() -> void:
	create_timer(170.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var level = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.use_director = false
	level.seed_value = 1
	root.add_child(level)
	await _frames(2)

	var problems: Array[String] = []
	var connections := 0
	var walkable := 0
	var combat_rooms := 0
	var placed := 0
	for map_seed in range(1, SEEDS + 1):
		level.generate(map_seed)
		await _frames(2)
		var layout = level.layout
		for problem in layout.validate():
			problems.append("seed %d: %s" % [map_seed, problem])
		var walk := _walkability(level)
		connections += walk.connections
		walkable += walk.walkable
		if walk.walkable != walk.connections:
			problems.append("seed %d: %d of %d connections blocked" % [map_seed, walk.connections - walk.walkable, walk.connections])
		for coord: Vector2i in layout.cells:
			var room: Node2D = level.rooms[coord]
			var cell = layout.get_cell(coord)
			var floor_rect := Rect2(room.global_position, CELL_SIZE)
			if not level.bounds.encloses(floor_rect):
				problems.append("seed %d: room %s outside the map" % [map_seed, coord])
			var inside := floor_rect.grow(-WALL)
			for child in room.get_children():
				var thing := child.is_in_group("enemies") or child.is_in_group("npcs") \
						or child.is_in_group("chests") or child.is_in_group("exit_portals")
				if thing and child is Node2D:
					placed += 1
					if not inside.has_point(child.global_position):
						problems.append("seed %d: %s at %s is in a wall or out of room %s" % [map_seed, child.name, child.global_position, coord])
			if cell.type == COMBAT:
				combat_rooms += 1
				var data = cell.room_data
				if room.enemies_alive < maxi(data.min_enemies, 1) or room.enemies_alive > data.max_enemies:
					problems.append("seed %d: combat room %s has %d enemies (%d..%d)"
							% [map_seed, coord, room.enemies_alive, data.min_enemies, data.max_enemies])
		var start: Node2D = level.rooms[layout.start_cell]
		if not Rect2(start.global_position, CELL_SIZE).grow(-WALL).has_point(level.player.global_position):
			problems.append("seed %d: Nico does not start inside the start room" % map_seed)

	for problem in problems.slice(0, 10):
		printerr(problem)
	_check(walkable == connections, "%d maps: every connection is walkable (%d/%d)" % [SEEDS, walkable, connections])
	_check(combat_rooms > 0 and problems.filter(func(p: String) -> bool: return "combat room" in p).is_empty(),
			"every combat room has its enemies (%d rooms)" % combat_rooms)
	_check(problems.filter(func(p: String) -> bool: return "wall or out" in p or "outside the map" in p).is_empty(),
			"nothing is placed in a wall or outside its room (%d things)" % placed)
	_check(problems.is_empty(), "no problems in %d maps (%d found)" % [SEEDS, problems.size()])
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


## How many connections a Nico-sized body can cross (door to door through the corridor).
func _walkability(level: Node) -> Dictionary:
	var layout = level.layout
	var space: PhysicsDirectSpaceState2D = level.get_world_2d().direct_space_state
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 12)
	var report := {"connections": 0, "walkable": 0}
	for coord: Vector2i in layout.cells:
		for dir in [Vector2i.RIGHT, Vector2i.DOWN]:
			var next: Vector2i = coord + dir
			if not layout.are_connected(coord, next):
				continue
			report.connections += 1
			var from := _door_point(level, coord, dir)
			var to := _door_point(level, next, -dir)
			var params := PhysicsShapeQueryParameters2D.new()
			params.shape = shape
			params.transform = Transform2D(0.0, from)
			params.motion = to - from
			params.collision_mask = 1
			var result := space.cast_motion(params)
			if result.size() == 2 and result[0] >= 1.0:
				report.walkable += 1
	return report


func _door_point(level: Node, coord: Vector2i, dir: Vector2i) -> Vector2:
	var origin: Vector2 = level.cell_origin(coord)
	var margin := 14.0
	match dir:
		Vector2i.RIGHT:
			return origin + Vector2(CELL_SIZE.x - margin, CELL_SIZE.y / 2.0)
		Vector2i.LEFT:
			return origin + Vector2(margin, CELL_SIZE.y / 2.0)
		Vector2i.DOWN:
			return origin + Vector2(CELL_SIZE.x / 2.0, CELL_SIZE.y - margin)
		_:
			return origin + Vector2(CELL_SIZE.x / 2.0, margin)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
