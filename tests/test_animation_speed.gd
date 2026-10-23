extends SceneTree
## Walk/run playback follows the real speed (speed_scale = speed / reference, 0.5..2.0) for Nico and
## enemies, and Nico's dash plays the run cycle. Run:
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
	_check(sprite.animation == &"walk" and is_equal_approx(sprite.speed_scale, 1.0),
			"Nico walking at full speed plays walk at 1.0x (%.2f)" % sprite.speed_scale)
	Input.action_press("dash")
	await _frames(4)
	Input.action_release("dash")
	_check(sprite.animation == &"run" and is_equal_approx(sprite.speed_scale, 2.0),
			"the dash plays the run cycle, capped at 2x (%s, %.2f)" % [sprite.animation, sprite.speed_scale])
	Input.action_release("move_right")
	await _frames(20)
	_check(sprite.animation == &"idle" and is_equal_approx(sprite.speed_scale, 1.0), "resting plays idle at 1.0x")

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
