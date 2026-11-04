extends SceneTree
## RemoteControl autoload: wiring server -> mapper, forwarded signals, stop releases the held
## actions, the headless guard (D7) and the quit paths. Never binds a real port (a server double
## stands in when the server has to look "running").
## Run: godot --headless --path . --script res://tests/test_remote_control.gd

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var autoload = root.get_node_or_null("RemoteControl")
	_check(autoload != null, "RemoteControl autoload exists")
	if autoload != null:
		_check(autoload.process_mode == Node.PROCESS_MODE_ALWAYS, "autoload processes while paused")
		_check(autoload.server != null and autoload.server.get_parent() == autoload, "autoload owns the server")

	var script: Script = load("res://scripts/net/remote_control.gd")
	var rc = script.new()
	root.add_child(rc)
	await process_frame

	# D7: no port in headless runs.
	_check(rc.start() == ERR_UNAVAILABLE, "start returns ERR_UNAVAILABLE in headless")
	_check(not rc.is_running() and not rc.server.is_running(), "no port opened")
	_check(rc.get_urls() is PackedStringArray, "get_urls forwards the server's list")

	# Wiring: server messages reach the real input actions.
	rc.server.message_received.emit({"type": "action", "name": "attack", "pressed": true})
	_check(Input.is_action_pressed("attack"), "message_received -> mapper.apply presses the action")
	rc.server.message_received.emit({"type": "move", "x": 1.0, "y": 0.0})
	_check(Input.is_action_pressed("move_right"), "move message presses move_right")

	# The autoload drives the mapper's clock: without new move messages the watchdog lets go.
	await create_timer(0.5).timeout
	_check(not Input.is_action_pressed("move_right"), "watchdog releases movement through the autoload")
	_check(Input.is_action_pressed("attack"), "buttons are not touched by the watchdog")

	# Forwarded signals.
	var seen := {"connected": 0, "disconnected": 0, "rejected": 0}
	rc.controller_connected.connect(func() -> void: seen["connected"] += 1)
	rc.controller_disconnected.connect(func() -> void: seen["disconnected"] += 1)
	rc.controller_rejected.connect(func() -> void: seen["rejected"] += 1)
	rc.server.controller_connected.emit()
	rc.server.controller_rejected.emit()
	_check(seen["connected"] == 1 and seen["rejected"] == 1, "connected and rejected forwarded")
	rc.server.controller_disconnected.emit()
	_check(seen["disconnected"] == 1, "disconnected forwarded")
	_check(not Input.is_action_pressed("attack"), "a disconnect releases every held action")

	# stop() releases what the phone holds.
	rc.server.message_received.emit({"type": "action", "name": "dash", "pressed": true})
	_check(Input.is_action_pressed("dash"), "dash held")
	rc.stop()
	_check(not Input.is_action_pressed("dash"), "stop releases the held actions")

	# A server double that "listens": start is idempotent, stop stops it.
	var fake = (load("res://tests/fake_control_server.gd") as Script).new()
	rc.set_server(fake)
	_check(rc.server == fake and fake.get_parent() == rc, "set_server swaps and adopts the server")
	_check(rc.start() == OK and rc.is_running(), "start opens the (fake) server")
	_check(rc.start() == OK and fake.start_calls == 1, "start is idempotent")
	fake.fake_controller = true
	_check(rc.has_controller(), "has_controller forwards")
	fake.message_received.emit({"type": "action", "name": "interact", "pressed": true})
	_check(Input.is_action_pressed("interact"), "new server is wired to the mapper")
	rc.stop()
	_check(not rc.is_running() and not Input.is_action_pressed("interact"), "stop closes and releases")
	_check(seen["disconnected"] == 2, "dropping the phone on stop is forwarded")

	# Quit: the close request stops the server and releases everything.
	rc.start()
	fake.message_received.emit({"type": "action", "name": "skill_1", "pressed": true})
	rc.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_check(not rc.is_running() and not Input.is_action_pressed("skill_1"), "quit request stops and releases")

	# Leaving the tree does the same.
	rc.start()
	fake.message_received.emit({"type": "action", "name": "skill_2", "pressed": true})
	rc.free()
	_check(not Input.is_action_pressed("skill_2"), "exit tree releases the held actions")

	await process_frame
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)


func _check(cond: bool, label: String) -> void:
	if not cond:
		_ok = false
		printerr("FAIL: " + label)
