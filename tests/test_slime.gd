extends SceneTree
## Slime test: its art and data load, it chases, and it attacks by crouching and leaping toward where
## the player stood (so sidestepping dodges it and a standing player gets hurt).
## Run: godot --headless --path . --script res://tests/test_slime.gd

const ARENA := Vector2(300, 180)

var _ok := true
var _room: Node
var _player: Node2D


func _initialize() -> void:
	create_timer(40.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	_room = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(_room)
	await _frames(3)
	_player = _room.get_node("Player")

	var scene: PackedScene = load("res://scenes/enemies/slime.tscn")
	var slime = _spawn(scene, ARENA + Vector2(90, 0))
	var frames: SpriteFrames = slime.data.sprite_frames
	for anim: StringName in [&"idle", &"walk", &"run", &"attack", &"hurt", &"death"]:
		_check(frames.has_animation(anim) and frames.get_frame_count(anim) > 0, "slime has %s" % anim)
	_check(frames.get_frame_count(&"attack") == 5 and frames.get_frame_count(&"death") == 6,
			"slime attack has 5 frames (crouch, leap, peak, land, recover) and death 6")
	_check(slime.data is SlimeData and slime.data.leap_speed > 0.0, "slime uses a SlimeData with a leap speed")

	# Dodge: the player steps away while the slime crouches; the leap goes where he stood.
	_player.global_position = ARENA
	var start_health: int = _player.health.current
	var dodged := false
	var leap_from := Vector2.ZERO
	var leap_dir := Vector2.ZERO
	for i in 400:
		await physics_frame
		if not dodged and slime.state == slime.State.ATTACK:
			dodged = true
			leap_from = slime.global_position
			leap_dir = (_player.global_position - slime.global_position).normalized()
			_player.global_position = ARENA + Vector2(0, 90)
		if dodged and slime.state != slime.State.ATTACK:
			break
	_check(dodged, "the slime starts an attack when the player is in range")
	var moved: Vector2 = slime.global_position - leap_from
	var expected: float = slime.data.leap_speed * slime.data.attack_time
	_check(moved.length() > expected * 0.6 and moved.normalized().dot(leap_dir) > 0.9,
			"the slime leaps %.0f px toward where the player stood (expected about %.0f)" % [moved.length(), expected])
	_check(_player.health.current == start_health, "a sidestep dodges the leap")
	slime.queue_free()
	await _frames(3)

	# A player that stands still gets hit.
	_player.global_position = ARENA
	slime = _spawn(scene, ARENA + Vector2(60, 0))
	await _frames(240)
	_check(_player.health.current < start_health, "a leap that lands hurts the player (%d -> %d)" % [start_health, _player.health.current])
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _spawn(scene: PackedScene, at: Vector2) -> Node:
	var slime = scene.instantiate()
	slime.data = slime.data.duplicate()
	slime.data.patrol_radius = 0.0
	_room.add_child(slime)
	slime.global_position = at
	return slime


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
