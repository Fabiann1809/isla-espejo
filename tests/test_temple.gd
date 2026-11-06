extends SceneTree
## The Templo del Eclipse scenario: its data (25 enemies, a roster of 10, 13 room designs, surge
## rooms), every room plan a valid design with its markers on spawn_ok cells, 30 seeds that build a
## map where every room is reached from the start (one staircase per level between neighbours), surge
## rooms in most maps, the full level built with every enemy on its island and on its platform's
## level, each of the 25 enemies alive for 3 s in a temple room without leaving it or stepping in lava,
## and the chapter chain: the ruins lead to the temple, which ends the journey.
## Run: godot --headless --path . --script res://tests/test_temple.gd
## `Level`/`Room` must not be referenced as types here (autoload compile order).

const TILE := 16
const ROOM_SIZE := Vector2(480, 288)
const ALL_DOORS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const MARKER_CONTAINERS := ["EnemySpawns", "NpcSpawn", "BossSpawn", "ChestSpawn", "SpecialSpawn", "ExitSpawn"]
const ROOM_IDS := ["temple_start", "temple_boss", "temple_pillar_court", "temple_isles", "temple_terraces",
		"temple_trap_walk", "temple_lava_falls", "temple_surge_basin", "temple_surge_tiers", "temple_surge_bridges",
		"temple_sanctum", "temple_event", "temple_special"]
const ENEMY_IDS := ["centinela_obsidiana", "carcelero_cadenas", "acolito_brasero", "verdugo_piedra", "duelista_maldito",
		"salamandra_cristal", "gusano_puentes", "caracol_escoria", "carnero_basalto", "manta_hollin", "eco_espejo",
		"monje_sin_rostro", "mascara_parasita", "oraculo_ceniza", "custodio_sello", "ojo_sol", "campanero_bronce",
		"rueda_devoradora", "arana_talladora", "forjador_condenado", "baldosa_hambrienta", "manos_abismo",
		"vasija_poseida", "relojero_trampas", "nucleo_cria"]
## Seconds each enemy runs in the temple room, and how many physics frames that is.
const RUN_SECONDS := 3.0

var _ok := true
var _theme: Resource


