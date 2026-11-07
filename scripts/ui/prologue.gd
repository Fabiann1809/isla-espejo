class_name Prologue
extends Control
## The prologue: four short animated scenes (assets/video/prologue/, Ogg Theora, made by
## tools/prologue_scenes/) with the lines of the story over them, all read from data/story/prologue.json:
## the storm, Nico waking on the beach, the broken compass and the unknown island. Each scene fades
## in and out of black by itself, so the cuts between them are clean. Subtitles are typed over the
## picture at the times the data gives; E/J skips to the next scene, Esc skips it all.
## Shown once, when a new journey starts from the main menu; then the first island opens.

signal finished

const STORY_PATH := "res://data/story/prologue.json"
const FADE := 0.4
const TYPE_SPEED := 32.0          # characters per second
const HINT_SECONDS := 6.0
const TEXT_SIZE := 16
const SPEAKER_SIZE := 13
const TEXT_COLOR := Color(0.96, 0.95, 1.0)

## Scene opened at the end (empty in tests: only `finished` is emitted).
@export_file("*.tscn") var next_scene := "res://scenes/levels/forest_level.tscn"
## Speed of the scene clock when no video plays (headless runs); tests raise it.
var clock_speed := 1.0

var scenes: Array = []
## Every line of every scene, in order; each carries its scene number in "scene".
var lines: Array = []
var scene_index := -1

var _use_video := true
var _player: VideoStreamPlayer
var _panel: PanelContainer
var _speaker: Label
var _text: Label
var _hint: Label
var _time := 0.0
var _age := 0.0
var _shown: Dictionary = {}
var _played_sfx: Dictionary = {}
var _done := false


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var story := _load_story()
	scenes = story.get("scenes", [])
	for i in scenes.size():
		for line: Dictionary in scenes[i].get("lines", []):
			var entry := line.duplicate()
			entry["scene"] = i
			lines.append(entry)
	# A headless run (the tests, the CI) has nothing to show the video with: the scenes run on a clock.
	_use_video = DisplayServer.get_name() != "headless"
	_build(story.get("hint", ""))
	Sound.play_music(StringName())
	start_scene(0)


func _process(delta: float) -> void:
	if _done or scene_index < 0 or scene_index >= scenes.size():
		return
	_age += delta
	_hint.modulate.a = clampf(HINT_SECONDS - _age, 0.0, 1.0) * 0.75
	if _use_video and _player.is_playing():
		_time = _player.stream_position
	else:
		_time += delta * clock_speed
	_play_sfx()
	update_subtitle(_time)
	var duration: float = scenes[scene_index].get("duration", 10.0)
	if _time >= duration or (_use_video and not _player.is_playing() and _time > 1.0):
		start_scene(scene_index + 1)


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		finish()
	elif event.is_action_pressed("interact") or event.is_action_pressed("attack") \
			or event.is_action_pressed("ui_accept"):
		skip_scene()
	else:
		return
	get_viewport().set_input_as_handled()


## Starts scene `index`; after the last one the prologue ends.
func start_scene(index: int) -> void:
	scene_index = index
	if index >= scenes.size():
		finish()
		return
	_time = 0.0
	_shown = {}
	_played_sfx.clear()
	_panel.hide()
	if _use_video:
		var stream := load(scenes[index].get("video", "")) as VideoStream
		if stream == null:
			_use_video = false
			return
		_player.stream = stream
		_player.play()


func skip_scene() -> void:
	start_scene(scene_index + 1)


func finish() -> void:
	if _done:
		return
	_done = true
	if _player != null:
		_player.stop()
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.BLACK, FADE)
	await tween.finished
	finished.emit()
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)


## Shows the subtitle that belongs to scene time `time` (or hides the panel when there is none).
func update_subtitle(time: float) -> void:
	var current: Dictionary = {}
	for line: Dictionary in scenes[scene_index].get("lines", []):
		if time >= float(line.get("at", 0.0)) and time < float(line.get("until", 0.0)):
			current = line
			break
	if current.is_empty():
		_shown = {}
		_panel.hide()
		return
	if _shown != current:
		_shown = current
		var speaker: String = current.get("speaker", "")
		_speaker.text = speaker
		_speaker.visible = speaker != ""
		_text.text = current.get("text", "")
		_place_panel(str(current.get("place", "bottom")))
		_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if speaker != "" else HORIZONTAL_ALIGNMENT_CENTER
	var at := float(current.get("at", 0.0))
	var until := float(current.get("until", 0.0))
	_text.visible_characters = int((time - at) * TYPE_SPEED)
	_panel.modulate.a = minf(clampf((time - at) / 0.3, 0.0, 1.0), clampf((until - time) / FADE, 0.0, 1.0))
	_panel.show()


## Puts the subtitle where the picture has room: "bottom", "top" or "bottom_right" (so it never covers Nico).
func _place_panel(place: String) -> void:
	var margin := 22.0
	match place:
		"top":
			_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
			_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
			_panel.grow_vertical = Control.GROW_DIRECTION_END
			_panel.offset_top = margin - 6.0
			_text.custom_minimum_size.x = 350
		"bottom_right":
			_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
			_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
			_panel.offset_right = -margin + 6.0
			_panel.offset_bottom = -margin + 6.0
			_text.custom_minimum_size.x = 230
		_:
			_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
			_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
			_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
			_panel.offset_top = -margin
			_panel.offset_bottom = -margin
			_text.custom_minimum_size.x = 350
	_panel.reset_size()


## What the subtitle shows right now (for tests): the whole line, even while it is being typed.
func shown_text() -> String:
	return _text.text if _panel.visible else ""


func _play_sfx() -> void:
	var cues: Array = scenes[scene_index].get("sfx", [])
	for i in cues.size():
		if _time >= float(cues[i].get("at", 0.0)) and not _played_sfx.has(i):
			_played_sfx[i] = true
			Sound.play(StringName(cues[i].get("cue", "")))


func _load_story() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORY_PATH))
	return parsed if parsed is Dictionary else {}


func _build(hint: String) -> void:
	var back := ColorRect.new()
	back.color = Color.BLACK
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	_player = VideoStreamPlayer.new()
	_player.set_anchors_preset(Control.PRESET_FULL_RECT)
	_player.expand = true
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_player)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.panel_box(12.0, 7.0))
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_top = -22
	_panel.offset_bottom = -22
	_panel.hide()
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	_panel.add_child(box)
	_speaker = UiKit.menu_label("", SPEAKER_SIZE, UiKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(_speaker)
	_text = UiKit.menu_label("", TEXT_SIZE, TEXT_COLOR)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(350, 0)
	box.add_child(_text)

	_hint = UiKit.menu_label(hint, UiKit.SMALL_FONT_SIZE, UiKit.LAVENDER, HORIZONTAL_ALIGNMENT_RIGHT)
	_hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hint.offset_left = -300
	_hint.offset_right = -8
	_hint.offset_top = 6
	add_child(_hint)
