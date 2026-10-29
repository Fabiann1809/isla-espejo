extends SceneTree
## Esqueleto test: its art and data load and it fights with the generic melee behaviour: it chases
## the player, warns with its club swing and hurts a player who stays in reach.
## Run: godot --headless --path . --script res://tests/test_esqueleto.gd

const ARENA := Vector2(300, 180)

var _ok := true


func _initialize() -> void:
	create_timer(40.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	var room = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(room)
	await _frames(3)
	var player: Node2D = room.get_node("Player")
	player.global_position = ARENA
	var skeleton = load("res://scenes/enemies/esqueleto.tscn").instantiate()
	skeleton.data = skeleton.data.duplicate()
	skeleton.data.patrol_radius = 0.0
	room.add_child(skeleton)
	skeleton.global_position = ARENA + Vector2(90, 0)

	var frames: SpriteFrames = skeleton.data.sprite_frames
	for anim: StringName in [&"idle", &"walk", &"run", &"attack", &"hurt", &"death"]:
		_check(frames.has_animation(anim) and frames.get_frame_count(anim) > 0, "skeleton has %s" % anim)
	_check(frames.get_frame_count(&"attack") == 7, "skeleton attack has the 7-frame club swing")

	var start_distance: float = skeleton.global_position.distance_to(player.global_position)
	var health_before: int = player.health.current
	var swung := false
	for i in 300:
		await physics_frame
		if skeleton.state == skeleton.State.ATTACK:
			swung = true
	_check(skeleton.target == player, "the skeleton detects the player")
	_check(skeleton.global_position.distance_to(player.global_position) < start_distance, "it walks toward the player")
	_check(swung, "it swings its club when it reaches the player")
	_check(player.health.current < health_before, "the swing hurts the player (%d -> %d)" % [health_before, player.health.current])
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
