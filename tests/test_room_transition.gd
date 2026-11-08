extends SceneTree
## The entrance to the boss's arena: the first time Nico steps in, the screen dips and the camera breathes in,
## with no name or text. Ordinary rooms (and the start room) have no transition, it does not repeat in the same
## map, and a headless run without asking has none.
## Run: godot --headless --path . --script res://tests/test_room_transition.gd

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame

	# Without a screen (and without asking for it) there is no transition.
	var plain: Node2D = load("res://scenes/levels/forest_level.tscn").instantiate()
	root.add_child(plain)
	await process_frame
	await process_frame
	_check(plain.get_node_or_null("RoomTransition") == null, "no transition in a headless run unless asked")
	plain.queue_free()
	await process_frame

	var level: Node2D = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.intro_in_headless = true
	level.chapter_intro = false
	level.seed_value = 7
	root.add_child(level)
	for i in 8:
		await physics_frame
	var transition = level.get_node_or_null("RoomTransition")
	_check(transition != null, "the real game has the transition")
	var camera: Camera2D = level.player.get_node("Camera2D")
	_check(transition._dip.color.a == 0.0 and camera.zoom == Vector2.ONE, "the start room has none")
	_check(transition.find_children("*", "Label", true, false).is_empty(), "and it never shows any name or text")

	# An ordinary combat room: nothing.
	var combat = null
	var boss_room = null
	for coord in level.rooms:
		var room = level.rooms[coord]
		if room.data.type == RoomData.RoomType.COMBAT and combat == null:
			combat = room
		elif room.data.type == RoomData.RoomType.BOSS:
			boss_room = room
	level.player.global_position = combat.global_position + combat.center() + Vector2(0, 60)
	for i in 8:
		await physics_frame
	_check(transition._dip.color.a == 0.0 and camera.zoom == Vector2.ONE, "an ordinary room has no transition")

	# The boss's arena: the dip and the camera breath.
	level.player.global_position = boss_room.global_position + boss_room.center() + Vector2(-150, 100)
	for i in 6:
		await physics_frame
	_check(transition._dip.color.a > 0.0, "entering the boss's arena dips the screen")
	_check(camera.zoom.x > 1.0, "and the camera breathes in")
	Engine.time_scale = 30.0
	for i in 120:
		await process_frame
	Engine.time_scale = 1.0
	await process_frame
	_check(camera.zoom == Vector2.ONE and transition._dip.color.a == 0.0, "then everything settles back")

	# Leaving and coming back in the same map: not again.
	level.player.global_position = combat.global_position + combat.center() + Vector2(0, 60)
	for i in 20:
		await physics_frame
	level.player.global_position = boss_room.global_position + boss_room.center() + Vector2(-150, 100)
	for i in 6:
		await physics_frame
	_check(transition._dip.color.a == 0.0 and camera.zoom == Vector2.ONE, "the arena does not play it twice in a map")

	level.queue_free()
	await process_frame
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
