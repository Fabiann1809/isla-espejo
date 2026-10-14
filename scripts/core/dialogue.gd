extends Node
## Dialogue runner (autoload "Dialogue"). Conversations are data: one JSON file per speaker in
## data/dialogues/ (format described in docs/EMPEZAR.md). An NPC calls `Dialogue.start("elder")`;
## which set of lines plays depends on the story flags in GameState, and finishing a conversation
## can set flags (so the NPC says something new next time).

signal started(dialogue_id: StringName)
signal finished(dialogue_id: StringName, state: StringName)

const DIALOGUE_DIR := "res://data/dialogues/"
const BOX_SCENE := preload("res://scenes/ui/dialogue_box.tscn")
## Pressing a key right as the conversation starts must not skip its first line.
const MIN_LINE_TIME := 0.25

var active := false

var _box: Node
var _id: StringName
var _state: StringName
var _data := {}
var _lines: Array = []
var _index := 0
var _line_time := 0.0


func _ready() -> void:
	_box = BOX_SCENE.instantiate()
	add_child(_box)
	_box.hide_box()


func _process(delta: float) -> void:
	if not active:
		return
	_line_time += delta
	if _line_time >= MIN_LINE_TIME and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack")):
		_advance()


## Starts the conversation `dialogue_id` (a file name in data/dialogues/). Returns false if it
## cannot be played.
func start(dialogue_id: StringName) -> bool:
	if active:
		return false
	var data := load_dialogue(dialogue_id)
	if data.is_empty():
		return false
	var state := pick_state(data)
	_lines = data.states[state]
	if _lines.is_empty():
		return false
	_id = dialogue_id
	_state = state
	_data = data
	_index = 0
	active = true
	started.emit(_id)
	Events.dialogue_started.emit(_id)
	_show_current()
	return true


## The parsed file of a dialogue, or an empty dictionary (with a warning) if it is missing or broken.
func load_dialogue(dialogue_id: StringName) -> Dictionary:
	var path := DIALOGUE_DIR + String(dialogue_id) + ".json"
	if not FileAccess.file_exists(path):
		push_warning("Dialogue '%s' not found (%s)." % [dialogue_id, path])
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		push_warning("Dialogue '%s' is not valid JSON." % dialogue_id)
		return {}
	return json.data


## The state whose conditions are met: the first rule whose required flags are all set wins.
## A rule without `requires` always matches, so end the list with one as the default.
func pick_state(data: Dictionary) -> StringName:
	for rule in data.get("rules", []):
		var met := true
		for flag in rule.get("requires", []):
			if not GameState.has_flag(StringName(flag)):
				met = false
		if met:
			return StringName(rule.state)
	return StringName(data.states.keys()[0])


func _advance() -> void:
	if _box.is_typing():
		_box.complete_line()
		_line_time = 0.0
		return
	_index += 1
	if _index >= _lines.size():
		_finish()
	else:
		_show_current()


func _show_current() -> void:
	var line = _lines[_index]
	var speaker: String = _data.get("speaker", "")
	var text := ""
	if line is Dictionary:
		speaker = line.get("speaker", speaker)
		text = line.get("text", "")
	else:
		text = str(line)
	_line_time = 0.0
	_box.show_line(speaker, text, _index == _lines.size() - 1)


func _finish() -> void:
	active = false
	_box.hide_box()
	for flag in _data.get("on_finish", {}).get(String(_state), []):
		GameState.set_flag(StringName(flag))
	finished.emit(_id, _state)
	Events.dialogue_finished.emit(_id, _state)
