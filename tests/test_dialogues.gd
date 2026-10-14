extends SceneTree
## Dialogue test: validates EVERY file in data/dialogues/ (so anyone adding an NPC gets told what is
## wrong) and plays the Anciano's conversation through the real Dialogue autoload.
## Run: godot --headless --path . --script res://tests/test_dialogues.gd

const REQUIRED_STATES := ["first", "again", "final"]

var _ok := true
var _started: Array = []
var _finished: Array = []


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var events: Node = root.get_node("Events")
	events.dialogue_started.connect(func(id: StringName) -> void: _started.append(id))
	events.dialogue_finished.connect(func(id: StringName, state: StringName) -> void: _finished.append([id, state]))
	root.get_node("GameState").reset()

	_validate_files()
	await _play_elder()

	root.get_node("GameState").reset()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


# --- Every dialogue file -------------------------------------------------------------------------

func _validate_files() -> void:
	var files: Array[String] = []
	for file in DirAccess.open("res://data/dialogues").get_files():
		if file.ends_with(".json"):
			files.append(file)
	_check(files.has("elder.json"), "the Anciano's dialogue exists (%d dialogue files)" % files.size())

	for file in files:
		var label := file.get_basename()
		var json := JSON.new()
		var parsed := json.parse(FileAccess.get_file_as_string("res://data/dialogues/" + file))
		_check(parsed == OK and json.data is Dictionary, "%s is valid JSON" % label)
		if parsed != OK or not (json.data is Dictionary):
			continue
		var data: Dictionary = json.data
		_check(str(data.get("speaker", "")) != "", "%s has a speaker name" % label)

		var states: Dictionary = data.get("states", {})
		var missing: Array[String] = []
		for state in REQUIRED_STATES:
			if not states.has(state):
				missing.append(state)
		_check(missing.is_empty(), "%s has the three states first/again/final (missing: %s)" % [label, missing])

		var lines_ok := true
		for state in states:
			var lines = states[state]
			if not (lines is Array) or lines.is_empty():
				lines_ok = false
				continue
			for line in lines:
				var text := ""
				if line is Dictionary:
					text = str(line.get("text", ""))
				elif line is String:
					text = line
				if text.strip_edges() == "":
					lines_ok = false
		_check(lines_ok, "%s: every state has at least one non-empty line" % label)

		var rules: Array = data.get("rules", [])
		var rules_ok := not rules.is_empty()
		for rule in rules:
			if not (rule is Dictionary) or not states.has(rule.get("state", "")):
				rules_ok = false
		_check(rules_ok, "%s: every rule points to an existing state" % label)
		_check(not rules.is_empty() and not rules[-1].has("requires"), "%s: the last rule is an unconditional default" % label)

		var finish_ok := true
		for state in data.get("on_finish", {}):
			if not states.has(state):
				finish_ok = false
		_check(finish_ok, "%s: on_finish only names existing states" % label)


# --- The Anciano through the real autoload ----------------------------------------------------------

func _play_elder() -> void:
	var dialogue: Node = root.get_node("Dialogue")
	var state: Node = root.get_node("GameState")

	var data: Dictionary = dialogue.load_dialogue(&"elder")
	_check(dialogue.pick_state(data) == &"first", "with no story progress the Anciano starts with his first lines")
	_check(not dialogue.start(&"does_not_exist") and not dialogue.active, "a missing dialogue does not start (and does not crash)")

	_started.clear()
	_finished.clear()
	_check(dialogue.start(&"elder") and dialogue.active, "the conversation starts")
	_check(_started == [&"elder"], "Events.dialogue_started is emitted")
	_check(not dialogue.start(&"elder"), "a second conversation cannot start while one is open")
	var box: Node = dialogue._box
	_check(box.is_typing(), "the first line types itself out")

	var lines: Array = data.states.first
	var shown := 0
	for i in lines.size():
		box.complete_line()
		_check(not box.is_typing(), "line %d can be completed at once" % (i + 1))
		shown += 1
		await _advance()
	_check(shown == 4 and not dialogue.active, "the whole first conversation plays and then ends (%d lines)" % shown)
	_check(_finished == [[&"elder", &"first"]], "Events.dialogue_finished reports the state that played")
	_check(state.has_flag(&"met_elder"), "finishing the first conversation sets the 'met_elder' flag")

	_check(dialogue.pick_state(data) == &"again", "the next time the Anciano gives his hint")
	_started.clear()
	_finished.clear()
	dialogue.start(&"elder")
	for i in data.states.again.size():
		box.complete_line()
		await _advance()
	_check(_finished == [[&"elder", &"again"]], "the 'again' state plays")
	_check(not state.has_flag(&"forest_boss_defeated"), "talking does not defeat the boss")

	state.set_flag(&"forest_boss_defeated")
	_check(dialogue.pick_state(data) == &"final", "after the boss falls the Anciano says his final lines")
	_finished.clear()
	dialogue.start(&"elder")
	for i in data.states.final.size():
		box.complete_line()
		await _advance()
	_check(_finished == [[&"elder", &"final"]], "the 'final' state plays")

	# Pressing the key while a line is still typing completes it instead of skipping it.
	state.reset()
	dialogue.start(&"elder")
	await create_timer(0.3).timeout
	_check(box.is_typing(), "the line is still typing after 0.3 s")
	await _tap("interact")
	_check(not box.is_typing() and dialogue.active and dialogue._index == 0, "the first key press completes the line without skipping it")
	await _advance()
	_check(dialogue._index == 1, "the second key press moves to the next line")
	box.complete_line()
	await _advance()
	box.complete_line()
	await _advance()
	box.complete_line()
	await _advance()
	_check(not dialogue.active, "the conversation can be finished with the key alone")


## Advances one line: waits out the guard time, then presses the key.
func _advance() -> void:
	await create_timer(0.3).timeout
	await _tap("interact")


func _tap(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
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
