extends SceneTree
## The end of the first island: taking the forest's exit ends the journey with the ending screen
## (the run's summary with the victory texts) instead of building another forest.
## `Level` and other autoload-using types must not be referenced here (autoload compile order).
## Run: godot --headless --path . --script res://tests/test_ending.gd

var _ok := true


func _initialize() -> void:
	create_timer(90.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var events = root.get_node("Events")
	var profile = root.get_node("PlayerProfile")
	var texts: Dictionary = profile.config.texts
	_check(texts.get("ending_line", "") != "" and texts.get("ending", "") != "" and texts.get("ending_continue", "") != "",
			"the ending texts live in the profile config")

	var level: Node2D = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.seed_value = 5
	level.completion_delay = 0.05
	root.add_child(level)
	await _frames(3)
	_check(level.end_after_last_chapter and level.scenario.next_scenario == null,
			"the forest is the last chapter and the real level ends the journey after it")
	var ended := {"count": 0}
	level.journey_ended.connect(func() -> void: ended.count += 1)
	var builds := {"count": 0}
	level.generated.connect(func(_layout) -> void: builds.count += 1)
	var panel: Control = level.get_node("ProfileSummary/Panel")
	_check(not panel.visible, "no summary while playing")

	profile.begin_run()
	events.scenario_completed.emit(&"forest")
	_check(not panel.visible, "finishing a chapter shows nothing before the veil falls")
	await create_timer(2.0).timeout
	_check(ended.count == 1, "taking the last exit ends the journey")
	_check(builds.count == 0, "no new forest is built after the last chapter")
	_check(panel.visible and level.get_node("ProfileSummary").ending_shown, "the ending screen is shown")
	var lines := _texts(level)
	_check(texts.ending_line in lines and texts.ending_continue in lines and not texts.continue in lines,
			"it speaks of the ending, not of trying again")

	events.scenario_completed.emit(&"forest")
	await create_timer(0.5).timeout
	_check(ended.count == 1, "the exit cannot end the journey twice")
	level.free()
	quit(0 if _ok else 1)


func _texts(level: Node) -> Array[String]:
	var texts: Array[String] = []
	for label in level.get_node("ProfileSummary/Panel/Margin/Content").find_children("*", "Label", true, false):
		if not label.is_queued_for_deletion():
			texts.append(label.text)
	return texts


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
