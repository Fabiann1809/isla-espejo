class_name UiKit
extends RefCounted
## Small helpers so every menu looks the same: one Theme for buttons, panels and sliders (built in
## code, no art needed) and shortcuts to create labels and buttons.

const BACKGROUND := Color(0.05, 0.06, 0.1)
const PANEL := Color(0.07, 0.08, 0.13, 0.96)
const ACCENT := Color(0.55, 0.45, 0.85)
const TEXT := Color(0.92, 0.92, 0.96)
const TEXT_DIM := Color(0.6, 0.62, 0.72)

static var _theme: Theme


static func theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.set_default_font_size(14)
		_theme.set_stylebox("normal", "Button", _box(Color(0.12, 0.13, 0.2), Color(0.25, 0.26, 0.38)))
		_theme.set_stylebox("hover", "Button", _box(Color(0.18, 0.17, 0.3), ACCENT))
		_theme.set_stylebox("focus", "Button", _box(Color(0.18, 0.17, 0.3), ACCENT))
		_theme.set_stylebox("pressed", "Button", _box(Color(0.25, 0.2, 0.4), ACCENT))
		_theme.set_stylebox("disabled", "Button", _box(Color(0.09, 0.09, 0.13), Color(0.16, 0.16, 0.22)))
		_theme.set_color("font_color", "Button", TEXT)
		_theme.set_color("font_hover_color", "Button", Color.WHITE)
		_theme.set_color("font_focus_color", "Button", Color.WHITE)
		_theme.set_color("font_disabled_color", "Button", Color(0.4, 0.4, 0.5))
		_theme.set_stylebox("panel", "PanelContainer", _box(PANEL, ACCENT, 2))
		_theme.set_color("font_color", "Label", TEXT)
	return _theme


static func _box(fill: Color, border: Color, border_width := 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(3)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	return box


static func button(text: String, min_width := 200.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 28)
	return b


static func label(text: String, size := 14, color := TEXT, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
