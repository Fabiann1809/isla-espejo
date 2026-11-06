extends SceneTree
## The temple's own scenery (TempleProp): every kind builds from its strip and animates, neighbours
## are out of step, a solid prop blocks only its base and only the actors of its level, a hazard
## geyser hurts while it erupts, flat pieces (vines, banners...) have no collision, and the trap
## walk's spikes, saw and rolling rock hurt on their rhythm through a Hitbox, never blocking.
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
	_check(kinds.size() == 24, "TempleProp has 24 kinds (%d)" % kinds.size())
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

	# Props side by side flicker out of step: 32 px apart, most pairs get different values.
	var different := 0
	for i in 5:
		var x := 96.0 + 64.0 * i
		if _prop_script.flicker_seconds(Vector2(x, 96)) != _prop_script.flicker_seconds(Vector2(x + 32.0, 96)):
			different += 1
	_check(different >= 4, "braziers 32 px apart flicker out of step (%d of 5 pairs differ)" % different)

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

	# A pillar on level 2 blocks only level-2 actors (Heights.block_layer).
	var top_pillar: Node2D = _make(kinds["PILLAR_CARVED"], Vector2(400, 150))
	top_pillar.level = 2
	room.add_child(top_pillar)
	await _frames(2)
	_check(top_pillar.get_node("Body").collision_layer == 1 << (Heights.block_layer(2) - 1),
			"a level-2 pillar's body is on the layer that blocks level 2")
	await _walk(player, Vector2(370, 150), 1, "move_right", 40)
	_check(player.global_position.x > 420.0, "a high Nico walks through a level-2 pillar (x = %.0f)" % player.global_position.x)
	await _walk(player, Vector2(370, 150), 2, "move_right", 40)
	_check(player.global_position.x < 398.0, "a level-2 Nico is blocked by it (x = %.0f)" % player.global_position.x)
	top_pillar.queue_free()
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
	ambient.queue_free()
	await _frames(1)

	await _check_traps(kinds, room, player)
	_finish()


