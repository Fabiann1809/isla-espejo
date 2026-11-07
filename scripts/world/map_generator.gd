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
## The special room (the Mercader's shop) lies at least this many steps from the start.
const SPECIAL_MIN_DISTANCE := 3


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
	# The special room (the Mercader's shop) is picked first and far from the start: at least
	# SPECIAL_MIN_DISTANCE steps away and, when the map allows, in the second half of the run; never next
	# to the boss. The first spot of `spots` that fits wins (far dead ends come first); with none, the
	# farthest spot. Reward rooms then take the next spots.
	var half := (layout.main_path.size() - 1) >> 1
	var special := -1
	for need in [maxi(SPECIAL_MIN_DISTANCE, half), SPECIAL_MIN_DISTANCE]:
		for i in spots.size():
			var coord := spots[i]
			if dist[coord] >= need and not layout.are_connected(coord, layout.boss_cell):
				special = i
				break
		if special >= 0:
			break
	if special < 0:
		# Nothing far enough: the farthest spot, off the boss's side if any spot is.
		for avoid_boss in [true, false]:
			for i in spots.size():
				var coord := spots[i]
				if avoid_boss and layout.are_connected(coord, layout.boss_cell):
					continue
				if special < 0 or dist[coord] > dist[spots[special]]:
					special = i
			if special >= 0:
				break
	if scenario.special_rooms > 0 and special >= 0:
		layout.get_cell(spots[special]).type = RoomData.RoomType.SPECIAL
		spots.remove_at(special)
	for i in mini(scenario.reward_rooms, spots.size()):
		layout.get_cell(spots[i]).type = RoomData.RoomType.REWARD
	# No combat cell was left: turn the farthest cell that is not start, boss or event into the special room.
	if scenario.special_rooms > 0 and layout.count_of_type(RoomData.RoomType.SPECIAL) == 0:
		var far := Vector2i(-1, -1)
		for coord: Vector2i in layout.cells:
			var type := layout.get_cell(coord).type
			if type == RoomData.RoomType.START or type == RoomData.RoomType.BOSS or type == RoomData.RoomType.EVENT:
				continue
			if far.x < 0 or dist[coord] > dist[far] or (dist[coord] == dist[far] and (coord.x < far.x or (coord.x == far.x and coord.y < far.y))):
				far = coord
		if far.x >= 0:
			layout.get_cell(far).type = RoomData.RoomType.SPECIAL


static func _first_combat(layout: MapLayout, coords: Array[Vector2i]) -> Vector2i:
	for coord in coords:
		if layout.get_cell(coord).type == RoomData.RoomType.COMBAT:
			return coord
	return coords[0]


# --- 4. Concrete rooms --------------------------------------------------------------

## A corridor between rooms of different height is a staircase that climbs one level, so a cell
## never gets a room two levels away from a connected neighbour that already has its room. The
## start and boss rooms are fixed, so they go first and constrain their neighbours.
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
	for coord: Vector2i in coords:
		var cell := layout.get_cell(coord)
		if cell.type == RoomData.RoomType.START or cell.type == RoomData.RoomType.BOSS:
			continue
		cell.room_data = _pick_room(scenario, cell.type, rng, weight_modifiers, used,
				_neighbour_heights(layout, coord))
		if cell.room_data != null:
			used[cell.room_data.id] = used.get(cell.room_data.id, 0) + 1


## Heights of the connected neighbours that already have a room.
static func _neighbour_heights(layout: MapLayout, coord: Vector2i) -> Array[int]:
	var heights: Array[int] = []
	for other in layout.neighbors_connected(coord):
		var room := layout.get_cell(other).room_data
		if room != null and not heights.has(room.height):
			heights.append(room.height)
	return heights


## Rooms more than one level away from any neighbour's height weigh 0. If that leaves nothing
## (neighbours two levels apart and no room between them), the rooms at the height of at least one
## neighbour are tried, then any room, so the map is still built. Without neighbour heights (or with
## every room within reach) the draw is exactly the one it always was.
static func _pick_room(scenario: ScenarioData, type: RoomData.RoomType, rng: RandomNumberGenerator,
		weight_modifiers: Dictionary, used: Dictionary, neighbour_heights: Array[int] = []) -> RoomData:
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

	var within_reach := _weights_within_reach(pool, weights, neighbour_heights)
	if _sum(within_reach) > 0.0:
		return pool[_weighted_index(within_reach, rng)]
	if _sum(weights) > 0.0:
		var same_height := _weights_at_any_height(pool, weights, neighbour_heights)
		if _sum(same_height) > 0.0:
			return pool[_weighted_index(same_height, rng)]
	return pool[_weighted_index(weights, rng)]


## `weights` with a 0 for every room more than one level from any of `heights` (no heights: the
## weights as they are).
static func _weights_within_reach(pool: Array[RoomData], weights: Array[float], heights: Array[int]) -> Array[float]:
	var result: Array[float] = weights.duplicate()
	for i in pool.size():
		for height in heights:
			if absi(pool[i].height - height) > 1:
				result[i] = 0.0
	return result


## `weights` with a 0 for every room whose height is not one of `heights`.
static func _weights_at_any_height(pool: Array[RoomData], weights: Array[float], heights: Array[int]) -> Array[float]:
	var result: Array[float] = weights.duplicate()
	for i in pool.size():
		if not heights.has(pool[i].height):
			result[i] = 0.0
	return result


static func _sum(weights: Array[float]) -> float:
	var total := 0.0
	for weight in weights:
		total += weight
	return total


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
