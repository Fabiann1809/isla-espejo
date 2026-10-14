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
	await _frames(6)
	_check(dummy.hits == 1, "dummy is hit exactly once per swing (hits=%d)" % dummy.hits)
	await _frames(30)
	_check(player.state == player.State.IDLE, "returns to idle after the swing")

	_reset_dummy(dummy, player)
	await _tap("attack")
	await _frames(30)
	_check(dummy.hits == 2, "second swing after cooldown hits (hits=%d)" % dummy.hits)

	_reset_dummy(dummy, player)
	player.facing = Vector2.LEFT
	await _frames(30)
	await _tap("attack")
	await _frames(20)
	_check(dummy.hits == 2, "swing in the wrong direction misses (hits=%d)" % dummy.hits)

	await _frames(40)
	await _tap("dash")
	_check(player.state == player.State.DASH and player.is_invulnerable(), "dash grants invulnerability")
	await _frames(20)
	_check(not player.is_invulnerable(), "invulnerability ends after the dash")

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
