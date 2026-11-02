extends SceneTree
## Verdugo de piedra test, with real physics: its slam is warned by a circle at its feet, then a
## shockwave ring grows on the ground and hurts Nico (2) only when its band reaches him, never past
## its max radius, and not while he dashes through it. It is also hard to push.
## The arena is moved off the origin so warnings and rings are checked in room coordinates.
## Run: godot --headless --path . --script res://tests/test_verdugo_piedra.gd

const ARENA_OFFSET := Vector2(40, 24)
const SPOT := Vector2(200, 200)

var _ok := true
var _arena: Node2D
var _player: Node2D
var _executioner: Node2D


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_arena = Node2D.new()
	_arena.position = ARENA_OFFSET
	root.add_child(_arena)
	_player = load("res://scenes/player/player.tscn").instantiate()
	_player.position = SPOT + Vector2(30, 0) - ARENA_OFFSET
	_arena.add_child(_player)
	_executioner = load("res://scenes/enemies/verdugo_piedra.tscn").instantiate()
	_executioner.data = _executioner.data.duplicate()
	_executioner.data.patrol_radius = 0.0
	_executioner.position = SPOT - ARENA_OFFSET
	_arena.add_child(_executioner)
	var data = _executioner.data
	_check(data.max_health >= 15, "the executioner is sturdy (%d hp)" % data.max_health)

	# --- Warning circle at its feet during the windup
	await _until(func() -> bool: return _executioner.state == _executioner.State.ATTACK, 300)
	var warning: Node2D = _find_zone()
	_check(warning != null, "the slam is warned by a circle on the ground")
	if warning != null:
		_check(warning.global_position.distance_to(_executioner.global_position) < 1.0,
				"the warning circle is at its feet (in room coordinates)")

	# --- The ring hurts only when its band reaches Nico
	var distance := 95.0
	_player.global_position = _executioner.global_position + Vector2(distance, 0)
	var health_before: int = _player.health.current
	await _until(func() -> bool: return _executioner.wave_radius() >= 0.0, 120)
	var wave: Node2D = _arena.get_node_or_null("Shockwave")
	_check(wave != null and wave.z_index == -1 and not wave.z_as_relative, "the ring is drawn on the ground layer")
	var early := false
	var max_seen := 0.0
	while _executioner.wave_radius() >= 0.0:
		var radius: float = _executioner.wave_radius()
		max_seen = maxf(max_seen, radius)
		if radius < distance - data.wave_band - 4.0 and _player.health.current != health_before:
			early = true
		await physics_frame
	_check(max_seen > distance, "the ring grows past Nico (%.0f px)" % max_seen)
	_check(not early, "it does not hurt before its band reaches him")
	_check(_player.health.current == health_before - data.wave_damage,
			"the ring hurts Nico once for %d (%d -> %d)" % [data.wave_damage, health_before, _player.health.current])

	# --- Beyond the max radius nobody is hurt
	await _next_slam(Vector2(data.wave_max_radius + 25.0, 0))
	health_before = _player.health.current
	await _until(func() -> bool: return _executioner.wave_radius() >= 0.0, 120)
	await _until(func() -> bool: return _executioner.wave_radius() < 0.0, 120)
	_check(_player.health.current == health_before, "the ring stops at its max radius")

	# --- Dashing through the ring
	var dash_from := 70.0
	await _next_slam(Vector2(dash_from, 0))
	health_before = _player.health.current
	_player.facing = Vector2.LEFT
	await _until(func() -> bool: return _executioner.wave_radius() >= dash_from - data.wave_band - 15.0, 200)
	_player._start_dash()
	await _until(func() -> bool: return _executioner.wave_radius() < 0.0, 120)
	_check(_player.global_position.distance_to(_executioner.global_position) < dash_from - 20.0, "Nico dashed toward the hammer")
	_check(_player.health.current == health_before, "dashing through the ring avoids it (%d -> %d)" % [health_before, _player.health.current])

	# --- Hard to push
	_executioner.apply_knockback(Vector2(200, 0))
	_check(_executioner.velocity.length() <= 200.0 * (1.0 - data.knockback_resistance) + 0.5,
			"a push barely moves it (%.0f px/s)" % _executioner.velocity.length())
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


## Brings Nico next to it until it starts a new slam, then puts him at `offset` from the hammer.
func _next_slam(offset: Vector2) -> void:
	_player.global_position = _executioner.global_position + Vector2(30, 0)
	await _until(func() -> bool:
		return _executioner.state == _executioner.State.ATTACK \
				and _executioner._attack_phase == _executioner.AttackPhase.WINDUP, 400)
	_player.global_position = _executioner.global_position + offset


func _find_zone() -> Node2D:
	var zone_script: Script = load("res://scripts/skills/skill_zone.gd")
	for child in _arena.get_children():
		if child.get_script() == zone_script:
			return child
	return null


func _until(condition: Callable, max_frames: int) -> void:
	for i in max_frames:
		if condition.call():
			return
		await physics_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
