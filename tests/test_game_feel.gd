extends SceneTree
## Game feel (GameFeel): hit stop, camera shake, sparks, damage numbers, the red hurt flash and the
## low-health edge, all driven by the Events bus.
## Run: godot --headless --path . --script res://tests/test_game_feel.gd

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var events = root.get_node("Events")

	var room: Node = load("res://scenes/levels/test_room.tscn").instantiate()
	# Only Nico: the test room's grunts and traps would hurt him and start freezes of their own.
	for name in ["Trap1", "Trap2", "Grunt1", "Grunt2"]:
		room.get_node(name).free()
	root.add_child(room)
	var feel = load("res://scripts/effects/game_feel.gd").new()
	room.add_child(feel)
	await _frames(3)
	var player = room.get_node("Player")
	var camera: Camera2D = player.get_node("Camera2D")
	_check(not feel.hit_stop_enabled, "hit stop is off in headless runs unless a test turns it on")
	feel.hit_stop_enabled = true

	# A hurt player: freeze, shake, red flash.
	events.player_damaged.emit(1, player.global_position + Vector2(10, 0))
	_check(Engine.time_scale < 1.0 and feel.is_hit_stopped(), "being hurt freezes the game for an instant")
	_check(feel.is_shaking(), "being hurt shakes the camera")
	_check(feel.get_node("FeelOverlay/HurtFlash").color.a > 0.0, "being hurt flashes the screen red")
	await _frames(2)
	_check(camera.offset != Vector2.ZERO or feel.is_shaking(), "the shake moves the camera")
	await _real_wait(0.5)
	_check(Engine.time_scale == 1.0 and not feel.is_hit_stopped(), "the freeze ends and time runs normally again")
	await _frames(30)
	_check(not feel.is_shaking() and camera.offset == Vector2.ZERO, "the shake fades and the camera goes back to its place")

	# A hit enemy: sparks and a damage number; a dead one: more sparks.
	var enemy: Node2D = load("res://scenes/enemies/slime.tscn").instantiate()
	room.add_child(enemy)
	enemy.global_position = player.global_position + Vector2(60, 0)
	await _frames(2)
	var before: int = feel.get_child_count()
	events.enemy_damaged.emit(enemy, 2)
	var labels: Array = feel.get_children().filter(func(n: Node) -> bool: return n is Label)
	_check(feel.get_child_count() >= before + 2 and labels.size() == 1 and labels[0].text == "2",
			"a hit throws sparks and shows its damage")
	events.enemy_killed.emit(enemy)
	_check(feel.get_children().filter(func(n: Node) -> bool: return n is CPUParticles2D).size() >= 2,
			"a kill throws a burst of sparks")
	await _real_wait(1.5)
	_check(feel.get_children().filter(func(n: Node) -> bool: return n is Label or n is CPUParticles2D).is_empty(),
			"sparks and numbers clean themselves up")

	# A dodge leaves fading afterimages of Nico.
	# Counted as they appear: a slow frame may already have faded the first one.
	var ghosts := [0]
	var count_ghost := func(n: Node) -> void:
		if n is Sprite2D:
			ghosts[0] += 1
	feel.child_entered_tree.connect(count_ghost)
	var still := [true]
	var check_still := func(n: Node) -> void:
		if n is Node2D and n.physics_interpolation_mode != Node.PHYSICS_INTERPOLATION_MODE_OFF:
			still[0] = false
	feel.child_entered_tree.connect(check_still)
	events.player_dashed.emit(Vector2.RIGHT)
	await _real_wait(0.2)
	feel.child_entered_tree.disconnect(count_ghost)
	feel.child_entered_tree.disconnect(check_still)
	_check(ghosts[0] >= 2, "a dodge leaves afterimages behind Nico")
	_check(still[0], "afterimages and sparks are not interpolated (no stray copy far from Nico)")
	await _real_wait(0.6)
	_check(feel.get_children().filter(func(n: Node) -> bool: return n is Sprite2D).is_empty(),
			"the afterimages fade away")

	# Low health: the edge pulses at 1 heart and goes away when healed.
	var low = feel.get_node("FeelOverlay/LowHealth")
	events.player_health_changed.emit(1, 5)
	_check(low.visible, "at one heart the screen edge pulses red")
	events.player_health_changed.emit(3, 5)
	_check(not low.visible, "healed, the red edge goes away")

	# A boss slam shakes harder than a kill.
	events.boss_attack_struck.emit(&"forest_guardian", &"slam", Vector2.ZERO)
	_check(feel.is_shaking(), "a boss slam shakes the camera")

	# Leaving the tree in the middle of a freeze never leaves the game slowed down.
	feel.hit_stop(5.0)
	feel.queue_free()
	await _frames(2)
	_check(Engine.time_scale == 1.0, "removing the effects restores the time scale")

	quit(0 if _ok else 1)


## Waits real milliseconds (timers would be slowed down by a freeze).
func _real_wait(seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
