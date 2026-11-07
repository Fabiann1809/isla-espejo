class_name UiKit
extends RefCounted
## Small helpers so every menu looks the same: one Theme for buttons, panels, sliders and switches
## (framed with the pixel art in assets/ui/menu/, drawn by tools/make_menu_art.py) and shortcuts to
## create labels and buttons.

const BACKGROUND := Color(0.05, 0.06, 0.1)
const PANEL := Color(0.07, 0.08, 0.13, 0.96)
const ACCENT := Color(0.55, 0.45, 0.85)
const TEXT := Color(0.92, 0.92, 0.96)
const TEXT_DIM := Color(0.6, 0.62, 0.72)

## Pixel font for small in-world texts (damage numbers); without the file the default font is used.
const PIXEL_FONT := "res://assets/fonts/kenney_pixel.ttf"
## Font of every menu text (Pixelify Sans, OFL): Kenney's pixel font draws "ó" as a capital.
const MENU_FONT := "res://assets/fonts/pixelify_sans.ttf"
const MENU_ART := "res://assets/ui/menu/%s.png"
const GOLD := Color(1.0, 0.94, 0.76)
const LAVENDER := Color(0.8, 0.77, 0.93)
## Size of menu buttons and labels, and of the fine print (controls bar, confirmations).
const FONT_SIZE := 13
const SMALL_FONT_SIZE := 10

static var _theme: Theme
static var _pixel_font: Font
static var _menu_font: Font


static func theme() -> Theme:
	if _theme == null:
		_theme = Theme.new()
		_theme.set_default_font_size(14)
		var font := menu_font()
		for kind in ["Button", "CheckButton"]:
			if font != null:
				_theme.set_font("font", kind, font)
			_theme.set_font_size("font_size", kind, FONT_SIZE)
			_theme.set_color("font_color", kind, LAVENDER)
			_theme.set_color("font_hover_color", kind, GOLD)
			_theme.set_color("font_focus_color", kind, GOLD)
			_theme.set_color("font_pressed_color", kind, GOLD)
			_theme.set_color("font_hover_pressed_color", kind, GOLD)
			_theme.set_color("font_disabled_color", kind, Color(0.4, 0.4, 0.55))
			_theme.set_color("font_outline_color", kind, Color(0.04, 0.03, 0.12))
			_theme.set_constant("outline_size", kind, 0)
		var normal := _frame("button_normal", 6)
		var selected := _frame("button_selected", 6)
		var pressed := _frame("button_selected", 6, Color(0.8, 0.8, 0.85))
		var disabled := _frame("button_normal", 6, Color(0.55, 0.55, 0.65, 0.8))
		_theme.set_stylebox("normal", "Button", normal)
		_theme.set_stylebox("hover", "Button", selected)
		_theme.set_stylebox("focus", "Button", selected)
		_theme.set_stylebox("pressed", "Button", pressed)
		_theme.set_stylebox("disabled", "Button", disabled)
		# A switch: the row lights up like a button when it has the focus.
		_theme.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
		_theme.set_stylebox("hover", "CheckButton", selected)
		_theme.set_stylebox("focus", "CheckButton", selected)
		_theme.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
		_theme.set_stylebox("hover_pressed", "CheckButton", selected)
		_theme.set_stylebox("disabled", "CheckButton", StyleBoxEmpty.new())
		_theme.set_icon("checked", "CheckButton", load(MENU_ART % "toggle_on"))
		_theme.set_icon("unchecked", "CheckButton", load(MENU_ART % "toggle_off"))
		_theme.set_icon("checked_disabled", "CheckButton", load(MENU_ART % "toggle_on"))
		_theme.set_icon("unchecked_disabled", "CheckButton", load(MENU_ART % "toggle_off"))
		_theme.set_constant("h_separation", "CheckButton", 10)
		_theme.set_stylebox("panel", "PanelContainer", _frame("panel", 8, Color.WHITE, 14.0, 12.0))
		_theme.set_color("font_color", "Label", TEXT)
		_theme.set_stylebox("slider", "HSlider", _bar(Color(0.04, 0.03, 0.12), Color(0.23, 0.2, 0.44)))
		_theme.set_stylebox("grabber_area", "HSlider", _bar(Color(0.66, 0.54, 0.3), Color(0.04, 0.03, 0.12)))
		_theme.set_stylebox("grabber_area_highlight", "HSlider", _bar(Color(0.96, 0.85, 0.54), Color(0.04, 0.03, 0.12)))
		_theme.set_icon("grabber", "HSlider", load(MENU_ART % "grabber"))
		_theme.set_icon("grabber_highlight", "HSlider", load(MENU_ART % "grabber_hover"))
		_theme.set_icon("grabber_disabled", "HSlider", load(MENU_ART % "grabber"))
	return _theme


## A 9-slice frame from assets/ui/menu/<name>.png.
static func _frame(art: String, margin: int, tint := Color.WHITE, pad_x := 8.0, pad_y := 4.0) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = load(MENU_ART % art)
	box.set_texture_margin_all(margin)
	box.modulate_color = tint
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	return box


## A thin square bar (slider track and fill).
static func _bar(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	return box


static func button(text: String, min_width := 200.0, min_height := 26.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, min_height)
	# Interface sounds (the Sound autoload; missing in tools that run without it).
	b.focus_entered.connect(func() -> void: _ui_sound(&"ui_hover"))
	b.pressed.connect(func() -> void: _ui_sound(&"ui_click"))
	return b


static func _ui_sound(cue: StringName) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var sound := tree.root.get_node_or_null("Sound") if tree != null else null
	if sound != null:
		sound.play(cue)


static func label(text: String, size := 14, color := TEXT, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func pixel_font() -> Font:
	if _pixel_font == null and ResourceLoader.exists(PIXEL_FONT):
		_pixel_font = load(PIXEL_FONT)
	return _pixel_font


static func menu_font() -> Font:
	if _menu_font == null and ResourceLoader.exists(MENU_FONT):
		# "fi" and friends would turn into ligatures that break the pixel grid.
		var variation := FontVariation.new()
		variation.base_font = load(MENU_FONT)
		variation.opentype_features = {"liga": 0, "clig": 0, "calt": 0}
		_menu_font = variation
	return _menu_font


## A label in the menu font, so every menu text matches the buttons.
static func menu_label(text: String, size := FONT_SIZE, color := LAVENDER, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := label(text, size, color, align)
	var font := menu_font()
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_color_override("font_shadow_color", Color(0.04, 0.03, 0.12, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


## The ornamental line (a diamond between two rules) used under menu titles.
static func divider() -> TextureRect:
	var line := TextureRect.new()
	line.texture = load(MENU_ART % "divider")
	line.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.custom_minimum_size = Vector2(0, 11)
	return line
