extends SceneTree
## A hit that cuts an attack short gives the enemy a short rest after its hurt
## (Tuning.INTERRUPTED_ATTACK_COOLDOWN), for every enemy of every scenario's pool and the mini bosses:
## it does not warn again the moment it recovers. A hit outside an attack changes nothing.
## Run: godot --headless --path . --script res://tests/test_enemy_interrupt.gd

const SCENARIOS := "res://data/scenarios/"
const ATTACK := 3

var _ok := true


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var tuning: Script = load("res://scripts/core/tuning.gd")
	var level = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.use_director = false
	level.seed_value = 4242
	root.add_child(level)
	await _frames(2)
	var player: Node2D = level.player
	var room: Node2D = level.rooms[level.layout.start_cell]

	var scenes := {}
	for file in DirAccess.get_files_at(SCENARIOS):
		if file.ends_with(".tres"):
			var scenario: Resource = load(SCENARIOS + file)
			for scene in scenario.enemy_pool:
				scenes[scene.resource_path] = scene
			if scenario.miniboss_scene != null:
				scenes[scenario.miniboss_scene.resource_path] = scenario.miniboss_scene
	var rested := []
	var too_soon := []
	var untouched := true
	for path in scenes:
		var enemy: Node2D = scenes[path].instantiate()
		enemy.position = Vector2(240, 144)
		room.add_child(enemy)
		await physics_frame
		player.global_position = enemy.global_position + Vector2(20, 0)
		enemy._acquire_target(player)
		# A hit outside an attack (it may have started one on its own: stop it first): no extra rest.
		enemy._enter_idle()
		var before: float = enemy._attack_cooldown_left
		enemy.get_node("Hurtbox").receive_hit(0, player.global_position)
		untouched = untouched and enemy._attack_cooldown_left <= before
		await _frames(int(enemy.data.hurt_time * 60) + 2)
		enemy._start_attack()
		var attacking: bool = enemy.state == ATTACK
		enemy.get_node("Hurtbox").receive_hit(0, player.global_position)
		var wanted: float = enemy.data.hurt_time + tuning.INTERRUPTED_ATTACK_COOLDOWN
		if attacking and enemy._attack_cooldown_left >= wanted - 0.001:
			rested.append(path.get_file())
		else:
			too_soon.append(path.get_file())
		enemy.free()
	_check(too_soon.is_empty() and rested.size() == scenes.size(),
			"every enemy rests %.1f s after its hurt when an attack is cut short (%s; failed: %s)"
			% [tuning.INTERRUPTED_ATTACK_COOLDOWN, rested, too_soon])
	_check(untouched, "a hit outside an attack adds no rest")
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
