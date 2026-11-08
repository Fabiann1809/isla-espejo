extends SceneTree
## The chapter intro: when the real game starts a chapter the camera opens on the start room seen from farther
## away while the island's name appears, then glides in to Nico and gives the controls back; any action key skips it; a
## headless run or `--no-intro` starts at once.
## Run: godot --headless --path . --script res://tests/test_chapter_intro.gd

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame

	# Without a screen the intro does not play: the game starts on Nico at once.
	var plain: Node2D = load("res://scenes/levels/forest_level.tscn").instantiate()
	root.add_child(plain)
	await process_frame
	await process_frame
	_check(plain.get_node_or_null("ChapterIntro") == null, "no intro in a headless run unless asked")
	_check(not plain.player._locked, "so the player is free at once")
	plain.queue_free()
	await process_frame

	# Asked for: it opens far away, with the island's name, and holds the controls.
	var level: Node2D = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.intro_in_headless = true
	level.seed_value = 7
	root.add_child(level)
	for i in 8:
		await process_frame
	var intro = level.get_node_or_null("ChapterIntro")
	_check(intro != null, "the chapter starts with its intro")
	if intro == null:
		quit(1)
		return
	var camera: Camera2D = level.player.get_node("Camera2D")
	_check(intro.title_label.text == level.scenario.display_name, "the title is the island's name")
	_check(intro.subtitle_label.text == level.scenario.chapter_title, "and its chapter phrase is under it")
	_check(camera.zoom.x < 1.0, "the camera starts zoomed out")
	var start_room = level.room_at(level.layout.start_cell)
	var view_center: Vector2 = level.player.global_position + camera.position
	_check(view_center.distance_to(start_room.global_position + start_room.center()) < 1.0, "centered on the room where Nico appears, not on the whole map")
	_check(camera.position.length() < start_room.pixel_size().length(), "so the glide is short (less than a room)")
	_check(level.player._locked, "the controls are held during the intro")
	_check(not level.get_node("Hud").visible, "the HUD waits for the end")

	# It ends by itself and gives everything back.
	var ended := [false]
	intro.finished.connect(func() -> void: ended[0] = true)
	Engine.time_scale = 40.0
	var guard := 0
	while not ended[0] and guard < 600:
		await process_frame
		guard += 1
	Engine.time_scale = 1.0
	await process_frame
	_check(ended[0], "the intro ends by itself")
	_check(camera.zoom == Vector2.ONE and camera.position == Vector2.ZERO, "the camera is back on Nico at the game's own zoom")
	_check(camera.limit_right - camera.limit_left > 0 and camera.limit_right < 100000, "its limits were never lifted")
	_check(not level.player._locked, "the player is free")
	_check(level.get_node("Hud").visible, "the HUD is back")
	_check(not is_instance_valid(intro) or intro.is_queued_for_deletion(), "and the intro frees itself")
	level.queue_free()
	await process_frame

	# Any action key skips it.
	var skipped: Node2D = load("res://scenes/levels/forest_level.tscn").instantiate()
	skipped.intro_in_headless = true
	skipped.seed_value = 7
	root.add_child(skipped)
	for i in 8:
		await process_frame
	var intro2 = skipped.get_node_or_null("ChapterIntro")
	var skip_end := [false]
	intro2.finished.connect(func() -> void: skip_end[0] = true)
	var press := InputEventAction.new()
	press.action = "interact"
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	await process_frame
	await process_frame
	_check(skip_end[0], "a key press skips the intro")
	_check(not skipped.player._locked and skipped.player.get_node("Camera2D").zoom == Vector2.ONE, "leaving the game as if it had played")
	var release := InputEventAction.new()
	release.action = "interact"
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	skipped.queue_free()
	await process_frame
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
