extends SceneTree
## Dying loses the whole journey (resources, skills, fragments, flags and the saved chapter); only
## the player profile, which is what the island learned, is kept.
## Run: godot --headless --path . --script res://tests/test_death.gd

var _ok := true


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	root.get_node("PlayerProfile").persistence_enabled = false
	var state = root.get_node("GameState")
	var save = root.get_node("SaveGame")
	state.reset()

	var level: Node2D = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.seed_value = 77
	level.use_director = false
	root.add_child(level)
	await _frames(5)
	var player = level.player

	state.collect_fragment(&"green")
	state.learn_skill(&"roots")
	state.set_flag(&"forest_boss_defeated")
	state.apply_to_player(player)
	player.add_gold(7)
	load("res://data/resources/arrows.tres").apply(player)
	_check(player.gold == 7 and player.skills.is_unlocked(0), "before dying Nico has gold, an orb and a skill")
	_check(save.scenario_id == &"forest", "the saved chapter is the forest")

	var shots_before: int = root.get_node("PlayerProfile").stats.shots
	player.die()
	await _frames(2)
	_check(player.gold == 0 and player._extra_arrows == 0, "dying drops the gold and the orb")
	_check(state.fragments.is_empty() and state.skills.is_empty() and state.flags.is_empty(),
			"dying drops fragments, skills and defeated bosses")
	_check(save.scenario_id == &"", "the saved chapter goes back to the beginning")
	_check(root.get_node("PlayerProfile").model != null, "the profile (what the island learned) is kept")

	level.free()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
