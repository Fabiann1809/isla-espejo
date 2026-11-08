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

	await _test_resources_and_upgrades(hud, events)

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
	# Saving shows a short note that goes away by itself.
	var saved: Label = hud.get_node("SavedNote")
	_check(not saved.visible, "no saved note before anything is saved")
	events.game_saved.emit()
	_check(saved.visible and saved.text != "", "saving shows a short note")
	await create_timer(2.4).timeout
	_check(not saved.visible, "the saved note goes away by itself")
	quit(0 if _ok else 1)


## Gold coin icon, the row of bought upgrades, the fragment icons and the skill slots.
func _test_resources_and_upgrades(hud: Node, events: Node) -> void:
	var state = root.get_node("GameState")
	state.reset()
	events.level_started.emit(&"forest", 1)
	await process_frame
	var coin: Node = hud.find_child("Coin", true, false)
	_check(coin is TextureRect and coin.texture != null, "the gold shows the coin icon, not a plain rectangle")
	events.player_gold_changed.emit(42)
	_check(hud._gold_label.text == "42", "the number is beside the coin")

	var row: Control = hud.get_node("Upgrades")
	_check(not row.visible, "no upgrades: the row is hidden")
	state.add_upgrade(&"crit_chance")
	_check(row.visible and row.get_child_count() == 1, "buying an upgrade shows it at once")
	var entry: Node = row.get_child(0)
	_check(entry.get_child(0) is TextureRect and entry.get_child(0).texture != null, "the entry has the shop icon")
	_check(entry.get_child(1).text == "Nv1", "the entry shows its level")
	state.add_upgrade(&"crit_chance")
	state.add_upgrade(&"max_health")
	await process_frame
	var labels: Array = row.get_children().filter(func(n: Node) -> bool: return not n.is_queued_for_deletion()).map(
			func(n: Node) -> String: return n.get_child(1).text)
	_check(labels == ["Nv2", "Nv1"] or labels == ["Nv1", "Nv2"], "two upgrades, each with its level (%s)" % [labels])
	_check(row.get_global_rect().end.x <= 480.0 and row.get_global_rect().end.y <= 270.0, "the row stays on screen")
	state.reset()
	events.level_started.emit(&"forest", 1)
	await process_frame
	_check(not row.visible, "a new journey (death) clears the row")

	for id in [&"green", &"blue", &"violet"]:
		_check(hud._fragment_icons[id] is Control, "fragment slot %s exists" % id)
	state.collect_fragment(&"green")
	events.fragment_collected.emit(&"green")
	var green: Control = hud._fragment_icons[&"green"]
	var blue: Control = hud._fragment_icons[&"blue"]
	if green is ColorRect:
		_check(green.color != blue.color, "without art a collected fragment is lit and the others dark")
	else:
		_check(green.modulate != blue.modulate, "with art a collected fragment is lit and the others dark")
	state.reset()
	events.fragment_collected.emit(&"green")

	var bar: Node = hud.get_node("SkillBar")
	_check(bar.get_child_count() == 3, "the skill bar has three slots")
	_check(not bar.slot_state(0).unlocked, "a slot without a skill reads as locked")
	var strip := StripArt.build("res://assets/sprites/shop/gold_coin.png")
	_check(strip != null and strip.sprite_frames.get_frame_count(&"default") == 1, "a square picture is a one-frame strip")
	strip.free()
	_check(StripArt.build("res://assets/sprites/pickups/does_not_exist.png") == null, "missing art builds nothing")


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
