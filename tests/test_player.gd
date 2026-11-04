extends SceneTree
## Gameplay test for the player (attack, cooldown, dash i-frames, camera limits, hurt/die).
## Run: godot --headless --path . --script res://tests/test_player.gd

var _ok := true


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	var room: Node = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(room)
	await _frames(3)

	var player = room.get_node("Player")
	var dummy = room.get_node("Dummy1")
	player.global_position = dummy.global_position - Vector2(20, 0)
	player.facing = Vector2.RIGHT
	await _frames(2)
	_check(player.state == player.State.IDLE, "starts idle")

	await _tap("attack")
	_check(player.state == player.State.ATTACK, "attack enters ATTACK state")
	await _frames(20)
	_check(dummy.hits == 1, "dummy is hit exactly once per shot (hits=%d)" % dummy.hits)
	await _frames(30)
	_check(player.state == player.State.IDLE, "returns to idle after the shot")

	_reset_dummy(dummy, player)
	await _tap("attack")
	await _frames(30)
	_check(dummy.hits == 2, "second shot after cooldown hits (hits=%d)" % dummy.hits)

	_reset_dummy(dummy, player)
	player.facing = Vector2.LEFT
	await _frames(30)
	await _tap("attack")
	await _frames(20)
	_check(dummy.hits == 2, "shot in the wrong direction misses (hits=%d)" % dummy.hits)

	await _frames(40)
	await _tap("dash")
	_check(player.state == player.State.DASH and player.is_invulnerable(), "dash grants invulnerability")
	await _frames(20)
	_check(not player.is_invulnerable(), "invulnerability ends after the dash")

	await _test_input_buffer(player)

	player.global_position = Vector2(470, 260)
	await _frames(60)
	var cam: Camera2D = player.get_node("Camera2D")
	_check(cam.limit_right == 480 and cam.limit_left == -480, "camera limits are applied")

	player.hurt(player.global_position - Vector2(10, 0))
	_check(player.state == player.State.HURT, "hurt state")
	await _frames(30)
	_check(player.state == player.State.IDLE, "recovers from hurt")
	player.die()
	_check(player.state == player.State.DEAD, "dead state")

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


## An attack pressed during its cooldown fires when the cooldown ends; a press made too early
## expires and does not fire.
func _test_input_buffer(player: CharacterBody2D) -> void:
	var attacks := [0]
	var count := func(_dir: Vector2) -> void: attacks[0] += 1
	player.attacked.connect(count)
	player.facing = Vector2.UP
	await _frames(60)
	await _tap("attack")
	_check(attacks[0] == 1, "buffer test: first attack")
	# Press again while the cooldown still has less than the buffer time left.
	while player._attack_cooldown_left > 0.1:
		await physics_frame
	_check(player._attack_cooldown_left > 0.0, "second press lands during the cooldown")
	await _tap("attack")
	await _frames(4)
	_check(attacks[0] == 2, "buffered attack fires once the cooldown ends (attacks=%d)" % attacks[0])

	await _frames(60)
	await _tap("attack")
	_check(attacks[0] == 3, "buffer test: third attack")
	# Pressed right away: the cooldown outlasts the buffer, so the press expires.
	await _tap("attack")
	await _frames(40)
	_check(attacks[0] == 3, "an expired buffered press does not fire (attacks=%d)" % attacks[0])

	await _tap("dash")
	await _frames(1)
	_check(player.state == player.State.DASH, "buffer test: dash")
	while player._dash_cooldown_left > 0.1:
		await physics_frame
	await _tap("dash")
	var dashed_again: bool = player.state == player.State.DASH
	for i in 4:
		await physics_frame
		dashed_again = dashed_again or player.state == player.State.DASH
	_check(dashed_again, "buffered dash fires once its cooldown ends")
	player.attacked.disconnect(count)
	await _frames(60)

	# A dash tapped late in an attack swing (dash cooldown 0) happens right after the swing.
	await _tap("attack")
	_check(player.state == player.State.ATTACK and player._dash_cooldown_left == 0.0, "swing with dash ready")
	while player.state == player.State.ATTACK and player._state_time_left > 0.1:
		await physics_frame
	await _press("dash")
	var dash_after_swing := false
	for i in 9:  # ~0.15 s
		await physics_frame
		if player.state == player.State.DASH:
			dash_after_swing = true
			break
	await _release("dash")
	_check(dash_after_swing, "dash tapped during an attack fires after the swing")
	await _frames(60)

	# A tap in a free state with no cooldown fires once, not again from the buffer.
	var dashes := [0]
	var count_dash := func(_dir: Vector2) -> void: dashes[0] += 1
	player.dashed.connect(count_dash)
	await _tap("dash")
	await _frames(60)
	_check(dashes[0] == 1, "a direct press fires once (dashes=%d)" % dashes[0])
	player.dashed.disconnect(count_dash)

	# HURT lets Nico act again when it ends: a late press is buffered and fires after it, an
	# early one (more than the buffer time before the end) expires.
	await _frames(60)
	player.hurt(player.global_position + Vector2(0, 10))
	_check(player.state == player.State.HURT, "buffer test: hurt")
	while player.state == player.State.HURT and player._state_time_left > 0.1:
		await physics_frame
	await _tap("attack")
	await _frames(4)
	_check(player.state == player.State.ATTACK, "attack pressed late in HURT fires after it")
	await _frames(80)
	attacks[0] = 0
	player.attacked.connect(count)
	player.hurt(player.global_position + Vector2(0, 10))
	await _tap("attack")  # pressed at the start of the 0.25 s hurt
	await _frames(40)
	_check(attacks[0] == 0, "attack pressed early in HURT expires (attacks=%d)" % attacks[0])
	player.attacked.disconnect(count)
	await _frames(60)


## The dummy is knocked back by every hit; put it back in front of the player.
func _reset_dummy(dummy: Node2D, player: Node2D) -> void:
	dummy.global_position = player.global_position + Vector2(20, 0)
	dummy.velocity = Vector2.ZERO


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await physics_frame


func _release(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = false
	Input.parse_input_event(event)
	await physics_frame


func _tap(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(5)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
