extends SceneTree
## The temple's own scenery (TempleProp): every kind builds from its strip and animates, neighbours
## are out of step, a solid prop blocks only its base and only the actors of its level, a hazard
## geyser hurts while it erupts and flat pieces (vines, banners...) have no collision.
## Run: godot --headless --path . --script res://tests/test_temple_props.gd

var _ok := true
var _prop_script: GDScript
var _damaged := 0


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_prop_script = load("res://scripts/world/temple_prop.gd")
	_check(_prop_script != null, "scripts/world/temple_prop.gd exists")
	if _prop_script == null:
		_finish()
		return
	var kinds: Dictionary = _prop_script.get_script_constant_map()["Kind"]
	_check(kinds.size() == 21, "TempleProp has 21 kinds (%d)" % kinds.size())
	_check(FileAccess.file_exists("res://assets/sprites/temple_props/props.json"), "props.json exists")

	# Every kind builds and animates.
	var animated := 0
	for kind_name in kinds:
		var prop: Node2D = _prop_script.new()
		prop.kind = kinds[kind_name]
		prop.position = Vector2(64, 64)
		root.add_child(prop)
		var sprite := _sprite_of(prop)
		var frames := 0
		if sprite != null and sprite.sprite_frames != null:
			frames = sprite.sprite_frames.get_frame_count(sprite.animation)
		var playing := sprite != null and sprite.is_playing()
		if frames >= 4 and playing:
			animated += 1
		else:
			print("  %s: frames %d playing %s" % [kind_name, frames, playing])
		prop.queue_free()
	_check(animated == kinds.size(), "every kind builds and animates (%d of %d)" % [animated, kinds.size()])
	await process_frame

	# Neighbouring props start on different frames.
	var a: Node2D = _make(kinds["BRAZIER"], Vector2(96, 96))
	var b: Node2D = _make(kinds["BRAZIER"], Vector2(128, 96))
	root.add_child(a)
	root.add_child(b)
	_check(_sprite_of(a).frame != _sprite_of(b).frame, "neighbouring props start on different frames (%d, %d)"
			% [_sprite_of(a).frame, _sprite_of(b).frame])
	a.queue_free()
	b.queue_free()

	# A light's flicker depends only on its position, so a rebuilt light keeps its rhythm.
	var flicker_a: float = _prop_script.flicker_seconds(Vector2(96, 96))
	var flicker_b: float = _prop_script.flicker_seconds(Vector2(96, 96))
	var flicker_low := Tuning.RUIN_LIGHT_FLICKER_SECONDS * Tuning.TEMPLE_PROP_LIGHT_FLICKER_MIN
	var flicker_high := Tuning.RUIN_LIGHT_FLICKER_SECONDS * Tuning.TEMPLE_PROP_LIGHT_FLICKER_MAX
	_check(flicker_a == flicker_b and flicker_a >= flicker_low and flicker_a <= flicker_high,
			"light flicker is deterministic (%.3f, %.3f)" % [flicker_a, flicker_b])

	# Vines, banners and the other flat or overhead kinds have no collision.
	for flat in ["VINES", "BANNER", "LAVA_FALL", "EMBER_VENT", "PLANT", "RUBBLE"]:
		var prop: Node2D = _make(kinds[flat], Vector2(64, 64))
		root.add_child(prop)
		_check(_bodies_of(prop) == 0 and prop.blocks_cells().is_empty(), "%s has no collision" % flat)
		prop.queue_free()
	var solid: Node2D = _make(kinds["PILLAR_CARVED"], Vector2(200, 100))
	root.add_child(solid)
	var cells: Array[Vector2i] = solid.blocks_cells()
	_check(_bodies_of(solid) == 1 and cells.has(Vector2i(12, 6)) and cells.size() <= 2,
			"a pillar blocks one body over the cells of its footprint (%s)" % [cells])
	solid.queue_free()
	await process_frame

	var room: Node = load("res://scenes/levels/test_room.tscn").instantiate()
	for node_name in ["Trap1", "Trap2", "Grunt1", "Grunt2", "Dummy1", "Dummy2", "Dummy3"]:
		room.get_node(node_name).free()
	root.add_child(room)
	var player: Node2D = room.get_node("Player")
	var events: Node = root.get_node("Events")
	events.player_damaged.connect(func(_amount: int, _from: Vector2) -> void: _damaged += 1)

	# A pillar blocks a low walker at its base and not at its top.
	var pillar: Node2D = _make(kinds["PILLAR_CARVED"], Vector2(400, 150))
	room.add_child(pillar)
	await _frames(2)
	await _walk(player, Vector2(370, 150), 0, "move_right", 40)
	_check(player.global_position.x < 398.0, "a pillar blocks Nico at its base (x = %.0f)" % player.global_position.x)
	await _walk(player, Vector2(370, 110), 0, "move_right", 40)
	_check(player.global_position.x > 420.0, "Nico walks behind the pillar's top (x = %.0f)" % player.global_position.x)
	pillar.queue_free()

	# A pillar on level 1 blocks only level-1 actors.
	var high_pillar: Node2D = _make(kinds["PILLAR_CARVED"], Vector2(400, 150))
	high_pillar.level = 1
	room.add_child(high_pillar)
	await _frames(2)
	await _walk(player, Vector2(370, 150), 0, "move_right", 40)
	_check(player.global_position.x > 420.0, "a low Nico walks through a level-1 pillar (x = %.0f)" % player.global_position.x)
	await _walk(player, Vector2(370, 150), 1, "move_right", 40)
	_check(player.global_position.x < 398.0, "a high Nico is blocked by it (x = %.0f)" % player.global_position.x)
	high_pillar.queue_free()

	# A pillar on level 2 blocks only level-2 actors (needs Heights.block_layer).
	if Heights.new().has_method("block_layer"):
		var top_pillar: Node2D = _make(kinds["PILLAR_CARVED"], Vector2(400, 150))
		top_pillar.level = 2
		room.add_child(top_pillar)
		await _frames(2)
		await _walk(player, Vector2(370, 150), 1, "move_right", 40)
		_check(player.global_position.x > 420.0, "a high Nico walks through a level-2 pillar (x = %.0f)" % player.global_position.x)
		await _walk(player, Vector2(370, 150), 2, "move_right", 40)
		_check(player.global_position.x < 398.0, "a level-2 Nico is blocked by it (x = %.0f)" % player.global_position.x)
		top_pillar.queue_free()
	else:
		print("SKIP a pillar on level 2 blocks only level-2 actors (Heights has no block_layer yet)")
	Heights.set_level(player, 0)

	# A hazard geyser hurts Nico only while erupting; an ambient one never does.
	var geyser: Node2D = _make(kinds["GEYSER"], Vector2(240, 150))
	geyser.hazard = true
	room.add_child(geyser)
	player.global_position = Vector2(240, 150)
	await _frames(2)
	_damaged = 0
	var idle_frames := int(ceil((Tuning.TEMPLE_GEYSER_IDLE + Tuning.TEMPLE_GEYSER_RUMBLE) * 60.0)) - 6
	await _frames(idle_frames)
	_check(_damaged == 0 and not geyser.is_erupting(), "a hazard geyser does not hurt while idle or rumbling")
	await _frames(12)
	_check(geyser.is_erupting(), "then it erupts")
	await _frames(6)
	_check(_damaged == 1, "and hurts Nico once while erupting (%d)" % _damaged)
	var erupt_frames := int(ceil((Tuning.TEMPLE_GEYSER_ERUPT + Tuning.TEMPLE_GEYSER_SETTLE) * 60.0)) + 6
	await _frames(erupt_frames)
	_check(not geyser.is_erupting() and _damaged == 1, "it settles and hurts no more (%d)" % _damaged)
	geyser.queue_free()
	var ambient: Node2D = _make(kinds["GEYSER"], Vector2(240, 150))
	room.add_child(ambient)
	await _frames(2)
	_check(ambient.get_node_or_null("Hitbox") == null and ambient.blocks_cells().is_empty(),
			"an ambient geyser has no hitbox and blocks no cell")
	_finish()


func _finish() -> void:
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _make(kind: int, at: Vector2) -> Node2D:
	var prop: Node2D = _prop_script.new()
	prop.kind = kind
	prop.position = at
	return prop


func _sprite_of(prop: Node) -> AnimatedSprite2D:
	for child in prop.get_children():
		if child is AnimatedSprite2D:
			return child
	return null


func _bodies_of(prop: Node) -> int:
	var count := 0
	for child in prop.get_children():
		if child is StaticBody2D:
			count += 1
	return count


func _walk(player: Node2D, from: Vector2, level: int, action: String, frames: int) -> void:
	player.global_position = from
	Heights.set_level(player, level)
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
