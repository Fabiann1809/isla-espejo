extends SceneTree
## Walk/run playback follows the real speed (speed_scale = speed / reference, 0.5..2.0) for Nico and
## enemies, Nico's dash plays the side walk and his swing fits in attack_time. Run:
## godot --headless --path . --script res://tests/test_animation_speed.gd

const ARENA := Vector2(300, 180)

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var room = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(room)
	await _frames(3)
	for other in get_nodes_in_group("enemies"):
		other.queue_free()
	var player = room.get_node("Player")
	player.global_position = ARENA
	var sprite: AnimatedSprite2D = player.get_node("Sprite")

	Input.action_press("move_right")
	await _frames(10)
	_check(sprite.animation == &"walk_side" and is_equal_approx(sprite.speed_scale, 1.0),
			"Nico walking at full speed plays walk at 1.0x (%.2f)" % sprite.speed_scale)
	var before_x: float = player.global_position.x
	await _frames(1)
	var step: float = player.global_position.x - before_x
	_check(is_equal_approx(step, 2.0), "Nico walks exactly 2 px per physics tick (%.3f)" % step)
	Input.action_press("dash")
	await _frames(3)
	var dash_x: float = player.global_position.x
	await _frames(1)
	_check(is_equal_approx(player.global_position.x - dash_x, 5.0), "the dash moves exactly 5 px per tick (%.3f)" % (player.global_position.x - dash_x))
	Input.action_release("dash")
	# No dash art is connected yet: the dash shows the side walk, capped at 2x.
	_check(sprite.animation == &"walk_side" and is_equal_approx(sprite.speed_scale, 2.0),
			"the dash plays the side walk cycle, capped at 2x (%s, %.2f)" % [sprite.animation, sprite.speed_scale])
	Input.action_release("move_right")
	await _frames(20)
	_check(sprite.animation == &"idle_side" and is_equal_approx(sprite.speed_scale, 1.0), "resting plays idle at 1.0x")

	# The swing: the 5 side frames last exactly attack_time, flipped to the side Nico faces.
	for side in ["move_left", "move_down"]:
		Input.action_press(side)
		await _frames(3)
		Input.action_release(side)
		Input.action_press("attack")
		await _frames(2)
		Input.action_release("attack")
		var expected_scale := 5.0 / (12.0 * float(player.attack_time))
		_check(sprite.animation == &"attack_side" and is_equal_approx(sprite.speed_scale, expected_scale)
				and sprite.flip_h == (side == "move_left"),
				"attacking after %s plays attack_side at %.2fx (got %s, %.2f, flip %s)" % [side, expected_scale, sprite.animation, sprite.speed_scale, sprite.flip_h])
		await _frames(30)

	for multiplier in [1.0, 0.6, 3.0]:
		var enemy = load("res://scenes/enemies/murcielago.tscn").instantiate()
		enemy.data = enemy.data.duplicate()
		enemy.data.detection_range = 0.0
		enemy.data.patrol_radius = 200.0
		enemy.data.patrol_wait = 0.0
		enemy.speed_multiplier = multiplier
		room.add_child(enemy)
		enemy.global_position = ARENA + Vector2(0, 60)
		var bat_sprite: AnimatedSprite2D = enemy.get_node("Sprite")
		var seen := -1.0
		for i in 90:
			await physics_frame
			if bat_sprite.animation == &"walk" and enemy.velocity.length() > 1.0:
				seen = bat_sprite.speed_scale
				break
		var expected := clampf(multiplier, 0.5, 2.0)
		_check(is_equal_approx(seen, expected), "a patrolling bat at %.1fx speed plays walk at %.2fx (got %.2f)" % [multiplier, expected, seen])
		enemy.queue_free()
		await physics_frame

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
