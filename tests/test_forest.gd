extends SceneTree
## Forest scenario test (Bosque de la Aurora): data, tileset catalog, map generation and the built
## level (themed rooms and corridors, walkability).
## Run: godot --headless --path . --script res://tests/test_forest.gd
## `Level`/`Room` must not be referenced as types here (autoload compile order).

var _ok := true


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	root.get_node("PlayerProfile").persistence_enabled = false

	var scenario: ScenarioData = load("res://data/scenarios/forest.tres")
	_test_data(scenario)
	_test_tileset_catalog()
	_test_generation(scenario)
	await _test_built_level()

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _test_data(scenario: ScenarioData) -> void:
	_check(scenario != null and scenario.id == &"forest" and scenario.display_name == "Bosque de la Aurora", "the forest scenario loads")
	_check(scenario.theme != null and scenario.theme.tileset != null and scenario.theme.tileset.texture != null,
			"it has a visual theme with a tileset profile")
	var kinds := {}
	for room in scenario.rooms:
		kinds[room.type] = kinds.get(room.type, 0) + 1
	var total := scenario.rooms.size() + 2
	_check(total >= 6 and total <= 10, "it has between 6 and 10 hand-made rooms (%d)" % total)
	_check(kinds.get(RoomData.RoomType.COMBAT, 0) >= 3 and kinds.has(RoomData.RoomType.EVENT)
			and kinds.has(RoomData.RoomType.REWARD) and kinds.has(RoomData.RoomType.SPECIAL),
			"it has combat, event, reward and special rooms")
	var tags := {}
	for room in scenario.rooms:
		for tag in room.tags:
			tags[tag] = true
	_check(tags.has(&"standard") and tags.has(&"ambush") and tags.has(&"watch"),
			"it has rooms for every AI reaction (standard, ambush, watch)")
	_check(scenario.enemy_pool.size() > 0 and scenario.start_room != null and scenario.boss_room != null, "it has enemies, a start room and a boss room")
	var pool_ids: Array = scenario.enemy_pool.map(func(scene: PackedScene) -> String: return scene.resource_path.get_file().get_basename())
	pool_ids.sort()
	_check(pool_ids == ["esqueleto", "planta_tiradora", "slime"], "the forest pool only has enemies with their own art (%s)" % [pool_ids])
	_check_pool_weights(scenario)
	var credits := FileAccess.get_file_as_string("res://CREDITS.md")
	_check("Kenney" in credits and "CC0" in credits, "the tileset is credited in CREDITS.md")
	_check(FileAccess.file_exists("res://assets/tilesets/kenney_roguelike_rpg/License.txt"), "the pack's license file is kept next to the art")


## Every role the game asks for has a tile in the default profile, inside its sheet (so a wrong
## coordinate is caught), and the profile's TileSet matches the sheet (16x16, 1 px apart).
func _test_tileset_catalog() -> void:
	var profile: TilesetProfile = load(TileArt.DEFAULT_PROFILE)
	var source := profile.tile_set().get_source(0) as TileSetAtlasSource
	_check(source != null and source.texture_region_size == Vector2i(16, 16) and source.separation == Vector2i(1, 1),
			"the TileSet is 16x16 with a 1 px separation")
	var problems := profile.problems(TileArt.ROLES, TileArt.PATTERNS)
	_check(TileArt.ROLES.size() > 20 and problems.is_empty(),
			"every role has a tile in the default profile (%d roles, problems: %s)" % [TileArt.ROLES.size(), problems])
	var editor_set: TileSet = load("res://assets/tilesets/forest_tileset.tres")
	_check(editor_set.get_source(0).get_tiles_count() == source.get_tiles_count(),
			"the editor's TileSet has the same tiles as the profile")


