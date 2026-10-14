class_name MapGenerator
extends RefCounted
## Procedural map generator. Same scenario + same seed always gives the same layout.
##
## 1. A random walk from the start (bottom row) to the boss (top row) makes the main path.
## 2. Side rooms (dead ends) branch off it, and a few extra doors may create loops.
## 3. Special rooms (event, reward, special) are assigned to fitting cells.
## 4. Every cell gets a concrete room, weighted by the room data and the director's modifiers.

const MAX_PATH_ATTEMPTS := 300
## Picking a room again is less likely each time it was already used, for variety.
const REPEAT_PENALTY := 0.4


## `weight_modifiers` maps a room tag to a multiplier (e.g. {&"ambush": 2.0}); this is how the
## adaptive AI steers which rooms appear.
static func generate(scenario: ScenarioData, map_seed: int, weight_modifiers := {}) -> MapLayout:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed

	var layout := MapLayout.new()
	layout.map_seed = map_seed
	layout.scenario = scenario
	layout.grid_size = scenario.grid_size

	_place_main_path(layout, scenario, rng)
	_place_side_rooms(layout, scenario, rng)
	_add_loops(layout, scenario, rng)
	_assign_types(layout, scenario, rng)
	_assign_rooms(layout, scenario, rng, weight_modifiers)
	return layout


# --- 1. Main path ---------------------------------------------------------------

static func _place_main_path(layout: MapLayout, scenario: ScenarioData, rng: RandomNumberGenerator) -> void:
	var size := scenario.grid_size
	layout.start_cell = Vector2i(rng.randi_range(0, size.x - 1), size.y - 1)
	layout.boss_cell = Vector2i(rng.randi_range(0, size.x - 1), 0)

	var path: Array[Vector2i] = []
	for attempt in MAX_PATH_ATTEMPTS:
		path = _random_walk(layout, scenario, rng)
		if path.size() >= scenario.min_main_path:
			break
		path = []
	if path.is_empty():
		path = _straight_path(layout)

	layout.main_path = path
	for i in path.size():
		layout.add_cell(path[i])
		if i > 0:
			layout.connect_cells(path[i - 1], path[i])


static func _random_walk(layout: MapLayout, scenario: ScenarioData, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var path: Array[Vector2i] = [layout.start_cell]
	var visited := {layout.start_cell: true}
	var current := layout.start_cell
	while current != layout.boss_cell:
		var options: Array[Vector2i] = []
		var weights: Array[float] = []
		for dir in MapLayout.DIRS:
			var next := current + dir
			if not layout.in_grid(next) or visited.has(next):
				continue
			# Prune walks that can no longer reach the boss within the length limit.
			if path.size() + 1 + _manhattan(next, layout.boss_cell) > scenario.max_main_path:
				continue
			options.append(next)
			weights.append(_step_weight(dir, current, layout.boss_cell))
		if options.is_empty():
			return []
		current = options[_weighted_index(weights, rng)]
		visited[current] = true
		path.append(current)
	return path


## Prefers going up (toward the boss row) and toward the boss column.
static func _step_weight(dir: Vector2i, current: Vector2i, boss: Vector2i) -> float:
	if dir == Vector2i.UP:
		return 3.0
	if dir == Vector2i.DOWN:
		return 0.4
	var toward_boss := signi(boss.x - current.x)
	if toward_boss == 0:
		return 1.0
	return 2.0 if dir.x == toward_boss else 0.6


## Guaranteed fallback: along the bottom row to the boss column, then straight up.
static func _straight_path(layout: MapLayout) -> Array[Vector2i]:
	var path: Array[Vector2i] = [layout.start_cell]
	var current := layout.start_cell
	while current.x != layout.boss_cell.x:
		current.x += signi(layout.boss_cell.x - current.x)
		path.append(current)
	while current.y != layout.boss_cell.y:
		current.y -= 1
		path.append(current)
	return path


# --- 2. Side rooms and loops ------------------------------------------------------

static func _place_side_rooms(layout: MapLayout, scenario: ScenarioData, rng: RandomNumberGenerator) -> void:
	for i in scenario.side_rooms:
		var candidates: Array = []
		for coord: Vector2i in layout.cells:
			if coord == layout.boss_cell:
				continue
			for dir in MapLayout.DIRS:
				var next: Vector2i = coord + dir
				if layout.in_grid(next) and not layout.has_cell(next):
					candidates.append([coord, next])
		if candidates.is_empty():
			return
		var pick: Array = candidates[rng.randi_range(0, candidates.size() - 1)]
		layout.add_cell(pick[1])
		layout.connect_cells(pick[0], pick[1])


static func _add_loops(layout: MapLayout, scenario: ScenarioData, rng: RandomNumberGenerator) -> void:
	for coord: Vector2i in layout.cells.keys():
		for dir in [Vector2i.RIGHT, Vector2i.DOWN]:
			var other: Vector2i = coord + dir
			if not layout.has_cell(other) or layout.are_connected(coord, other):
				continue
			if coord == layout.boss_cell or other == layout.boss_cell:
				continue
			if rng.randf() < scenario.loop_chance:
				layout.connect_cells(coord, other)


# --- 3. Room types ------------------------------------------------------------------

static func _assign_types(layout: MapLayout, scenario: ScenarioData, rng: RandomNumberGenerator) -> void:
	for cell: MapLayout.Cell in layout.cells.values():
		cell.type = RoomData.RoomType.COMBAT
	layout.get_cell(layout.start_cell).type = RoomData.RoomType.START
	layout.get_cell(layout.boss_cell).type = RoomData.RoomType.BOSS

	var dist := layout.distances_from(layout.start_cell)

	# Event rooms sit along the main path, evenly spread between start and boss.
	var interior: Array[Vector2i] = []
	for i in range(1, layout.main_path.size() - 1):
		interior.append(layout.main_path[i])
	for i in scenario.event_rooms:
		if interior.is_empty():
			break
		var index := (i + 1) * interior.size() / (scenario.event_rooms + 1)
		var coord := interior[clampi(index, 0, interior.size() - 1)]
		if layout.get_cell(coord).type != RoomData.RoomType.COMBAT:
			coord = _first_combat(layout, interior)
		layout.get_cell(coord).type = RoomData.RoomType.EVENT

	# Reward and special rooms prefer dead ends far from the start.
	var dead_ends: Array[Vector2i] = []
	var others: Array[Vector2i] = []
	for coord: Vector2i in layout.cells:
		var cell := layout.get_cell(coord)
		if cell.type != RoomData.RoomType.COMBAT:
			continue
		if cell.doors.size() == 1:
			dead_ends.append(coord)
		else:
			others.append(coord)
	# Far dead ends first; the random fraction only breaks ties (keys are drawn once, in order).
	var keys := {}
	for coord in dead_ends:
		keys[coord] = dist[coord] + rng.randf() * 0.5
	dead_ends.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return keys[a] > keys[b])
	_shuffle(others, rng)
	var spots: Array[Vector2i] = dead_ends + others
	var wanted: Array[RoomData.RoomType] = []
	for i in scenario.reward_rooms:
		wanted.append(RoomData.RoomType.REWARD)
	for i in scenario.special_rooms:
		wanted.append(RoomData.RoomType.SPECIAL)
	for i in mini(wanted.size(), spots.size()):
		layout.get_cell(spots[i]).type = wanted[i]


