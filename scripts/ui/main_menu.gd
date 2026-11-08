class_name MainMenu
extends Control
## Title screen: start a new journey, continue the saved one, options, credits and quit.
## Texts come from data/ui/texts.json. Starting or continuing opens the first playable scene.
##
## The picture is the night forest of assets/ui/menu/ (drawn by tools/make_menu_art.py): Nico draws
## his bow at a bat by the moon. Only a few things move: the bat, an arrow that keeps flying at it,
## the lantern's glow and the fireflies. Every position below is in the game's 480x270 pixels.

const GAME_SCENE := "res://scenes/levels/forest_level.tscn"
## A new journey starts with the storm (the prologue), which then opens GAME_SCENE.
const PROLOGUE_SCENE := "res://scenes/ui/prologue.tscn"
const ART := "res://assets/ui/menu/%s.png"
const BAT_STRIP := "res://assets/sprites/murcielago/murcielago_idle.png"

const BAT_CELL := 64
const BAT_FRAMES := 4
const BAT_POS := Vector2(318, 44)
const NICO_POS := Vector2(58, 142)
## Where the arrow leaves the bow, relative to Nico's picture (the bow hand).
const NICO_GRIP := Vector2(66, 27)
const LANTERN_POS := Vector2(60, 149)
const TITLE_POS := Vector2(80, 28)
const DIVIDER_POS := Vector2(77, 66)
const SUBTITLE_RECT := Rect2(78, 74, 200, 18)
const MENU_POS := Vector2(304, 100)
const BUTTON_SIZE := Vector2(144, 26)
const BUTTON_GAP := 2
const FOOTER_POS := Vector2(70, 247)
const FOOTER_SIZE := Vector2(340, 15)
## The arrow flies for this long, then the bat flinches; the whole loop repeats.
const SHOT_PAUSE := 1.6
const SHOT_SECONDS := 0.75
const SHOT_REST := 0.9
const FIREFLY := Color(1.0, 0.95, 0.5, 0.9)

var start_button: Button
var continue_button: Button
var options_button: Button
var credits_button: Button
var quit_button: Button
var options: OptionsMenu
var credits: CreditsScreen

var _menu: Control
var _footer: Control
var _buttons: VBoxContainer
var _cursor: TextureRect
var _confirming_start := false
var _bat: AnimatedSprite2D
var _bat_halo: Sprite2D
var _shot: Sprite2D
var _glow: Sprite2D
var _time := 0.0
var _subtitle: Label


func _ready() -> void:
	Sound.play_music(&"menu")
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_add_scenery()
	_add_title()
	_add_menu()
	_add_footer()

	options = OptionsMenu.new()
	credits = CreditsScreen.new()
	for panel: Control in [options, credits]:
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		panel.grow_vertical = Control.GROW_DIRECTION_BOTH
		panel.closed.connect(_on_panel_closed)
		add_child(panel)
	_focus_first()


func _process(delta: float) -> void:
	_time += delta
	if _glow != null:
		# A lantern flame never burns steadily: two slow waves and a quick one.
		_glow.modulate.a = 0.82 + 0.1 * sin(_time * 3.1) + 0.05 * sin(_time * 11.3) + 0.03 * sin(_time * 23.0)


func _picture(name: String, at: Vector2, centered := false) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(ART % name)
	sprite.centered = centered
	sprite.position = at
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	return sprite


func _add_scenery() -> void:
	var back := _picture("background", Vector2.ZERO)
	back.name = "Backdrop"
	_add_fireflies()
	_glow = _picture("lantern_glow", Vector2.ZERO)
	_bat_halo = _picture("bat_halo", BAT_POS + Vector2(BAT_CELL, BAT_CELL) / 2.0 + Vector2(0, 2), true)
	_add_bat()
	_picture("nico", NICO_POS).name = "Nico"
	_add_shot()


