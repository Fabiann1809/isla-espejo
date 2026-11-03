extends SceneTree
## Rooms have a height (RoomData.height) and a corridor between rooms of different height is a
## staircase: steps on its floor and a StairZone that makes whoever walks it high or low; same-height
## corridors stay plain; enemies live on the height of their room.
## Run: godot --headless --path . --script res://tests/test_stairs_corridor.gd
## `Level`/`Room` must not be referenced as types here (autoload compile order).

var _ok := true


func _initialize() -> void:
	create_timer(150.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	root.get_node("PlayerProfile").persistence_enabled = false

	var scenario: ScenarioData = load("res://data/scenarios/forest.tres").duplicate()
	scenario.theme = load("res://data/themes/ruins.tres")
	var copies: Array[RoomData] = []
	for i in scenario.rooms.size():
		var copy: RoomData = scenario.rooms[i].duplicate()
		# Half of the combat variants are raised; the rest stay on the ground.
		copy.height = 1 if i % 2 == 0 and copy.type == RoomData.RoomType.COMBAT else 0
		copies.append(copy)
	scenario.rooms = copies
	var level: Node2D = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.scenario = scenario
	level.seed_value = 4242
	level.use_director = false
	root.add_child(level)
	for i in 6:
		await physics_frame

	var layout = level.layout
	var connections := 0
	var uphill := 0
	for coord: Vector2i in layout.cells:
		for dir in [Vector2i.RIGHT, Vector2i.DOWN]:
			if layout.are_connected(coord, coord + dir):
				connections += 1
				if layout.get_cell(coord).room_data.height != layout.get_cell(coord + dir).room_data.height:
					uphill += 1
	var zones := level.get_node("Map/Corridors").find_children("*", "Area2D", false, false).filter(
			func(node: Node) -> bool: return node.get_script() != null and node.get_script().get_global_name() == &"StairZone")
	var stairs := level.get_node("Map/Corridors").find_children("Stairs*", "Node2D", false, false)
	_check(uphill > 0 and zones.size() == uphill and stairs.size() == uphill,
			"every corridor between rooms of different height is a staircase (%d of %d corridors)" % [zones.size(), connections])
	_check(connections > uphill, "and the other corridors stay plain")

	# Walk one staircase from its low end: the player ends up high on the other side.
	var zone: Node2D = zones[0]
	var shape: RectangleShape2D = zone.get_child(0).shape
	var player: Node2D = level.player
	var uphill_dir: Vector2 = zone.direction
	var action: String = {Vector2.RIGHT: "move_right", Vector2.LEFT: "move_left", Vector2.DOWN: "move_down", Vector2.UP: "move_up"}[uphill_dir]
	var length: float = shape.size.dot(uphill_dir.abs())
	player.global_position = zone.global_position - uphill_dir * (length / 2.0 + 14.0)
	Heights.set_level(player, Heights.LOW)
	Input.action_press(action)
	for i in 70:
		await physics_frame
	Input.action_release(action)
	_check(Heights.level_of(player) == Heights.HIGH, "walking up a staircase corridor makes the player high")
	var back: String = {"move_right": "move_left", "move_left": "move_right", "move_down": "move_up", "move_up": "move_down"}[action]
	Input.action_press(back)
	for i in 70:
		await physics_frame
	Input.action_release(back)
	_check(Heights.level_of(player) == Heights.LOW, "and walking back down makes him low again")

	# Enemies take the height of their room.
	var raised := 0
	var grounded := 0
	for room in level.rooms.values():
		for node in room.get_children():
			if node.is_in_group("enemies"):
				var matches: bool = Heights.level_of(node) == room.data.height
				if matches:
					raised += 1 if room.data.height == 1 else 0
					grounded += 1 if room.data.height == 0 else 0
	_check(raised > 0 and grounded > 0, "enemies are born on the height of their room (%d raised, %d on the ground)" % [raised, grounded])
	level.free()

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
