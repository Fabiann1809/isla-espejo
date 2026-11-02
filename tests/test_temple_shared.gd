extends SceneTree
## Shared pieces of the temple enemies (island 3): enemies can pull and slow Nico, and a ground
## hazard hurts and slows whoever stands on it, then goes away.
## Run: godot --headless --path . --script res://tests/test_temple_shared.gd

var _ok := true


func _initialize() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var player = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(200, 200)
	root.add_child(player)
	await _frames(2)

	# Slow: walking speed drops while it lasts.
	player.apply_slow(0.5, 0.3)
	_check(player.is_slowed(), "an enemy can slow Nico")
	await create_timer(0.4).timeout
	_check(not player.is_slowed(), "the slow wears off")

	# Pull: dragged toward the anchor until close to it.
	var start: Vector2 = player.global_position
	player.apply_pull(start + Vector2(-120, 0), 300.0, 1.0)
	await create_timer(0.15).timeout
	_check(player.global_position.x < start.x - 20.0, "a pull drags Nico toward its anchor")
	await create_timer(0.6).timeout
	_check(not player.is_pulled() and player.global_position.distance_to(start + Vector2(-120, 0)) < 20.0,
			"the pull ends when he reaches it")

	# A ground hazard under Nico hurts him and slows him; it goes away by itself.
	var hazard_script: Script = load("res://scripts/enemies/ground_hazard.gd")
	var hp: int = player.health.current
	var hazard = hazard_script.create(player.global_position, 10.0, 0.6, 1, Color.ORANGE)
	hazard.slow_factor = 0.5
	root.add_child(hazard)
	await _frames(4)
	_check(player.health.current == hp - 1, "standing on a hazard hurts (%d -> %d)" % [hp, player.health.current])
	_check(player.is_slowed(), "and slows")
	await create_timer(0.8).timeout
	_check(not is_instance_valid(hazard), "the hazard fades away after its lifetime")
	quit(0 if _ok else 1)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
