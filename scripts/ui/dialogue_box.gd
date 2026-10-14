extends CanvasLayer
## The dialogue panel at the bottom of the screen: speaker, text typed out letter by letter and a hint.
## Driven by the Dialogue autoload; it only displays. Placeholder art.

const CHARACTERS_PER_SECOND := 55.0

var _tween: Tween

@onready var _panel: PanelContainer = $Panel
@onready var _speaker: Label = $Panel/Margin/Content/Speaker
@onready var _text: Label = $Panel/Margin/Content/Text
@onready var _hint: Label = $Panel/Margin/Content/Hint


func _ready() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.05, 0.09, 0.95)
	background.border_color = Color(0.6, 0.5, 0.85)
	background.set_border_width_all(2)
	background.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", background)


func show_line(speaker: String, text: String, is_last: bool) -> void:
	_speaker.text = speaker
	_text.text = text
	_text.visible_ratio = 0.0
	_hint.text = "[E]  " + ("▪" if is_last else "▼")
	_panel.show()
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_text, "visible_ratio", 1.0, maxf(text.length() / CHARACTERS_PER_SECOND, 0.05))


func is_typing() -> bool:
	return _panel.visible and _text.visible_ratio < 1.0


## Shows the whole line at once.
func complete_line() -> void:
	if _tween != null:
		_tween.kill()
	_text.visible_ratio = 1.0


func hide_box() -> void:
	if _tween != null:
		_tween.kill()
	_panel.hide()
