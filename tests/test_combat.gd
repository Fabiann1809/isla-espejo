extends SceneTree
## Combat test: health, hurtbox/hitbox, i-frames, traps, enemy death, knockback and the Events bus.
## Run: godot --headless --path . --script res://tests/test_combat.gd

var _ok := true
var _log := {"attacked": 0, "hit_enemy": 0, "damaged": 0, "health": 0, "died": 0,
		"enemy_damaged": 0, "enemy_killed": 0}


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	var events: Node = root.get_node("Events")
	events.player_attacked.connect(func(_d: Vector2) -> void: _log.attacked += 1)
	events.player_hit_enemy.connect(func(_e: Node, _dmg: int) -> void: _log.hit_enemy += 1)
	events.player_damaged.connect(func(_a: int, _p: Vector2) -> void: _log.damaged += 1)
	events.player_health_changed.connect(func(_c: int, _m: int) -> void: _log.health += 1)
	events.player_died.connect(func() -> void: _log.died += 1)
	events.enemy_damaged.connect(func(_e: Node, _a: int) -> void: _log.enemy_damaged += 1)
	events.enemy_killed.connect(func(_e: Node) -> void: _log.enemy_killed += 1)

	var room: Node = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(room)
	await _frames(3)

	var player = room.get_node("Player")
	var hurtbox: Hurtbox = player.get_node("Hurtbox")
	var dummy = room.get_node("Dummy3")
	_check(player.health.current == 5 and player.health.max_health == 5, "player starts with 5 health")

	# --- Player attacks an enemy: events, damage, knockback
	player.global_position = dummy.global_position - Vector2(20, 0)
	player.facing = Vector2.RIGHT
	await _frames(2)
	var dummy_x: float = dummy.global_position.x
	await _tap("attack")
	await _frames(10)
	_check(_log.attacked == 1, "Events.player_attacked emitted")
	_check(_log.hit_enemy == 1, "Events.player_hit_enemy emitted")
	_check(_log.enemy_damaged == 1, "Events.enemy_damaged emitted")
	_check(dummy.health.current == 4, "enemy lost 1 health (now %d)" % dummy.health.current)
	_check(dummy.global_position.x > dummy_x, "enemy is knocked back away from the player")

	# --- Enemy dies and is removed
	for i in 4:
		dummy.get_node("Hurtbox").receive_hit(1, Vector2.ZERO)
	await _frames(2)
	_check(_log.enemy_killed == 1, "Events.enemy_killed emitted")
	_check(not is_instance_valid(dummy), "dead enemy is removed from the scene")

	# --- Player takes damage: health, hurt state, i-frames, events
	player.global_position = Vector2(300, 200)
	await _frames(2)
	_check(hurtbox.receive_hit(1, player.global_position - Vector2(10, 0)), "hurtbox accepts a hit")
	_check(player.health.current == 4, "player health drops to 4")
	_check(player.state == player.State.HURT, "player enters HURT state")
	_check(_log.damaged == 1, "Events.player_damaged emitted")
	_check(not hurtbox.receive_hit(1, Vector2.ZERO), "hurtbox rejects hits during i-frames")
	_check(player.health.current == 4, "i-frames prevent extra damage")
	await _frames(60)
	_check(hurtbox.receive_hit(1, Vector2.ZERO), "hurtbox accepts hits again after i-frames")
	_check(player.health.current == 3, "player health drops to 3")
	_check(_log.health >= 3, "Events.player_health_changed emitted on each change")

	# --- Dash i-frames block damage
	await _frames(60)
	player.facing = Vector2.RIGHT
	await _tap("dash")
	_check(not hurtbox.receive_hit(1, Vector2.ZERO), "dash i-frames block damage")
	await _frames(70)

	# --- A trap hurts the player
	var before: int = player.health.current
	player.global_position = room.get_node("Trap1").global_position
	await _frames(130)
	_check(player.health.current < before, "spike trap damages the player (%d -> %d)" % [before, player.health.current])

	# --- Death
	player.global_position = Vector2(300, 200)
	await _frames(70)
	var remaining: int = player.health.current
	player.health.take_damage(remaining - 1)
	await _frames(60)
	_check(hurtbox.receive_hit(1, Vector2.ZERO), "last hit is accepted")
	_check(player.state == player.State.DEAD, "player dies at 0 health")
	_check(_log.died == 1, "Events.player_died emitted once")
	_check(not hurtbox.receive_hit(1, Vector2.ZERO), "dead player cannot be hit")

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _tap(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(5)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
