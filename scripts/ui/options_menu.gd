class_name OptionsMenu
extends PanelContainer
## Volume and full screen. Shared by the main menu and the pause menu; it only talks to the
## `Settings` autoload and tells its owner when the player goes back.

signal closed

var volume_slider: HSlider
var fullscreen_check: CheckButton
var back_button: Button


func _ready() -> void:
	theme = UiKit.theme()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	box.add_child(UiKit.label(UiText.t("options_title"), 18))

	var volume_row := HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 12)
	volume_row.add_child(UiKit.label(UiText.t("options_volume"), 14, UiKit.TEXT, HORIZONTAL_ALIGNMENT_LEFT))
	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.custom_minimum_size = Vector2(150, 20)
	volume_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	volume_row.add_child(volume_slider)
	box.add_child(volume_row)

	fullscreen_check = CheckButton.new()
	fullscreen_check.text = UiText.t("options_fullscreen")
	box.add_child(fullscreen_check)

	back_button = UiKit.button(UiText.t("options_back"))
	box.add_child(back_button)

	refresh()
	volume_slider.value_changed.connect(Settings.set_volume)
	fullscreen_check.toggled.connect(Settings.set_fullscreen)
	back_button.pressed.connect(close)
	hide()


func open() -> void:
	refresh()
	show()
	back_button.grab_focus()


func close() -> void:
	hide()
	closed.emit()


## Shows the current values without triggering a change.
func refresh() -> void:
	volume_slider.set_value_no_signal(Settings.volume)
	fullscreen_check.set_pressed_no_signal(Settings.fullscreen)