func _add_bat() -> void:
	var strip: Texture2D = load(BAT_STRIP)
	var frames := SpriteFrames.new()
	frames.add_animation(&"fly")
	frames.set_animation_speed(&"fly", 8.0)
	frames.set_animation_loop(&"fly", true)
	for i in BAT_FRAMES:
		var atlas := AtlasTexture.new()
		atlas.atlas = strip
		atlas.region = Rect2(i * BAT_CELL, 0, BAT_CELL, BAT_CELL)
		frames.add_frame(&"fly", atlas)
	_bat = AnimatedSprite2D.new()
	_bat.sprite_frames = frames
	_bat.centered = false
	_bat.position = BAT_POS
	_bat.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_bat)
	_bat.play(&"fly")
	var bob := create_tween().set_loops()
	bob.tween_property(_bat, "offset:y", -2.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	bob.tween_property(_bat, "offset:y", 2.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## The arrow loops: leaves the bow, reaches the bat (which flinches), and a new one flies.
func _add_shot() -> void:
	_shot = _picture("shot", Vector2.ZERO, true)
	_shot.hide()
	var from := NICO_POS + NICO_GRIP + Vector2(10, -6)
	var target := _bat_center()
	var direction := (target - from).normalized()
	_shot.rotation = direction.angle()
	var loop := create_tween().set_loops()
	loop.tween_interval(SHOT_PAUSE)
	loop.tween_callback(func() -> void:
		_shot.position = from
		_shot.modulate.a = 1.0
		_shot.show())
	loop.tween_property(_shot, "position", target - direction * 16.0, SHOT_SECONDS)
	loop.tween_callback(_on_arrow_hit)
	loop.tween_property(_shot, "modulate:a", 0.0, 0.15)
	loop.tween_callback(_shot.hide)
	loop.tween_interval(SHOT_REST)


func _bat_center() -> Vector2:
	return BAT_POS + Vector2(BAT_CELL, BAT_CELL) / 2.0 + Vector2(0, 2)


func _on_arrow_hit() -> void:
	var flash := create_tween()
	flash.tween_property(_bat, "modulate", Color(2.2, 1.5, 1.5), 0.05)
	flash.tween_property(_bat, "modulate", Color.WHITE, 0.25)
	var hop := create_tween()
	hop.tween_property(_bat, "position", BAT_POS + Vector2(4, -3), 0.08)
	hop.tween_property(_bat, "position", BAT_POS, 0.3).set_trans(Tween.TRANS_SINE)


func _add_fireflies() -> void:
	var fireflies := CPUParticles2D.new()
	fireflies.texture = RoomDressing.pixel()
	fireflies.amount = 12
	fireflies.lifetime = 5.0
	fireflies.preprocess = 5.0
	fireflies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fireflies.emission_rect_extents = Vector2(120, 45)
	fireflies.position = Vector2(240, 195)
	fireflies.gravity = Vector2(0, -3)
	fireflies.direction = Vector2.RIGHT
	fireflies.spread = 180.0
	fireflies.initial_velocity_min = 2.0
	fireflies.initial_velocity_max = 8.0
	fireflies.scale_amount_min = 1.0
	fireflies.scale_amount_max = 2.0
	fireflies.color = FIREFLY
	var blink := Gradient.new()
	blink.set_color(0, Color(1, 1, 1, 0))
	blink.add_point(0.3, Color.WHITE)
	blink.add_point(0.7, Color(1, 1, 1, 0.3))
	blink.set_color(blink.get_point_count() - 1, Color(1, 1, 1, 0))
	fireflies.color_ramp = blink
	add_child(fireflies)


func _add_title() -> void:
	_picture("title", TITLE_POS).name = "Title"
	_picture("divider", DIVIDER_POS).name = "Divider"
	var subtitle := UiKit.menu_label(UiText.t("menu_subtitle"), 16, Color(0.82, 0.78, 0.96))
	add_child(subtitle)
	# Kept to report a damaged save in its place (see _on_continue).
	_subtitle = subtitle
	_place(subtitle, SUBTITLE_RECT)


func _add_menu() -> void:
	_menu = Control.new()
	_menu.position = MENU_POS
	add_child(_menu)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", BUTTON_GAP)
	_menu.add_child(_buttons)
	start_button = _add_button(UiText.t("menu_start"), _on_start)
	continue_button = _add_button(UiText.t("menu_continue"), _on_continue)
	options_button = _add_button(UiText.t("menu_options"), func() -> void: _open(options))
	credits_button = _add_button(UiText.t("menu_credits"), func() -> void: _open(credits))
	quit_button = _add_button(UiText.t("menu_quit"), get_tree().quit)
	continue_button.disabled = not SaveGame.has_save()
	# The gold arrow marks the selected button (keyboard focus or mouse hover).
	_cursor = TextureRect.new()
	_cursor.texture = load(ART % "arrow")
	_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_menu.add_child(_cursor)


func _add_button(text: String, action: Callable) -> Button:
	var button := UiKit.button(text, BUTTON_SIZE.x, BUTTON_SIZE.y)
	button.pressed.connect(action)
	button.focus_entered.connect(_move_cursor.bind(button))
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			button.grab_focus())
	_buttons.add_child(button)
	return button


func _move_cursor(button: Button) -> void:
	_cursor.show()
	# Buttons are laid out on the next frame; their slot is already known from the index.
	_cursor.position = Vector2(4, button.get_index() * (BUTTON_SIZE.y + BUTTON_GAP) + (BUTTON_SIZE.y - 9) / 2.0)


func _add_footer() -> void:
	_footer = Control.new()
	add_child(_footer)
	var bar := _picture("footer", FOOTER_POS)
	bar.name = "ControlsBar"
	bar.reparent(_footer)
	var controls := UiKit.menu_label(UiText.t("menu_controls"), UiKit.SMALL_FONT_SIZE, Color(0.72, 0.69, 0.91))
	_footer.add_child(controls)
	_place(controls, Rect2(FOOTER_POS + Vector2(0, 1), FOOTER_SIZE))


## Puts a control in `rect` (set after it joins the tree, or its minimum size wins).
func _place(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.position = rect.position
	control.size = rect.size
	if control is Label:
		(control as Label).clip_text = true


func _focus_first() -> void:
	(continue_button if not continue_button.disabled else start_button).grab_focus()


func _open(panel: Control) -> void:
	_menu.hide()
	_footer.hide()
	panel.open()


func _on_panel_closed() -> void:
	_menu.show()
	_cancel_start_confirm()
	_footer.show()
	_focus_first()


## Back from a panel, the "borrar el progreso" question is forgotten: one press must never erase.
func _cancel_start_confirm() -> void:
	if _confirming_start:
		_confirming_start = false
		start_button.text = UiText.t("menu_start")


## With a save, the first press only asks for confirmation: starting over deletes the progress.
func _on_start() -> void:
	if SaveGame.has_save() and not _confirming_start:
		_confirming_start = true
		start_button.text = UiText.t("menu_start_confirm")
		# Too long for the big font: two lines of fine print.
		start_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		start_button.add_theme_font_size_override("font_size", UiKit.SMALL_FONT_SIZE)
		return
	SaveGame.new_game()
	get_tree().change_scene_to_file(PROLOGUE_SCENE)


func _on_continue() -> void:
	if SaveGame.load_save():
		get_tree().change_scene_to_file(GAME_SCENE)
	else:
		_subtitle.text = UiText.t("save_corrupt")
