extends SceneTree
## Acólito del brasero test: it fires a fan of fire-tinted flames centred on Nico that hurts him,
## backs away when he comes too close, and never backs out of its room (cornered, it fires anyway).
## Run: godot --headless --path . --script res://tests/test_acolito_brasero.gd

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
	_scene = load("res://scenes/enemies/acolito_brasero.tscn")

	var acolyte = _spawn(ARENA + Vector2(120, 0))
	var frames: SpriteFrames = acolyte.data.sprite_frames
	for anim: StringName in [&"idle", &"walk", &"run", &"attack", &"special", &"hurt", &"death"]:
		_check(frames.has_animation(anim) and frames.get_frame_count(anim) > 0, "acolyte has %s" % anim)
	_check(acolyte.data is BrazierAcolyteData and acolyte.data.projectile_scene != null,
			"the acolyte uses a BrazierAcolyteData with a projectile")
	acolyte.free()
	await _fan_of_fire()
	await _backs_away()
	await _stays_in_its_room()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _fan_of_fire() -> void:
	_reset_player(ARENA)
	var acolyte = _spawn(ARENA + Vector2(120, 0))
	var hp: int = _player.health.current
	var flames: Array = []
	var saw_special := false
	for i in 200:
		await physics_frame
		saw_special = saw_special or acolyte.get_node("Sprite").animation == &"special"
		flames = _find_orbs()
		if not flames.is_empty():
			break
	_check(saw_special, "the fan plays the special animation")
	_check(flames.size() == acolyte.data.fan_count, "it fires %d flames at once (%d)" % [acolyte.data.fan_count, flames.size()])
	if flames.size() >= 2:
		var from: Array = []
		for flame in flames:
			from.append(flame.global_position)
		await _frames(4)
		var angles: Array = []
		var aimed := false
		var to_player: Vector2 = (_player.global_position - acolyte.global_position).normalized()
		for i in flames.size():
			if not is_instance_valid(flames[i]):
				continue
			var heading: Vector2 = (flames[i].global_position - from[i]).normalized()
			angles.append(to_player.angle_to(heading))
			aimed = aimed or heading.dot(to_player) > 0.99
		angles.sort()
		var spread: float = rad_to_deg(angles.back() - angles.front()) if angles.size() >= 2 else 0.0
		_check(absf(absf(spread) - acolyte.data.fan_angle) < 3.0, "the flames spread over the fan's angle (%.0f deg)" % absf(spread))
		_check(aimed, "the middle flame flies at Nico")
		_check(flames[0].modulate == acolyte.data.fire_tint, "the flames are tinted with fire")
	await _frames(120)
	_check(_player.health.current < hp, "the fan hurts Nico (%d -> %d)" % [hp, _player.health.current])
	await _free(acolyte)


func _backs_away() -> void:
	_reset_player(ARENA)
	var acolyte = _spawn(ARENA + Vector2(45, 0))
	var retreated := false
	for i in 40:
		await physics_frame
		retreated = retreated or acolyte.is_retreating()
	var distance: float = acolyte.global_position.distance_to(_player.global_position)
	_check(retreated, "the acolyte backs away when Nico is too close")
	_check(distance > 60.0, "and gains distance (45 -> %.0f px)" % distance)
	await _free(acolyte)


func _stays_in_its_room() -> void:
	_reset_player(ARENA)
	var home := Rect2(ARENA.x - 100.0, ARENA.y - 80.0, 180.0, 160.0)
	var inner: Rect2 = home.grow(-load("res://scripts/core/tuning.gd").DASH_ROOM_MARGIN + 2.0)
	var acolyte = _spawn(ARENA + Vector2(50, 0), home)
	var inside := true
	var fired := false
	for i in 240:
		await physics_frame
		inside = inside and inner.has_point(acolyte.global_position)
		fired = fired or not _find_orbs().is_empty()
	_check(inside, "backing away never takes it out of its room (%s)" % acolyte.global_position)
	_check(fired, "cornered, it fires anyway")
	await _free(acolyte)


func _find_orbs() -> Array:
	var orbs: Array = []
	for child in _room.get_children():
		if child is EnemyOrb and not child.is_queued_for_deletion():
			orbs.append(child)
	return orbs


func _reset_player(at: Vector2) -> void:
	_player.global_position = at
	_player.health.heal(_player.health.max_health)


func _spawn(at: Vector2, home := Rect2()) -> Node:
	var acolyte = _scene.instantiate()
	acolyte.data = acolyte.data.duplicate()
	acolyte.position = at
	acolyte.home_area = home
	_room.add_child(acolyte)
	return acolyte


## Frees an enemy and its flames, and lets Nico's hit invulnerability run out before the next case.
func _free(enemy: Node) -> void:
	enemy.queue_free()
	for orb in _find_orbs():
		orb.queue_free()
	await create_timer(1.0).timeout


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
