class_name MainMenu
extends Control
## Title screen: start a new journey, continue the saved one, options, credits and quit.
## Texts come from data/ui/texts.json. Starting or continuing opens the first playable scene.

const GAME_SCENE := "res://scenes/levels/forest_level.tscn"
const NICO_FRAMES := "res://data/player/nico_frames.tres"

var start_button: Button
var continue_button: Button
var options_button: Button
var credits_button: Button
var quit_button: Button
var options: OptionsMenu
var credits: CreditsScreen

var _menu: VBoxContainer
var _confirming_start := false


func _ready() -> void:
	theme = UiKit.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = UiKit.BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var title := UiKit.label(UiText.t("menu_title"), 40, Color(0.85, 0.8, 1.0))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -200
	title.offset_right = 200
	title.offset_top = 22
	add_child(title)
	var subtitle := UiKit.label(UiText.t("menu_subtitle"), 13, UiKit.TEXT_DIM)
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.offset_left = -200
	subtitle.offset_right = 200
	subtitle.offset_top = 72
	add_child(subtitle)

	_add_nico()

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 6)
	_menu.set_anchors_preset(Control.PRESET_CENTER)
	_menu.offset_left = -50
	_menu.offset_right = 150
	_menu.offset_top = -52
	_menu.offset_bottom = 120
	add_child(_menu)
	start_button = _add_button(UiText.t("menu_start"), _on_start)
	continue_button = _add_button(UiText.t("menu_continue"), _on_continue)
	options_button = _add_button(UiText.t("menu_options"), func() -> void: _open(options))
	credits_button = _add_button(UiText.t("menu_credits"), func() -> void: _open(credits))
	quit_button = _add_button(UiText.t("menu_quit"), get_tree().quit)
	continue_button.disabled = not SaveGame.has_save()

	var controls := UiKit.label(UiText.t("menu_controls"), 10, UiKit.TEXT_DIM)
	controls.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	controls.offset_left = -310
	controls.offset_right = 310
	controls.offset_top = -22
	controls.offset_bottom = -6
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
	var button := UiKit.button(text)
	button.pressed.connect(action)
	_menu.add_child(button)
	return button


## Nico walking next to the menu (the same animation the game uses).
func _add_nico() -> void:
	var frames: SpriteFrames = load(NICO_FRAMES)
	if frames == null:
		return
	var nico := AnimatedSprite2D.new()
	nico.sprite_frames = frames
	nico.scale = Vector2(2.5, 2.5)
	nico.position = Vector2(150, 230)
	add_child(nico)
	nico.play(&"walk")


func _focus_first() -> void:
	(continue_button if not continue_button.disabled else start_button).grab_focus()


func _open(panel: Control) -> void:
	_menu.hide()
	panel.open()


func _on_panel_closed() -> void:
	_menu.show()
	_focus_first()


## With a save, the first press only asks for confirmation: starting over deletes the progress.
func _on_start() -> void:
	if SaveGame.has_save() and not _confirming_start:
		_confirming_start = true
		start_button.text = UiText.t("menu_start_confirm")
		return
	SaveGame.new_game()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_continue() -> void:
	if SaveGame.load_save():
		get_tree().change_scene_to_file(GAME_SCENE)
