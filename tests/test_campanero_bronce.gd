extends SceneTree
## Campanero de bronce test, with real physics: its strike is warned by a circle at its feet, then
## the bell sends rings one after another along the ground; each hurts Nico once when its band
## reaches him (never before), none reaches past its max radius, and dashing through a ring avoids it.
## Nico is held in place (his knockback would carry him out of the next rings) and, for the count,
## his post-hit blink is turned off so every ring can land.
## The arena is moved off the origin so warnings and rings are checked in room coordinates.
## Run: godot --headless --path . --script res://tests/test_campanero_bronce.gd

const ARENA_OFFSET := Vector2(40, 24)
const SPOT := Vector2(220, 200)

var _ok := true
var _arena: Node2D
var _player: Node2D
var _ringer: Node2D


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_arena = Node2D.new()
	_arena.position = ARENA_OFFSET
	root.add_child(_arena)
	_player = load("res://scenes/player/player.tscn").instantiate()
	_player.position = SPOT + Vector2(40, 0) - ARENA_OFFSET
	_arena.add_child(_player)
	_ringer = load("res://scenes/enemies/campanero_bronce.tscn").instantiate()
	_ringer.data = _ringer.data.duplicate()
	_ringer.data.patrol_radius = 0.0
	_ringer.position = SPOT - ARENA_OFFSET
	_arena.add_child(_ringer)
	var data = _ringer.data
	var frames: SpriteFrames = data.sprite_frames
	for anim: StringName in [&"idle", &"walk", &"run", &"attack", &"special", &"hurt", &"death"]:
		_check(frames.has_animation(anim), "the bell ringer has %s" % anim)
	_check(data.max_health >= 4 and data.max_health <= 8 and data.ring_damage == 1, "hard but fair stats")
	_check(data.ring_count >= 2, "it sends several rings per strike (%d)" % data.ring_count)

	# --- Warning circle at its feet
	await _until(func() -> bool: return _ringer.state == _ringer.State.ATTACK, 300)
	var warning: Node2D = _find_zone()
	_check(warning != null, "the strike is warned by a circle on the ground")
	if warning != null:
		_check(warning.global_position.distance_to(_ringer.global_position) < 1.0, "at its feet (in room coordinates)")

	# --- Every ring hurts once, only when its band reaches him
	_player.hit_invulnerability_time = 0.0
	var distance := 80.0
	var hold: Vector2 = _ringer.global_position + Vector2(distance, 0)
	var hp: int = _player.health.current
	await _until(func() -> bool: return not _ringer.ring_radii().is_empty(), 120)
	var ring: Node2D = _arena.get_node_or_null("BellRing")
	_check(ring != null and ring.z_index == -1 and not ring.z_as_relative, "the rings lie on the ground layer")
	var early := false
	var most_at_once := 0
	var hits := 0
	var last_hp := hp
	var max_seen := 0.0
	for i in 400:
		_player.global_position = hold
		var radii: Array = _ringer.ring_radii()
		most_at_once = maxi(most_at_once, radii.size())
		for radius in radii:
			max_seen = maxf(max_seen, radius)
		if _player.health.current < last_hp:
			hits += last_hp - _player.health.current
			# The newest ring that hurt must have reached him.
			var reached := false
			for radius in radii:
				reached = reached or radius >= distance - data.ring_band - 4.0
			early = early or not reached
			last_hp = _player.health.current
		if radii.is_empty() and _ringer.toll_step == _ringer.Toll.RECOVER:
			break
		await physics_frame
	_check(most_at_once >= 2, "the rings follow one another (%d out at once)" % most_at_once)
	_check(not early, "no ring hurts before its band reaches him")
	_check(hits == data.ring_count * data.ring_damage, "each ring hurts him once (%d hits for %d rings)" % [hits, data.ring_count])
	_check(max_seen <= data.ring_max_radius + 0.01 and max_seen > distance, "the rings grow past him to their max radius")
	_player.hit_invulnerability_time = 0.8
	_player.health.heal(_player.health.max_health)

	# --- Beyond the max radius nobody is hurt
	await _next_strike()
	hold = _ringer.global_position + Vector2(data.ring_max_radius + 20.0, 0)
	hp = _player.health.current
	await _hold_until_rings_end(hold)
	_check(_player.health.current == hp, "the rings stop at their max radius")

	# --- Dashing through a ring
	_ringer.data.ring_count = 1
	var dash_from := 70.0
	await _next_strike()
	_player.global_position = _ringer.global_position + Vector2(dash_from, 0)
	_player.facing = Vector2.LEFT
	hp = _player.health.current
	await _until(func() -> bool:
		var radii: Array = _ringer.ring_radii()
		return not radii.is_empty() and radii[0] >= dash_from - data.ring_band - 15.0, 200)
	_player._start_dash()
	await _until(func() -> bool: return _ringer.toll_step == _ringer.Toll.RECOVER and _ringer.ring_radii().is_empty(), 200)
	_check(_player.global_position.distance_to(_ringer.global_position) < dash_from - 20.0, "Nico dashed toward the bell")
	_check(_player.health.current == hp, "dashing through the ring avoids it (%d -> %d)" % [hp, _player.health.current])
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


## Brings Nico next to it until it starts a new strike.
func _next_strike() -> void:
	await _until(func() -> bool: return _ringer.state != _ringer.State.ATTACK, 300)
	_player.global_position = _ringer.global_position + Vector2(40, 0)
	await _until(func() -> bool:
		return _ringer.state == _ringer.State.ATTACK and _ringer.toll_step == _ringer.Toll.WINDUP, 400)


func _hold_until_rings_end(at: Vector2) -> void:
	for i in 400:
		_player.global_position = at
		if _ringer.toll_step == _ringer.Toll.RECOVER and _ringer.ring_radii().is_empty():
			return
		await physics_frame


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
