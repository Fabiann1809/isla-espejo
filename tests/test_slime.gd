extends SceneTree
## Slime test: its art and data load, it always moves by hopping (advancing only while airborne) and
## its close-range lunge hurts a player who stands next to it.
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
	_check(slime.data is SlimeData and slime.data.air_last_frame < frames.get_frame_count(&"walk"), "slime uses a SlimeData whose airborne frames exist")

	# It advances only by hopping: it moves in the airborne frames and stays put on the ground, and it
	# never shows the idle pose while it chases.
	_player.global_position = ARENA
	var air_moves := 0.0
	var ground_moves := 0.0
	var air_samples := 0
	var ground_samples := 0
	var always_hopping := true
	var start_distance: float = slime.global_position.distance_to(_player.global_position)
	var previous: Vector2 = slime.global_position
	for i in 120:
		await physics_frame
		var step: float = slime.global_position.distance_to(previous)
		previous = slime.global_position
		if slime.state != slime.State.CHASE:
			continue
		var sprite: AnimatedSprite2D = slime.get_node("Sprite")
		always_hopping = always_hopping and sprite.animation == &"walk"
		if sprite.frame >= slime.data.air_first_frame and sprite.frame <= slime.data.air_last_frame:
			air_moves += step
			air_samples += 1
		else:
			ground_moves += step
			ground_samples += 1
	_check(air_samples > 10 and ground_samples > 5, "it chases through whole hops (%d airborne, %d grounded ticks)" % [air_samples, ground_samples])
	_check(always_hopping, "it plays the hop, never the idle pose, while it chases")
	_check(ground_moves < air_moves * 0.1, "it moves only while airborne (%.1f px in the air, %.1f px on the ground)" % [air_moves, ground_moves])
	_check(slime.global_position.distance_to(_player.global_position) < start_distance, "hopping brings it closer to the player")
	slime.queue_free()
	await _frames(3)
	var start_health: int = _player.health.current

	# A player that stands still gets hit.
	_player.global_position = ARENA
	slime = _spawn(scene, ARENA + Vector2(60, 0))
	await _frames(240)
	_check(_player.health.current < start_health, "its lunge hurts a player who stands next to it (%d -> %d)" % [start_health, _player.health.current])
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
