extends SceneTree
## Phone controller panel: texts, QR image, status wiring and the headless guard (no port opened).
## The panel is a view of the RemoteControl autoload: closing it never stops the phone controller.
## Run: godot --headless --path . --script res://tests/test_controller_panel.gd

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	for key in ["options_controller", "controller_title", "controller_waiting",
			"controller_connected", "controller_busy", "controller_error", "controller_back",
			"controller_disconnect", "controller_stopped"]:
		var text := _text(key)
		_check(text != "" and text != key, "text %s resolves" % key)

	var rc = root.get_node("RemoteControl")
	var panel_script: Script = load("res://scripts/ui/controller_panel.gd")
	var panel = panel_script.new()
	root.add_child(panel)
	await process_frame
	_check(not panel.visible, "panel starts hidden")
	panel.open()
	_check(not rc.is_running(), "headless: no port opened")
	_check(panel.status_label.text == _text("controller_error"), "headless shows the error text")
	_check(panel.visible, "panel is visible after open")

	panel.show_urls(PackedStringArray(["http://192.168.1.20:8080/"]))
	_check(panel.qr_rect.texture != null, "QR texture created for the URL")
	_check(panel.url_label.text == "http://192.168.1.20:8080/", "URL shown as text")

	rc.controller_connected.emit()
	_check(panel.status_label.text == _text("controller_connected"), "connected status")
	rc.controller_disconnected.emit()
	_check(panel.status_label.text == _text("controller_waiting"), "waiting after disconnect")
	rc.controller_connected.emit()
	rc.controller_rejected.emit()
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

	# Freeing a panel with a busy timer pending must not resume anything on a dead instance.
	var temp = panel_script.new()
	root.add_child(temp)
	await process_frame
	rc.controller_rejected.emit()
	temp.free()
	await create_timer(2.2).timeout

	# From here on a server double "listens" (no port), so running/stopped can be observed.
	var fake = (load("res://tests/fake_control_server.gd") as Script).new()
	rc.set_server(fake)
	var pause: CanvasLayer = (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate()
	root.add_child(pause)
	await process_frame
	pause.pause()
	pause.options_button.pressed.emit()
	pause.options.controller_button.pressed.emit()
	var view = pause.options.controller_panel
	_check(pause.options.is_controller_open(), "pause: controller panel open")
	_check(rc.is_running(), "opening the panel starts the phone controller")
	_check(view.qr_rect.texture != null and view.url_label.text.begins_with("http://192.168.1.20:8080/"),
			"QR and address shown")
	_check(view.url_label.text.contains("http://10.0.0.7:8080/"), "every address listed as text")
	fake.fake_controller = true
	fake.message_received.emit({"type": "action", "name": "attack", "pressed": true})
	pause.resume()
	_check(not pause.options.is_controller_open() and not view.visible, "resume hides the panel")
	_check(rc.is_running() and fake.stop_calls == 0, "resume keeps the phone controller running")
	_check(Input.is_action_pressed("attack"), "the phone still holds its action after resume")
	_check(not pause.is_open() and not paused, "resume still resumes")

	# Esc closes only the panel (back to the options), not the pause menu, and keeps the server.
	pause.pause()
	pause.options_button.pressed.emit()
	pause.options.controller_button.pressed.emit()
	var esc := InputEventAction.new()
	esc.action = &"pause"
	esc.pressed = true
	pause._unhandled_input(esc)
	_check(not view.visible and pause.options.visible and pause.is_open() and paused,
			"Esc hides the panel without resuming")
	_check(rc.is_running(), "Esc keeps the phone controller running")

	# Desconectar stops it; opening the panel again turns it back on.
	pause.options.controller_button.pressed.emit()
	view.disconnect_button.pressed.emit()
	_check(not rc.is_running() and not Input.is_action_pressed("attack"), "Desconectar stops and releases")
	_check(view.status_label.text == _text("controller_stopped") and view.qr_rect.texture == null,
			"disconnected state shown")
	view.back_button.pressed.emit()
	pause.options.controller_button.pressed.emit()
	_check(rc.is_running() and view.qr_rect.texture != null, "reopening the panel starts it again")
	# No address any more while a phone is attached: error text, but the phone is not dropped.
	fake.fake_controller = true
	fake.fake_urls = PackedStringArray()
	var stops_before: int = fake.stop_calls
	view.back_button.pressed.emit()
	pause.options.controller_button.pressed.emit()
	_check(view.status_label.text == _text("controller_error"), "no address shows the error text")
	_check(rc.is_running() and rc.has_controller() and fake.stop_calls == stops_before,
			"no address does not stop an attached phone")
	fake.fake_urls = PackedStringArray(["http://192.168.1.20:8080/"])
	pause.resume()
	pause.queue_free()
	await process_frame
	_check(rc.is_running(), "freeing the menus keeps the phone controller running")
	rc.stop()
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)


func _text(key: String) -> String:
	var ui_text: Script = load("res://scripts/core/ui_text.gd")
	return ui_text.t(key)


func _check(cond: bool, label: String) -> void:
	if not cond:
		_ok = false
		printerr("FAIL: " + label)
