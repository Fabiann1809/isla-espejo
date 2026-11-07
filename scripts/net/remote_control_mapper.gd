class_name RemoteControlMapper
extends RefCounted
## Turns messages from the phone controller into the game's real input actions.
## Pure logic: it only calls Input.action_press / action_release on actions from the InputMap.
## It never reads the clock: the owner passes the time to `apply()` and calls `tick()` every
## physics frame (before the player's, as an autoload does).
##
## Movement watchdog: the move_* actions are let go when no move message arrived for
## MOVE_TIMEOUT_MS, so a lost "stick released" message cannot keep Nico walking.
## Minimum hold: a button release is applied only once the press has lasted MIN_HOLD_MS and the
## player has had one whole physics frame to see it; an earlier release waits in `tick()`.
##
## Menus: `Input.action_press` makes no `InputEvent`, so Control focus, the shop, the pause menu
## and the prologue would never see the phone. On top of the action presses the mapper feeds
## `InputEventAction`s (`Input.parse_input_event`, flushed at once): the stick as ui_up/down/left/
## right with key repeat while held, attack and interact as ui_accept, dash as ui_cancel, and the
## phone's pause button as the `pause` action. Only the ui_* event is sent for attack, interact
## and dash (never the raw action event as well), so a menu never reacts twice to one tap.

const DEADZONE := 0.2
## The page repeats its move every 80 ms; 300 ms rides out Wi-Fi power-save gaps of 150-300 ms.
const MOVE_TIMEOUT_MS := 300
## About one physics frame at 60 Hz.
const MIN_HOLD_MS := 17
const MOVE_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]
const BUTTON_ACTIONS: Array[StringName] = [&"attack", &"dash", &"skill_1", &"skill_2", &"skill_3", &"interact", &"pause"]
## Button -> the ui_* action its press fires as an event.
const UI_OF_BUTTON := {&"attack": &"ui_accept", &"interact": &"ui_accept", &"dash": &"ui_cancel"}
## Fired as an event of their own name only (nothing polls them).
const EVENT_ONLY_ACTIONS: Array[StringName] = [&"pause"]
## The stick must pass this to count as a menu direction.
const NAV_THRESHOLD := 0.5
## Key repeat of a held direction: first after NAV_REPEAT_DELAY_MS, then every NAV_REPEAT_MS.
const NAV_REPEAT_DELAY_MS := 400
const NAV_REPEAT_MS := 130

## Actions this mapper currently holds down (name -> true).
var _held: Dictionary = {}
## Button actions currently pressed: name -> {"at": press time in ms, "tick": tick count then}.
var _presses: Dictionary = {}
## Button actions whose release came too early and waits for `tick()` (name -> true).
var _pending_release: Dictionary = {}
var _last_move_ms := -1
## The ui_* direction the stick holds now (&"" = none) and when it repeats next.
var _nav_action: StringName = &""
var _nav_next_ms := 0
## ui_* actions held by an event: name -> {source button: true} (attack and interact share ui_accept).
var _ui_held: Dictionary = {}
var _now_ms := 0
var _ticks := 0


## Applies one message received at `now_ms`. Returns false (and does nothing) when it is unknown
## or malformed. The game always passes the time (RemoteControl._on_message); the -1 default
## (use the time of the last `tick()`) is only for tests that do not care about time.
func apply(msg: Dictionary, now_ms: int = -1) -> bool:
	if now_ms >= 0:
		_now_ms = now_ms
	match msg.get("type"):
		"move":
			return _apply_move(msg)
		"action":
			return _apply_action(msg)
		"ping":
			return true
	return false


## Called every physics frame: applies the deferred releases that are due and the movement
## watchdog.
func tick(now_ms: int) -> void:
	_now_ms = now_ms
	_ticks += 1
	for action: StringName in _pending_release.keys():
		# Two ticks: the tick of this frame runs before the player, so only from the second
		# one on has a whole frame seen the press.
		if _hold_done(action, 2):
			_release_button(action)
	if _nav_action != &"" and now_ms >= _nav_next_ms:
		_fire_ui(_nav_action, false)
		_fire_ui(_nav_action, true)
		_nav_next_ms = now_ms + NAV_REPEAT_MS
	if _last_move_ms >= 0 and now_ms - _last_move_ms >= MOVE_TIMEOUT_MS:
		_last_move_ms = -1
		_set_nav(&"")
		for action: StringName in MOVE_ACTIONS:
			if _held.has(action):
				Input.action_release(action)
				_held.erase(action)


