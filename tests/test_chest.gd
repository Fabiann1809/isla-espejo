extends SceneTree
## Chests give a random prize: health, gold or a free shop upgrade; the roll is seedable, a health prize
## at full health becomes gold and an upgrade prize with everything maxed becomes gold.
## Run: godot --headless --path . --script res://tests/test_chest.gd

var _ok := true
var _state: Node
var _player: Node


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_state = root.get_node("GameState")
	_state.reset()
	var room: Node = load("res://scenes/levels/test_room.tscn").instantiate()
	root.add_child(room)
	for i in 3:
		await process_frame
	_player = room.get_node("Player")
	_player.add_gold(-_player.gold)

	var ui_text: GDScript = load("res://scripts/core/ui_text.gd")
	var texts: Dictionary = {}
	for key in ["chest_heal", "chest_gold", "chest_upgrade"]:
		texts[key] = ui_text.t(key)
	_check(texts["chest_gold"].contains("%d") and texts["chest_upgrade"].contains("%s"), "the prize lines are in texts.json")

	var scene: PackedScene = load("res://scenes/world/chest.tscn")
	var base: Node = scene.instantiate()
	_check(is_equal_approx(base.weight_heal, 65.0) and is_equal_approx(base.weight_gold, 30.0)
			and is_equal_approx(base.weight_upgrade, 5.0), "default odds 65 / 30 / 5 are data on the chest")
	base.free()

	# Health.
	_player.health.take_damage(3)
	var before: int = _player.health.current
	var chest := _chest(scene, 1.0, 0.0, 0.0)
	var line: String = chest.give_prize(_player)
	_check(chest.prize == 0 and _player.health.current == before + chest.heal_amount, "a health prize heals")
	_check(line == texts["chest_heal"] % chest.heal_amount, "and says so (%s)" % line)

	# Health at full life becomes gold.
	_player.health.heal(100)
	var gold_before: int = _player.gold
	chest = _chest(scene, 1.0, 0.0, 0.0)
	chest.give_prize(_player)
	_check(chest.prize == 1 and _player.gold >= gold_before + chest.gold_min and _player.gold <= gold_before + chest.gold_max,
			"at full health a health roll gives gold instead (%d -> %d)" % [gold_before, _player.gold])

	# Gold, through the gold event.
	var totals: Array[int] = []
	root.get_node("Events").player_gold_changed.connect(func(total: int) -> void: totals.append(total))
	gold_before = _player.gold
	chest = _chest(scene, 0.0, 1.0, 0.0)
	line = chest.give_prize(_player)
	var gained: int = _player.gold - gold_before
	_check(chest.prize == 1 and gained >= 4 and gained <= 8 and totals.back() == _player.gold, "a gold prize adds 4-8 coins and announces it")
	_check(line == texts["chest_gold"] % gained, "with its own line (%s)" % line)

	# Upgrade.
	chest = _chest(scene, 0.0, 0.0, 1.0)
	var changes: Array = []
	_state.upgrade_changed.connect(func(id: StringName, level: int) -> void: changes.append([id, level]))
	line = chest.give_prize(_player)
	_check(chest.prize == 2 and changes.size() == 1 and _state.upgrade_level(chest.upgrade_given) == 1
			and changes[0][0] == chest.upgrade_given, "an upgrade prize raises one shop upgrade and announces it")
	var catalog: Resource = load("res://data/shop/items.tres")
	var given_name := ""
	for item in catalog.items:
		if item.upgrade_id == chest.upgrade_given:
			given_name = item.display_name
	_check(line == texts["chest_upgrade"] % given_name, "with its own line (%s)" % line)

	# Maxed fallback.
	for item in catalog.items:
		if item.kind == 2:
			while _state.upgrade_level(item.upgrade_id) < item.max_level:
				_state.add_upgrade(item.upgrade_id)
	changes.clear()
	gold_before = _player.gold
	chest = _chest(scene, 0.0, 0.0, 1.0)
	chest.give_prize(_player)
	_check(chest.prize == 1 and changes.is_empty() and _player.gold > gold_before, "with every upgrade maxed an upgrade roll gives gold")

	# Seeded rolls repeat and follow the odds.
	_state.reset()
	_check(_sequence(scene, 77) == _sequence(scene, 77), "the same seed gives the same prizes")
	var counts := [0, 0, 0]
	var sample: Node = scene.instantiate()
	sample.rng.seed = 5
	for i in 2000:
		counts[sample._roll()] += 1
	sample.free()
	_check(counts[0] > counts[1] and counts[1] > counts[2] and counts[2] > 0 and counts[0] > 1100 and counts[0] < 1500,
			"health is most likely, then gold, then rarely an upgrade %s" % [counts])

	_state.reset()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _chest(scene: PackedScene, heal: float, gold: float, upgrade: float) -> Node:
	var chest: Node = scene.instantiate()
	chest.weight_heal = heal
	chest.weight_gold = gold
	chest.weight_upgrade = upgrade
	chest.rng.seed = 11
	return chest


func _sequence(scene: PackedScene, seed_value: int) -> Array:
	var out: Array = []
	var chest: Node = scene.instantiate()
	chest.rng.seed = seed_value
	for i in 30:
		out.append(chest._roll())
	chest.free()
	return out


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
	else:
		print("FAIL: ", label)
		_ok = false
