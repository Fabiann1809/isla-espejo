extends SceneTree
## Phone controller panel: texts, QR image, status wiring and the headless guard (no port opened).
## Run: godot --headless --path . --script res://tests/test_controller_panel.gd

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	for key in ["options_controller", "controller_title", "controller_waiting",
			"controller_connected", "controller_busy", "controller_error", "controller_back"]:
		var text := _text(key)
		_check(text != "" and text != key, "text %s resolves" % key)

	var panel_script: Script = load("res://scripts/ui/controller_panel.gd")
	var panel = panel_script.new()
	root.add_child(panel)
	await process_frame
	_check(not panel.visible, "panel starts hidden")
	panel.open()
	_check(not panel.server.is_running(), "headless: no port opened")
	_check(panel.status_label.text == _text("controller_error"), "headless shows the error text")
	_check(panel.visible, "panel is visible after open")

	panel.show_url("http://192.168.1.20:8080/")
	_check(panel.qr_rect.texture != null, "QR texture created for the URL")
	_check(panel.url_label.text == "http://192.168.1.20:8080/", "URL shown as text")

	panel.server.controller_connected.emit()
	_check(panel.status_label.text == _text("controller_connected"), "connected status")
	panel.server.controller_disconnected.emit()
	_check(panel.status_label.text == _text("controller_waiting"), "waiting after disconnect")
	panel.server.controller_connected.emit()
	panel.server.controller_rejected.emit()
	_check(panel.status_label.text == _text("controller_busy"), "busy status")

	var closed_count := [0]
	panel.closed.connect(func() -> void: closed_count[0] += 1)
	panel.back_button.pressed.emit()
	_check(not panel.visible and closed_count[0] == 1, "back closes the panel")

	var options_script: Script = load("res://scripts/ui/options_menu.gd")
	var holder := Control.new()
	root.add_child(holder)
	var options = options_script.new()
	holder.add_child(options)
	await process_frame
	options.open()
	options.controller_button.pressed.emit()
	_check(not options.visible and options.controller_panel.visible, "button swaps options for the panel")
	options.controller_panel.back_button.pressed.emit()
	_check(options.visible and not options.controller_panel.visible, "back returns to options")
	holder.queue_free()
	panel.queue_free()

	var pause: CanvasLayer = (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate()
	root.add_child(pause)
	await process_frame
	pause.pause()
	pause.options_button.pressed.emit()
	pause.options.controller_button.pressed.emit()
	_check(pause.options.is_controller_open(), "pause: controller panel open")
	pause.resume()
	_check(not pause.options.is_controller_open() and not pause.options.controller_panel.server.is_running(),
			"resume closes the panel and stops the server")
	_check(not pause.is_open() and not paused, "resume still resumes")
	pause.queue_free()
	await process_frame
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)


func _text(key: String) -> String:
	var ui_text: Script = load("res://scripts/core/ui_text.gd")
	return ui_text.t(key)


func _check(cond: bool, label: String) -> void:
	if not cond:
		_ok = false
		printerr("FAIL: " + label)