func _initialize() -> void:
	create_timer(170.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	root.get_node("PlayerProfile").persistence_enabled = false
	_theme = load("res://data/themes/temple.tres")

	var scenario: ScenarioData = load("res://data/scenarios/temple.tres")
	_check(scenario != null, "data/scenarios/temple.tres exists")
	if scenario == null:
		_finish()
		return
	_check_data(scenario)
	await _check_plans(scenario)
	_check_layouts(scenario)
	await _check_level(scenario)
	await _check_enemies(scenario)
	_check_chapters(scenario)
	_finish()


# --- data ------------------------------------------------------------------------------------------
func _check_data(scenario: ScenarioData) -> void:
	_check(scenario.id == &"temple" and scenario.display_name == "Templo del Eclipse"
			and scenario.chapter_title == "El templo conoce tu destino.", "the temple scenario has its id and Spanish titles")
	var ids: Array = scenario.enemy_pool.map(func(scene: PackedScene) -> String: return scene.resource_path.get_file().get_basename())
	ids.sort()
	var wanted := ENEMY_IDS.duplicate()
	wanted.sort()
	_check(ids == wanted, "its pool holds the 25 temple enemies (%d)" % ids.size())
	_check(scenario.roster_size == 10, "a map fields a roster of 10 (%d)" % scenario.roster_size)
	_check(scenario.theme != null and scenario.theme.wall_style == RoomTheme.WallStyle.LAVA, "it has the temple theme (lava walls)")
	_check(scenario.grid_size == Vector2i(5, 6) and scenario.min_main_path == 7 and scenario.max_main_path == 12
			and scenario.side_rooms == 4 and scenario.reward_rooms == 2, "its grid and path limits are the brief's")
	var rooms: Array[RoomData] = [scenario.start_room, scenario.boss_room]
	rooms.append_array(scenario.rooms)
	var found: Array = rooms.map(func(r: RoomData) -> String: return String(r.id))
	found.sort()
	var expected := ROOM_IDS.duplicate()
	expected.sort()
	_check(found == expected, "it has the 13 room designs (%s)" % [found])
	_check(scenario.boss_room.height == 1 and scenario.start_room.height == 0, "the boss arena is raised and the start is on the ground")
	# The brief's table: every room's type, base height and exact tag set.
	var table := {
		&"temple_start": [RoomData.RoomType.START, 0, []],
		&"temple_boss": [RoomData.RoomType.BOSS, 1, []],
		&"temple_pillar_court": [RoomData.RoomType.COMBAT, 0, [&"court"]],
		&"temple_isles": [RoomData.RoomType.COMBAT, 0, [&"bridges"]],
		&"temple_terraces": [RoomData.RoomType.COMBAT, 0, [&"heights"]],
		&"temple_trap_walk": [RoomData.RoomType.COMBAT, 0, [&"traps"]],
		&"temple_lava_falls": [RoomData.RoomType.COMBAT, 1, [&"falls"]],
		&"temple_surge_basin": [RoomData.RoomType.COMBAT, 0, [&"surge"]],
		&"temple_surge_tiers": [RoomData.RoomType.COMBAT, 0, [&"surge"]],
		&"temple_surge_bridges": [RoomData.RoomType.COMBAT, 0, [&"bridges", &"surge"]],
		&"temple_sanctum": [RoomData.RoomType.REWARD, 0, [&"bridges"]],
		&"temple_event": [RoomData.RoomType.EVENT, 0, []],
		&"temple_special": [RoomData.RoomType.SPECIAL, 0, []],
	}
	for room in rooms:
		var row: Array = table.get(room.id, [])
		var room_tags: Array = Array(room.tags)
		var same_tags: bool = not row.is_empty() and room_tags.size() == row[2].size()
		if same_tags:
			for tag in row[2]:
				same_tags = same_tags and room_tags.has(tag)
		_check(not row.is_empty() and room.type == row[0] and room.height == row[1] and same_tags,
				"%s is %s at height %s with tags %s (brief: %s)" % [room.id, room.type, room.height, room_tags, row])
	var surge := {}
	for room in scenario.rooms:
		if room.surge_stages > 0:
			surge[room.id] = room.surge_stages
			_check(room.weight == 2.0 and room.tags.has(&"surge") and room.height == 0,
					"%s is a surge room of weight 2 at base height 0" % room.id)
	_check(surge.get(&"temple_surge_basin", 0) == 1 and surge.get(&"temple_surge_tiers", 0) == 2
			and surge.get(&"temple_surge_bridges", 0) == 2 and surge.size() == 3,
			"three surge rooms: one of one stage and two of two (%s)" % [surge])
	var tags := {}
	for room in scenario.rooms:
		for tag in room.tags:
			tags[tag] = true
	for tag in [&"court", &"bridges", &"heights", &"traps", &"falls", &"surge"]:
		_check(tags.has(tag), "a room carries the tag %s" % tag)
	_check(scenario.boss_scene != null and scenario.boss_scene.resource_path.ends_with("ancient_guardian.tscn")
			and scenario.objective_flag == &"temple_boss_defeated", "the Guardián antiguo is its boss")
	_check(scenario.objective != "" and scenario.objective_done != "" and scenario.completion_text != "",
			"its objective and completion texts are set")
	_check(scenario.drops.size() == 3 and not scenario.chest_scenes.is_empty() and scenario.exit_scene != null,
			"it has drops, chests and an exit")
	var affinities := 0
	for room in scenario.rooms:
		affinities += room.enemy_affinity.size()
	_check(affinities > 0, "rooms declare enemy affinities (%d)" % affinities)


# --- plans and markers -----------------------------------------------------------------------------
func _check_plans(scenario: ScenarioData) -> void:
	TileArt.use_profile(_theme.tileset)
	var rooms: Array[RoomData] = [scenario.start_room, scenario.boss_room]
	rooms.append_array(scenario.rooms)
	var bad_plans := 0
	var bad_markers := 0
	var markers := 0
	var few_spawns := 0
	var holder := Node2D.new()
	root.add_child(holder)
	for data in rooms:
		var room: Node2D = data.scene.instantiate()
		room.theme = _theme
		room.debug_label = false
		room.setup(data, ALL_DOORS.duplicate())
		holder.add_child(room)
		await physics_frame
		var shape = room.get_node_or_null("Shape")
		if shape == null or not ("plan" in shape) or shape.plan == null:
			bad_plans += 1
			printerr("%s has no temple Shape" % data.id)
			room.queue_free()
			continue
		var problems: Array = shape.plan.validate(data.surge_stages)
		if not problems.is_empty():
			bad_plans += 1
			printerr("%s: %s" % [data.id, problems])
		if shape.plan.base_height != data.height:
			bad_plans += 1
			printerr("%s: the plan's base height %d is not the room's %d" % [data.id, shape.plan.base_height, data.height])
		var points: Array[Vector2] = []
		if data.type != RoomData.RoomType.BOSS:
			points.append(room.player_spawn())
		for container in MARKER_CONTAINERS:
			points.append_array(room.spawn_points(container))
		for point in points:
			markers += 1
			var cell := Vector2i((point / TILE).floor())
			if not shape.plan.spawn_ok(cell):
				bad_markers += 1
				printerr("%s: the marker at %s (cell %s) is not spawn_ok" % [data.id, point, cell])
		if data.type == RoomData.RoomType.COMBAT and room.spawn_points("EnemySpawns").size() < 6:
			few_spawns += 1
			printerr("%s has %d enemy spawns" % [data.id, room.spawn_points("EnemySpawns").size()])
		room.queue_free()
	holder.queue_free()
	await process_frame
	_check(bad_plans == 0, "every temple room plan is a valid design of its room's base height")
	_check(bad_markers == 0, "every marker is on a spawn_ok cell (%d markers)" % markers)
	_check(few_spawns == 0, "every combat room has at least 6 enemy spawns")


# --- layouts ---------------------------------------------------------------------------------------
func _check_layouts(scenario: ScenarioData) -> void:
	var invalid := 0
	var unreachable := 0
	var with_surge := 0
	var bad_counts := 0
	for map_seed in range(1, 31):
		var layout := MapGenerator.generate(scenario, map_seed)
		if not layout.validate().is_empty():
			invalid += 1
			printerr("seed %d: %s" % [map_seed, layout.validate()])
		if _reached_with_stairs(layout).size() != layout.cells.size():
			unreachable += 1
		var surge_rooms := 0
		for cell: MapLayout.Cell in layout.cells.values():
			if cell.room_data != null and cell.room_data.surge_stages > 0:
				surge_rooms += 1
		if surge_rooms > 0:
			with_surge += 1
		if layout.count_of_type(RoomData.RoomType.EVENT) != 1 or layout.count_of_type(RoomData.RoomType.REWARD) != 2 \
				or layout.count_of_type(RoomData.RoomType.SPECIAL) != 1:
			bad_counts += 1
	_check(invalid == 0, "seeds 1..30 give valid temple layouts (%d invalid)" % invalid)
	_check(unreachable == 0, "every room is reached from the start by doors and corridors, one level per staircase (%d maps fail)" % unreachable)
	_check(bad_counts == 0, "every map has 1 event, 2 reward and 1 special room (%d wrong)" % bad_counts)
	_check(with_surge >= 25, "at least one surge room appears in 25 of 30 seeds (%d)" % with_surge)


## The cells a walker reaches from the start: through a corridor to a connected neighbour whose room
## is at most one level away (a staircase corridor climbs exactly one level).
func _reached_with_stairs(layout: MapLayout) -> Dictionary:
	var seen := {layout.start_cell: true}
	var queue: Array[Vector2i] = [layout.start_cell]
	var head := 0
	while head < queue.size():
		var coord := queue[head]
		head += 1
		var here: int = layout.get_cell(coord).room_data.height
		for other in layout.neighbors_connected(coord):
			var there: int = layout.get_cell(other).room_data.height
			if not seen.has(other) and absi(here - there) <= 1:
				seen[other] = true
				queue.append(other)
	return seen


# --- the built level -------------------------------------------------------------------------------
func _check_level(scenario: ScenarioData) -> void:
	var level: Node2D = load("res://scenes/levels/temple_level.tscn").instantiate()
	_check(level != null and level.scenario == scenario and level.end_after_last_chapter,
			"scenes/levels/temple_level.tscn plays the temple and ends the journey after it")
	level.use_director = false
	var seeds := [3, 11, 17]
	var built := 0
	var shapes_ok := true
	var enemies_ok := true
	var surge_ok := true
	var total_enemies := 0
	var surge_rooms := 0
	var build_ms := 0
	for map_seed in seeds:
		level.seed_value = map_seed
		if built == 0:
			var started := Time.get_ticks_msec()
			root.add_child(level)
			build_ms = Time.get_ticks_msec() - started
		else:
			level.generate(map_seed)
		for i in 4:
			await physics_frame
		if level.rooms.size() != level.layout.cells.size() or not level.layout.validate().is_empty():
			continue
		built += 1
		for room in level.rooms.values():
			var shape = room.get_node_or_null("Shape")
			if shape == null or not ("plan" in shape) or shape.plan == null:
				shapes_ok = false
				continue
			var surge = room.get_node_or_null("LavaSurge")
			if (surge != null) != (room.data.surge_stages > 0):
				surge_ok = false
				printerr("seed %d: %s surge node %s" % [map_seed, room.data.id, surge != null])
			if surge != null:
				surge_rooms += 1
			var safe: Array = surge.safe_spawn_cells() if surge != null else []
			for child in room.get_children():
				if not child.is_in_group("enemies"):
					continue
				total_enemies += 1
				var cell := Vector2i((child.position / TILE).floor())
				var level_ok: bool = Heights.level_of(child) == room.height_at(child.position)
				var island_ok: bool = shape.plan.spawn_ok(cell)
				var safe_ok: bool = surge == null or safe.has(cell)
				if not (level_ok and island_ok and safe_ok):
					enemies_ok = false
					printerr("seed %d: %s in %s at %s level %d (plan %d) spawn_ok %s safe %s" % [map_seed, child.name, room.data.id,
							cell, Heights.level_of(child), room.height_at(child.position), island_ok, safe_ok])
	_check(built == seeds.size(), "the temple level builds a valid map for seeds %s" % [seeds])
	_check(shapes_ok, "every room of the built maps is a temple island")
	_check(enemies_ok and total_enemies > 0, "every enemy stands on a spawn_ok cell at its platform's level, surge rooms' on the safe level (%d enemies)" % total_enemies)
	_check(surge_ok, "exactly the surge rooms carry a LavaSurge (%d over %d maps)" % [surge_rooms, built])
	var roster_ids: Array = level.roster.map(func(s: PackedScene) -> String: return s.resource_path.get_file().get_basename())
	_check(level.roster.size() == 10 and roster_ids.all(func(id: String) -> bool: return id in ENEMY_IDS),
			"the map's roster is 10 of the 25 (%s)" % [roster_ids])
	var enemies: Array = level.get_tree().get_nodes_in_group("enemies")
	var in_roster := enemies.all(func(e: Node) -> bool: return not e.data.id in ENEMY_IDS or String(e.data.id) in roster_ids)
	_check(in_roster, "every temple enemy on the map is in its roster")
	print("Temple map build time (seed %d, first build): %d ms" % [seeds[0], build_ms])
	level.free()


# --- every enemy in a temple room ------------------------------------------------------------------
func _check_enemies(scenario: ScenarioData) -> void:
	var data: RoomData = null
	for room in scenario.rooms:
		if room.id == &"temple_pillar_court":
			data = room
	if data == null:
		_check(false, "the pillar court exists for the enemy check")
		return
	var room: Node2D = data.scene.instantiate()
	room.theme = _theme
	room.debug_label = false
	room.setup(data, ALL_DOORS.duplicate())
	root.add_child(room)
	var player: Node2D = load("res://scenes/player/player.tscn").instantiate()
	player.position = room.player_spawn() if room.get_node_or_null("PlayerSpawn") != null else ROOM_SIZE / 2.0
	room.add_child(player)
	await physics_frame
	var shape = room.get_node("Shape")
	var points: Array[Vector2] = room.spawn_points("EnemySpawns")
	var left := 0
	var in_lava := 0
	var ran := 0
	var frames := int(RUN_SECONDS * Engine.physics_ticks_per_second)
	var index := 0
	while index < ENEMY_IDS.size():
		var batch: Array = []
		for i in points.size():
			if index >= ENEMY_IDS.size():
				break
			var enemy: Node2D = load("res://scenes/enemies/%s.tscn" % ENEMY_IDS[index]).instantiate()
			enemy.position = points[i]
			room.add_child(enemy)
			Placement.reset(enemy)
			batch.append(enemy)
			index += 1
		for i in frames:
			await physics_frame
		for enemy in batch:
			if not is_instance_valid(enemy):
				continue
			ran += 1
			var inside := Rect2(Vector2.ZERO, ROOM_SIZE).grow(TILE).has_point(enemy.position)
			if not inside:
				left += 1
				printerr("%s left the room (%s)" % [enemy.data.id, enemy.position])
			var cell := Vector2i((enemy.position / TILE).floor())
			if inside and shape.plan.is_lava(cell) and not Heights.is_flyer(enemy):
				in_lava += 1
				printerr("%s stands in lava at %s" % [enemy.data.id, cell])
			enemy.queue_free()
		# What a batch left behind (hazards, pits, blocks, brood) goes before the next one.
		for group: StringName in [&"ground_hazards", &"iron_blocks", &"enemies"]:
			for leftover in get_nodes_in_group(group):
				if room.is_ancestor_of(leftover):
					leftover.queue_free()
		await physics_frame
	_check(ran == ENEMY_IDS.size(), "each of the 25 enemies ran %.0f s in the pillar court (%d)" % [RUN_SECONDS, ran])
	_check(left == 0, "none of them left the room (%d did)" % left)
	_check(in_lava == 0, "none of them (but flyers) stepped into lava (%d did)" % in_lava)
	room.free()


# --- chapters --------------------------------------------------------------------------------------
func _check_chapters(scenario: ScenarioData) -> void:
	var ruins: Resource = load("res://data/scenarios/ruins.tres")
	_check(ruins.next_scenario == scenario, "the ruins lead to the temple")
	_check(scenario.next_scenario == null, "the temple is the last chapter: it ends the journey")


func _finish() -> void:
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
