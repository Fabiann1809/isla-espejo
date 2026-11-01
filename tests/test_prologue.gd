extends SceneTree
## The prologue (the storm): its lines come from data/story/prologue.json, E/J shows the next one,
## the last line or Esc ends it, and a new journey from the main menu goes through it.
## Run: godot --headless --path . --script res://tests/test_prologue.gd

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame

	var prologue = load("res://scenes/ui/prologue.tscn").instantiate()
	prologue.next_scene = ""
	root.add_child(prologue)
	await process_frame
	_check(prologue.lines.size() >= 3, "the prologue reads its lines from data")
	_check(prologue.index == 0 and prologue._text.text == prologue.lines[0].text, "it starts with the first line")
	var lines := prologue.lines as Array
	_check(lines.all(func(line: Dictionary) -> bool: return line.get("text", "") != ""), "every line has its text")

	await _tap("interact")
	_check(prologue.index == 1, "E shows the next line")
	await _tap("attack")
	_check(prologue.index == 2, "J also shows the next line")

	var ended := [false]
	prologue.finished.connect(func() -> void: ended[0] = true)
	await _tap("pause")
	await create_timer(1.0).timeout
	_check(ended[0], "Esc skips the rest of the prologue")
	prologue.queue_free()

	# Waiting is enough: the lines go by themselves and the prologue ends after the last one.
	var waited = load("res://scenes/ui/prologue.tscn").instantiate()
	waited.next_scene = ""
	var waited_end := [false]
	waited.finished.connect(func() -> void: waited_end[0] = true)
	root.add_child(waited)
	await process_frame
	waited.next_line()
	waited.next_line()
	waited.next_line()
	waited.next_line()
	waited.next_line()
	await create_timer(1.0).timeout
	_check(waited_end[0], "after the last line the prologue ends")

	var menu_script: String = FileAccess.get_file_as_string("res://scripts/ui/main_menu.gd")
	_check(menu_script.contains("change_scene_to_file(PROLOGUE_SCENE)"), "a new journey starts with the prologue")
	quit(0 if _ok else 1)


func _tap(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
