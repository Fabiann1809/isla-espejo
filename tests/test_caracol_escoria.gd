extends SceneTree
## Caracol de escoria test: it is slow and sturdy (a hit barely pushes it), it leaves a burning
## trail of evenly spaced patches along its way that hurt and slow Nico and fade after a few
## seconds, and its bite hurts.
## Run: godot --headless --path . --script res://tests/test_caracol_escoria.gd

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
	_scene = load("res://scenes/enemies/caracol_escoria.tscn")

	var snail = _spawn(ARENA + Vector2(100, 0))
	var frames: SpriteFrames = snail.data.sprite_frames
	for anim: StringName in [&"idle", &"walk", &"run", &"attack", &"special", &"hurt", &"death"]:
		_check(frames.has_animation(anim) and frames.get_frame_count(anim) > 0, "snail has %s" % anim)
	_check(snail.data is SlagSnailData, "the snail uses a SlagSnailData")
	_check(snail.health.max_health >= 12 and snail.data.attack_armor and snail.data.knockback_resistance >= 0.5,
			"the snail is sturdy (%d hp)" % snail.health.max_health)
	snail.free()
	await _burning_trail()
	await _sturdy_and_bites()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _burning_trail() -> void:
	_player.global_position = ARENA
	var start := ARENA + Vector2(100, 0)
	var snail = _spawn(start)
	var spacing: float = snail.data.trail_spacing
	await create_timer(3.0).timeout
	var patches := get_nodes_in_group(&"ground_hazards")
	_check(patches.size() >= 3, "the snail leaves a trail behind it (%d patches)" % patches.size())
	var even := patches.size() >= 2
	for i in range(1, patches.size()):
		var gap: float = patches[i].global_position.distance_to(patches[i - 1].global_position)
		even = even and absf(gap - spacing) < 3.0
	_check(even, "the patches are about %.0f px apart" % spacing)
	var behind := not patches.is_empty()
	for patch in patches:
		behind = behind and patch.global_position.distance_to(snail.global_position) \
				< start.distance_to(snail.global_position) + 1.0 and patch.global_position.x >= snail.global_position.x
	_check(behind, "the trail lies along the way it crawled")
	var crawled: float = start.distance_to(snail.global_position)
	_check(crawled < 3.0 * snail.data.chase_speed + 2.0, "the snail is slow (%.0f px in 3 s)" % crawled)
	# Nico steps on the trail: it burns and slows him.
	var first: Node2D = patches[0]
	var hp: int = _player.health.current
	snail.queue_free()
	_player.global_position = first.global_position
	await _frames(4)
	_check(_player.health.current == hp - 1, "the trail burns Nico (%d -> %d)" % [hp, _player.health.current])
	# The slow comes with the patch's next tick.
	await create_timer(first.tick + 0.1).timeout
	_check(_player.is_slowed() and is_equal_approx(_player._slow_factor, 0.55), "and slows him (x%.2f)" % _player._slow_factor)
	_player.global_position = ARENA + Vector2(0, 80)
	await create_timer(1.5).timeout
	_check(not is_instance_valid(first), "the oldest patch has faded after a few seconds")
	await create_timer(3.0).timeout
	_check(get_nodes_in_group(&"ground_hazards").is_empty(), "the whole trail fades away")


func _sturdy_and_bites() -> void:
	_player.global_position = ARENA
	_player.health.heal(_player.health.max_health)
	var snail = _spawn(ARENA + Vector2(30, 0))
	await _frames(2)
	var before: Vector2 = snail.global_position
	var max_health: int = snail.health.max_health
	snail.get_node("Hurtbox").receive_hit(1, snail.global_position + Vector2(-20, 0))
	await create_timer(0.3).timeout
	var pushed: float = snail.global_position.distance_to(before)
	_check(snail.health.current == max_health - 1, "one hit takes one of its %d hp" % max_health)
	_check(pushed < 6.0, "a hit barely pushes it (%.1f px)" % pushed)
	var hp: int = _player.health.current
	var bit := false
	for i in 300:
		await physics_frame
		if _player.health.current < hp:
			bit = true
			break
	_check(bit, "its bite hurts Nico")
	snail.queue_free()
	await _frames(2)


func _spawn(at: Vector2) -> Node:
	var snail = _scene.instantiate()
	snail.data = snail.data.duplicate()
	snail.position = at
	_room.add_child(snail)
	return snail


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
