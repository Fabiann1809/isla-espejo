extends SceneTree
## Carcelero de cadenas test: it aims (a line shows where), throws a chain no longer than its range,
## a caught Nico is hurt and dragged to it and then struck by its melee swing; a sidestep during the
## locked aim makes it miss, and a hit while aiming drops the chain.
## Run: godot --headless --path . --script res://tests/test_carcelero_cadenas.gd

const ARENA := Vector2(300, 180)

var _ok := true
var _room: Node
var _player: Node2D
var _scene: PackedScene


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_room = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(_room)
	await _frames(3)
	_player = _room.get_node("Player")
	_scene = load("res://scenes/enemies/carcelero_cadenas.tscn")

	var jailer = _spawn(ARENA + Vector2(90, 0))
	var frames: SpriteFrames = jailer.data.sprite_frames
	for anim: StringName in [&"idle", &"walk", &"run", &"attack", &"special", &"hurt", &"death"]:
		_check(frames.has_animation(anim) and frames.get_frame_count(anim) > 0, "jailer has %s" % anim)
	_check(jailer.data is ChainJailerData, "the jailer uses a ChainJailerData")
	jailer.free()
	await _catch_and_follow_up()
	await _sidestep_dodges()
	await _hit_drops_chain()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _catch_and_follow_up() -> void:
	_reset_player(ARENA)
	var jailer = _spawn(ARENA + Vector2(90, 0))
	var aim_line: Line2D = jailer.get_node("ChainAim")
	var chain_line: Line2D = jailer.get_node("Chain")
	var hitbox: Node2D = jailer.get_node("ChainHitbox")
	var hp: int = _player.health.current
	var saw_aim := false
	var saw_special := false
	var saw_chain := false
	var pulled := false
	var longest := 0.0
	for i in 150:
		await physics_frame
		saw_aim = saw_aim or aim_line.visible
		saw_chain = saw_chain or chain_line.visible
		saw_special = saw_special or jailer.get_node("Sprite").animation == &"special"
		pulled = pulled or _player.is_pulled()
		if chain_line.visible:
			longest = maxf(longest, hitbox.position.length())
		if pulled and not _player.is_pulled():
			break
	_check(saw_aim, "the jailer shows its aim before throwing")
	_check(saw_special, "the throw plays the special animation")
	_check(saw_chain, "the chain is drawn as a line while it flies")
	_check(longest <= jailer.data.chain_range + 10.0, "the chain flies no farther than its range (%.0f px)" % longest)
	_check(_player.health.current == hp - 1, "the chain's tip hurts Nico (%d -> %d)" % [hp, _player.health.current])
	_check(pulled, "a caught Nico is pulled")
	var distance: float = _player.global_position.distance_to(jailer.global_position)
	_check(distance < 26.0, "he is dragged next to the jailer (%.0f px)" % distance)
	# The melee swing follows the catch.
	var swung := false
	for i in 90:
		await physics_frame
		if jailer.state == jailer.State.ATTACK and not jailer.is_throwing():
			swung = true
		if _player.health.current < hp - 1:
			break
	_check(swung, "the jailer follows the catch with its melee swing")
	_check(_player.health.current == hp - 2, "and the swing hurts (%d -> %d)" % [hp, _player.health.current])
	await _free(jailer)


func _sidestep_dodges() -> void:
	_reset_player(ARENA)
	var jailer = _spawn(ARENA + Vector2(90, 0))
	var hp: int = _player.health.current
	# Wait until the aim is locked, then step aside.
	for i in 120:
		await physics_frame
		if jailer.is_throwing() and jailer._step_left < jailer.data.aim_lock_time * 0.5:
			break
	_player.global_position = ARENA + Vector2(0, 40)
	var chain_line: Line2D = jailer.get_node("Chain")
	var saw_chain := false
	for i in 40:
		await physics_frame
		saw_chain = saw_chain or chain_line.visible
		if saw_chain and not jailer.is_throwing():
			break
	_check(saw_chain, "the chain is thrown at where he was")
	_check(not _player.is_pulled() and _player.health.current == hp, "a sidestep during the locked aim dodges it")
	await _free(jailer)


func _hit_drops_chain() -> void:
	_reset_player(ARENA)
	var jailer = _spawn(ARENA + Vector2(90, 0))
	for i in 60:
		await physics_frame
		if jailer.is_throwing():
			break
	_check(jailer.is_throwing(), "the jailer starts aiming")
	jailer.get_node("Hurtbox").receive_hit(1, _player.global_position)
	await _frames(2)
	_check(not jailer.is_throwing() and not jailer.get_node("ChainAim").visible
			and not jailer.get_node("Chain").visible, "a hit while aiming drops the chain")
	await _free(jailer)


func _reset_player(at: Vector2) -> void:
	_player.global_position = at
	_player.health.heal(_player.health.max_health)
	_player.apply_pull(at, 0.0, 0.0)


func _spawn(at: Vector2) -> Node:
	var jailer = _scene.instantiate()
	jailer.data = jailer.data.duplicate()
	jailer.position = at
	_room.add_child(jailer)
	return jailer


## Frees an enemy and lets Nico's hit invulnerability run out before the next case.
func _free(enemy: Node) -> void:
	enemy.queue_free()
	await create_timer(1.0).timeout


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
