extends SceneTree
## The Ruinas' own scenery (RuinProp): every kind builds, solid ones block their base, and a terrace
## is a raised platform that can only be entered by its stairs (see Heights): low actors cannot step
## onto it anywhere else and high actors cannot step off it.
## Run: godot --headless --path . --script res://tests/test_ruin_props.gd

var _ok := true


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var profile: TilesetProfile = load("res://data/tilesets/ruins.tres")
	TileArt.use_profile(profile)

	# Every kind builds with the ruins tileset (no missing tile) and solid props have a body.
	var kinds := RuinProp.Kind.values()
	var built := 0
	for kind in kinds:
		var prop: RuinProp = RuinProp.new()
		prop.kind = kind
		prop.size_tiles = Vector2i(8, 5) if kind in [RuinProp.Kind.TERRACE, RuinProp.Kind.ALCOVE] else Vector2i(3, 2)
		root.add_child(prop)
		built += 1 if prop.get_child_count() > 0 else 0
		prop.queue_free()
	_check(built == kinds.size(), "all %d kinds of ruin props build" % kinds.size())
	await process_frame

	var room: Node = load("res://scenes/levels/test_room.tscn").instantiate()
	for name in ["Trap1", "Trap2", "Grunt1", "Grunt2", "Dummy1", "Dummy2", "Dummy3"]:
		room.get_node(name).free()
	root.add_child(room)
	var terrace := RuinProp.new()
	terrace.kind = RuinProp.Kind.TERRACE
	terrace.size_tiles = Vector2i(8, 5)
	terrace.position = Vector2(160, 96)
	room.add_child(terrace)
	await _frames(3)
	var player: Node2D = room.get_node("Player")

	# The terrace spans x 160..288, y 96..176; its stairs are x 208..240 (zone center (224, 160)).
	await _walk(player, Vector2(175, 215), "move_up", 60)
	_check(Heights.level_of(player) == Heights.LOW and player.global_position.y > 176.0,
			"a low Nico cannot climb the cliff away from the stairs (y = %.0f)" % player.global_position.y)
	await _walk(player, Vector2(224, 215), "move_up", 90)
	_check(Heights.level_of(player) == Heights.HIGH and player.global_position.y < 140.0,
			"by the stairs he climbs and is high on the surface (y = %.0f)" % player.global_position.y)
	await _walk(player, Vector2(175, 120), "move_down", 60)
	_check(Heights.level_of(player) == Heights.HIGH and player.global_position.y < 144.0,
			"a high Nico cannot walk off the front of the terrace (y = %.0f)" % player.global_position.y)
	await _walk(player, Vector2(270, 120), "move_right", 40)
	_check(player.global_position.x < 288.0, "nor off its side (x = %.0f)" % player.global_position.x)
	await _walk(player, Vector2(224, 130), "move_down", 90)
	_check(Heights.level_of(player) == Heights.LOW and player.global_position.y > 180.0,
			"by the stairs he goes down and is low again (y = %.0f)" % player.global_position.y)

	# A solid prop blocks its base.
	var crystal := RuinProp.new()
	crystal.kind = RuinProp.Kind.CRYSTAL
	crystal.position = Vector2(400, 96)
	room.add_child(crystal)
	await _frames(2)
	await _walk(player, Vector2(380, 124), "move_right", 40)
	_check(player.global_position.x < 403.0, "a crystal blocks Nico (x = %.0f)" % player.global_position.x)

	TileArt.use_profile(null)
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _walk(player: Node2D, from: Vector2, action: String, frames: int) -> void:
	player.global_position = from
	if from.y > 150.0:
		Heights.set_level(player, Heights.LOW)
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
