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

	await _test_phone_drives_the_ui(script)

	await process_frame
	print("PASS" if _ok else "FAIL")
	quit(0 if _ok else 1)


## Presses and releases a phone button the way the page does, with real time in between so the
## mapper's minimum hold and the physics ticks run.
func _tap(rc: Node, action: String) -> void:
	rc.server.message_received.emit({"type": "action", "name": action, "pressed": true})
	await create_timer(0.1).timeout
	rc.server.message_received.emit({"type": "action", "name": action, "pressed": false})
	await create_timer(0.1).timeout


## One stick push in `direction` ((x, y) with a magnitude over the menu threshold) and back.
func _flick(rc: Node, x: float, y: float) -> void:
	rc.server.message_received.emit({"type": "move", "x": x, "y": y})
	await create_timer(0.08).timeout
	rc.server.message_received.emit({"type": "move", "x": 0.0, "y": 0.0})
	await create_timer(0.08).timeout


## Real menus, shop, dialogue and pause menu driven only by phone messages.
func _test_phone_drives_the_ui(script: Script) -> void:
	var rc = script.new()
	root.add_child(rc)
	await process_frame

	# Main menu: the stick moves the focus, attack presses the focused button, dash goes back.
	var menu: Control = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	await process_frame
	await process_frame
	var first: Control = menu.get_viewport().gui_get_focus_owner()
	_check(first != null, "main menu has a focused button")
	await _flick(rc, 0.0, 1.0)
	var second: Control = menu.get_viewport().gui_get_focus_owner()
	_check(second != null and second != first, "stick down moves the focus in the main menu")
	await _flick(rc, 0.0, -1.0)
	_check(menu.get_viewport().gui_get_focus_owner() == first, "stick up moves it back")
	var guard := 0
	while menu.get_viewport().gui_get_focus_owner() != menu.options_button and guard < 6:
		await _flick(rc, 0.0, 1.0)
		guard += 1
	_check(menu.get_viewport().gui_get_focus_owner() == menu.options_button, "the stick reaches the options button")
	await _tap(rc, "attack")
	_check(menu.options.visible, "attack presses the focused main menu button (options opens)")
	await _tap(rc, "dash")
	_check(not menu.options.visible, "dash is back: it closes the options")
	menu.queue_free()
	await process_frame

	# Shop: opens paused, the phone keeps working while paused, buys, closes.
	var room: Node = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(room)
	await process_frame
	await process_frame
	var player: Node = room.get_node("Player")
	var state: Node = root.get_node("GameState")
	state.reset()
	player.add_gold(-player.gold)
	player.add_gold(30)
	var shop: Node = load("res://scripts/ui/shop_menu.gd").new()
	root.add_child(shop)
	await process_frame
	shop.open(player)
	await process_frame
	_check(shop.is_open() and paused, "the shop is open and the game paused")
	await _flick(rc, 0.0, 1.0)
	await _flick(rc, 0.0, 1.0)
	_check(shop.get_viewport().gui_get_focus_owner() == shop.item_buttons[2], "stick moves the focus in the paused shop")
	await _tap(rc, "attack")
	_check(player.gold == 18, "attack buys exactly once (gold 30 -> 18)")
	await _tap(rc, "interact")
	_check(player.gold == 0, "interact buys too, once (the second level costs 18)")
	await _tap(rc, "dash")
	_check(not shop.is_open() and not paused, "dash closes the shop and resumes the game")
	shop.open(player)
	await process_frame
	await _tap(rc, "pause")
	_check(not shop.is_open() and not paused, "the phone's pause button closes the shop")
	shop.queue_free()

	# Dialogue: attack advances it line by line until it ends.
	var dialogue: Node = root.get_node("Dialogue")
	_check(dialogue.start(&"elder"), "a conversation starts")
	await create_timer(0.4).timeout
	var taps := 0
	while dialogue.active and taps < 40:
		await _tap(rc, "attack" if taps % 2 == 0 else "interact")
		taps += 1
		await create_timer(0.3).timeout
	_check(not dialogue.active and taps > 1, "the phone advances the dialogue to its end (%d taps)" % taps)

	# Pause menu: pause opens it, the stick and attack drive it, pause and dash resume.
	var pause_menu: CanvasLayer = (load("res://scenes/ui/pause_menu.tscn") as PackedScene).instantiate()
	room.add_child(pause_menu)
	await process_frame
	await _tap(rc, "pause")
	_check(pause_menu.is_open() and paused, "the pause button pauses the game")
	_check(pause_menu.get_viewport().gui_get_focus_owner() == pause_menu.resume_button, "resume has the focus")
	await _flick(rc, 0.0, 1.0)
	_check(pause_menu.get_viewport().gui_get_focus_owner() == pause_menu.options_button, "stick moves the focus while paused")
	await _tap(rc, "attack")
	_check(pause_menu.options.visible, "attack opens the options from the pause menu")
	await _tap(rc, "dash")
	_check(not pause_menu.options.visible and pause_menu.is_open(), "dash closes the options, the pause menu stays")
	await _tap(rc, "dash")
	_check(not pause_menu.is_open() and not paused, "dash from the pause menu resumes")
	await _tap(rc, "pause")
	_check(pause_menu.is_open() and paused, "pause pauses again")
	await _tap(rc, "pause")
	_check(not pause_menu.is_open() and not paused, "pause unpauses")

	state.reset()
	room.queue_free()
	rc.free()


func _check(cond: bool, label: String) -> void:
	if not cond:
		_ok = false
		printerr("FAIL: " + label)