func _test_generation(scenario: ScenarioData) -> void:
	var invalid := 0
	var bad_counts := 0
	for map_seed in range(1, 301):
		var layout := MapGenerator.generate(scenario, map_seed)
		if not layout.validate().is_empty():
			invalid += 1
		if layout.count_of_type(RoomData.RoomType.EVENT) != 1 or layout.count_of_type(RoomData.RoomType.REWARD) != 2 \
				or layout.count_of_type(RoomData.RoomType.SPECIAL) != 1:
			bad_counts += 1
	_check(invalid == 0, "300 forest maps are valid and fully reachable (invalid: %d)" % invalid)
	_check(bad_counts == 0, "every forest map has 1 event, 2 reward and 1 special room (bad: %d)" % bad_counts)


func _test_built_level() -> void:
	var level: Node2D = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.seed_value = 4242
	level.use_director = false
	root.add_child(level)
	await _frames(5)

	var layout = level.layout
	_check(level.rooms.size() == layout.cells.size() and layout.validate().is_empty(), "the forest level builds a valid map")
	var themed := true
	for room in level.rooms.values():
		for layer_name in ["Ground", "Decor", "Border"]:
			if room.get_node_or_null(layer_name) == null:
				themed = false
		var ground: TileMapLayer = room.get_node_or_null("Ground")
		if ground == null or ground.get_used_cells().size() != 30 * 18:
			themed = false
	_check(themed, "every room has its Ground, Decor and Border tile layers and a fully painted floor")
	# Enemies are children of their own room: floors on the actors' z layer would be painted over an
	# enemy that wandered in from an earlier room or into a corridor.
	var floors_low := true
	var layers := level.get_node("Map").find_children("*", "TileMapLayer", true, false)
	for layer in layers:
		# Effective z: the backdrop's layers sit in a parent drawn below the floors.
		var z: int = layer.z_index + (layer.get_parent().z_index if layer.get_parent() is Node2D else 0)
		floors_low = floors_low and z < 0
	_check(not layers.is_empty() and floors_low, "every floor, border and corridor layer (%d) is drawn below the actors" % layers.size())
	# The Ente waits alone in the middle of the last combat room before the boss.
	var enemies := level.get_tree().get_nodes_in_group("enemies")
	var spirits := enemies.filter(func(n: Node) -> bool: return n.data.id == &"ente")
	var guard_ok := false
	if spirits.size() == 1:
		var guard_room = spirits[0].get_parent()
		var guard_cell: Vector2i = level.rooms.find_key(guard_room)
		var later_combat := false
		for i in range(layout.main_path.find(guard_cell) + 1, layout.main_path.size() - 1):
			later_combat = later_combat or layout.get_cell(layout.main_path[i]).type == RoomData.RoomType.COMBAT
		guard_ok = guard_room.data.type == RoomData.RoomType.COMBAT and guard_cell in layout.main_path 				and not later_combat and guard_room.enemies_alive == 1 and spirits[0].position.is_equal_approx(guard_room.center())
	_check(guard_ok, "the Ente is the only enemy of the last combat room before the boss, in its center")
	_check(enemies.filter(func(n: Node) -> bool: return n.data.id == &"ente").size() == 1, "there is exactly one Ente in the forest")
	var npcs := level.get_tree().get_nodes_in_group("npcs")
	var chests := level.get_tree().get_nodes_in_group("chests")
	var elders := npcs.filter(func(n: Node) -> bool: return n.dialogue_id == &"elder")
	var merchants := npcs.filter(func(n: Node) -> bool: return n.dialogue_id == &"merchant")
	_check(npcs.size() == 2 and elders.size() == 1 and elders[0].get_parent().data.type == RoomData.RoomType.EVENT,
			"the Anciano waits in the event room")
	_check(merchants.size() == 1 and merchants[0].get_parent().data.type == RoomData.RoomType.SPECIAL,
			"the Mercader waits in the special room")
	if merchants.size() == 1:
		var dialogue: Node = root.get_node("Dialogue")
		var talked := []
		var listener := func(id: StringName) -> void: talked.append(id)
		dialogue.started.connect(listener)
		merchants[0].get_node("Talk").interact(level.player)
		_check(dialogue.active and talked == [&"merchant"], "talking to the Mercader starts his dialogue")
		dialogue.started.disconnect(listener)
		dialogue._finish()
	var chests_ok := chests.size() == 2
	for chest in chests:
		chests_ok = chests_ok and chest.get_parent().data.type == RoomData.RoomType.REWARD
	_check(chests_ok, "there is one chest in each of the 2 reward rooms")
	var first_room = level.rooms.values()[0]
	_check(first_room.get_node("Walls").get_child_count() > 0 and first_room.get_node("Walls").find_children("*", "ColorRect", true, false).is_empty(),
			"the walls keep their collision but no longer draw flat rectangles")

	var corridor_layers := level.get_node("Map/Corridors").get_child_count()
	var connections := 0
	for coord: Vector2i in layout.cells:
		for dir in [Vector2i.RIGHT, Vector2i.DOWN]:
			if layout.are_connected(coord, coord + dir):
				connections += 1
	# Per corridor: its grass, its path and trees, and its walls.
	_check(corridor_layers == connections * 3, "every corridor has its tile layers and its walls (%d connections)" % connections)

	var total := 0
	var walkable := 0
	for map_seed in range(1, 9):
		level.generate(map_seed)
		await _frames(2)
		var report := _walkability(level)
		total += report.connections
		walkable += report.walkable
	_check(total > 0 and walkable == total, "8 forest maps: every connection can be walked through (%d/%d)" % [walkable, total])
	level.free()