## The trap walk's traps: spikes on a timer with a warning, a saw along its track, a rock down its lane;
## each hurts only through its Hitbox, blocks nobody and keeps its cells for the room generator.
func _check_traps(kinds: Dictionary, room: Node, player: Node2D) -> void:
	# Spikes: flat, no body, their cell is theirs; down (safe), warn (safe, tips out), up (hurts), retract.
	var spikes: Node2D = _make(kinds["SPIKES"], Vector2(240 + 8, 160 - 4))
	room.add_child(spikes)
	player.global_position = Vector2(248, 152)
	await _frames(2)
	_check(_bodies_of(spikes) == 0 and spikes.z_index == RoomTheme.GROUND_FX_Z and spikes.blocks_cells() == [Vector2i(15, 9)],
			"spikes are flat, have no body and keep their one cell (%s)" % [spikes.blocks_cells()])
	_damaged = 0
	var down_frames := int(ceil(Tuning.TEMPLE_SPIKES_DOWN * 60.0)) - 6
	await _frames(down_frames)
	_check(spikes.phase() == spikes.SpikesPhase.DOWN and _damaged == 0, "spikes sleep first and do not hurt (%d)" % _damaged)
	await _frames(12)
	_check(spikes.phase() == spikes.SpikesPhase.WARN and _sprite_of(spikes).animation == &"warn" and _damaged == 0,
			"then they warn with their own frames, still harmless (%s)" % _sprite_of(spikes).animation)
	await _frames(int(ceil(Tuning.TEMPLE_SPIKES_WARN * 60.0)) + 6)
	_check(spikes.phase() == spikes.SpikesPhase.UP and spikes.is_hazard_active() and _damaged == 1,
			"then they rise and hurt Nico standing on them (%d)" % _damaged)
	await _frames(int(ceil((Tuning.TEMPLE_SPIKES_UP + Tuning.TEMPLE_SPIKES_RETRACT) * 60.0)) + 6)
	_check(spikes.phase() == spikes.SpikesPhase.DOWN and not spikes.is_hazard_active() and _damaged == 1,
			"and sink back, harmless again (%d)" % _damaged)
	spikes.queue_free()
	await _frames(1)

	# The saw: its track of cells, its groove on the floor, the blade travelling along it, hurting on it.
	var saw: Node2D = _make(kinds["SAW"], Vector2(208 + 8, 160 - 4))
	saw.track = 4
	saw.direction = Vector2i.RIGHT
	room.add_child(saw)
	player.global_position = Vector2(80, 80)
	await _frames(2)
	var saw_cells: Array[Vector2i] = saw.blocks_cells()
	_check(_bodies_of(saw) == 0 and saw_cells == [Vector2i(13, 9), Vector2i(14, 9), Vector2i(15, 9), Vector2i(16, 9)],
			"a saw has no body and keeps the cells of its track (%s)" % [saw_cells])
	var grooves := 0
	for child in saw.get_children():
		if child is AnimatedSprite2D and String(child.name).begins_with("Track"):
			grooves += 1
	_check(grooves == 4 and saw.get_node("Mover/Hitbox") != null, "its groove runs the track and its hitbox rides the blade (%d pieces)" % grooves)
	var first: Vector2 = saw.mover_position()
	await _frames(30)
	var later: Vector2 = saw.mover_position()
	_check(later.x > first.x + 8.0 and later.y == first.y, "the blade travels along its track (%.0f -> %.0f)" % [first.x, later.x])
	_damaged = 0
	player.global_position = Vector2(232, 156)
	await _frames(int(ceil(Tuning.TEMPLE_SAW_HIT_EVERY * 60.0)) + 60)
	_check(_damaged >= 1, "it hurts Nico standing in its way (%d)" % _damaged)
	saw.queue_free()
	player.global_position = Vector2(80, 80)
	await _frames(1)

	# The rolling rock: it rumbles up, rolls down its lane, breaks at the end and comes again.
	var rock: Node2D = _make(kinds["ROLLING_ROCK"], Vector2(128 + 8, 160 - 4))
	rock.track = 6
	rock.direction = Vector2i.RIGHT
	room.add_child(rock)
	await _frames(2)
	_check(_bodies_of(rock) == 0 and rock.blocks_cells().size() == 6 and rock.blocks_cells()[5] == Vector2i(13, 9),
			"a rock has no body and keeps the cells of its lane (%s)" % [rock.blocks_cells()])
	_check(rock.phase() == rock.RockPhase.SPAWN and not rock.is_hazard_active(), "it starts rising, harmless")
	await _frames(int(ceil(Tuning.TEMPLE_ROCK_SPAWN * 60.0)) + 6)
	_check(rock.phase() == rock.RockPhase.ROLL and rock.is_hazard_active(), "then it rolls and hurts")
	_damaged = 0
	player.global_position = Vector2(184, 150)
	var lane: float = float((rock.track - 1) * 16)
	await _frames(int(ceil(lane / Tuning.TEMPLE_ROCK_SPEED * 60.0)) + 6)
	_check(_damaged >= 1, "it hurts Nico in its lane (%d)" % _damaged)
	_check(rock.phase() == rock.RockPhase.BREAK and rock.mover_position().x >= rock.position.x + lane - 1.0,
			"and breaks at the lane's end (%s, %.0f)" % [rock.RockPhase.keys()[rock.phase()], rock.mover_position().x])
	await _frames(int(ceil((Tuning.TEMPLE_ROCK_BREAK + Tuning.TEMPLE_ROCK_RESPAWN) * 60.0)) + 6)
	_check(rock.phase() == rock.RockPhase.SPAWN and rock.mover_position() == rock.position,
			"then rises again at the lane's start (%s)" % rock.RockPhase.keys()[rock.phase()])
	rock.queue_free()


func _finish() -> void:
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _make(kind: int, at: Vector2) -> Node2D:
	var prop: Node2D = _prop_script.new()
	prop.kind = kind
	prop.position = at
	return prop


## The prop's own art (a saw's or a rock's rides on its Mover).
func _sprite_of(prop: Node) -> AnimatedSprite2D:
	return prop.find_child("Art", true, false) as AnimatedSprite2D


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
