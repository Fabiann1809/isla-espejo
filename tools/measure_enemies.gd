extends SceneTree
## Measures how the forest's enemies behave around Nico over many seeds (no window needed):
## how many chase him at once, how many leave their own room, how big the groups around him get,
## how many bats chase together, and patrols stuck against a wall. Nico walks through every room of
## the map (room center -> door -> next room center) and is invulnerable; enemies are left alone.
##
## Runs each seed with neutral enemies and with the director's stealth reaction at the intensity
## that was observed in play (vision x1.43, patrol x1.72).
##   godot --headless --fixed-fps 60 --path . --script res://tools/measure_enemies.gd
## (`--fixed-fps 60` simulates as fast as the machine can instead of in real time.)

const SEEDS := 20
const WALK_SPEED := 120.0
const PAUSE_TICKS := 120
const PROFILES := [
	{"name": "neutral", "vision": 1.0, "patrol": 1.0},
	{"name": "stealth x1.43/x1.72", "vision": 1.43, "patrol": 1.72},
]
const CHASE := 2
const ATTACK := 3
const PATROL := 1
const GROUP_RADIUS := 64.0
const STUCK_TICKS := 90

var _level: Node


func _initialize() -> void:
	await process_frame
	_level = load("res://scenes/levels/forest_level.tscn").instantiate()
	_level.use_director = false
	_level.seed_value = 1
	root.add_child(_level)
	await _frames(2)
	for profile in PROFILES:
		var total := {"max_chasers": 0, "sum_max_chasers": 0, "enemies": 0, "left_room": 0,
				"max_group": 0, "max_bats": 0, "stuck": 0, "ticks_over_3": 0, "ticks": 0}
		for map_seed in range(1, SEEDS + 1):
			var result: Dictionary = await _run_map(map_seed, profile)
			total.max_chasers = maxi(total.max_chasers, result.max_chasers)
			total.sum_max_chasers += result.max_chasers
			total.enemies += result.enemies
			total.left_room += result.left_room
			total.max_group = maxi(total.max_group, result.max_group)
			total.max_bats = maxi(total.max_bats, result.max_bats)
			total.stuck += result.stuck
			total.ticks_over_3 += result.ticks_over_3
			total.ticks += result.ticks
		print("[%s] %d seeds | chasers at once: max %d, mean of per-map max %.1f | time with 4+ chasers %.1f%% | enemies that left their room %d/%d (%.0f%%) | biggest group near Nico %d | bats chasing at once %d | stuck patrols %d" % [
				profile.name, SEEDS, total.max_chasers, float(total.sum_max_chasers) / SEEDS,
				100.0 * total.ticks_over_3 / maxi(total.ticks, 1), total.left_room, total.enemies,
				100.0 * total.left_room / maxi(total.enemies, 1), total.max_group, total.max_bats, total.stuck])
	quit(0)


func _run_map(map_seed: int, profile: Dictionary) -> Dictionary:
	_level.generate(map_seed)
	await _frames(2)
	var enemies: Array = []
	var home := {}
	for node in get_nodes_in_group("enemies"):
		if node.get("phase") != null:
			continue  # the boss is territorial and is measured by its own tests
		node.vision_multiplier = profile.vision
		node.patrol_multiplier = profile.patrol
		enemies.append(node)
		var room: Node2D = node.get_parent()
		home[node] = Rect2(room.global_position, Vector2(480, 288))
	var result := {"max_chasers": 0, "enemies": enemies.size(), "left_room": 0, "max_group": 0,
			"max_bats": 0, "stuck": 0, "ticks_over_3": 0, "ticks": 0}
	var left := {}
	var still := {}
	var last := {}
	var player: Node2D = _level.player
	# Nico is moved by hand: without this enemies in his way would push him back forever.
	player.collision_mask = 0
	for point in _route():
		while player.global_position.distance_to(point) > 0.5:
			player.global_position = player.global_position.move_toward(point, WALK_SPEED / 60.0)
			await _tick(player, enemies, home, left, still, last, result)
		for i in PAUSE_TICKS:
			await _tick(player, enemies, home, left, still, last, result)
	result.left_room = left.size()
	return result


func _tick(player: Node2D, enemies: Array, home: Dictionary, left: Dictionary, still: Dictionary,
		last: Dictionary, result: Dictionary) -> void:
	player.set("_invulnerable_left", 99.0)
	player.health.current = player.health.max_health
	await physics_frame
	var chasers := 0
	var bats := 0
	var near := 0
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_dead():
			continue
		if not home[enemy].grow(-8.0).has_point(enemy.global_position):
			left[enemy] = true
		if enemy.state == CHASE or enemy.state == ATTACK:
			chasers += 1
			if String(enemy.scene_file_path).contains("murcielago"):
				bats += 1
			if enemy.global_position.distance_to(player.global_position) <= GROUP_RADIUS:
				near += 1
		var moved: float = enemy.global_position.distance_to(last.get(enemy, enemy.global_position))
		last[enemy] = enemy.global_position
		if enemy.state == PATROL and moved < 0.05:
			still[enemy] = still.get(enemy, 0) + 1
			if still[enemy] == STUCK_TICKS:
				result.stuck += 1
		else:
			still[enemy] = 0
	result.max_chasers = maxi(result.max_chasers, chasers)
	result.max_bats = maxi(result.max_bats, bats)
	result.max_group = maxi(result.max_group, near)
	result.ticks += 1
	if chasers >= 4:
		result.ticks_over_3 += 1


## Room centers in depth-first order from the start, with the door points in between and the way
## back after a dead end, so Nico walks every corridor like a player exploring the map.
func _route() -> Array[Vector2]:
	var layout = _level.layout
	var points: Array[Vector2] = []
	var seen := {}
	_visit(layout, layout.start_cell, seen, points)
	return points


func _visit(layout, coord: Vector2i, seen: Dictionary, points: Array[Vector2]) -> void:
	seen[coord] = true
	points.append(_center(coord))
	for dir in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]:
		var next: Vector2i = coord + dir
		if layout.has_cell(next) and not seen.has(next) and layout.are_connected(coord, next):
			_visit(layout, next, seen, points)
			points.append(_center(coord))


func _center(coord: Vector2i) -> Vector2:
	return _level.cell_origin(coord) + Vector2(240, 144)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
