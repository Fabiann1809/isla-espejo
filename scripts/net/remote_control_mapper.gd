class_name RemoteControlMapper
extends RefCounted
## Turns messages from the phone controller into the game's real input actions.
## Pure logic: it only calls Input.action_press / action_release on actions from the InputMap.

const DEADZONE := 0.2
const BUTTON_ACTIONS: Array[StringName] = [&"attack", &"dash", &"skill_1", &"skill_2", &"skill_3", &"interact"]

## Actions this mapper currently holds down (name -> true).
var _held: Dictionary = {}


## Applies one message. Returns false (and does nothing) when it is unknown or malformed.
func apply(msg: Dictionary) -> bool:
	match msg.get("type"):
		"move":
			return _apply_move(msg)
		"action":
			return _apply_action(msg)
		"ping":
			return true
	return false


func release_all() -> void:
	for action: StringName in _held.keys():
		Input.action_release(action)
	_held.clear()


func _apply_move(msg: Dictionary) -> bool:
	if not (msg.get("x") is float or msg.get("x") is int) or not (msg.get("y") is float or msg.get("y") is int):
		return false
	var x: float = _dead(clampf(float(msg["x"]), -1.0, 1.0))
	var y: float = _dead(clampf(float(msg["y"]), -1.0, 1.0))
	_set_strength(&"move_left", maxf(-x, 0.0))
	_set_strength(&"move_right", maxf(x, 0.0))
	_set_strength(&"move_up", maxf(-y, 0.0))
	_set_strength(&"move_down", maxf(y, 0.0))
	return true


func _apply_action(msg: Dictionary) -> bool:
	var action_name: Variant = msg.get("name")
	if not (action_name is String or action_name is StringName) or not msg.get("pressed") is bool:
		return false
	var action := StringName(action_name)
	if not BUTTON_ACTIONS.has(action):
		return false
	if msg["pressed"]:
		Input.action_press(action)
		_held[action] = true
	else:
		Input.action_release(action)
		_held.erase(action)
	return true


func _dead(value: float) -> float:
	return 0.0 if absf(value) < DEADZONE else value


func _set_strength(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
		_held[action] = true
	elif _held.has(action):
		Input.action_release(action)
		_held.erase(action)
