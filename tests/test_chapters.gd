extends SceneTree
## The chapters are chained: the forest's exit leads to the ruins, whose map is built in the same level with
## its own theme and tileset, and the player keeps what the boss gave.
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
	_check(forest.next_scenario == ruins, "the forest leads to the ruins")
	_check(ruins.next_scenario == null, "and the ruins are the last chapter so far")

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
	level.free()
	quit(0 if _ok else 1)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
