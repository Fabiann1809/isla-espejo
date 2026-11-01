class_name Prologue
extends Control
## The storm before the first island: a few lines over a dark sea with rain and lightning, read from
## data/story/prologue.json. Each line fades in; E/J (or waiting) shows the next, Esc skips it all.
## Shown once, when a new journey starts from the main menu; then the first island opens.

signal finished

const STORY_PATH := "res://data/story/prologue.json"
## Seconds a line stays before the next one comes by itself.
const LINE_TIME := 4.5
const FADE := 0.6
const SKY := Color(0.03, 0.04, 0.08)
const RAIN := Color(0.6, 0.7, 0.9, 0.45)
const SEA := Color(0.05, 0.07, 0.13)
const SPEAKER_COLOR := Color(0.75, 0.68, 1.0)

## Scene opened at the end (empty in tests: only `finished` is emitted).
@export_file("*.tscn") var next_scene := "res://scenes/levels/forest_level.tscn"

var lines: Array = []
var index := -1

var _text: Label
var _speaker: Label
var _flash: ColorRect
var _line_left := 0.0
var _done := false


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var story := _load_story()
	lines = story.get("lines", [])
	_build(story.get("hint", ""))
	Sound.play_music(StringName())
	next_line()


func _process(delta: float) -> void:
	if _done:
		return
	_line_left -= delta
	if _line_left <= 0.0:
		next_line()


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		finish()
	elif event.is_action_pressed("interact") or event.is_action_pressed("attack") \
			or event.is_action_pressed("ui_accept"):
		next_line()
	else:
		return
	get_viewport().set_input_as_handled()


## Shows the next line, or ends the prologue after the last one.
func next_line() -> void:
	index += 1
	if index >= lines.size():
		finish()
		return
	var line: Dictionary = lines[index]
	_speaker.text = line.get("speaker", "")
	_text.text = line.get("text", "")
	_text.modulate.a = 0.0
	_speaker.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_text, "modulate:a", 1.0, FADE)
	tween.tween_property(_speaker, "modulate:a", 1.0, FADE)
	_line_left = LINE_TIME
	if line.get("storm", false):
		_lightning()


func finish() -> void:
	if _done:
		return
	_done = true
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.BLACK, FADE)
	await tween.finished
	finished.emit()
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)


func _lightning() -> void:
	Sound.play(&"thunder")
	_flash.color.a = 0.55
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.5).set_delay(0.06)


func _load_story() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STORY_PATH))
	return parsed if parsed is Dictionary else {}


func _build(hint: String) -> void:
	var sky := ColorRect.new()
	sky.color = SKY
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sky)
	var sea := Polygon2D.new()
	sea.color = SEA
	var points := PackedVector2Array([Vector2(0, 270)])
	for x in range(0, 500, 20):
		points.append(Vector2(x, 222 + sin(x * 0.05) * 4.0))
	points.append(Vector2(480, 270))
	sea.polygon = points
	add_child(sea)
	var rain := CPUParticles2D.new()
	rain.texture = _rain_drop()
	rain.amount = 160
	rain.lifetime = 0.7
	rain.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	rain.emission_rect_extents = Vector2(300, 4)
	rain.position = Vector2(260, -10)
	rain.direction = Vector2(-0.25, 1)
	# The streaks lean with the wind (the texture is vertical).
	rain.angle_min = 14.0
	rain.angle_max = 14.0
	rain.spread = 2.0
	rain.gravity = Vector2.ZERO
	rain.initial_velocity_min = 380.0
	rain.initial_velocity_max = 460.0
	rain.scale_amount_min = 1.0
	rain.scale_amount_max = 1.0
	rain.color = RAIN
	rain.preprocess = 1.0
	add_child(rain)
	_flash = ColorRect.new()
	_flash.color = Color(0.85, 0.9, 1.0, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	_speaker = UiKit.label("", 12, SPEAKER_COLOR)
	box.add_child(_speaker)
	_text = UiKit.label("", 16)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(400, 0)
	_text.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_text)
	var hint_label := UiKit.label(hint, 10, UiKit.TEXT_DIM)
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.offset_left = -200
	hint_label.offset_right = 200
	hint_label.offset_top = -22
	hint_label.offset_bottom = -6
	add_child(hint_label)


## A thin vertical streak, brighter at its foot: one drop of rain.
func _rain_drop() -> Texture2D:
	var image := Image.create(1, 7, false, Image.FORMAT_RGBA8)
	for y in 7:
		image.set_pixel(0, y, Color(1, 1, 1, (y + 1) / 7.0))
	return ImageTexture.create_from_image(image)