static func _first_combat(layout: MapLayout, coords: Array[Vector2i]) -> Vector2i:
	for coord in coords:
		if layout.get_cell(coord).type == RoomData.RoomType.COMBAT:
			return coord
	return coords[0]


# --- 4. Concrete rooms --------------------------------------------------------------

static func _assign_rooms(layout: MapLayout, scenario: ScenarioData, rng: RandomNumberGenerator,
		weight_modifiers: Dictionary) -> void:
	var used := {}
	# Fixed order so the result only depends on the seed.
	var coords: Array = layout.cells.keys()
	coords.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	for coord: Vector2i in coords:
		var cell := layout.get_cell(coord)
		match cell.type:
			RoomData.RoomType.START:
				cell.room_data = scenario.start_room
			RoomData.RoomType.BOSS:
				cell.room_data = scenario.boss_room
			_:
				cell.room_data = _pick_room(scenario, cell.type, rng, weight_modifiers, used)
				if cell.room_data != null:
					used[cell.room_data.id] = used.get(cell.room_data.id, 0) + 1


static func _pick_room(scenario: ScenarioData, type: RoomData.RoomType, rng: RandomNumberGenerator,
		weight_modifiers: Dictionary, used: Dictionary) -> RoomData:
	var pool: Array[RoomData] = []
	for room in scenario.rooms:
		if room.type == type:
			pool.append(room)
	if pool.is_empty():
		# No room of that type: fall back to a combat room so the map is still playable.
		for room in scenario.rooms:
			if room.type == RoomData.RoomType.COMBAT:
				pool.append(room)
	if pool.is_empty():
		return null

	var weights: Array[float] = []
	for room in pool:
		var weight := room.weight * pow(REPEAT_PENALTY, used.get(room.id, 0))
		for tag in room.tags:
			weight *= weight_modifiers.get(tag, 1.0)
		weights.append(maxf(weight, 0.0))
	return pool[_weighted_index(weights, rng)]


# --- Helpers ------------------------------------------------------------------------

static func _weighted_index(weights: Array[float], rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for weight in weights:
		total += weight
	if total <= 0.0:
		return rng.randi_range(0, weights.size() - 1)
	var roll := rng.randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll < 0.0:
			return i
	return weights.size() - 1


static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
