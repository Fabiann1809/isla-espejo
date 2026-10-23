extends SceneTree
## Enemy animation test: while chasing a player who strafes, the idle/run animation must not
## flicker (each play() restarts the cycle at frame 0). Run:
## godot --headless --path . --script res://tests/test_enemy_animation.gd

const ARENA := Vector2(300, 180)
## Measured before the fix: 13 changes in 240 ticks, 7 of them 1-2 ticks after the previous one;
## after it: 9 (run, attack, recover, run...), none that short.
const MAX_CHANGES := 10

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
	player.health.max_health = 999
	player.health.current = 999
	var enemy = load("res://scenes/enemies/sombra_errante.tscn").instantiate()
	enemy.data = enemy.data.duplicate()
	enemy.data.attack_damage = 0
	room.add_child(enemy)
	enemy.global_position = ARENA + Vector2(0, 90)
	await _frames(5)
	enemy._acquire_target(player)
	var sprite: AnimatedSprite2D = enemy.get_node("Sprite")
	var changes := 0
	var restarts_in_a_row := 0
	var last := sprite.animation
	var last_change_tick := -100
	var sequence := []
	for i in 240:
		var left := (i / 20) % 2 == 0
		Input.action_press("move_left" if left else "move_right")
		Input.action_release("move_right" if left else "move_left")
		await physics_frame
		if sprite.animation != last:
			changes += 1
			# Attack and hurt show at once on purpose (they warn the player); only idle/walk/run
			# switching back and forth counts as flicker.
			var locomotion := [&"idle", &"walk", &"run"]
			if i - last_change_tick <= 2 and sprite.animation in locomotion and last in locomotion:
				restarts_in_a_row += 1
			last_change_tick = i
			last = sprite.animation
			sequence.append("%d:%s" % [i, sprite.animation])
	Input.action_release("move_left")
	Input.action_release("move_right")
	print("  sequence: ", sequence)
	print("  chase, 240 ticks: %d animation changes, %d of them 1-2 ticks after the previous one" % [changes, restarts_in_a_row])
	_check(changes <= MAX_CHANGES, "the chasing enemy does not flicker between animations (%d changes)" % changes)
	_check(restarts_in_a_row == 0, "no idle/walk/run animation lasts only 1-2 ticks (%d did)" % restarts_in_a_row)
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
