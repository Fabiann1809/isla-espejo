extends SceneTree
## Enemy roster per run (scripts/world/enemy_roster.gd): a map fields `roster_size` distinct enemies
## of the scenario's pool, drawn by the seed and weighted by the scenario's and the director's
## weights; size 0 keeps the whole pool (the forest and the ruins). A room's base weights are the
## scenario's times its `enemy_affinity`.
## Run: godot --headless --path . --script res://tests/test_enemy_roster.gd

const ENEMIES := ["slime", "planta_tiradora", "esqueleto", "grunt", "ente", "bestia_de_la_niebla",
		"sombra_errante", "murcielago"]

var _ok := true
var _roster: Script
var _plan_script: Script


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	_roster = load("res://scripts/world/enemy_roster.gd")
	_plan_script = load("res://scripts/ai/director_plan.gd")
	var pool: Array[PackedScene] = []
	for id in ENEMIES:
		pool.append(load("res://scenes/enemies/%s.tscn" % id))

	# --- size 0 (or the whole pool) keeps the pool as it is
	var whole: Array = _roster.pick(pool, 0, 7, {}, _plan_script.neutral())
	_check(whole == pool, "size 0 keeps the whole pool")
	var big: Array = _roster.pick(pool, pool.size() + 2, 7, {}, _plan_script.neutral())
	_check(big == pool, "a size at or over the pool keeps the whole pool in order")

	# --- a roster has `size` distinct enemies
	var picked: Array = _roster.pick(pool, 4, 11, {}, _plan_script.neutral())
	_check(picked.size() == 4 and _ids(picked).size() == 4, "a roster has size distinct enemies (%s)" % [_ids(picked)])
	var all_in_pool := true
	for scene in picked:
		all_in_pool = all_in_pool and pool.has(scene)
	_check(all_in_pool, "every enemy of the roster comes from the pool")

	# --- determinism
	var again: Array = _roster.pick(pool, 4, 11, {}, _plan_script.neutral())
	_check(again == picked, "same seed same roster")

	# --- variety over seeds
	var sets := {}
	for map_seed in range(1, 21):
		sets[_key(_roster.pick(pool, 4, map_seed, {}, _plan_script.neutral()))] = true
	_check(sets.size() >= 15, "different seeds give different rosters over 20 seeds (%d distinct)" % sets.size())

	# --- weight 0 never picked (scenario weight and director weight alike)
	var grunt_seen := 0
	var ente_seen := 0
	var zero_plan = _plan_script.neutral()
	zero_plan.enemy_weights = {&"ente": 0.0}
	for map_seed in range(1, 51):
		var roster: Array = _roster.pick(pool, 6, map_seed, {&"grunt": 0.0}, zero_plan)
		if _ids(roster).has(&"grunt"):
			grunt_seen += 1
		if _ids(roster).has(&"ente"):
			ente_seen += 1
	_check(grunt_seen == 0 and ente_seen == 0, "weight 0 never picked (grunt %d, ente %d of 50)" % [grunt_seen, ente_seen])

	# --- heavier enemies appear more often
	var heavy_plan = _plan_script.neutral()
	heavy_plan.enemy_weights = {&"esqueleto": 4.0}
	var counts := {}
	for map_seed in range(1, 501):
		for id in _ids(_roster.pick(pool, 3, map_seed, {&"slime": 5.0}, heavy_plan)):
			counts[id] = counts.get(id, 0) + 1
	var light := 0
	for id in ENEMIES:
		if id != "slime" and id != "esqueleto":
			light = maxi(light, counts.get(StringName(id), 0))
	_check(counts.get(&"slime", 0) > light * 2 and counts.get(&"esqueleto", 0) > light * 2,
			"heavier enemies appear more often over 500 seeds (slime %d, esqueleto %d, heaviest other %d)"
			% [counts.get(&"slime", 0), counts.get(&"esqueleto", 0), light])

	# --- room affinity multiplies the scenario weight
	var weights: Dictionary = _roster.room_weights({&"a": 2.0, &"b": 0.5}, {&"b": 4.0, &"c": 3.0})
	_check(weights == {&"a": 2.0, &"b": 2.0, &"c": 3.0},
			"room affinity multiplies the scenario weight (missing ids count as 1): %s" % [weights])
	_check(_roster.room_weights({&"a": 2.0}, {}) == {&"a": 2.0}, "no affinity keeps the scenario's weights")

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _ids(scenes: Array) -> Array[StringName]:
	var ids: Array[StringName] = []
	for scene in scenes:
		var id := StringName(scene.resource_path.get_file().get_basename())
		if not ids.has(id):
			ids.append(id)
	return ids


func _key(scenes: Array) -> String:
	var ids := _ids(scenes)
	ids.sort()
	return ",".join(ids)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
