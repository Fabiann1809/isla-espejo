extends SceneTree
## Main menu design test: the art exists, the scenery is built, the gold arrow follows the selected
## button, the controls bar hides while a panel is open, and the shared theme frames buttons,
## panels, sliders and switches with the menu art.
## Run: godot --headless --path . --script res://tests/test_menu_design.gd

const ART := ["background", "lantern_glow", "nico", "bat_halo", "shot", "title", "divider",
		"button_normal", "button_selected", "arrow", "footer", "panel", "grabber", "grabber_hover",
		"toggle_on", "toggle_off"]

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	root.get_node("SaveGame").persistence_enabled = false

	for art in ART:
		_check(ResourceLoader.exists("res://assets/ui/menu/%s.png" % art), "art exists: %s" % art)
	_check(ResourceLoader.exists("res://assets/fonts/pixelify_sans.ttf"), "the menu font exists")

	var menu: Control = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	for node in ["Backdrop", "Nico", "Title", "Divider"]:
		_check(menu.get_node_or_null(node) != null, "the menu has %s" % node)
	_check(menu._bat != null and menu._bat.is_playing(), "the bat flaps")
	_check(menu._shot != null and menu._glow != null, "the arrow and the lantern glow exist")

	# The arrow marks the focused button, whichever it is.
	menu.credits_button.grab_focus()
	var expected_y: float = menu.credits_button.get_index() * (menu.BUTTON_SIZE.y + menu.BUTTON_GAP) + (menu.BUTTON_SIZE.y - 9) / 2.0
	_check(is_equal_approx(menu._cursor.position.y, expected_y), "the arrow follows the focus")

	# Opening a panel hides the menu and the controls bar; closing brings both back.
	menu.options_button.pressed.emit()
	_check(not menu._menu.visible and not menu._footer.visible and menu.options.visible, "a panel replaces the menu and bar")
	menu.options.close()
	_check(menu._menu.visible and menu._footer.visible, "closing the panel restores them")

	# Every button fits its label (the longest is "Abandonar la isla").
	var font: Font = menu.quit_button.get_theme_font("font")
	var width: float = font.get_string_size(menu.quit_button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.FONT_SIZE).x
	_check(width < menu.BUTTON_SIZE.x - 30.0, "the longest label fits beside the arrow (%d px)" % int(width))
	# Fine print is not hard-coded: the controls text comes from data.
	_check(UiText.t("menu_controls").contains("WASD"), "the controls bar text comes from texts.json")

	var theme: Theme = UiKit.theme()
	_check(theme.get_stylebox("normal", "Button") is StyleBoxTexture, "buttons use the framed art")
	_check(theme.get_stylebox("panel", "PanelContainer") is StyleBoxTexture, "panels use the framed art")
	_check(theme.get_icon("checked", "CheckButton") != null and theme.get_icon("grabber", "HSlider") != null, "switch and slider use the art")
	_check(UiKit.menu_font() != null, "the menu font loads")

	menu.queue_free()
	await process_frame
	quit(0 if _ok else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		printerr("FAIL ", label)
		_ok = false
