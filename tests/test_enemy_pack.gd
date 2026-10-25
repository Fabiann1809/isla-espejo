extends SceneTree
## Enemies that pile up: in a real forest map, with every enemy able to see Nico from anywhere, no
## more than Tuning.MAX_HUNTERS hunt him at once (Tuning.MAX_HUNTERS_OF_A_KIND of one kind), and when
## he leaves a room its enemies stop and walk back instead of following him through the corridors.
## Spawn markers of every forest room are at least Tuning.MIN_SPAWN_DISTANCE apart.
## Before the fix (tools/measure_enemies.gd, 20 maps): up to 17 hunters at once, 27 with the
## director's stealth reaction, and 77% / 97% of the enemies left their room.
## Run: godot --headless --path . --script res://tests/test_enemy_pack.gd

const CHASE := 2
const ATTACK := 3

var _ok := true


func _initialize() -> void:
	create_timer(150.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var tuning: Script = load("res://scripts/core/tuning.gd")
	_check_spawn_spacing(tuning)

	var level = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.use_director = false
	level.seed_value = 31337
	root.add_child(level)
	await _frames(2)
	var player: Node2D = level.player
	player.collision_mask = 0
	var enemies: Array = []
	for enemy in get_nodes_in_group("enemies"):
		if enemy.get("phase") == null and level.get_node("Map").is_ancestor_of(enemy):
			# Sees across the whole map: the caps, not the sight, must keep the hunt small.
			enemy.vision_multiplier = 20.0
			enemies.append(enemy)

	# The busiest combat room.
	var busiest: Node2D = null
	for room in level.rooms.values():
		if busiest == null or room.enemies_alive > busiest.enemies_alive:
			busiest = room
	_check(busiest.enemies_alive >= 3, "a room with %d enemies to test" % busiest.enemies_alive)

	var max_hunters := 0
	var max_same := 0
	for tick in 150:
		_keep_alive(player)
		player.global_position = busiest.global_position + Vector2(240, 144)
		await physics_frame
		var counts := _hunters(enemies)
		max_hunters = maxi(max_hunters, counts.total)
		max_same = maxi(max_same, counts.same_kind)
	_check(max_hunters > 0 and max_hunters <= tuning.MAX_HUNTERS,
			"at most %d enemies hunt Nico at once (saw %d)" % [tuning.MAX_HUNTERS, max_hunters])
	_check(max_same <= tuning.MAX_HUNTERS_OF_A_KIND,
			"at most %d of one kind hunt together (saw %d)" % [tuning.MAX_HUNTERS_OF_A_KIND, max_same])

	# Nico leaves for a far room: the hunters stop and go back.
	var far: Node2D = busiest
	for room in level.rooms.values():
		if room.global_position.distance_to(busiest.global_position) > far.global_position.distance_to(busiest.global_position):
			far = room
	var outside := {}
	for tick in 240:
		_keep_alive(player)
		player.global_position = far.global_position + Vector2(240, 144)
		await physics_frame
		for enemy in enemies:
			if is_instance_valid(enemy) and not enemy.home_area.grow(tuning.TERRITORY_MARGIN + 4.0).has_point(enemy.global_position):
				outside[enemy] = true
	var still_hunting := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.target != null and not far.is_ancestor_of(enemy):
			still_hunting += 1
	_check(outside.is_empty(), "no enemy follows Nico out of its room (%d did)" % outside.size())
	_check(still_hunting == 0, "enemies of the rooms he left stop hunting him (%d still do)" % still_hunting)

	# Hit from outside its room (a skill from the corridor): it still takes the hit and the push
	# before walking back.
	var victim: Node2D = null
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead() and busiest.is_ancestor_of(enemy):
			victim = enemy
	if victim != null:
		player.global_position = busiest.global_position + Vector2(240, -120)
		victim.get_node("Hurtbox").receive_hit(1, victim.global_position + Vector2(0, -10))
		var hurt_held := true
		for i in 3:
			await physics_frame
			hurt_held = hurt_held and victim.state == 4
		_check(hurt_held, "an enemy hit from outside its room still plays its hurt and push first")
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check_spawn_spacing(tuning: Script) -> void:
	var closest := INF
	for room_data in load("res://data/scenarios/forest.tres").rooms:
		var room: Node = room_data.scene.instantiate()
		var spawns: Node = room.get_node_or_null("EnemySpawns")
		if spawns != null:
			var points := spawns.get_children()
			for i in points.size():
				for j in range(i + 1, points.size()):
					closest = minf(closest, points[i].position.distance_to(points[j].position))
		room.free()
	_check(closest >= tuning.MIN_SPAWN_DISTANCE,
			"enemy spawns of every forest room are at least %d px apart (closest %d)" % [tuning.MIN_SPAWN_DISTANCE, closest])


func _hunters(enemies: Array) -> Dictionary:
	var total := 0
	var kinds := {}
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_dead() and enemy.target != null \
				and (enemy.state == CHASE or enemy.state == ATTACK):
			total += 1
			kinds[enemy.scene_file_path] = kinds.get(enemy.scene_file_path, 0) + 1
	var same := 0
	for kind in kinds:
		same = maxi(same, kinds[kind])
	return {"total": total, "same_kind": same}


func _keep_alive(player: Node) -> void:
	player.set("_invulnerable_left", 99.0)
	player.health.current = player.health.max_health


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
