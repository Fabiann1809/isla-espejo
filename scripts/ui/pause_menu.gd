class_name PauseMenu
extends CanvasLayer
## Pause (Esc): resume, options, back to the main menu or leave the game. It stops the whole tree
## and keeps working while the tree is paused. It does not open during a conversation.

const MENU_SCENE := "res://scenes/ui/main_menu.tscn"

var resume_button: Button
var options_button: Button
var menu_button: Button
var quit_button: Button
var options: OptionsMenu

var _root: Control
var _panel: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 30
	var root := Control.new()
	root.theme = UiKit.theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	box.add_child(UiKit.label(UiText.t("pause_title"), 20))
	resume_button = _add_button(box, UiText.t("pause_resume"), resume)
	options_button = _add_button(box, UiText.t("menu_options"), _open_options)
	menu_button = _add_button(box, UiText.t("pause_menu"), _to_main_menu)
	quit_button = _add_button(box, UiText.t("menu_quit"), _quit)

	options = OptionsMenu.new()
	options.set_anchors_preset(Control.PRESET_CENTER)
	options.grow_horizontal = Control.GROW_DIRECTION_BOTH
	options.grow_vertical = Control.GROW_DIRECTION_BOTH
	options.closed.connect(func() -> void:
		_panel.show()
		resume_button.grab_focus())
	root.add_child(options)
	_root = root
	_root.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if is_open():
		if options.visible:
			options.close()
		else:
			resume()
	elif not Dialogue.active:
		pause()
	get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _root.visible


func pause() -> void:
	get_tree().paused = true
	_panel.show()
	options.hide()
	_root.show()
	resume_button.grab_focus()


func resume() -> void:
	_root.hide()
	get_tree().paused = false


func _add_button(parent: Node, text: String, action: Callable) -> Button:
	var button := UiKit.button(text)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _open_options() -> void:
	_panel.hide()
	options.open()


func _to_main_menu() -> void:
	SaveGame.save()
	resume()
	get_tree().change_scene_to_file(MENU_SCENE)


func _quit() -> void:
	SaveGame.save()
	get_tree().quit()
