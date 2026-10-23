extends SceneTree
## Walk/run playback follows the real speed (speed_scale = speed / reference, 0.5..2.0) for Nico and
## enemies; Nico's swing, dash and hurt fit in their state's time and death plays once. Run:
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
	var dash_scale := 3.0 / (12.0 * float(player.dash_time))
	_check(sprite.animation == &"dash_side" and is_equal_approx(sprite.speed_scale, dash_scale) and not sprite.flip_h,
			"the dash plays dash_side fit to dash_time (%.2fx; got %s, %.2f)" % [dash_scale, sprite.animation, sprite.speed_scale])
	_check(sprite.modulate == player.TINT_DASH_SOFT and player.is_invulnerable(),
			"over its own art the dash tint is soft (%s) and the dash still has its i-frames" % sprite.modulate)
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
				and sprite.flip_h == (side == "move_left")
				and sprite.flip_h == (player.get_node("SwordPivot").scale.x < 0.0),
				"attacking after %s plays attack_side at %.2fx, body and sword on the same side (got %s, %.2f, flip %s)" % [side, expected_scale, sprite.animation, sprite.speed_scale, sprite.flip_h])
		await _frames(30)

	# Dash to the left: flipped. A dash straight up keeps the side pose and the side Nico last faced.
	await _frames(40)
	for case in [["move_left", true], ["move_up", true]]:
		Input.action_press(case[0])
		await _frames(2)
		Input.action_press("dash")
		await _frames(3)
		Input.action_release("dash")
		Input.action_release(case[0])
		_check(sprite.animation == &"dash_side" and sprite.flip_h == case[1],
				"dashing with %s plays dash_side, flip %s (got %s, %s)" % [case[0], case[1], sprite.animation, sprite.flip_h])
		await _frames(40)

	# Hurt: 2 frames at 8 fps last exactly hurt_time (0.25 s).
	player.hurt(player.global_position + Vector2(20, 0))
	await _frames(1)
	var hurt_scale := 2.0 / (8.0 * float(player.hurt_time))
	_check(sprite.animation == &"hurt_side" and is_equal_approx(sprite.speed_scale, hurt_scale),
			"getting hurt plays hurt_side fit to hurt_time (%.2fx; got %s, %.2f)" % [hurt_scale, sprite.animation, sprite.speed_scale])
	_check(sprite.modulate == player.TINT_HURT_SOFT and player.is_invulnerable(),
			"the hurt tint is soft (%s) and the hit invulnerability is unchanged" % sprite.modulate)
	await _frames(60)

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

	# Death: plays once and stays on its last frame (a lone Nico: the test room reloads on death).
	room.queue_free()
	await _frames(2)
	player = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	await _frames(2)
	sprite = player.get_node("Sprite")
	player.die()
	await _frames(1)
	_check(sprite.animation == &"death_side" and not sprite.sprite_frames.get_animation_loop(&"death_side"), "dying plays death_side once")
	_check(sprite.modulate == player.TINT_DEAD_SOFT, "the death tint is soft (%s)" % sprite.modulate)
	await _frames(90)
	_check(sprite.animation == &"death_side" and sprite.frame == sprite.sprite_frames.get_frame_count(&"death_side") - 1,
			"and stays on its last frame (frame %d)" % sprite.frame)

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
