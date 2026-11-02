extends SceneTree
## Statuses one enemy gives another (temple enemies): a magic shield blocks every hit while it lasts,
## and a frenzy makes an enemy faster and its attacks come back sooner.
## Run: godot --headless --path . --script res://tests/test_enemy_status.gd

var _ok := true


func _initialize() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var enemy = load("res://scenes/enemies/grunt.tscn").instantiate()
	enemy.position = Vector2(300, 300)
	root.add_child(enemy)
	await _frames(2)
	var hurtbox = enemy.get_node("Hurtbox")

	# Shield: hits are blocked while it lasts, then they land again.
	var hp: int = enemy.health.current
	enemy.apply_shield(0.3)
	hurtbox.receive_hit(1, Vector2(250, 300))
	_check(enemy.is_shielded() and enemy.health.current == hp, "a shielded enemy takes no damage")
	await create_timer(0.4).timeout
	_check(not enemy.is_shielded(), "the shield wears off")
	hurtbox.receive_hit(1, Vector2(250, 300))
	_check(enemy.health.current == hp - 1, "then hits land again")

	# Frenzy: faster, and its attack cooldown runs faster.
	var normal: float = enemy._speed_scale()
	enemy.apply_frenzy(1.5, 2.0, 0.5)
	_check(enemy.is_frenzied() and is_equal_approx(enemy._speed_scale(), normal * 1.5), "a frenzied enemy is faster")
	enemy._attack_cooldown_left = 1.0
	await create_timer(0.2).timeout
	_check(enemy._attack_cooldown_left < 0.7, "and its attacks come back sooner (%.2f left)" % enemy._attack_cooldown_left)
	enemy.end_frenzy()
	_check(not enemy.is_frenzied() and is_equal_approx(enemy._speed_scale(), normal), "the frenzy can be ended at once")
	quit(0 if _ok else 1)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