func _walkability(level: Node2D) -> Dictionary:
	var layout = level.layout
	var space := level.get_world_2d().direct_space_state
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 12)
	var report := {"connections": 0, "walkable": 0}
	var size := Vector2(480, 288)
	for coord: Vector2i in layout.cells:
		for dir in [Vector2i.RIGHT, Vector2i.DOWN]:
			var neighbour: Vector2i = coord + dir
			if not layout.are_connected(coord, neighbour):
				continue
			report.connections += 1
			var from: Vector2
			var to: Vector2
			var origin: Vector2 = level.cell_origin(coord)
			var next_origin: Vector2 = level.cell_origin(neighbour)
			if dir == Vector2i.RIGHT:
				from = origin + Vector2(size.x - 14.0, size.y / 2.0)
				to = next_origin + Vector2(14.0, size.y / 2.0)
			else:
				from = origin + Vector2(size.x / 2.0, size.y - 14.0)
				to = next_origin + Vector2(size.x / 2.0, 14.0)
			var params := PhysicsShapeQueryParameters2D.new()
			params.shape = shape
			params.transform = Transform2D(0.0, from)
			params.motion = to - from
			params.collision_mask = 1
			var result := space.cast_motion(params)
			if result.size() == 2 and result[0] >= 1.0:
				report.walkable += 1
	return report


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


## The pool is picked by the scenario's weights: slimes most, then plants and skeletons.
func _check_pool_weights(scenario: Resource) -> void:
	var picker = load("res://scripts/world/room.gd").new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var counts := {}
	# 550 rooms of 4 enemies: 2200 picks.
	for i in 550:
		for scene in picker.pick_enemies(scenario.enemy_pool, 4, rng, null, scenario.enemy_weights):
			var id: String = scene.resource_path.get_file().get_basename()
			counts[id] = counts.get(id, 0) + 1
	picker.free()
	_check(counts["slime"] > counts["planta_tiradora"] and counts["slime"] > counts["esqueleto"],
			"slimes are the most frequent enemy of the forest (%s)" % [counts])
	_check(abs(counts["slime"] - 1000) < 120 and abs(counts["planta_tiradora"] - 600) < 120 and abs(counts["esqueleto"] - 600) < 120,
			"the picks follow the 5:3:3 weights")
