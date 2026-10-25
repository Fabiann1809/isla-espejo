extends SceneTree
## Enemy mix of a room: the pool is shared out by its weights (the director's, or equal) without the
## repeats of drawing with replacement, and over many rooms each enemy keeps its expected share.
## Before (one independent draw per spot, 3000 rooms of 2-6): 1763 rooms over their fair share and
## 112 rooms of 3+ with a single kind. Run: godot --headless --path . --script res://tests/test_enemy_mix.gd

const ROOMS := 3000

var _ok := true


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var room_script: Script = load("res://scripts/world/room.gd")
	var scenario: Resource = load("res://data/scenarios/forest.tres")
	var pool: Array[PackedScene] = scenario.enemy_pool
	var plan_script: Script = load("res://scripts/ai/director_plan.gd")

	var neutral = plan_script.neutral()
	var even := _measure(room_script, pool, neutral)
	print("equal weights: %s" % even)
	_check(even.over_share == 0, "no room gets more of one enemy than its fair share (%d of %d rooms)"
			% [even.over_share, ROOMS])
	_check(even.max_share_error < 0.02, "each enemy keeps its expected share (worst error %.3f)" % even.max_share_error)

	# With director weights the shares follow them (here 3:1:1).
	var weighted = plan_script.neutral()
	weighted.enemy_weights = {&"murcielago": 3.0}
	var biased := _measure(room_script, pool, weighted)
	print("weights 3:1:1: %s" % biased)
	_check(biased.max_share_error < 0.02, "director weights are respected (worst error %.3f)" % biased.max_share_error)

	# Without sprite_frames an enemy is drawn as a red square.
	var missing: Array[String] = []
	for scene in pool:
		var enemy = scene.instantiate()
		if enemy.data == null or enemy.data.sprite_frames == null:
			missing.append(_id(scene))
		enemy.free()
	_check(missing.is_empty(), "every enemy of the forest pool has its art (missing: %s)" % [missing])

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _measure(room_script: Script, pool: Array[PackedScene], plan) -> Dictionary:
	# One generator for every room, as in a map (consecutive seeds give correlated first draws).
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261025
	var totals := {}
	var expected := {}
	var weight_sum := 0.0
	for scene in pool:
		weight_sum += plan.enemy_weight(_id(scene))
	var over_share := 0
	var all_same := 0
	var spots := 0
	for i in ROOMS:
		var count := rng.randi_range(2, 6)
		var picks: Array = room_script.pick_enemies(pool, count, rng, plan)
		spots += count
		var in_room := {}
		for scene in picks:
			in_room[scene] = in_room.get(scene, 0) + 1
			totals[scene] = totals.get(scene, 0) + 1
		var over := false
		for scene in pool:
			var share: float = count * plan.enemy_weight(_id(scene)) / weight_sum
			expected[scene] = expected.get(scene, 0.0) + share
			over = over or in_room.get(scene, 0) > ceili(share)
		if over:
			over_share += 1
		if in_room.size() == 1 and count >= 3:
			all_same += 1
	var max_error := 0.0
	for scene in pool:
		max_error = maxf(max_error, absf(totals.get(scene, 0) - expected[scene]) / spots)
	return {"over_share": over_share, "all_same_3plus": all_same, "max_share_error": max_error}


func _id(scene: PackedScene) -> StringName:
	return StringName(scene.resource_path.get_file().get_basename())


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
