extends SceneTree
## Patrols on a real forest map, with the director's widest patrols (x2): enemies stay inside their
## own room and none keeps walking into a tree or a wall. Before the fix 80 patrols got stuck in two
## maps (tools/measure_enemies.gd). Run: godot --headless --path . --script res://tests/test_enemy_patrol.gd

const SEEDS := [4242, 31337]
const SECONDS := 4.0
const PATROL := 1
const STUCK_TICKS := 60

var _ok := true


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var level = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.use_director = false
	level.seed_value = SEEDS[0]
	root.add_child(level)
	await _frames(2)
	# Nobody to chase: only patrols.
	level.player.remove_from_group("player")

	var outside := 0
	var stuck := 0
	var enemies_total := 0
	var homes_set := true
	for map_seed in SEEDS:
		level.generate(map_seed)
		await _frames(2)
		var enemies: Array = []
		for enemy in get_nodes_in_group("enemies"):
			if enemy.get("phase") == null and not enemy.is_queued_for_deletion():
				enemy.patrol_multiplier = 2.0
				enemies.append(enemy)
				homes_set = homes_set and enemy.home_area.has_area()
		enemies_total += enemies.size()
		var still := {}
		var last := {}
		var left := {}
		for tick in int(SECONDS * 60):
			await physics_frame
			for enemy in enemies:
				if not enemy.home_area.has_point(enemy.global_position):
					left[enemy] = true
				var moved: float = enemy.global_position.distance_to(last.get(enemy, enemy.global_position))
				last[enemy] = enemy.global_position
				still[enemy] = still.get(enemy, 0) + 1 if enemy.state == PATROL and moved < 0.05 else 0
				if still[enemy] == STUCK_TICKS:
					stuck += 1
		outside += left.size()
	_check(enemies_total > 0 and homes_set, "every enemy knows its room (%d enemies)" % enemies_total)
	_check(outside == 0, "patrols stay inside their room (%d left it)" % outside)
	_check(stuck == 0, "no patrol keeps walking into an obstacle (%d stuck for 1 s)" % stuck)
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
