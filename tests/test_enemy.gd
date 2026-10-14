extends SceneTree
## Enemy base test: detection, line of sight, chase, attack, hurt, death and director modifiers.
## Run: godot --headless --path . --script res://tests/test_enemy.gd

## Note: do not reference `Enemy` (class_name) or `preload` scenes here; that compiles scripts
## before the autoloads exist. Load at runtime and use untyped variables.

## Empty corner of the test room, away from dummies and traps.
const ARENA := Vector2(300, 180)

var _ok := true
var _detected := 0
var _room: Node
var _player: Node2D
var _grunt: PackedScene


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	_grunt = load("res://scenes/enemies/grunt.tscn")
	var events: Node = root.get_node("Events")
	events.enemy_detected_player.connect(func(_e: Node) -> void: _detected += 1)

	_room = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(_room)
	await _frames(3)
	_player = _room.get_node("Player")
	_player.global_position = ARENA
	await _frames(2)

	# --- Far away: it does not notice the player
	var far = _spawn(ARENA + Vector2(250, 0))
	await _frames(30)
	_check(far.target == null and far.state != far.State.CHASE, "enemy out of range does not detect")
	_check(_detected == 0, "no detection event while out of range")
	far.queue_free()

	# --- Wall blocks line of sight (enemy outside the room, player inside, 50px apart)
	_player.global_position = Vector2(0, -250)
	var behind_wall = _spawn(Vector2(0, -300))
	await _frames(30)
	_check(behind_wall.target == null, "wall blocks line of sight")
	behind_wall.queue_free()
	_player.global_position = ARENA
	await _frames(2)

	# --- Director modifiers
	var strong = _spawn(ARENA + Vector2(0, 100), {"health_multiplier": 2.0})
	_check(strong.health.max_health == 6, "health_multiplier doubles health (%d)" % strong.health.max_health)
	strong.free()  # immediately: it is inside vision range and must not get a physics tick
	var blind = _spawn(ARENA + Vector2(90, 0), {"vision_multiplier": 0.5})
	await _frames(30)
	_check(blind.target == null, "vision_multiplier 0.5 shrinks detection (90px > 60px)")
	blind.queue_free()

	# --- Detects, chases and attacks
	var enemy = _spawn(ARENA + Vector2(100, 0))
	var start_distance: float = enemy.global_position.distance_to(_player.global_position)
	await _frames(30)
	_check(enemy.target == _player, "enemy detects the player in range")
	_check(_detected == 1, "Events.enemy_detected_player emitted once (%d)" % _detected)
	_check(enemy.state in [enemy.State.CHASE, enemy.State.ATTACK], "enemy chases")
	_check(enemy.global_position.distance_to(_player.global_position) < start_distance, "enemy gets closer")
	var health_before: int = _player.health.current
	await _frames(120)
	_check(_player.health.current < health_before,
			"enemy attack hurts the player (%d -> %d)" % [health_before, _player.health.current])

	# --- Player hits the enemy: hurt, knockback, then dies
	_player.global_position = enemy.global_position - Vector2(18, 0)
	_player.facing = Vector2.RIGHT
	await _frames(3)
	var hurt_hits := 0
	for i in 3:
		enemy.get_node("Hurtbox").receive_hit(1, _player.global_position)
		hurt_hits += 1
		if i == 0:
			_check(enemy.state == enemy.State.HURT, "enemy enters HURT when hit")
		await _frames(25)
	await _frames(25)
	_check(not is_instance_valid(enemy), "enemy dies at 0 health and is removed")

	# --- Hit enemy becomes aware even without seeing the player
	_player.global_position = ARENA
	var shy = _spawn(ARENA + Vector2(250, 0), {"vision_multiplier": 0.1})
	await _frames(20)
	_check(shy.target == null, "unaware enemy has no target")
	shy.get_node("Hurtbox").receive_hit(1, ARENA)
	_check(shy.target == _player, "enemy becomes aware when hit")

	# --- Loses the target when the player flees beyond lose range
	var chaser = _spawn(ARENA + Vector2(60, 0))
	await _frames(20)
	_check(chaser.target == _player, "chaser acquired the player")
	_player.global_position = ARENA - Vector2(400, 0) + Vector2(0, 0)
	await _frames(10)
	_check(chaser.target == null, "enemy loses the target beyond lose range")
	_check(chaser.state in [chaser.State.IDLE, chaser.State.PATROL], "enemy returns to idle/patrol")

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _spawn(at: Vector2, modifiers := {}) -> Node2D:
	var enemy = _grunt.instantiate()
	# Own copy of the data without random patrol, so the test is deterministic.
	enemy.data = enemy.data.duplicate()
	enemy.data.patrol_radius = 0.0
	enemy.global_position = at
	for key in modifiers:
		enemy.set(key, modifiers[key])
	_room.add_child(enemy)
	enemy.global_position = at
	return enemy


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
