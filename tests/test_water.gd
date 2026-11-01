extends SceneTree
## Ponds are water (physics layer 7): Nico and enemies cannot walk into them, but arrows and enemy
## orbs fly over, so a fight across a pond is not a stalemate.
## Run: godot --headless --path . --script res://tests/test_water.gd

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var room: Node = load("res://scenes/levels/test_room.tscn").instantiate()
	for name in ["Trap1", "Trap2", "Grunt1", "Grunt2", "Dummy1", "Dummy2", "Dummy3"]:
		room.get_node(name).free()
	var pond = load("res://scripts/world/room_prop.gd").new()
	pond.kind = 5  # RoomProp.Kind.POND
	pond.size_tiles = Vector2i(3, 3)
	pond.position = Vector2(192, 96)
	room.add_child(pond)
	root.add_child(room)
	await _frames(3)
	var player: Node2D = room.get_node("Player")
	var water_body: StaticBody2D = null
	for child in pond.get_children():
		if child is StaticBody2D:
			water_body = child
	_check(water_body != null and water_body.collision_layer == 1 << 6, "a pond's body is on the water layer")

	# Nico walks right into the pond from its left side and stops at the shore.
	player.global_position = Vector2(170, 120)
	Input.action_press("move_right")
	await _frames(40)
	Input.action_release("move_right")
	_check(player.global_position.x < 200.0, "Nico cannot walk into the water (x = %.0f)" % player.global_position.x)

	# An arrow shot over the pond keeps flying past it.
	var arrow = load("res://scenes/player/arrow.tscn").instantiate()
	arrow.setup(Vector2.RIGHT, 300.0, 200.0, 1)
	room.add_child(arrow)
	arrow.global_position = Vector2(170, 120)
	await _frames(25)
	_check(is_instance_valid(arrow) and arrow.global_position.x > 250.0, "an arrow flies over the pond")
	quit(0 if _ok else 1)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
