extends SceneTree
## The prologue: four animated scenes (the storm, the awakening, the compass, the island) whose videos and
## subtitles come from data/story/prologue.json. The right line shows in the right scene and at the right time,
## E/J skips a scene, Esc skips it all, waiting plays them all, and a new journey from the main menu goes through it.
## Run: godot --headless --path . --script res://tests/test_prologue.gd

const LINES := [
	"La tormenta llegó sin aviso.",
	"Cuando Nico abrió los ojos, el mar ya no estaba a su alrededor.",
	"Mi brújula… está rota. ¿Qué es este lugar?",
	"No sé dónde estoy… pero tengo que volver a casa.",
]

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame

	var prologue = load("res://scenes/ui/prologue.tscn").instantiate()
	prologue.next_scene = ""
	prologue.clock_speed = 0.0          # frozen: the test moves the clock itself
	root.add_child(prologue)
	await process_frame

	# --- the data
	_check(prologue.scenes.size() == 4, "the prologue has four scenes")
	_check(prologue.lines.size() == 4, "and one line in each")
	for i in 4:
		var scene: Dictionary = prologue.scenes[i]
		_check(ResourceLoader.exists(scene.get("video", "")), "scene %d has its video" % i)
		var duration: float = scene.get("duration", 0.0)
		var line: Dictionary = scene.get("lines", [{}])[0]
		_check(line.get("text", "") == LINES[i], "scene %d says what the story says" % i)
		_check(["bottom", "top", "bottom_right"].has(line.get("place", "")), "scene %d says where its subtitle goes" % i)
		_check(float(line.get("at", -1.0)) >= 0.0 and float(line.get("at", 0.0)) < float(line.get("until", 0.0)) and float(line.get("until", 0.0)) <= duration,
				"scene %d shows its line inside the scene" % i)
	_check(prologue.scenes[0].get("lines")[0].get("speaker", "x") == "" and prologue.scenes[1].get("lines")[0].get("speaker", "x") == "",
			"the first two lines are the narrator's")
	_check(prologue.scenes[2].get("lines")[0].get("speaker") == "Nico" and prologue.scenes[3].get("lines")[0].get("speaker") == "Nico",
			"the last two are Nico's")
	_check((prologue.scenes[0].get("sfx", []) as Array).size() >= 3, "the storm has its thunder cues")
	for cue in prologue.scenes[0].get("sfx", []):
		_check(float(cue.get("at", -1.0)) > 0.0 and float(cue.get("at", 0.0)) < float(prologue.scenes[0].get("duration", 0.0)), "a thunder cue falls inside the scene")

	# --- the right line at the right time
	_check(prologue.scene_index == 0, "it starts with the storm")
	prologue.update_subtitle(0.2)
	_check(prologue.shown_text() == "", "nothing is said before the line's time")
	prologue.update_subtitle(2.0)
	_check(prologue.shown_text() == LINES[0], "the storm line shows during the storm")
	prologue.update_subtitle(8.0)
	_check(prologue.shown_text() == "", "and goes away before the scene ends")

	# --- E / J skip a scene
	await _tap("interact")
	_check(prologue.scene_index == 1, "E goes to the next scene")
	prologue.update_subtitle(4.0)
	_check(prologue.shown_text() == LINES[1], "the second scene says its own line")
	await _tap("attack")
	_check(prologue.scene_index == 2, "J also goes to the next scene")
	prologue.update_subtitle(5.0)
	_check(prologue.shown_text() == LINES[2] and prologue._speaker.text == "Nico", "Nico speaks in the compass scene")

	# --- Esc skips it all
	var ended := [false]
	prologue.finished.connect(func() -> void: ended[0] = true)
	await _tap("pause")
	await create_timer(1.0).timeout
	_check(ended[0], "Esc skips the rest of the prologue")
	prologue.queue_free()

	# --- waiting plays every scene in order and ends
	var waited = load("res://scenes/ui/prologue.tscn").instantiate()
	waited.next_scene = ""
	waited.clock_speed = 60.0
	var seen: Array[int] = []
	var waited_end := [false]
	waited.finished.connect(func() -> void: waited_end[0] = true)
	root.add_child(waited)
	var last := -1
	var guard := 0
	while not waited_end[0] and guard < 600:
		await process_frame
		guard += 1
		if waited.scene_index != last:
			last = waited.scene_index
			seen.append(last)
	await create_timer(1.0).timeout
	_check(seen.size() >= 4 and seen[0] == 0 and seen[1] == 1 and seen[2] == 2 and seen[3] == 3, "the scenes play in order")
	_check(waited_end[0], "after the last scene the prologue ends")

	var menu_script: String = FileAccess.get_file_as_string("res://scripts/ui/main_menu.gd")
	_check(menu_script.contains("change_scene_to_file(PROLOGUE_SCENE)"), "a new journey starts with the prologue")
	quit(0 if _ok else 1)


func _tap(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	Input.flush_buffered_events()
	await process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	await process_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
