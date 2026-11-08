extends CanvasLayer
## The dialogue panel at the bottom of the screen: a name tag on its upper edge, the text typed out letter by
## letter and an arrow that blinks when the line is complete. Each speaker has its own colors, read from
## `data/ui/dialogue_speakers.json` (an unknown speaker uses "default"). Driven by the Dialogue autoload; it only
## displays.

const CHARACTERS_PER_SECOND := 55.0
const SPEAKERS_FILE := "res://data/ui/dialogue_speakers.json"
## Seconds the panel takes to fade in when a conversation opens, and one blink of the arrow.
const FADE_SECONDS := 0.12
const ARROW_BLINK_SECONDS := 0.45

static var _speakers := {}

var _tween: Tween
var _blink: Tween
var _is_last := false

@onready var _panel: PanelContainer = $Panel
@onready var _text: Label = $Panel/Margin/Text
@onready var _tag: PanelContainer = $Tag
@onready var _name: Label = $Tag/Name
@onready var _arrow: Label = $Arrow


func _ready() -> void:
	var font := UiKit.pixel_font()
	if font != null:
		# Not the arrow: the pixel font has no ▼ / ■, the theme's font does.
		for label: Label in [_text, _name]:
			label.add_theme_font_override("font", font)


## The colors of a speaker: fill, border, text, tag and tag_text (as Color), falling back to "default".
static func style_of(speaker: String) -> Dictionary:
	if _speakers.is_empty() and FileAccess.file_exists(SPEAKERS_FILE):
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(SPEAKERS_FILE)) == OK and json.data is Dictionary:
			_speakers = json.data
	var raw: Dictionary = _speakers.get(speaker, _speakers.get("default", {}))
	var fallback: Dictionary = _speakers.get("default", {})
	var colors := {}
	for key in ["fill", "border", "text", "tag", "tag_text"]:
		colors[key] = Color.html(str(raw.get(key, fallback.get(key, "#ffffff"))))
	return colors


func show_line(speaker: String, text: String, is_last: bool) -> void:
	_is_last = is_last
	_apply_style(style_of(speaker))
	_name.text = speaker
	_tag.visible = speaker != ""
	_text.text = text
	_text.visible_ratio = 0.0
	_stop_blink()
	_arrow.visible = false
	if not _panel.visible:
		_fade_in()
	_panel.show()
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_text, "visible_ratio", 1.0, maxf(text.length() / CHARACTERS_PER_SECOND, 0.05))
	_tween.finished.connect(_line_done)


func is_typing() -> bool:
	return _panel.visible and _text.visible_ratio < 1.0


## Shows the whole line at once.
func complete_line() -> void:
	if _tween != null:
		_tween.kill()
	_text.visible_ratio = 1.0
	_line_done()


func hide_box() -> void:
	if _tween != null:
		_tween.kill()
	_stop_blink()
	_panel.hide()
	_tag.hide()
	_arrow.hide()


func _apply_style(colors: Dictionary) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = colors.fill
	box.border_color = colors.border
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.anti_aliasing = false
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 2
	_panel.add_theme_stylebox_override("panel", box)
	_text.add_theme_color_override("font_color", colors.text)
	var tag := StyleBoxFlat.new()
	tag.bg_color = colors.tag
	tag.set_corner_radius_all(3)
	tag.anti_aliasing = false
	tag.content_margin_left = 6.0
	tag.content_margin_right = 6.0
	tag.content_margin_top = 0.0
	tag.content_margin_bottom = 1.0
	_tag.add_theme_stylebox_override("panel", tag)
	_name.add_theme_color_override("font_color", colors.tag_text)
	_arrow.add_theme_color_override("font_color", colors.text)


## Called when the whole line is on screen: the arrow appears and blinks.
func _line_done() -> void:
	if not _panel.visible:
		return
	_arrow.text = "E  " + ("■" if _is_last else "▼")
	_arrow.visible = true
	_stop_blink()
	_blink = create_tween().set_loops()
	_blink.tween_property(_arrow, "modulate:a", 0.25, ARROW_BLINK_SECONDS)
	_blink.tween_property(_arrow, "modulate:a", 1.0, ARROW_BLINK_SECONDS)


func _stop_blink() -> void:
	if _blink != null:
		_blink.kill()
	_arrow.modulate.a = 1.0


func _fade_in() -> void:
	for node: CanvasItem in [_panel, _tag]:
		node.modulate.a = 0.0
		create_tween().tween_property(node, "modulate:a", 1.0, FADE_SECONDS)
