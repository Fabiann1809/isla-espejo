extends SceneTree
## HUD polish: pixel hearts, the boss bar's damage trail and the boss name card that opens a fight.
## Run: godot --headless --path . --script res://tests/test_hud.gd

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var events = root.get_node("Events")
	var hud = load("res://scenes/ui/hud.tscn").instantiate()
	root.add_child(hud)
	await process_frame

	events.player_health_changed.emit(3, 5)
	await process_frame
	var hearts: Array = hud.get_node("Margin/Hearts").get_children().filter(
			func(n: Node) -> bool: return not n.is_queued_for_deletion())
	_check(hearts.size() == 5 and hearts.all(func(h: Node) -> bool: return h is TextureRect),
			"one pixel heart icon per heart of health")
	_check(hearts[2].texture != hearts[3].texture, "full and empty hearts look different")

	events.boss_health_changed.emit(&"forest_guardian", 90, 90, "Guardián del bosque")
	await process_frame
	_check(hud.get_node_or_null("BossCard") != null, "the boss's name card opens its fight")
	var fill: ColorRect = hud.get_node("BossBar/Track/Fill")
	var trail: ColorRect = hud.get_node("BossBar/Track/Trail")
	events.boss_health_changed.emit(&"forest_guardian", 45, 90, "Guardián del bosque")
	await process_frame
	_check(is_equal_approx(fill.anchor_right, 0.5) and trail.anchor_right > 0.9,
			"a hit empties the bar at once and leaves a pale trail of the damage")
	await create_timer(1.0).timeout
	_check(is_equal_approx(trail.anchor_right, 0.5), "the trail catches up with the bar")
	await create_timer(3.0).timeout
	_check(hud.get_node_or_null("BossCard") == null, "the name card goes away by itself")
	events.boss_health_changed.emit(&"forest_guardian", 40, 90, "Guardián del bosque")
	await process_frame
	_check(hud.get_node_or_null("BossCard") == null, "the card is shown once per boss, not on every hit")
	# The controls hint: shown when the first island starts, gone after a shot and a dodge.
	var hint: Label = hud.get_node("ControlsHint")
	events.level_started.emit(&"forest", 1)
	_check(hint.visible and hint.text != "", "the first island starts with the controls hint")
	events.player_shot.emit(Vector2.RIGHT, -1.0)
	_check(hint.visible, "one shot is not enough to hide it")
	events.player_dashed.emit(Vector2.RIGHT)
	await create_timer(2.2).timeout
	_check(not hint.visible, "after shooting and dodging the hint fades away")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
