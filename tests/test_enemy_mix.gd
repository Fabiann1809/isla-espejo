extends SceneTree
## Enemy mix of a room, for every scenario in data/scenarios: the pool is shared out by its weights
## (the scenario's `enemy_weights` times the director's) without the repeats of one independent draw
## per spot, and over many rooms each enemy keeps its expected share.
## The same holds for the rooms of real generated maps of every scenario, so a change to how rooms
## spawn their enemies that stops using `Room.pick_enemies()` fails here.
## Before (one draw per spot, 3000 rooms of 2-6, equal weights): 1763 rooms over their fair share and
## 112 rooms of 3+ with a single kind. Run: godot --headless --path . --script res://tests/test_enemy_mix.gd

const ROOMS := 3000
const SCENARIOS := "res://data/scenarios/"
const MAPS := 25
const COMBAT := 1

var _ok := true


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var room_script: Script = load("res://scripts/world/room.gd")
	var plan_script: Script = load("res://scripts/ai/director_plan.gd")
	var scenarios := 0
	for file in DirAccess.get_files_at(SCENARIOS):
		if not file.ends_with(".tres"):
			continue
		var scenario: Resource = load(SCENARIOS + file)
		var pool: Array[PackedScene] = scenario.enemy_pool
		if pool.is_empty():
			continue
		scenarios += 1
		var base: Dictionary = scenario.enemy_weights
		var neutral := _measure(room_script, pool, base, plan_script.neutral())
		print("%s: %s" % [scenario.id, neutral])
		_check(neutral.over_share == 0, "%s: no room gets more of one enemy than its fair share (%d of %d rooms)"
				% [scenario.id, neutral.over_share, ROOMS])
		_check(neutral.max_share_error < 0.02, "%s: each enemy keeps the scenario's share (worst error %.3f)"
				% [scenario.id, neutral.max_share_error])

		# The director's weights multiply the scenario's (here 3x for the first enemy of the pool).
		var weighted = plan_script.neutral()
		weighted.enemy_weights = {_id(pool[0]): 3.0}
		var biased := _measure(room_script, pool, base, weighted)
		_check(biased.max_share_error < 0.02, "%s: the director's weights multiply the scenario's (worst error %.3f)"
				% [scenario.id, biased.max_share_error])

		# Without sprite_frames an enemy is drawn as a red square.
		var missing: Array[String] = []
		for scene in pool:
			var enemy = scene.instantiate()
			if enemy.data == null or enemy.data.sprite_frames == null:
				missing.append(_id(scene))
			enemy.free()
		_check(missing.is_empty() or scenario.id == &"test",
				"%s: every enemy of the pool has its art (missing: %s)" % [scenario.id, missing])
	_check(scenarios >= 1, "%d scenarios with enemies checked" % scenarios)
	await _check_real_maps()

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


## Builds MAPS maps of every scenario with the real Level and checks each combat room's enemies
## against its fair share of the scenario's weights (the mini boss room holds only the mini boss).
func _check_real_maps() -> void:
	var level = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.use_director = false
	root.add_child(level)
	await physics_frame
	for file in DirAccess.get_files_at(SCENARIOS):
		if not file.ends_with(".tres"):
			continue
		var scenario: Resource = load(SCENARIOS + file)
		if scenario.enemy_pool.is_empty():
			continue
		level.scenario = scenario
		var base: Dictionary = scenario.enemy_weights
		var weights := {}
		var weight_sum := 0.0
		for scene in scenario.enemy_pool:
			weights[_id(scene)] = float(base.get(_id(scene), 1.0))
			weight_sum += weights[_id(scene)]
		var rooms := 0
		var over := []
		for map_seed in MAPS:
			level.generate(map_seed + 1)
			for coord in level.layout.cells:
				if level.layout.cells[coord].type != COMBAT or coord == level._guard_cell:
					continue
				var in_room := {}
				var count := 0
				for child in level.rooms[coord].get_children():
					if child.is_in_group("enemies"):
						count += 1
						var id := StringName(child.scene_file_path.get_file().get_basename())
						in_room[id] = in_room.get(id, 0) + 1
				if count == 0:
					continue
				rooms += 1
				for id in in_room:
					if in_room[id] > ceili(count * weights.get(id, 0.0) / weight_sum):
						over.append("seed %d %s: %s" % [map_seed + 1, coord, in_room])
						break
		_check(rooms > 0 and over.is_empty(), "%s: real maps spawn each room's fair share (%d rooms, over: %s)"
				% [scenario.id, rooms, over.slice(0, 3)])
	level.free()


func _measure(room_script: Script, pool: Array[PackedScene], base: Dictionary, plan) -> Dictionary:
	# One generator for every room, as in a map (consecutive seeds give correlated first draws).
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261025
	var weights := {}
	var weight_sum := 0.0
	for scene in pool:
		weights[scene] = float(base.get(_id(scene), 1.0)) * plan.enemy_weight(_id(scene))
		weight_sum += weights[scene]
	var totals := {}
	var expected := {}
	var over_share := 0
	var spots := 0
	for i in ROOMS:
		var count := rng.randi_range(2, 6)
		var picks: Array = room_script.pick_enemies(pool, count, rng, plan, base)
		spots += count
		var in_room := {}
		for scene in picks:
			in_room[scene] = in_room.get(scene, 0) + 1
			totals[scene] = totals.get(scene, 0) + 1
		var over := false
		for scene in pool:
			var share: float = count * weights[scene] / weight_sum
			expected[scene] = expected.get(scene, 0.0) + share
			over = over or in_room.get(scene, 0) > ceili(share)
		if over:
			over_share += 1
	var max_error := 0.0
	for scene in pool:
		max_error = maxf(max_error, absf(totals.get(scene, 0) - expected[scene]) / spots)
	return {"over_share": over_share, "max_share_error": max_error}


func _id(scene: PackedScene) -> StringName:
	return StringName(scene.resource_path.get_file().get_basename())


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
