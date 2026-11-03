extends SceneTree
## Máscara parásita test, with real physics: it flies to the nearest other enemy and rides its head
## (drawn over it), sending it into a frenzy; Nico's arrows cannot hit the mask while it rides, they
## hit the host. When the host dies the mask jumps off and flees from Nico (now it can be hit), then
## rides the next enemy; with no host left it bites Nico by itself.
## Run: godot --headless --path . --script res://tests/test_mascara_parasita.gd

## A room-like territory around the test.
const HOME := Rect2(-230, -140, 460, 280)

var _ok := true
var _room: Node2D
var _player: Node2D


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_room = load("res://scenes/levels/test_room.tscn").instantiate()
	for node_name in ["Trap1", "Trap2", "Grunt1", "Grunt2", "Dummy1", "Dummy2", "Dummy3"]:
		_room.get_node(node_name).free()
	root.add_child(_room)
	await _frames(3)
	_player = _room.get_node("Player")
	_player.health.set_max_health(50)
	_player.global_position = Vector2(0, 120)

	var mask = load("res://scenes/enemies/mascara_parasita.tscn").instantiate()
	mask.data = mask.data.duplicate()
	mask.data.patrol_radius = 0.0
	mask.position = Vector2(0, -60)
	mask.home_area = HOME
	var frames: SpriteFrames = mask.data.sprite_frames
	for anim: StringName in [&"idle", &"walk", &"run", &"attack", &"special", &"hurt", &"death"]:
		_check(frames.has_animation(anim) and frames.get_frame_count(anim) > 0, "mask has %s" % anim)
	_check(mask.data is ParasiteMaskData, "the mask uses a ParasiteMaskData")
	var first = _spawn_host(Vector2(-70, -60))
	var second = _spawn_host(Vector2(150, -60))
	_room.add_child(mask)
	await _frames(2)
	_check(mask.collision_layer == 0, "its flying body never blocks anyone")

	# --- It flies to the nearest enemy and rides it.
	var saw_special := false
	for i in 180:
		await physics_frame
		saw_special = saw_special or mask.get_node("Sprite").animation == &"special"
		if mask.is_riding():
			break
	_check(mask.is_riding() and mask.host() == first, "it rides the nearest enemy")
	_check(saw_special, "the leap plays the special animation")
	await _frames(3)
	_check(first.is_frenzied() and first._speed_scale() > 1.2, "its host is in a frenzy (speed x%.2f)" % first._speed_scale())
	_check(not second.is_frenzied(), "the other enemy is not")
	_check(first.is_masked(), "riding tells its host it is masked (Enemy.set_masked(true))")
	_check(not second.is_masked(), "the other enemy is not masked")
	var sprite: Node2D = mask.get_node("Sprite")
	_check(mask.global_position.y > first.global_position.y and sprite.global_position.y < first.global_position.y - 10.0,
			"it sits on its host's head, drawn over it")
	first.global_position += Vector2(0, 20)
	await _frames(2)
	_check(mask.global_position.distance_to(first.global_position) < 2.0, "and follows it")

	# --- Arrows cannot hit it while it rides: they hit the host.
	await _frames(2)
	var mask_hp: int = mask.health.current
	var host_hp: int = first.health.current
	_shoot_at(first.global_position)
	await _frames(20)
	_check(mask.health.current == mask_hp, "an arrow cannot hit the riding mask")
	_check(first.health.current < host_hp, "it hits the host instead (%d -> %d)" % [host_hp, first.health.current])

	# --- The host dies: the mask jumps off and flees from Nico, and can be hit.
	var before: float = mask.global_position.distance_to(_player.global_position)
	first.health.take_damage(first.health.max_health, _player.global_position)
	await _frames(2)
	_check(not mask.is_riding() and mask.is_fleeing(), "when its host dies the mask jumps off and flees")
	_check(not is_instance_valid(first) or not first.is_masked(), "jumping off unmasks the old host (set_masked(false))")
	await create_timer(mask.data.flee_time * 0.8).timeout
	_check(mask.global_position.distance_to(_player.global_position) > before + 20.0, "away from Nico")
	mask_hp = mask.health.current
	mask.get_node("Hurtbox").receive_hit(1, _player.global_position)
	_check(mask.health.current == mask_hp - 1, "now it can be hit")

	# --- Then it rides the next enemy.
	for i in 300:
		await physics_frame
		if mask.is_riding():
			break
	_check(mask.is_riding() and mask.host() == second, "it looks for another host and rides it")
	await _frames(2)
	_check(second.is_frenzied() and second.is_masked(), "the new host is in a frenzy and masked")

	# --- With no host left it bites Nico by itself.
	second.health.take_damage(second.health.max_health, _player.global_position)
	await _frames(2)
	_check(not is_instance_valid(second) or not second.is_masked(), "and is unmasked when it dies")
	_player.global_position = mask.global_position + Vector2(0, 50)
	var hp: int = _player.health.current
	var bit := false
	for i in 400:
		await physics_frame
		if _player.health.current < hp:
			bit = true
			break
	_check(not mask.is_riding() and mask.host() == null, "no host is left")
	_check(bit, "alone, it bites Nico (%d -> %d)" % [hp, _player.health.current])
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


## A skeleton that stands still and never notices Nico, so only the mask acts.
func _spawn_host(at: Vector2) -> Node:
	var host = load("res://scenes/enemies/esqueleto.tscn").instantiate()
	host.data = host.data.duplicate()
	host.data.patrol_radius = 0.0
	host.data.detection_range = 1.0
	host.position = at
	host.home_area = HOME
	_room.add_child(host)
	return host


## One of Nico's arrows, fired from the left at `at`.
func _shoot_at(at: Vector2) -> void:
	var arrow = load("res://data/weapons/bow.tres").projectile_scene.instantiate()
	arrow.setup(Vector2.RIGHT, 300.0, 120.0, 1)
	arrow.position = at + Vector2(-50, 0)
	_room.add_child(arrow)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
