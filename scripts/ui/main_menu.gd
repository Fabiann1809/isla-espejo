class_name MainMenu
extends Control
## Title screen: start a new journey, continue the saved one, options, credits and quit.
## Texts come from data/ui/texts.json. Starting or continuing opens the first playable scene.

const GAME_SCENE := "res://scenes/levels/forest_level.tscn"
## A new journey starts with the storm (the prologue), which then opens GAME_SCENE.
const PROLOGUE_SCENE := "res://scenes/ui/prologue.tscn"
const NICO_FRAMES := "res://data/player/nico_frames.tres"
## The night forest behind the menu: a sky from top to horizon, the moon, two rows of trees.
const SKY_TOP := Color(0.03, 0.04, 0.1)
const SKY_HORIZON := Color(0.16, 0.12, 0.28)
const MOON := Color(0.95, 0.92, 0.8)
const GROUND_Y := 196.0
const GROUND := Color(0.04, 0.07, 0.06)
const FAR_TREES := "res://assets/art_forest/boundary/canopy_sil_%d.png"
const NEAR_TREES := ["res://assets/art_forest/boundary/dark_oak_silhouette.png",
		"res://assets/art_forest/boundary/dark_round_silhouette.png",
		"res://assets/art_forest/boundary/dark_mossy_silhouette.png",
		"res://assets/art_forest/boundary/dark_grand_silhouette.png"]
const FIREFLY := Color(1.0, 0.9, 0.45, 0.9)

var start_button: Button
var continue_button: Button
var options_button: Button
var credits_button: Button
var quit_button: Button
var options: OptionsMenu
var credits: CreditsScreen

var _menu: VBoxContainer
var _confirming_start := false
var _subtitle: Label


func _ready() -> void:
	Sound.play_music(&"menu")
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = UiKit.BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_add_scenery()

	var title := UiKit.label(UiText.t("menu_title"), 32, Color(0.85, 0.8, 1.0))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -200
	title.offset_right = 200
	title.offset_top = 12
	add_child(title)
	_subtitle = UiKit.label(UiText.t("menu_subtitle"), 13, UiKit.TEXT_DIM)
	var subtitle := _subtitle
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.offset_left = -200
	subtitle.offset_right = 200
	subtitle.offset_top = 54
	add_child(subtitle)

	_add_nico()

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 3)
	_menu.set_anchors_preset(Control.PRESET_CENTER)
	_menu.offset_left = -30
	_menu.offset_right = 170
	_menu.offset_top = -52
	_menu.offset_bottom = 90
	add_child(_menu)
	start_button = _add_button(UiText.t("menu_start"), _on_start)
	continue_button = _add_button(UiText.t("menu_continue"), _on_continue)
	options_button = _add_button(UiText.t("menu_options"), func() -> void: _open(options))
	credits_button = _add_button(UiText.t("menu_credits"), func() -> void: _open(credits))
	quit_button = _add_button(UiText.t("menu_quit"), get_tree().quit)
	continue_button.disabled = not SaveGame.has_save()

	var controls := UiKit.label(UiText.t("menu_controls"), 10, UiKit.TEXT_DIM)
	controls.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	controls.offset_left = -236
	controls.offset_right = 236
	controls.offset_top = -20
	controls.offset_bottom = -4
	add_child(controls)

	options = OptionsMenu.new()
	credits = CreditsScreen.new()
	for panel: Control in [options, credits]:
		panel.set_anchors_preset(Control.PRESET_CENTER)
		panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		panel.grow_vertical = Control.GROW_DIRECTION_BOTH
		panel.closed.connect(_on_panel_closed)
		add_child(panel)
	_focus_first()


func _add_button(text: String, action: Callable) -> Button:
	var button := UiKit.button(text, 200.0, 24.0)
	button.pressed.connect(action)
	_menu.add_child(button)
	return button


## A night forest drawn with the game's own tree art, still except for the fireflies.
func _add_scenery() -> void:
	var sky := TextureRect.new()
	var gradient := Gradient.new()
	gradient.set_color(0, SKY_TOP)
	gradient.set_color(1, SKY_HORIZON)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	texture.width = 4
	texture.height = int(GROUND_Y)
	sky.texture = texture
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.position = Vector2.ZERO
	sky.size = Vector2(480, GROUND_Y)
	add_child(sky)

	var moon := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 24:
		points.append(Vector2.from_angle(TAU * i / 24.0) * 14.0)
	moon.polygon = points
	moon.color = MOON
	moon.position = Vector2(400, 52)
	add_child(moon)
	for ring in [[1.5, 0.07], [2.1, 0.035]]:
		var glow := Polygon2D.new()
		glow.polygon = points
		glow.scale = Vector2.ONE * ring[0]
		glow.color = Color(MOON, ring[1])
		glow.position = moon.position
		add_child(glow)

	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 40:
		var star := ColorRect.new()
		star.size = Vector2.ONE
		star.color = Color(1, 1, 1, rng.randf_range(0.25, 0.7))
		star.position = Vector2(rng.randi_range(0, 479), rng.randi_range(0, int(GROUND_Y) - 50))
		add_child(star)
	# Far row: small dark crowns, tinted toward the sky so they read as distance.
	for x in range(-10, 490, 22):
		var far := _tree_sprite(FAR_TREES % rng.randi_range(1, 9), Color(0.22, 0.2, 0.38))
		far.position = Vector2(x, GROUND_Y - 22 - rng.randi_range(0, 8))
		add_child(far)
	var ground := ColorRect.new()
	ground.color = GROUND
	ground.position = Vector2(0, GROUND_Y)
	ground.size = Vector2(480, 270 - GROUND_Y)
	add_child(ground)
	# Near row: big trees on both sides, leaving the middle free for the menu.
	for x in [-14, 18, 380, 420, 452]:
		var near := _tree_sprite(NEAR_TREES[rng.randi_range(0, NEAR_TREES.size() - 1)], Color(0.06, 0.08, 0.1))
		near.scale = Vector2(2, 2)
		near.position = Vector2(x, GROUND_Y + 12 - near.texture.get_height() * 2)
		add_child(near)

	var fireflies := CPUParticles2D.new()
	fireflies.texture = RoomDressing.pixel()
	fireflies.amount = 24
	fireflies.lifetime = 5.0
	fireflies.preprocess = 5.0
	fireflies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fireflies.emission_rect_extents = Vector2(240, 50)
	fireflies.position = Vector2(240, GROUND_Y - 30)
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


func _tree_sprite(path: String, tint: Color) -> TextureRect:
	var sprite := TextureRect.new()
	sprite.texture = load(path)
	sprite.modulate = tint
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sprite


## Nico walking next to the menu (the same animation the game uses).
func _add_nico() -> void:
	var frames: SpriteFrames = load(NICO_FRAMES)
	if frames == null:
		return
	var nico := AnimatedSprite2D.new()
	nico.sprite_frames = frames
	nico.scale = Vector2(2, 2)
	nico.position = Vector2(100, GROUND_Y - 22)
	add_child(nico)
	nico.play(&"walk")


func _focus_first() -> void:
	(continue_button if not continue_button.disabled else start_button).grab_focus()


func _open(panel: Control) -> void:
	_menu.hide()
	panel.open()


func _on_panel_closed() -> void:
	_menu.show()
	_cancel_start_confirm()
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
		return
	SaveGame.new_game()
	get_tree().change_scene_to_file(PROLOGUE_SCENE)


func _on_continue() -> void:
	if SaveGame.load_save():
		get_tree().change_scene_to_file(GAME_SCENE)
	else:
		_subtitle.text = UiText.t("save_corrupt")
