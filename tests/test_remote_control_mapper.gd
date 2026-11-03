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
	mapper.apply({"type": "action", "name": "attack", "pressed": false})
	_check(not Input.is_action_pressed("attack"), "attack released")
	for action in ["dash", "skill_1", "skill_2", "skill_3", "interact"]:
		mapper.apply({"type": "action", "name": action, "pressed": true})
		_check(Input.is_action_pressed(action), "%s pressed" % action)
		mapper.apply({"type": "action", "name": action, "pressed": false})

	_check(not mapper.apply({"type": "action", "name": "pause", "pressed": true}), "unknown action name rejected")
	_check(not Input.is_action_pressed("pause"), "rejected action does not press")
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

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
