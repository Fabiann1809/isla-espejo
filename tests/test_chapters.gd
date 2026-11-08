extends SceneTree
## The chapters are chained: the forest's exit leads to the ruins, whose map is built in the same level with
## its own theme and tileset, the ruins lead to the temple (the last chapter), and the player keeps what the
## boss gave.
## `Level` and other autoload-using types must not be referenced here (autoload compile order).
## Run: godot --headless --path . --script res://tests/test_chapters.gd

var _ok := true


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var events = root.get_node("Events")
	var forest: Resource = load("res://data/scenarios/forest.tres")
	var ruins: Resource = load("res://data/scenarios/ruins.tres")
	var temple: Resource = load("res://data/scenarios/temple.tres")
	_check(forest.next_scenario == ruins, "the forest leads to the ruins")
	_check(temple != null and ruins.next_scenario == temple, "the ruins lead to the temple")
	_check(temple != null and temple.next_scenario == null, "and the temple is the last chapter")

	var level: Node2D = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.seed_value = 11
	level.completion_delay = 0.05
	root.add_child(level)
	await _frames(3)
	_check(level.scenario.id == &"forest", "the level starts in the forest")
	var ended := {"count": 0}
	level.journey_ended.connect(func() -> void: ended.count += 1)
	var builds := {"count": 0}
	level.generated.connect(func(_layout) -> void: builds.count += 1)
	events.scenario_completed.emit(&"forest")
	await create_timer(2.5).timeout
	_check(level.scenario.id == &"ruins", "taking the forest's exit makes the ruins the scenario")
	_check(builds.count == 1 and ended.count == 0, "a new map is built and the journey goes on")
	var shapes := 0
	for room in level.rooms.values():
		if room.get_node_or_null("Shape") != null:
			shapes += 1
	_check(shapes == level.rooms.size() and shapes > 3, "every room of the new map is a ruin cave (%d)" % shapes)
	_check(level.get_node_or_null("Map/Backdrop/Rock") != null, "with the ruins' rock around it")
	# The ruins end with their boss: the portal stays sealed until the serpent dies, then leads on.
	var serpent: Node2D = null
	for enemy in get_nodes_in_group("enemies"):
		if enemy.get("data") != null and enemy.data.id == &"stone_serpent":
			serpent = enemy
	_check(serpent != null and level.scenario.boss_scene != null, "the ruins' boss room holds the stone serpent")
	var portals := get_nodes_in_group("exit_portals")
	_check(portals.size() == 1 and level.scenario.objective_flag == &"ruins_boss_defeated"
			and portals[0].required_flag == &"ruins_boss_defeated", "the ruins' portal waits for ruins_boss_defeated")
	_check(portals.size() == 1 and not portals[0].is_open(), "the ruins' portal is sealed while the serpent lives")
	if serpent != null and portals.size() == 1:
		var done := {"scenarios": []}
		events.scenario_completed.connect(func(id: StringName) -> void: done.scenarios.append(id))
		portals[0].get_node("Use").interact(null)
		_check(done.scenarios.is_empty(), "using the sealed portal does not leave the ruins")
		serpent.get_node("Hurtbox").receive_hit(999, serpent.global_position)
		await _frames(3)
		_check(portals[0].is_open(), "the portal opens when the serpent dies")
		portals[0].get_node("Use").interact(null)
		await create_timer(2.5).timeout
		_check(done.scenarios == [&"ruins"] and level.scenario == temple, "and it leads to the temple")
	level.free()
	quit(0 if _ok else 1)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
