extends SceneTree
## Game feel in a playable level: a hit stop when Nico lands a hit (and the game resumes), a short
## camera shake when he is hurt, a puff of particles where an enemy dies, a dark ring on warning
## circles and outlined HUD text. Run: godot --headless --path . --script res://tests/test_game_feel.gd

var _ok := true


func _initialize() -> void:
	create_timer(60.0, true, false, true).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var tuning: Script = load("res://scripts/core/tuning.gd")
	var feel_script: Script = load("res://scripts/effects/game_feel.gd")
	var events: Node = root.get_node("Events")
	var level = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.use_director = false
	level.seed_value = 4242
	root.add_child(level)
	await _frames(3)
	_check(level.has_node("GameFeel"), "the level listens for the game-feel effects")

	# --- Hit stop: frozen for a few frames, then back to normal.
	feel_script.force_hitstop = true
	var enemy: Node2D = null
	for node in get_nodes_in_group("enemies"):
		if node.get("phase") == null and level.get_node("Map").is_ancestor_of(node):
			enemy = node
			break
	var started := Time.get_ticks_usec()
	events.player_hit_enemy.emit(enemy, 1)
	var frozen := Engine.time_scale == 0.0
	while Engine.time_scale == 0.0 and Time.get_ticks_usec() - started < 500000:
		await process_frame
	var stop_ms: int = (Time.get_ticks_usec() - started) / 1000
	_check(frozen and Engine.time_scale == 1.0 and stop_ms >= 30 and stop_ms <= 120,
			"a hit freezes the game for %d frames and resumes (~%d ms)" % [tuning.HITSTOP_FRAMES, stop_ms])
	feel_script.force_hitstop = false
	Engine.time_scale = 1.0

	# --- Camera shake when Nico is hurt, back to rest afterwards.
	var camera: Camera2D = level.player.get_node("Camera2D")
	events.player_damaged.emit(1, level.player.global_position)
	var moved := false
	var shake_start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - shake_start < 100:
		await process_frame
		moved = moved or camera.offset != Vector2.ZERO
	await create_timer(tuning.SHAKE_DURATION + 0.2).timeout
	_check(moved and camera.offset == Vector2.ZERO, "being hurt shakes the camera briefly")
	_check(absf(camera.offset.x) <= tuning.SHAKE_STRENGTH, "the shake is subtle (at most %d px)" % tuning.SHAKE_STRENGTH)

	# --- Death puff.
	var room: Node = enemy.get_parent()
	enemy.get_node("Hurtbox").receive_hit(999, enemy.global_position + Vector2(10, 0))
	await _frames(2)
	var puffs := room.find_children("DeathPuff", "CPUParticles2D", false, false)
	_check(puffs.size() == 1 and puffs[0].emitting, "a dying enemy leaves a puff of particles")
	await create_timer(tuning.DEATH_PARTICLE_LIFETIME + 0.6).timeout
	_check(room.find_children("DeathPuff", "CPUParticles2D", false, false).is_empty(), "the puff frees itself")

	# --- Readability.
	var hud: Node = level.get_node("Hud")
	var outlined := true
	for label in hud.find_children("*", "Label", true, false):
		outlined = outlined and label.get_theme_constant("outline_size") == tuning.HUD_TEXT_OUTLINE
	_check(outlined, "every HUD text has a dark outline")
	_check(tuning.ZONE_OUTLINE_ALPHA > 0.0 and tuning.ZONE_OUTLINE_ALPHA < 1.0, "warning circles get a soft dark ring")

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
