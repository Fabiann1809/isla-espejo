extends SceneTree
## Centinela de obsidiana test, with real physics and real arrows: its shield stops arrows from the
## front (no damage, Events.arrow_blocked) but not from behind, it turns toward Nico at a limited
## rate, its swing hurts, and right after the swing the lowered shield lets a frontal arrow through.
## Run: godot --headless --path . --script res://tests/test_centinela_obsidiana.gd

const ARROW_SPEED := 260.0
const ARROW_RANGE := 200.0
## Nico far away (beyond the sentinel's lose range) while the shield is tried on its own.
const FAR := Vector2(700, 200)

var _ok := true
var _blocked := 0
var _arena: Node2D
var _player: Node2D


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	root.get_node("Events").arrow_blocked.connect(func(_at: Vector2) -> void: _blocked += 1)
	_arena = Node2D.new()
	root.add_child(_arena)
	_player = load("res://scenes/player/player.tscn").instantiate()
	_player.position = FAR
	_arena.add_child(_player)
	await _frames(2)

	# --- The shield: front blocked, back open
	var sentinel = _spawn(Vector2(200, 200), Vector2.RIGHT)
	await _frames(2)
	var frames: SpriteFrames = sentinel.data.sprite_frames
	for anim: StringName in [&"idle", &"walk", &"run", &"attack", &"special", &"hurt", &"death"]:
		_check(frames.has_animation(anim), "sentinel has %s" % anim)
	var hp: int = sentinel.health.current
	var arrow = _shoot(Vector2(250, 200), Vector2.LEFT)
	await _frames(20)
	_check(sentinel.health.current == hp, "a frontal arrow does no damage (%d -> %d)" % [hp, sentinel.health.current])
	_check(_blocked == 1, "the block is published as Events.arrow_blocked (%d)" % _blocked)
	_check(not is_instance_valid(arrow), "the shield stops the arrow")
	_check(sentinel.state != sentinel.State.HURT, "a blocked arrow does not stagger it")
	_shoot(Vector2(150, 200), Vector2.RIGHT)
	await _frames(20)
	_check(sentinel.health.current == hp - 1, "an arrow in the back hurts (%d -> %d)" % [hp, sentinel.health.current])
	_check(_blocked == 1, "a hit in the back is not a block")
	sentinel.queue_free()
	await _frames(2)

	# --- Turning: Nico behind it, it turns at its turn rate, not at once
	var start := Vector2(200, 200)
	sentinel = _spawn(start, Vector2.RIGHT)
	_player.global_position = start + Vector2(-20, 0)
	var turn_rate: float = sentinel.data.turn_rate
	while sentinel.state != sentinel.State.CHASE:
		await physics_frame
	var facing_before: Vector2 = sentinel.facing
	await _frames(15)
	var turned := rad_to_deg(absf(facing_before.angle_to(sentinel.facing)))
	_check(turned > 5.0 and turned <= turn_rate * 0.25 + 3.0,
			"it turns gradually toward Nico behind it (%.0f deg in 0.25 s)" % turned)

	# --- Once facing him it swings; the swing hurts and the shield is down right after it
	var health_before: int = _player.health.current
	var reached_recover := false
	for i in 300:
		await physics_frame
		if sentinel.state == sentinel.State.ATTACK and sentinel._attack_phase == sentinel.AttackPhase.RECOVER:
			reached_recover = true
			break
	_check(reached_recover, "it faces Nico and swings")
	_check(_player.health.current < health_before, "the swing hurts Nico (%d -> %d)" % [health_before, _player.health.current])
	_check(not sentinel.is_shield_up(), "the shield is lowered after the swing")
	hp = sentinel.health.current
	var front: Vector2 = sentinel.facing
	_shoot(sentinel.global_position + front * 40.0, -front)
	await _frames(12)
	_check(sentinel.health.current == hp - 1, "a frontal arrow gets through the lowered shield (%d -> %d)" % [hp, sentinel.health.current])
	_check(_blocked == 1, "and is not counted as a block")
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _spawn(at: Vector2, facing: Vector2) -> Node2D:
	var sentinel = load("res://scenes/enemies/centinela_obsidiana.tscn").instantiate()
	sentinel.data = sentinel.data.duplicate()
	sentinel.data.patrol_radius = 0.0
	sentinel.position = at
	_arena.add_child(sentinel)
	sentinel.facing = facing
	return sentinel


func _shoot(from: Vector2, direction: Vector2) -> Node2D:
	var arrow = load("res://scenes/player/arrow.tscn").instantiate()
	arrow.setup(direction, ARROW_SPEED, ARROW_RANGE, 1)
	arrow.position = from
	_arena.add_child(arrow)
	return arrow


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
