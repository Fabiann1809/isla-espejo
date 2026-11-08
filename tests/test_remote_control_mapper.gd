extends SceneTree
## RemoteControlMapper test: phone messages -> real input actions.
## Run: godot --headless --path . --script res://tests/test_remote_control_mapper.gd

var _ok := true


func _initialize() -> void:
	var mapper = load("res://scripts/net/remote_control_mapper.gd").new()

	_check(mapper.apply({"type": "move", "x": 1.0, "y": 0.0}), "valid move accepted")
	_check(Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_left"), "move x=1 presses move_right only")
	_check(is_equal_approx(Input.get_action_strength("move_right"), 1.0), "move_right strength is 1")

	mapper.apply({"type": "move", "x": -0.6, "y": 0.5})
	_check(Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right"), "x=-0.6 swaps to move_left")
	_check(Input.is_action_pressed("move_down") and not Input.is_action_pressed("move_up"), "positive y is down")
	_check(is_equal_approx(Input.get_action_strength("move_left"), 0.6), "move_left strength is 0.6")

	mapper.apply({"type": "move", "x": 0.0, "y": -1.0})
	_check(Input.is_action_pressed("move_up") and not Input.is_action_pressed("move_down"), "negative y is up")
	_check(not Input.is_action_pressed("move_left"), "move_left released when x returns to 0")

	mapper.apply({"type": "move", "x": 5.0, "y": -9.0})
	_check(is_equal_approx(Input.get_action_strength("move_right"), 1.0), "x is clamped to 1")
	_check(is_equal_approx(Input.get_action_strength("move_up"), 1.0), "y is clamped to -1")

	mapper.apply({"type": "move", "x": 0.19, "y": -0.1})
	_check(not Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_up"), "deadzone: below 0.2 counts as 0")
	mapper.apply({"type": "move", "x": 0.25, "y": 0.0})
	_check(Input.is_action_pressed("move_right"), "above the deadzone presses")

	_check(mapper.apply({"type": "action", "name": "attack", "pressed": true}), "valid action accepted")
	_check(Input.is_action_pressed("attack"), "attack pressed")
	mapper.tick(40)
	mapper.tick(60)
	mapper.apply({"type": "action", "name": "attack", "pressed": false}, 80)
	_check(not Input.is_action_pressed("attack"), "attack released (held long enough)")
	for action in ["dash", "skill_1", "skill_2", "skill_3", "interact"]:
		mapper.apply({"type": "action", "name": action, "pressed": true})
		_check(Input.is_action_pressed(action), "%s pressed" % action)
		mapper.apply({"type": "action", "name": action, "pressed": false})

	_check(not mapper.apply({"type": "action", "name": "debug_overlay", "pressed": true}), "unknown action name rejected")
	_check(not Input.is_action_pressed("debug_overlay"), "rejected action does not press")
	_check(not mapper.apply({"type": "action", "name": "move_left", "pressed": true}), "move_* is not a button action")
	_check(not Input.is_action_pressed("move_left"), "move_left not pressed through action")
	_check(not mapper.apply({"type": "action", "name": 5, "pressed": true}), "non-string name rejected")
	_check(not mapper.apply({"type": "action", "name": "attack", "pressed": "yes"}), "non-bool pressed rejected")
	_check(not mapper.apply({"type": "action", "name": "attack"}), "missing pressed rejected")
	_check(not mapper.apply({"type": "move", "x": "1", "y": 0}), "string coordinate rejected")
	_check(not mapper.apply({"type": "move", "x": 1.0}), "missing y rejected")
	_check(not mapper.apply({"type": "teleport"}), "unknown type rejected")
	_check(not mapper.apply({}), "empty message rejected")
	_check(not mapper.apply({"type": 3}), "non-string type rejected")
	_check(mapper.apply({"type": "ping"}), "ping accepted")

	mapper.apply({"type": "move", "x": 1.0, "y": 1.0})
	mapper.apply({"type": "action", "name": "dash", "pressed": true})
	mapper.apply({"type": "action", "name": "skill_2", "pressed": true})
	mapper.release_all()
	var any := false
	for action in ["move_left", "move_right", "move_up", "move_down", "attack", "dash", "skill_1", "skill_2", "skill_3", "interact"]:
		any = any or Input.is_action_pressed(action)
	_check(not any, "release_all releases everything")

	_test_min_hold()
	_test_watchdog()
	await _test_menu_events()

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


## A quick tap stays pressed until the player has seen it for a whole physics frame.
func _test_min_hold() -> void:
	var mapper = load("res://scripts/net/remote_control_mapper.gd").new()
	mapper.tick(1000)
	mapper.apply({"type": "action", "name": "attack", "pressed": true}, 1000)
	mapper.apply({"type": "action", "name": "attack", "pressed": false}, 1005)
	_check(Input.is_action_pressed("attack") and mapper.is_release_pending(&"attack"), "early release is deferred")
	mapper.tick(1010)
	_check(Input.is_action_pressed("attack"), "tap still pressed in the next physics frame")
	mapper.tick(1040)
	_check(not Input.is_action_pressed("attack") and not mapper.is_release_pending(&"attack"),
			"deferred release applied on the following tick")

	# Enough time but no physics frame in between: still deferred.
	mapper.apply({"type": "action", "name": "dash", "pressed": true}, 2000)
	mapper.apply({"type": "action", "name": "dash", "pressed": false}, 2050)
	_check(Input.is_action_pressed("dash"), "release waits for a physics frame even after 17 ms")
	mapper.tick(2060)
	_check(Input.is_action_pressed("dash"), "the first tick runs before the player: still pressed")
	mapper.tick(2076)
	_check(not Input.is_action_pressed("dash"), "released on the second tick")

	# Held for a frame and 17 ms: released at once.
	mapper.apply({"type": "action", "name": "skill_1", "pressed": true}, 3000)
	mapper.tick(3016)
	mapper.apply({"type": "action", "name": "skill_1", "pressed": false}, 3017)
	_check(not Input.is_action_pressed("skill_1"), "a long enough press is released immediately")

	# A new press cancels the waiting release.
	mapper.apply({"type": "action", "name": "interact", "pressed": true}, 4000)
	mapper.apply({"type": "action", "name": "interact", "pressed": false}, 4002)
	mapper.apply({"type": "action", "name": "interact", "pressed": true}, 4004)
	mapper.tick(4020)
	mapper.tick(4040)
	_check(Input.is_action_pressed("interact") and not mapper.is_release_pending(&"interact"),
			"a new press cancels the deferred release")
	mapper.release_all()

	# release_all lets go now and forgets the deferred releases.
	mapper.apply({"type": "action", "name": "dash", "pressed": true}, 5000)
	mapper.apply({"type": "action", "name": "dash", "pressed": false}, 5001)
	mapper.release_all()
	_check(not Input.is_action_pressed("dash") and not mapper.is_release_pending(&"dash"),
			"release_all releases now and clears pending releases")
	mapper.apply({"type": "action", "name": "dash", "pressed": true}, 5010)
	mapper.tick(5020)
	mapper.tick(5040)
	_check(Input.is_action_pressed("dash"), "no stale deferred release after release_all")
	mapper.release_all()


## No move message for 300 ms lets go of the movement, not before.
func _test_watchdog() -> void:
	var mapper = load("res://scripts/net/remote_control_mapper.gd").new()
	mapper.apply({"type": "move", "x": 1.0, "y": 0.5}, 10000)
	mapper.tick(10100)
	mapper.tick(10299)
	_check(Input.is_action_pressed("move_right") and Input.is_action_pressed("move_down"), "move kept at 299 ms")
	mapper.tick(10300)
	_check(not Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_down"),
			"move released after 300 ms without a move message")
	mapper.apply({"type": "move", "x": -1.0, "y": 0.0}, 11000)
	mapper.tick(11150)
	mapper.apply({"type": "move", "x": -1.0, "y": 0.0}, 11150)
	mapper.tick(11300)
	_check(Input.is_action_pressed("move_left"), "each move message restarts the watchdog")
	mapper.apply({"type": "action", "name": "attack", "pressed": true}, 11300)
	mapper.tick(11450)
	_check(not Input.is_action_pressed("move_left") and Input.is_action_pressed("attack"),
			"the watchdog only releases movement")
	mapper.release_all()


## The same messages also arrive as ui_* events so Control focus, menus and the shop see them.
func _test_menu_events() -> void:
	await process_frame
	var seen: Array = []
	var recorder := Node.new()
	recorder.set_script(load("res://tests/event_recorder.gd"))
	recorder.seen = seen
	root.add_child(recorder)
	var mapper = load("res://scripts/net/remote_control_mapper.gd").new()

	mapper.apply({"type": "move", "x": 1.0, "y": 0.2}, 20000)
	_check(seen == ["ui_right:1"], "stick right fires ui_right once")
	_check(Input.is_action_pressed("ui_right"), "ui_right is pressed")
	mapper.apply({"type": "move", "x": 1.0, "y": 0.0}, 20050)
	_check(seen == ["ui_right:1"], "same direction fires nothing new")
	mapper.tick(20300)
	_check(seen == ["ui_right:1"], "no repeat before the delay")
	mapper.apply({"type": "move", "x": 1.0, "y": 0.0}, 20400)
	mapper.tick(20450)
	_check(seen.size() == 3 and seen[2] == "ui_right:1", "key repeat after the delay")
	mapper.tick(20500)
	_check(seen.size() == 3, "next repeat waits for the interval")
	mapper.apply({"type": "move", "x": 1.0, "y": 0.0}, 20590)
	mapper.tick(20600)
	_check(seen.size() == 5, "repeats every interval while held")
	mapper.apply({"type": "move", "x": 0.0, "y": 1.0}, 20610)
	_check(not Input.is_action_pressed("ui_right") and Input.is_action_pressed("ui_down"), "direction change swaps ui actions")
	mapper.apply({"type": "move", "x": 0.3, "y": 0.3}, 20620)
	_check(not Input.is_action_pressed("ui_down"), "a small stick movement is no menu direction")
	mapper.apply({"type": "move", "x": -0.2, "y": -0.9}, 20630)
	_check(Input.is_action_pressed("ui_up"), "stick up fires ui_up")
	mapper.tick(21000)
	_check(not Input.is_action_pressed("ui_up"), "the watchdog releases the menu direction")

	seen.clear()
	mapper.apply({"type": "action", "name": "attack", "pressed": true}, 22000)
	_check(seen == ["ui_accept:1"], "attack fires ui_accept and no raw attack event")
	_check(Input.is_action_pressed("attack") and Input.is_action_pressed("ui_accept"), "attack stays polled too")
	mapper.apply({"type": "action", "name": "interact", "pressed": true}, 22001)
	_check(seen == ["ui_accept:1"], "interact while attack is held does not fire ui_accept twice")
	mapper.tick(22020)
	mapper.tick(22040)
	mapper.apply({"type": "action", "name": "attack", "pressed": false}, 22050)
	_check(Input.is_action_pressed("ui_accept"), "ui_accept stays while interact holds it")
	mapper.tick(22060)
	mapper.tick(22080)
	mapper.apply({"type": "action", "name": "interact", "pressed": false}, 22090)
	_check(not Input.is_action_pressed("ui_accept") and seen[-1] == "ui_accept:0", "ui_accept released with the last button")

	seen.clear()
	mapper.apply({"type": "action", "name": "dash", "pressed": true}, 23000)
	_check(seen == ["ui_cancel:1"], "dash fires ui_cancel")
	mapper.tick(23020)
	mapper.tick(23040)
	mapper.apply({"type": "action", "name": "dash", "pressed": false}, 23050)
	_check(seen[-1] == "ui_cancel:0", "dash release lets go of ui_cancel")

	seen.clear()
	_check(mapper.apply({"type": "action", "name": "pause", "pressed": true}, 24000), "the pause button is accepted")
	_check(seen == ["pause:1"], "pause fires the pause action as an event")
	mapper.tick(24020)
	mapper.tick(24040)
	mapper.apply({"type": "action", "name": "pause", "pressed": false}, 24050)
	_check(seen[-1] == "pause:0", "pause release is sent")

	mapper.apply({"type": "move", "x": 0.0, "y": 1.0}, 25000)
	mapper.apply({"type": "action", "name": "dash", "pressed": true}, 25000)
	mapper.release_all()
	_check(not Input.is_action_pressed("ui_down") and not Input.is_action_pressed("ui_cancel"), "release_all lets go of the ui events")
	recorder.free()