## Lets go of everything at once, deferred releases included (phone gone).
func release_all() -> void:
	for action: StringName in _held.keys():
		Input.action_release(action)
	_held.clear()
	_set_nav(&"")
	for ui: StringName in _ui_held.keys():
		_fire_ui(ui, false)
	_ui_held.clear()
	_presses.clear()
	_pending_release.clear()
	_last_move_ms = -1


## True while a release of `action` waits for its minimum hold.
func is_release_pending(action: StringName) -> bool:
	return _pending_release.has(action)


func _apply_move(msg: Dictionary) -> bool:
	if not (msg.get("x") is float or msg.get("x") is int) or not (msg.get("y") is float or msg.get("y") is int):
		return false
	_last_move_ms = _now_ms
	var x: float = _dead(clampf(float(msg["x"]), -1.0, 1.0))
	var y: float = _dead(clampf(float(msg["y"]), -1.0, 1.0))
	_set_strength(&"move_left", maxf(-x, 0.0))
	_set_strength(&"move_right", maxf(x, 0.0))
	_set_strength(&"move_up", maxf(-y, 0.0))
	_set_strength(&"move_down", maxf(y, 0.0))
	_set_nav(_nav_for(x, y))
	return true


func _apply_action(msg: Dictionary) -> bool:
	var action_name: Variant = msg.get("name")
	if not (action_name is String or action_name is StringName) or not msg.get("pressed") is bool:
		return false
	var action := StringName(action_name)
	if not BUTTON_ACTIONS.has(action):
		return false
	if msg["pressed"]:
		# A new press cancels a release still waiting from the previous tap.
		_pending_release.erase(action)
		_held[action] = true
		_presses[action] = {"at": _now_ms, "tick": _ticks}
		_event_press(action)
	elif _presses.has(action) and not _hold_done(action, 1):
		_pending_release[action] = true
	else:
		_release_button(action)
	return true


## The press of `action` lasted MIN_HOLD_MS and `min_ticks` ticks ran since it.
func _hold_done(action: StringName, min_ticks: int) -> bool:
	var press: Dictionary = _presses.get(action, {})
	if press.is_empty():
		return true
	return _now_ms - int(press["at"]) >= MIN_HOLD_MS and _ticks - int(press["tick"]) >= min_ticks


func _release_button(action: StringName) -> void:
	_event_release(action)
	_held.erase(action)
	_presses.erase(action)
	_pending_release.erase(action)


func _dead(value: float) -> float:
	return 0.0 if absf(value) < DEADZONE else value


func _set_strength(action: StringName, strength: float) -> void:
	if strength > 0.0:
		Input.action_press(action, strength)
		_held[action] = true
	elif _held.has(action):
		Input.action_release(action)
		_held.erase(action)


## The press of a button: the polled action (the game reads it) and its menu event.
func _event_press(action: StringName) -> void:
	if EVENT_ONLY_ACTIONS.has(action):
		_fire_ui(action, true)
		return
	Input.action_press(action)
	if UI_OF_BUTTON.has(action):
		_ui_hold(UI_OF_BUTTON[action], action)


func _event_release(action: StringName) -> void:
	if EVENT_ONLY_ACTIONS.has(action):
		_fire_ui(action, false)
		return
	Input.action_release(action)
	if UI_OF_BUTTON.has(action):
		_ui_drop(UI_OF_BUTTON[action], action)


func _ui_hold(ui: StringName, source: StringName) -> void:
	var sources: Dictionary = _ui_held.get(ui, {})
	var first := sources.is_empty()
	sources[source] = true
	_ui_held[ui] = sources
	if first:
		_fire_ui(ui, true)


func _ui_drop(ui: StringName, source: StringName) -> void:
	var sources: Dictionary = _ui_held.get(ui, {})
	sources.erase(source)
	if sources.is_empty() and _ui_held.has(ui):
		_ui_held.erase(ui)
		_fire_ui(ui, false)


## Sends one action as an InputEvent and delivers it now, so focus navigation and `_input`
## handlers see it in this frame.
func _fire_ui(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _nav_for(x: float, y: float) -> StringName:
	if maxf(absf(x), absf(y)) < NAV_THRESHOLD:
		return &""
	if absf(x) >= absf(y):
		return &"ui_right" if x > 0.0 else &"ui_left"
	return &"ui_down" if y > 0.0 else &"ui_up"


## Changes the menu direction the stick holds: lets go of the old one, presses the new one and
## arms the key repeat.
func _set_nav(direction: StringName) -> void:
	if direction == _nav_action:
		return
	if _nav_action != &"":
		_fire_ui(_nav_action, false)
	_nav_action = direction
	if direction != &"":
		_fire_ui(direction, true)
		_nav_next_ms = _now_ms + NAV_REPEAT_DELAY_MS
