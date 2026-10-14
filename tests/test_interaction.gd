extends SceneTree
## Interaction test: the E prompt, nearest object, chests and their rewards, NPC conversations and
## the player lock during a dialogue.
## Run: godot --headless --path . --script res://tests/test_interaction.gd

## Empty corner of the test room, away from dummies, traps and grunts.
const ARENA := Vector2(300, 180)

var _ok := true
var _room: Node
var _player: Node2D
var _prompts: Array[String] = []
var _messages: Array[String] = []
var _opened := 0


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var events: Node = root.get_node("Events")
	events.interaction_prompt_changed.connect(func(text: String) -> void: _prompts.append(text))
	events.message_requested.connect(func(text: String) -> void: _messages.append(text))
	events.chest_opened.connect(func(_chest: Node) -> void: _opened += 1)
	root.get_node("GameState").reset()
	root.get_node("PlayerProfile").persistence_enabled = false

	_room = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(_room)
	await _frames(4)
	_player = _room.get_node("Player")

	await _test_chests()
	await _test_nearest()
	await _test_npc()

	root.get_node("GameState").reset()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


# --- Chests --------------------------------------------------------------------------------------

func _test_chests() -> void:
	var hud: Node = _room.get_node("Hud")
	var heart := _place("res://scenes/world/chest_heart.tscn", ARENA)
	_player.global_position = ARENA + Vector2(0, 24)
	_player.health.take_damage(2)
	_prompts.clear()
	await _frames(3)
	_check(_prompts.size() > 0 and _prompts[-1] == "Abrir", "standing next to a chest shows its prompt ('%s')" % (_prompts[-1] if _prompts.size() > 0 else "-"))
	_check(hud.get_node("Prompt").visible and hud.get_node("Prompt").text == "[E] Abrir", "the HUD shows '[E] Abrir'")

	var before: int = _player.health.current
	_messages.clear()
	await _tap("interact")
	_check(heart.opened and _opened == 1, "pressing E opens the chest (Events.chest_opened)")
	_check(_player.health.max_health == 6 and _player.health.current == before + 1, "a heart chest adds a heart (%d/%d)" % [_player.health.current, _player.health.max_health])
	_check(_messages == [heart.message], "the chest tells the player what they found")
	await process_frame
	_check(hud.get_node("Toast").visible and hud.get_node("Toast").text == heart.message, "the HUD shows the message")
	_check(_prompts[-1] == "" and not hud.get_node("Prompt").visible, "an opened chest no longer shows a prompt")

	var health_after: int = _player.health.current
	await _tap("interact")
	_check(_opened == 1 and _player.health.current == health_after and _player.health.max_health == 6, "an opened chest gives nothing more")

	var heal := _place("res://scenes/world/chest_heal.tscn", ARENA + Vector2(80, 0))
	_player.global_position = ARENA + Vector2(80, 24)
	_player.health.take_damage(_player.health.current - 2)
	await _frames(3)
	await _tap("interact")
	_check(heal.opened and _player.health.current == 5, "a healing chest restores health (2 -> %d)" % _player.health.current)
	_check(_player.health.max_health == 6, "a healing chest does not change the maximum")
	heart.free()
	heal.free()
	_player.health.heal(10)


# --- Which object is chosen ------------------------------------------------------------------------

func _test_nearest() -> void:
	var chest := _place("res://scenes/world/chest_heal.tscn", ARENA)
	var elder := _place("res://scenes/npcs/elder.tscn", ARENA + Vector2(28, 0))
	_player.global_position = ARENA + Vector2(2, 24)
	_prompts.clear()
	await _frames(3)
	_check(_prompts.size() > 0 and _prompts[-1] == "Abrir", "with two objects in reach the nearest one wins (the chest)")
	_player.global_position = ARENA + Vector2(26, 24)
	await _frames(3)
	_check(_prompts[-1] == "Hablar", "moving closer to the NPC changes the prompt to 'Hablar'")
	_player.global_position = ARENA + Vector2(26, 150)
	await _frames(3)
	_check(_prompts[-1] == "", "far from everything there is no prompt")
	chest.free()
	elder.free()
	await _frames(2)


# --- Talking to the Anciano --------------------------------------------------------------------------------

func _test_npc() -> void:
	var dialogue: Node = root.get_node("Dialogue")
	var state: Node = root.get_node("GameState")
	state.reset()
	var elder := _place("res://scenes/npcs/elder.tscn", ARENA)
	_check(elder.get_node("Name").text == "El Anciano", "the NPC shows the speaker's name from its dialogue file")
	_player.global_position = ARENA + Vector2(0, 24)
	await _frames(3)

	await _tap("interact")
	_check(dialogue.active and dialogue._state == &"first", "pressing E next to the Anciano starts his first conversation")
	_check(not _player.can_cast() and not _player.can_interact(), "the player cannot cast or interact during a dialogue")

	var start: Vector2 = _player.global_position
	Input.action_press("move_right")
	await _frames(20)
	Input.action_release("move_right")
	_check(_player.global_position.distance_to(start) < 0.5, "the player cannot move during a dialogue")
	var state_before: int = _player.state
	await _tap("attack")
	_check(_player.state != _player.State.ATTACK and state_before != _player.State.ATTACK, "the attack key advances the dialogue instead of attacking")

	var guard := 0
	while dialogue.active and guard < 10:
		guard += 1
		dialogue._box.complete_line()
		await create_timer(0.3).timeout
		await _tap("interact")
	_check(not dialogue.active and state.has_flag(&"met_elder"), "the conversation ends and remembers the meeting")

	await _frames(3)
	_check(not dialogue.active, "the key that closed the dialogue does not reopen it")
	_check(_player.can_cast(), "the player can act again after the dialogue")
	start = _player.global_position
	Input.action_press("move_right")
	await _frames(12)
	Input.action_release("move_right")
	_check(_player.global_position.distance_to(start) > 5.0, "the player can move again")

	await create_timer(0.5).timeout
	_player.global_position = ARENA + Vector2(0, 24)
	await _frames(3)
	await _tap("interact")
	_check(dialogue.active and dialogue._state == &"again", "talking again gives the hint ('again')")
	guard = 0
	while dialogue.active and guard < 10:
		guard += 1
		dialogue._box.complete_line()
		await create_timer(0.3).timeout
		await _tap("interact")
	_check(not dialogue.active, "the second conversation ends too")
	elder.free()


# --- Helpers --------------------------------------------------------------------------------------------

func _place(scene_path: String, at: Vector2) -> Node2D:
	var node: Node2D = load(scene_path).instantiate()
	node.position = at
	_room.add_child(node)
	return node


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _tap(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(3)
	await process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(2)
