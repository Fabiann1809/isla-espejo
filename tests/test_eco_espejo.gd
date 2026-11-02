extends SceneTree
## Eco del Espejo test, with real physics: it looks like a tinted, see-through Nico; once it hunts him
## it walks his path as it was a moment ago (catching up and hurting him by touch when he stands
## still), echoes each of his shots in the same direction after the same delay, and stops echoing
## once it is killed.
## Run: godot --headless --path . --script res://tests/test_eco_espejo.gd

## A room-like territory around the test.
const HOME := Rect2(-230, -140, 460, 280)
const NICO_SPEED := 90.0

var _ok := true
var _room: Node2D
var _player: Node2D
var _events: Node


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_events = root.get_node("Events")
	_room = load("res://scenes/levels/test_room.tscn").instantiate()
	for node_name in ["Trap1", "Trap2", "Grunt1", "Grunt2", "Dummy1", "Dummy2", "Dummy3"]:
		_room.get_node(node_name).free()
	root.add_child(_room)
	await _frames(3)
	_player = _room.get_node("Player")
	_player.health.set_max_health(50)
	_player.global_position = Vector2(-120, 60)

	var echo = load("res://scenes/enemies/eco_espejo.tscn").instantiate()
	echo.data = echo.data.duplicate()
	echo.data.patrol_radius = 0.0
	echo.position = Vector2(-150, -80)
	echo.home_area = HOME
	_room.add_child(echo)
	await _frames(2)
	var frames: SpriteFrames = echo.data.sprite_frames
	for anim: StringName in [&"idle", &"walk", &"run", &"attack", &"hurt", &"death"]:
		_check(frames.has_animation(anim) and frames.get_frame_count(anim) > 0, "echo has %s" % anim)
	_check(echo.data is MirrorEchoData and echo.data.projectile_scene != null, "the echo uses a MirrorEchoData with a shot")
	var sprite: CanvasItem = echo.get_node("Sprite")
	_check(sprite.self_modulate == echo.data.echo_tint and sprite.self_modulate.a < 1.0,
			"it looks like a tinted, see-through Nico")

	# --- Nico stands still: it reaches his spot and its touch hurts him.
	var hp: int = _player.health.current
	for i in 240:
		await physics_frame
		if _player.health.current < hp:
			break
	_check(echo.state == echo.State.CHASE, "it hunts Nico")
	_check(_player.health.current == hp - echo.data.touch_damage, "standing still, it catches up and its touch hurts (%d -> %d)" % [hp, _player.health.current])
	await create_timer(1.0).timeout

	# --- Nico walks: it walks his path one delay behind.
	var delay_frames := roundi(echo.data.echo_delay * Engine.physics_ticks_per_second)
	var trail: Array[Vector2] = []
	var worst := 0.0
	for i in 150:
		_player.global_position += Vector2(NICO_SPEED / Engine.physics_ticks_per_second, 0)
		trail.append(_player.global_position)
		await physics_frame
		if i >= delay_frames + 30:
			worst = maxf(worst, echo.global_position.distance_to(trail[i - delay_frames]))
	_check(worst < 12.0, "it walks Nico's path %.1f s behind him (off by %.1f px at most)" % [echo.data.echo_delay, worst])
	_check(echo.global_position.distance_to(_player.global_position) > NICO_SPEED * echo.data.echo_delay * 0.7,
			"so it trails behind him")
	_check(echo.facing.x > 0.9 and not sprite.flip_h, "facing where it walks")

	# --- Nico shoots: the echo fires the same way after the same delay.
	_clear_orbs()
	_events.player_shot.emit(Vector2.UP, -1.0)
	var waited := 0
	var orbs: Array = []
	for i in 120:
		await physics_frame
		waited += 1
		orbs = _find_orbs()
		if not orbs.is_empty():
			break
	_check(orbs.size() == 1, "it echoes Nico's shot")
	_check(absi(waited - delay_frames) <= 3, "after the delay (%d frames, expected %d)" % [waited, delay_frames])
	if orbs.size() == 1:
		var orb: Node2D = orbs[0]
		_check(orb.global_position.distance_to(echo.global_position) < echo.data.muzzle_distance + 6.0, "from the echo")
		_check(orb.modulate == echo.data.shot_tint, "tinted like the echo")
		var from: Vector2 = orb.global_position
		await _frames(4)
		if is_instance_valid(orb):
			var heading: Vector2 = (orb.global_position - from).normalized()
			_check(heading.dot(Vector2.UP) > 0.99, "in the direction Nico shot")
		_check(echo.get_node("Sprite").animation == &"attack", "with Nico's bow pose")

	# --- Killed, it echoes nothing more.
	_clear_orbs()
	_events.player_shot.emit(Vector2.LEFT, -1.0)
	echo.health.take_damage(echo.health.max_health, _player.global_position)
	await create_timer(echo.data.echo_delay + 0.3).timeout
	_check(_find_orbs().is_empty(), "killed, it stops echoing")
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _find_orbs() -> Array:
	var orbs: Array = []
	for child in _room.get_children():
		if child.get_script() == load("res://scripts/enemies/enemy_orb.gd") and not child.is_queued_for_deletion():
			orbs.append(child)
	return orbs


func _clear_orbs() -> void:
	for orb in _find_orbs():
		orb.queue_free()


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
