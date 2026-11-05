class_name OptionsMenu
extends PanelContainer
## Volume and full screen. Shared by the main menu and the pause menu; it only talks to the
## `Settings` autoload and tells its owner when the player goes back.

signal closed

var volume_slider: HSlider
var music_slider: HSlider
var sfx_slider: HSlider
var fullscreen_check: CheckButton
var controller_button: Button
var back_button: Button
var controller_panel: ControllerPanel


func _ready() -> void:
	theme = UiKit.theme()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(UiKit.label(UiText.t("options_title"), 18))

	volume_slider = _slider_row(box, UiText.t("options_volume"))
	music_slider = _slider_row(box, UiText.t("options_music"))
	sfx_slider = _slider_row(box, UiText.t("options_sfx"))

	fullscreen_check = CheckButton.new()
	fullscreen_check.text = UiText.t("options_fullscreen")
	box.add_child(fullscreen_check)

	controller_button = UiKit.button(UiText.t("options_controller"))
	box.add_child(controller_button)

	back_button = UiKit.button(UiText.t("options_back"))
	box.add_child(back_button)

	refresh()
	volume_slider.value_changed.connect(Settings.set_volume)
	music_slider.value_changed.connect(Settings.set_music_volume)
	sfx_slider.value_changed.connect(Settings.set_sfx_volume)
	fullscreen_check.toggled.connect(Settings.set_fullscreen)
	controller_button.pressed.connect(_open_controller)
	back_button.pressed.connect(close)
	hide()


func open() -> void:
	refresh()
	show()
	back_button.grab_focus()


func close() -> void:
	hide()
	closed.emit()


## Esc (ui_cancel) leaves the panel like its "Volver" button, in a menu and in the game alike.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## Hides the options and shows the phone controller panel next to them (a sibling, because a
## hidden parent would hide it too).
func _open_controller() -> void:
	if controller_panel == null:
		controller_panel = ControllerPanel.new()
		controller_panel.set_anchors_preset(Control.PRESET_CENTER)
		controller_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		controller_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
		controller_panel.closed.connect(func() -> void:
			show()
			controller_button.grab_focus())
		get_parent().add_child(controller_panel)
	hide()
	controller_panel.open()


## True while the phone controller panel is on screen (the options are hidden then).
func is_controller_open() -> bool:
	return controller_panel != null and controller_panel.visible


## Hides the controller panel if open. The phone controller (autoload `RemoteControl`) keeps
## running; only the panel's "Desconectar" button stops it.
func close_all() -> void:
	if is_controller_open():
		controller_panel.close()


func _exit_tree() -> void:
	if controller_panel != null and is_instance_valid(controller_panel):
		controller_panel.queue_free()


## Shows the current values without triggering a change.
func refresh() -> void:
	volume_slider.set_value_no_signal(Settings.volume)
	music_slider.set_value_no_signal(Settings.music_volume)
	sfx_slider.set_value_no_signal(Settings.sfx_volume)
	fullscreen_check.set_pressed_no_signal(Settings.fullscreen)


## A labeled 0..1 slider in a row of `box`.
func _slider_row(box: Container, text: String) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := UiKit.label(text, 14, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT)
	label.custom_minimum_size.x = 80
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.custom_minimum_size = Vector2(150, 20)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	box.add_child(row)
	return slider
