extends SceneTree
## Trees turn see-through while Nico stands behind their crown, and solid again when he leaves.
## Run: godot --headless --path . --script res://tests/test_canopy.gd

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var room: Node = load("res://scenes/levels/test_room.tscn").instantiate()
	for name in ["Trap1", "Trap2", "Grunt1", "Grunt2"]:
		room.get_node(name).free()
	var tree = load("res://scripts/world/room_prop.gd").new()
	tree.kind = 3  # TALL_ROUND_TREE
	tree.position = Vector2(240, 160)
	room.add_child(tree)
	var fade = load("res://scripts/effects/canopy_fade.gd").new()
	room.add_child(fade)
	root.add_child(room)
	await _frames(2)
	var player: Node2D = room.get_node("Player")
	var rect: Rect2 = fade.rect_of(tree)
	_check(rect.size.x > 16 and rect.size.y > 24, "the tree's drawn area is measured from its art")

	# Behind the crown: above the trunk, inside the drawing.
	player.global_position = Vector2(rect.get_center().x, rect.position.y + rect.size.y * 0.45 + 10)
	await _frames(30)
	_check(player.global_position.y < tree.global_position.y and fade.is_faded(tree),
			"a tree turns see-through while Nico is behind it")
	player.global_position = Vector2(rect.get_center().x, tree.global_position.y + 30)
	await _frames(40)
	_check(not fade.is_faded(tree), "in front of the tree it is solid again")
	quit(0 if _ok else 1)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
