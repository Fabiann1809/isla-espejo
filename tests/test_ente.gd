extends SceneTree
## Ente del bosque test: its art and data load and it fights with the generic melee behaviour: it
## chases the player, warns by spreading its arms and hurts a player who stays in reach.
## Run: godot --headless --path . --script res://tests/test_ente.gd

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
	var ente = load("res://scenes/enemies/ente.tscn").instantiate()
	ente.data = ente.data.duplicate()
	ente.data.patrol_radius = 0.0
	room.add_child(ente)
	ente.global_position = ARENA + Vector2(90, 0)

	var frames: SpriteFrames = ente.data.sprite_frames
	for anim: StringName in [&"idle", &"walk", &"run", &"attack", &"hurt", &"death"]:
		_check(frames.has_animation(anim) and frames.get_frame_count(anim) > 0, "ente has %s" % anim)
	_check(frames.get_frame_count(&"attack") == 7, "ente attack has the 7-frame slam")

	var start_distance: float = ente.global_position.distance_to(player.global_position)
	var health_before: int = player.health.current
	var slammed := false
	for i in 300:
		await physics_frame
		if ente.state == ente.State.ATTACK:
			slammed = true
	_check(ente.target == player, "the ente detects the player")
	_check(ente.global_position.distance_to(player.global_position) < start_distance, "it walks toward the player")
	_check(slammed, "it slams when it reaches the player")
	_check(player.health.current < health_before, "the slam hurts the player (%d -> %d)" % [health_before, player.health.current])
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
