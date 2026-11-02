extends SceneTree
## Duelista maldito test, with real physics and real arrows: it sidesteps an arrow coming at it
## (perpendicular to its flight) and answers with a lunge that hurts Nico; its cooldown lets the
## next arrow hit; with no chance it never dodges, and it ignores arrows that would miss it.
## Run: godot --headless --path . --script res://tests/test_duelista_maldito.gd

const ARROW_SPEED := 260.0
const ARROW_RANGE := 200.0

var _ok := true
var _arena: Node2D
var _player: Node2D


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_arena = Node2D.new()
	root.add_child(_arena)
	_player = load("res://scenes/player/player.tscn").instantiate()
	_player.position = Vector2(270, 200)
	_arena.add_child(_player)

	# --- Sidestep and lunge
	var duelist = _spawn(Vector2(200, 200), 1.0)
	await _frames(2)
	var hp: int = duelist.health.current
	var health_before: int = _player.health.current
	_shoot(duelist.global_position + Vector2(100, 0), Vector2.LEFT)
	var lateral := 0.0
	var lunged := false
	var lunge_hurt := false
	for i in 110:
		await physics_frame
		lateral = maxf(lateral, absf(duelist.global_position.y - 200.0))
		if duelist.maneuver == duelist.Maneuver.LUNGE:
			lunged = true
			if _player.health.current < health_before:
				lunge_hurt = true
	_check(duelist.health.current == hp, "the dodged arrow does no damage (%d -> %d)" % [hp, duelist.health.current])
	_check(lateral > 12.0, "it sidesteps across the arrow's line (%.0f px)" % lateral)
	_check(lunged, "it answers with a lunge")
	_check(lunge_hurt, "the lunge hurts Nico (%d -> %d)" % [health_before, _player.health.current])

	# --- Cooldown: the next arrow hits
	_check(duelist.maneuver == duelist.Maneuver.NONE, "the maneuver ends")
	_shoot(duelist.global_position + Vector2(30, 0), Vector2.LEFT)
	await _frames(12)
	_check(duelist.health.current == hp - 1, "during its cooldown an arrow hits (%d -> %d)" % [hp, duelist.health.current])
	duelist.queue_free()
	_player.global_position = Vector2(-400, -400)

	# --- No chance, no dodge
	var steady = _spawn(Vector2(500, 200), 0.0)
	await _frames(2)
	hp = steady.health.current
	_shoot(steady.global_position + Vector2(100, 0), Vector2.LEFT)
	await _frames(40)
	_check(steady.health.current == hp - 1, "with no dodge chance the arrow hits")
	_check(absf(steady.global_position.y - 200.0) < 2.0, "and it did not sidestep")

	# --- An arrow that would miss is ignored
	var calm = _spawn(Vector2(500, 400), 1.0)
	await _frames(2)
	_shoot(calm.global_position + Vector2(100, 30), Vector2.LEFT)
	var stirred := false
	for i in 40:
		await physics_frame
		if calm.maneuver != calm.Maneuver.NONE:
			stirred = true
	_check(not stirred, "an arrow flying past does not make it dodge")
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _spawn(at: Vector2, dodge_chance: float) -> Node2D:
	var duelist = load("res://scenes/enemies/duelista_maldito.tscn").instantiate()
	duelist.data = duelist.data.duplicate()
	duelist.data.patrol_radius = 0.0
	duelist.data.dodge_chance = dodge_chance
	duelist.position = at
	_arena.add_child(duelist)
	return duelist


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
