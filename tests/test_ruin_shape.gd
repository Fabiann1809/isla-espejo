extends SceneTree
## RuinShape: a room's outline written as text becomes rock that stops everybody, water that stops
## bodies (not arrows), a bridge that can be crossed and a waterfall wall; border walls the rock leans
## on are hidden. Also checks that the ruin room scenes hold valid plans.
## Run: godot --headless --path . --script res://tests/test_ruin_shape.gd

var _ok := true


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	TileArt.use_profile(load("res://data/tilesets/ruins.tres"))

	var room: Node = load("res://scenes/levels/test_room.tscn").instantiate()
	for name in ["Trap1", "Trap2", "Grunt1", "Grunt2", "Dummy1", "Dummy2", "Dummy3"]:
		room.get_node(name).free()
	root.add_child(room)
	var shape := RuinShape.new()
	shape.rows = _plan()
	shape.position = Vector2.ZERO
	room.add_child(shape)
	await _frames(3)
	var player: Node2D = room.get_node("Player")

	_check(shape.is_rock(Vector2i(5, 4)) and shape.is_water(Vector2i(9, 5)) and shape.cell_at(Vector2i(9, 8)) == "=" and shape.is_walkable(Vector2i(9, 8)),
			"the plan reads as rock, water and planks")
	_check(shape.get_node("RockMass") != null and shape.get_node("Water") != null and shape.get_node("Rocks") != null
			and shape.get_node("Waterfalls").get_child_count() == 4, "it draws rock, water, columns and a waterfall (2x2 cells)")
	_check(shape.hides_wall_at(Vector2i(0, 4)) and not shape.hides_wall_at(Vector2i(0, 8)),
			"a border wall the rock leans on is hidden, one in front of floor is not")

	# Rock stops Nico.
	await _walk(player, Vector2(40, 72), "move_right", 50)
	_check(player.global_position.x < 5.0 * 16.0, "Nico cannot walk into rock (x = %.0f)" % player.global_position.x)
	# Water stops him, the bridge lets him through.
	await _walk(player, Vector2(100, 200), "move_right", 60)
	_check(player.global_position.x < 9.0 * 16.0, "nor into the river (x = %.0f)" % player.global_position.x)
	await _walk(player, Vector2(100, 136), "move_right", 60)
	_check(player.global_position.x > 12.0 * 16.0, "but he crosses by the bridge (x = %.0f)" % player.global_position.x)
	# An arrow flies over the water.
	var arrow = load("res://scenes/player/arrow.tscn").instantiate()
	arrow.setup(Vector2.RIGHT, 300.0, 200.0, 1)
	room.add_child(arrow)
	arrow.global_position = Vector2(100, 200)
	await _frames(20)
	_check(is_instance_valid(arrow) and arrow.global_position.x > 160.0, "an arrow flies over the river")

	# Every ruin room holds a valid plan with open lanes.
	var bad := []
	var dir := DirAccess.open("res://scenes/levels/rooms/ruins")
	for file in dir.get_files():
		if not file.ends_with(".tscn"):
			continue
		var scene: Node = load("res://scenes/levels/rooms/ruins/" + file).instantiate()
		var plan: Array = scene.get_node("Shape").rows.split("\n")
		var valid: bool = plan.size() == 18 and plan.all(func(line: String) -> bool: return line.length() == 30)
		if valid:
			for x in range(1, 29):
				valid = valid and not (plan[8][x] in "#w") and not (plan[9][x] in "#w")
			for y in range(1, 17):
				valid = valid and not (plan[y][14] in "#w") and not (plan[y][15] in "#w")
		if not valid:
			bad.append(file)
		scene.free()
	_check(bad.is_empty(), "every ruin room has an 18x30 plan with open lanes (%s)" % [bad])

	TileArt.use_profile(null)
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


## Rock all round; a river across the middle with a bridge on rows 7..10; a rock block and a waterfall.
func _plan() -> String:
	var rows: Array[String] = []
	for y in 18:
		var line := ""
		for x in 30:
			var c := "."
			if x == 0 or y == 0 or x == 29 or y == 17:
				c = "#"
			elif x in [8, 9, 10] and not (y in [7, 8, 9, 10]):
				c = "~"
			elif x in [8, 9, 10] and y == 7 or x in [8, 9, 10] and y == 10:
				c = "r"
			elif x in [8, 9, 10] and y in [8, 9]:
				c = "="
			elif x in [3, 4, 5] and y in [3, 4, 5]:
				c = "#"
			elif x in [1, 2] and y in [3, 4]:
				c = "#"
			elif x in [20, 21] and y in [1, 2]:
				c = "w"
			line += c
		rows.append(line)
	return "\n".join(rows)


func _walk(player: Node2D, from: Vector2, action: String, frames: int) -> void:
	player.global_position = from
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)
	await _frames(1)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
