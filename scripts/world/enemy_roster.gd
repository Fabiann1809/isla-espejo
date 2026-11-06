class_name EnemyRoster
extends RefCounted
## Which enemies a run fields. A scenario with many enemies (the temple) gives each map a subset of
## `roster_size` of them, drawn by the map's seed and weighted by the scenario's `enemy_weights`
## times the director's, so every run meets a different cast and the same seed always meets the
## same one. Pure logic (no nodes). An enemy's id is the file name of its scene.

## Added to the map seed, so the roster's draws never move the layout's or the rooms' (seed + 1
## fills the rooms, seed + 2 the drops).
const SEED_OFFSET := 3


## `size` distinct scenes of `pool`, without replacement, each draw weighted by
## `base_weights[id] * plan.enemy_weight(id)` (a missing id counts as 1). `size <= 0` or a size at
## or over the pool keeps the whole pool in its order. A weight of 0 is never picked: when fewer
## than `size` enemies weigh anything the roster is smaller; when none does, all weigh the same.
static func pick(pool: Array[PackedScene], size: int, map_seed: int, base_weights: Dictionary,
		plan: DirectorPlan) -> Array[PackedScene]:
	if size <= 0 or size >= pool.size():
		return pool.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed + SEED_OFFSET
	var remaining: Array[PackedScene] = pool.duplicate()
	var weights: Array[float] = []
	var total := 0.0
	for scene in remaining:
		var id := enemy_id(scene)
		var weight := maxf(float(base_weights.get(id, 1.0)), 0.0)
		if plan != null:
			weight *= maxf(plan.enemy_weight(id), 0.0)
		weights.append(weight)
		total += weight
	if total <= 0.0:
		weights.fill(1.0)

	var picks: Array[PackedScene] = []
	while picks.size() < size:
		# The total is summed again from what is left: subtracting the picked weight would drift
		# (1e-16 instead of 0) and let a weight of 0 through once the positive ones are gone.
		var index := _draw(weights, rng)
		if index < 0:
			break
		picks.append(remaining[index])
		remaining.remove_at(index)
		weights.remove_at(index)
	return picks


## The base weights of one room: the scenario's `enemy_weights` times the room's `enemy_affinity`
## (enemy id -> multiplier), a missing id counting as 1 on either side.
static func room_weights(scenario_weights: Dictionary, affinity: Dictionary) -> Dictionary:
	var weights := scenario_weights.duplicate()
	for id in affinity:
		weights[id] = float(weights.get(id, 1.0)) * float(affinity[id])
	return weights


static func enemy_id(scene: PackedScene) -> StringName:
	return StringName(scene.resource_path.get_file().get_basename())


## One weighted draw among the weights above 0, or -1 when none is left. A roll that lands past
## every weight (rounding) still picks the last one that weighs something.
static func _draw(weights: Array[float], rng: RandomNumberGenerator) -> int:
	var total := 0.0
	var last_positive := -1
	for i in weights.size():
		if weights[i] > 0.0:
			total += weights[i]
			last_positive = i
	if last_positive < 0:
		return -1
	var roll := rng.randf() * total
	for i in weights.size():
		if weights[i] <= 0.0:
			continue
		roll -= weights[i]
		if roll < 0.0:
			return i
	return last_positive
