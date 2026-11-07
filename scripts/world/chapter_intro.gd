class_name ChapterIntro
extends CanvasLayer
## Presents an island when its chapter starts. The screen opens from black on the room where Nico appears,
## seen from farther away (the camera zoomed out and centered on that room, so its neighbours peek in) while
## the island's name rises over it; then the camera glides in to Nico, the title leaves and the controls come
## back. Any action key skips it.
## Values (zoom, seconds, text sizes) are in `Tuning`; the texts are the scenario's `display_name` and
## `chapter_title`. `Level` creates it (see its `chapter_intro` option) and it frees itself when done.

signal finished

var title_label: Label
var subtitle_label: Label

var _level: Level
var _player: Node2D
var _camera: Camera2D
var _hud: CanvasLayer
var _title: Control
var _tween: Tween
var _saved := {}
var _done := false


func start(level: Level) -> void:
	_level = level
	layer = 2
	_build(level.scenario)
	_player = level.player
	_camera = _player.get_node_or_null("Camera2D") if _player != null else null
	if _camera == null:
		_finish()
		return
	_saved = {
		"zoom": _camera.zoom,
		"position": _camera.position,
		"smoothing": _camera.position_smoothing_enabled,
	}
	_player.set_controls_locked(true)
	_hud = level.get_node_or_null("Hud") as CanvasLayer
	if _hud != null:
		_hud.hide()
	# The first shot is centered on the start room; the map's camera limits stay, so it never looks past the map.
	_camera.position_smoothing_enabled = false
	_camera.zoom = Vector2.ONE * Tuning.INTRO_ZOOM
	_camera.position = _start_room_center(level) - _player.global_position
	level.reveal(Tuning.INTRO_FADE)
	_run()


## Center of the room where the player starts (the map's center if the room cannot be found).
func _start_room_center(level: Level) -> Vector2:
	var room: Room = level.room_at(level.layout.start_cell) if level.layout != null else null
	if room == null:
		return level.bounds.get_center()
	return room.global_position + Level.CELL_SIZE / 2.0


func _run() -> void:
	var fly_at := Tuning.INTRO_HOLD
	var title_out := Tuning.INTRO_TITLE_IN + Tuning.INTRO_TITLE_SECONDS
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_title, "modulate:a", 1.0, 0.9).set_delay(Tuning.INTRO_TITLE_IN)
	_tween.tween_property(_title, "modulate:a", 0.0, 0.8).set_delay(title_out)
	_tween.tween_property(_camera, "position", Vector2.ZERO, Tuning.INTRO_FLY) \
			.set_delay(fly_at).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_camera, "zoom", Vector2.ONE, Tuning.INTRO_FLY) \
			.set_delay(fly_at).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(_finish).set_delay(fly_at + Tuning.INTRO_FLY)


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	for action in ["attack", "interact", "dash", "ui_accept"]:
		if event.is_action_pressed(action):
			_finish()
			get_viewport().set_input_as_handled()
			return


## Ends the intro at once (also what the end of the glide calls): the camera and the controls are given back.
func _finish() -> void:
	if _done:
		return
	_done = true
	if _tween != null:
		_tween.kill()
	if _camera != null and not _saved.is_empty():
		_camera.zoom = _saved["zoom"]
		_camera.position = _saved["position"]
		_camera.position_smoothing_enabled = _saved["smoothing"]
		_camera.reset_smoothing()
	if _level != null:
		_level.reveal(0.0)
	if _player != null:
		_player.set_controls_locked(false)
	if _hud != null:
		_hud.show()
	finished.emit()
	queue_free()


## The title block: a soft dark band, the island's name, an ornamental line and the chapter's phrase.
func _build(scenario: ScenarioData) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.modulate.a = 0.0
	add_child(root)
	_title = root
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0, 0, 0, 0))
	gradient.add_point(0.5, Color(0.02, 0.02, 0.08, 0.55))
	gradient.set_color(gradient.get_point_count() - 1, Color(0, 0, 0, 0))
	var band_texture := GradientTexture2D.new()
	band_texture.gradient = gradient
	band_texture.fill_from = Vector2(0, 0)
	band_texture.fill_to = Vector2(0, 1)
	band_texture.width = 4
	band_texture.height = 64
	var band := TextureRect.new()
	band.texture = band_texture
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.set_anchors_preset(Control.PRESET_CENTER)
	band.offset_left = -240
	band.offset_right = 240
	band.offset_top = -92
	band.offset_bottom = 28
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(band)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.offset_top = -78
	box.offset_bottom = 14
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)
	title_label = UiKit.menu_label(scenario.display_name, Tuning.INTRO_TITLE_SIZE, UiKit.GOLD)
	title_label.custom_minimum_size = Vector2(440, 0)
	box.add_child(title_label)
	box.add_child(UiKit.divider())
	subtitle_label = UiKit.menu_label(scenario.chapter_title, Tuning.INTRO_SUBTITLE_SIZE, Color(0.86, 0.82, 0.98))
	box.add_child(subtitle_label)
