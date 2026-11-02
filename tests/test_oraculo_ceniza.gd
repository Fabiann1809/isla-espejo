extends SceneTree
## Oráculo de ceniza test, with real physics and real input: it marks a warning circle on the ground
## where Nico will be (on him when he stands, ahead of him when he walks), a fireball falls there and
## hurts him only when it lands inside the circle; keeping his course gets him hit, turning around
## dodges it. It backs away when he comes too close.
## The arena is moved off the origin so marks are checked in room coordinates.
## Run: godot --headless --path . --script res://tests/test_oraculo_ceniza.gd

const ARENA_OFFSET := Vector2(40, 24)
const HOME := Rect2(0, 0, 600, 400)
const SPOT := Vector2(300, 120)
## Where Nico starts each walk, relative to the oracle: below it and to its left.
const WALK_FROM := Vector2(-80, 110)

var _ok := true
var _arena: Node2D
var _player: Node2D
var _oracle: Node2D


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_arena = Node2D.new()
	_arena.position = ARENA_OFFSET
	root.add_child(_arena)
	_player = load("res://scenes/player/player.tscn").instantiate()
	_player.position = SPOT + Vector2(0, 120) - ARENA_OFFSET
	_arena.add_child(_player)
	_oracle = load("res://scenes/enemies/oraculo_ceniza.tscn").instantiate()
	_oracle.data = _oracle.data.duplicate()
	_oracle.data.patrol_radius = 0.0
	_oracle.home_area = HOME
	_oracle.position = SPOT - ARENA_OFFSET
	_arena.add_child(_oracle)
	var data = _oracle.data
	var frames: SpriteFrames = data.sprite_frames
	for anim: StringName in [&"idle", &"walk", &"run", &"attack", &"special", &"hurt", &"death"]:
		_check(frames.has_animation(anim), "the oracle has %s" % anim)
	_check(data.max_health >= 4 and data.max_health <= 8 and data.strike_damage == 1, "hard but fair stats")

	# --- Nico stands still: the mark is on him, and it only hurts when the fireball lands
	await _until(func() -> bool: return _oracle.fireball_target() != null, 200)
	var target = _oracle.fireball_target()
	_check(target != null and target.distance_to(_player.global_position) < 2.0, "standing still, the mark is on Nico")
	var mark: Node2D = _find_mark(target, data.strike_radius)
	_check(mark != null, "the spot is marked by a warning circle of the strike's radius")
	if mark != null:
		_check(mark.z_index == -1, "the mark lies on the ground layer")
	_check(_arena.get_node_or_null("AshFireball") != null, "a fireball falls toward it")
	var hp: int = _player.health.current
	var early := false
	while _oracle.fireball_target() != null:
		early = early or _player.health.current != hp
		await physics_frame
	await _frames(4)
	_check(not early, "nothing hurts before it lands")
	_check(_player.health.current == hp - data.strike_damage, "the landing hurts Nico inside the mark (%d -> %d)" % [hp, _player.health.current])

	# --- Walking on: the mark is ahead of him and he walks into it
	var walk_start: Vector2 = await _walk_into_next_cast()
	target = _oracle.fireball_target()
	var expected: Vector2 = walk_start + Vector2(_player.speed * data.lead_time, 0).limit_length(data.max_lead)
	_check(target != null and target.distance_to(expected) < 6.0,
			"walking, the mark is where he is heading (%s, expected %s)" % [target, expected])
	hp = _player.health.current
	await _until(func() -> bool: return _oracle.fireball_target() == null, 120)
	await _frames(4)
	Input.action_release("move_right")
	_check(_player.health.current < hp, "keeping his course, he walks into the fireball (%d -> %d)" % [hp, _player.health.current])

	# --- Turning around dodges it
	await _walk_into_next_cast()
	Input.action_release("move_right")
	Input.action_press("move_left")
	hp = _player.health.current
	await _until(func() -> bool: return _oracle.fireball_target() == null, 120)
	await _frames(6)
	Input.action_release("move_left")
	_check(_player.health.current == hp, "turning around dodges it (%d -> %d)" % [hp, _player.health.current])

	# --- It keeps its distance
	await _until(func() -> bool: return _oracle.state != _oracle.State.ATTACK, 120)
	_player.global_position = _oracle.global_position + Vector2(35, 0)
	var start: Vector2 = _oracle.global_position
	await _frames(60)
	var distance: float = _oracle.global_position.distance_to(_player.global_position)
	_check(distance > 60.0 and _oracle.global_position.x < start.x, "it backs away from Nico (35 -> %.0f px)" % distance)
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


## Waits for the next staff raise, puts Nico at WALK_FROM and walks him right until the mark appears.
## Returns where he was when it appeared.
func _walk_into_next_cast() -> Vector2:
	await _until(func() -> bool:
		return _oracle.state == _oracle.State.ATTACK and _oracle.cast_step == _oracle.Cast.WINDUP, 400)
	_player.global_position = _oracle.global_position + WALK_FROM
	Input.action_press("move_right")
	var at: Vector2 = _player.global_position
	for i in 120:
		at = _player.global_position
		await physics_frame
		if _oracle.fireball_target() != null:
			break
	return at


func _find_mark(center: Vector2, radius: float) -> Node2D:
	var zone_script: Script = load("res://scripts/skills/skill_zone.gd")
	for child in _arena.get_children():
		if child.get_script() == zone_script and child.global_position.distance_to(center) < 1.0 \
				and absf(child.radius - radius) < 0.1:
			return child
	return null


func _until(condition: Callable, max_frames: int) -> void:
	for i in max_frames:
		if condition.call():
			return
		await physics_frame


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
