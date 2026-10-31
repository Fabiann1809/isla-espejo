extends SceneTree
## Every enemy that lives in a room keeps to it, whatever its kind: the room's enemies, the mini boss
## and the minions it summons take the room as their territory (the boss does not). On real forest
## maps, with the director's widest patrols (x2), patrols stay inside their room and none keeps
## walking into a tree or a wall (hopping slimes included); when Nico leaves a room its enemies stop
## and walk back instead of following him, and one hit from outside still plays its hurt first.
## Run: godot --headless --path . --script res://tests/test_enemy_territory.gd

const SEEDS := [4242, 31337]
const SECONDS := 4.0
const PATROL := 1
const HURT := 4
const STUCK_TICKS := 60

var _ok := true


func _initialize() -> void:
	create_timer(150.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var tuning: Script = load("res://scripts/core/tuning.gd")
	var level = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.use_director = false
	level.seed_value = SEEDS[0]
	root.add_child(level)
	await _frames(2)
	var player: Node2D = level.player

	# --- Homes: room enemies, the mini boss, a summoned minion; never the boss.
	var homes_ok := true
	var kinds := {}
	var boss_free := true
	var mini_boss_home := false
	for enemy in _map_enemies(level):
		var room: Node = enemy.get_parent()
		if enemy.get("phase") != null:
			boss_free = boss_free and not enemy.home_area.has_area()
			continue
		kinds[enemy.scene_file_path.get_file()] = true
		homes_ok = homes_ok and enemy.home_area == room.home_rect()
		if enemy.scene_file_path == level.scenario.miniboss_scene.resource_path:
			mini_boss_home = enemy.home_area.has_area()
	_check(homes_ok and kinds.size() >= 3, "every enemy of a room takes it as its territory (%s)" % [kinds.keys()])
	_check(mini_boss_home, "the mini boss keeps to its room too")
	_check(boss_free, "the boss keeps its own arena rules (no room territory)")
	var summoner: Node = level.scenario.miniboss_scene.instantiate()
	var minion_scene: PackedScene = summoner.data.minion_scene
	summoner.free()
	var some_room: Node2D = level.rooms[level.layout.start_cell]
	var minion: Node2D = minion_scene.instantiate()
	minion.position = Vector2(240, 144)
	some_room.add_child(minion)
	_check(minion.home_area == some_room.home_rect(), "a summoned minion takes the room it grows in")
	minion.free()

	# --- Patrols: nobody to chase.
	player.remove_from_group("player")
	var outside := 0
	var stuck := {}
	var total := 0
	for map_seed in SEEDS:
		level.generate(map_seed)
		await _frames(2)
		var enemies: Array = []
		for enemy in _map_enemies(level):
			if enemy.get("phase") == null:
				enemy.patrol_multiplier = 2.0
				enemies.append(enemy)
		total += enemies.size()
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
				# Slimes stand still between hops: only a whole second without moving counts.
				still[enemy] = still.get(enemy, 0) + 1 if enemy.state == PATROL and moved < 0.05 else 0
				if still[enemy] == STUCK_TICKS:
					var kind: String = enemy.scene_file_path.get_file()
					stuck[kind] = stuck.get(kind, 0) + 1
		outside += left.size()
	_check(total > 0 and outside == 0, "patrols stay inside their room (%d of %d left it)" % [outside, total])
	_check(stuck.is_empty(), "no patrol keeps walking into an obstacle (stuck for 1 s: %s)" % [stuck])

	# --- Nico leaves a room: its enemies stop and walk back.
	player.add_to_group("player")
	player.collision_mask = 0
	level.generate(31337)
	await _frames(2)
	var enemies: Array = []
	for enemy in _map_enemies(level):
		if enemy.get("phase") == null:
			# Sees across the whole map: only the territory may keep it home.
			enemy.vision_multiplier = 20.0
			enemies.append(enemy)
	var busiest: Node2D = null
	for room in level.rooms.values():
		if busiest == null or room.enemies_alive > busiest.enemies_alive:
			busiest = room
	for tick in 90:
		_keep_alive(player)
		player.global_position = busiest.global_position + Vector2(240, 144)
		await physics_frame
	var hunting := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and busiest.is_ancestor_of(enemy) and enemy.target != null:
			hunting += 1
	_check(hunting > 0, "the enemies of Nico's room hunt him (%d)" % hunting)
	var far: Node2D = busiest
	for room in level.rooms.values():
		if room.global_position.distance_to(busiest.global_position) > far.global_position.distance_to(busiest.global_position):
			far = room
	var followed := {}
	for tick in 240:
		_keep_alive(player)
		player.global_position = far.global_position + Vector2(240, 144)
		await physics_frame
		for enemy in enemies:
			if is_instance_valid(enemy) and not enemy.home_area.grow(tuning.TERRITORY_MARGIN + 4.0).has_point(enemy.global_position):
				followed[enemy] = true
	var still_hunting := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.target != null and not far.is_ancestor_of(enemy):
			still_hunting += 1
	_check(followed.is_empty(), "no enemy follows Nico out of its room (%d did)" % followed.size())
	_check(still_hunting == 0, "enemies of the rooms he left stop hunting him (%d still do)" % still_hunting)

	# --- Hit from outside its room (an arrow from the corridor): hurt and push first, then home.
	var victim: Node2D = null
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead() and busiest.is_ancestor_of(enemy) and enemy.health.current > 1:
			victim = enemy
	_check(victim != null, "an enemy to hit from outside its room")
	if victim != null:
		player.global_position = busiest.global_position + Vector2(240, -120)
		victim.get_node("Hurtbox").receive_hit(1, victim.global_position + Vector2(0, -10))
		var hurt_held := true
		for i in 3:
			await physics_frame
			hurt_held = hurt_held and victim.state == HURT
		_check(hurt_held, "an enemy hit from outside its room still plays its hurt and push first")
	level.free()
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _map_enemies(level: Node) -> Array:
	var map: Node = level.get_node("Map")
	return get_nodes_in_group("enemies").filter(func(e: Node) -> bool:
		return map.is_ancestor_of(e) and not e.is_queued_for_deletion())


func _keep_alive(player: Node) -> void:
	player.set("_invulnerable_left", 99.0)
	player.health.current = player.health.max_health


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
