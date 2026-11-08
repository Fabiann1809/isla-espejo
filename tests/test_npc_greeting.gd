extends SceneTree
## The Anciano greets Nico by himself: the first time the player enters the event room the conversation
## starts after a beat; it does not start again once they have met, and he is drawn a little larger than
## before so he stands at least as tall as Nico.
## Run: godot --headless --path . --script res://tests/test_npc_greeting.gd

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var state: Node = root.get_node("GameState")
	var dialogue: Node = root.get_node("Dialogue")
	state.reset()

	var level: Node2D = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.seed_value = 11
	root.add_child(level)
	for i in 6:
		await physics_frame
	var elder = null
	for npc in level.get_tree().get_nodes_in_group("npcs"):
		if npc.dialogue_id == &"elder":
			elder = npc
	_check(elder != null and elder.talk_on_enter, "the Anciano greets whoever enters his room")
	_check(elder.sprite_scale > 0.5 and elder.sprite_scale <= 0.7, "and he is drawn a little larger (%s) than the old half size" % elder.sprite_scale)

	var started: Array = []
	dialogue.started.connect(func(id: StringName) -> void: started.append(id))
	var room = elder.get_parent()
	# Far away: nothing happens.
	level.player.global_position = level.rooms[level.layout.start_cell].global_position + Vector2(240, 140)
	for i in 30:
		await physics_frame
	_check(started.is_empty(), "he says nothing while Nico is elsewhere")

	# Inside his room but still far: nothing yet (both must be on screen).
	level.player.global_position = elder.global_position + Vector2(180, 40)
	for i in 80:
		await physics_frame
	_check(started.is_empty() and room.player_inside, "walking into his room is not enough: he waits until Nico is close")
	# Close enough to see both: the conversation starts by itself after the greeting delay.
	level.player.global_position = elder.global_position + Vector2(60, 10)
	for i in 10:
		await physics_frame
	_check(started.is_empty(), "he waits a beat before speaking")
	for i in 80:
		await physics_frame
	_check(started == [&"elder"] and dialogue.active, "then the Anciano and Nico talk at once")
	_check(level.player._locked, "Nico stands still while they talk")
	dialogue._finish()
	await physics_frame
	_check(state.has_flag(&"met_elder") and not level.player._locked, "when they are done the island remembers and Nico is free")

	# Leaving and coming back: they have met, so he waits to be talked to.
	level.player.global_position = level.rooms[level.layout.start_cell].global_position + Vector2(240, 140)
	for i in 20:
		await physics_frame
	level.player.global_position = elder.global_position + Vector2(60, 10)
	for i in 120:
		await physics_frame
	_check(started == [&"elder"] and not dialogue.active, "he does not greet Nico a second time")

	state.reset()
	level.queue_free()
	await process_frame
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
