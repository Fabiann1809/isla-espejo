extends SceneTree
## Fog beast test: it uses the generic enemy behaviour and its own sprite data.

const ARENA := Vector2(300, 180)

var _ok := true
var _room: Node
var _player: Node2D


func _initialize() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	_room = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(_room)
	await _frames(3)
	_player = _room.get_node("Player")
	_player.global_position = ARENA
	var beast = load("res://scenes/enemies/bestia_de_la_niebla.tscn").instantiate()
	beast.data = beast.data.duplicate()
	beast.data.patrol_radius = 0.0
	beast.global_position = ARENA + Vector2(100, 0)
	_room.add_child(beast)
	beast.global_position = ARENA + Vector2(100, 0)

	await _frames(30)
	_check(beast.target == _player, "fog beast detects the player")
	_check(beast.state in [beast.State.CHASE, beast.State.ATTACK], "fog beast chases the player")
	var start_distance: float = beast.global_position.distance_to(_player.global_position)
	var health_before: int = _player.health.current
	await _frames(140)
	_check(beast.global_position.distance_to(_player.global_position) < start_distance,
			"generic chase closes the distance")
	_check(_player.health.current < health_before, "generic attack damages the player (%d -> %d)" % [health_before, _player.health.current])
	_check(beast.data.sprite_frames.has_animation(&"run"), "wolf has run animation")
	_check(beast.data.sprite_frames.has_animation(&"attack"), "wolf has attack animation")
	_check(beast.data.sprite_frames.get_frame_count(&"walk") == 8, "wolf walk has 8 complete frames")
	_check(beast.data.sprite_frames.get_frame_count(&"run") == 6, "wolf run has 6 complete frames")
	_check(beast.data.sprite_frames.get_frame_count(&"attack") == 8, "wolf attack has 8 complete frames")
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
