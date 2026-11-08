extends SceneTree
## The Ruinas de la Montaña scenario: data, tileset theme, map generation and the built level (rock
## walls, no forest pieces, staircase corridors where the rooms' heights differ).
## Run: godot --headless --path . --script res://tests/test_ruins.gd
## `Level`/`Room` must not be referenced as types here (autoload compile order).

var _ok := true


func _initialize() -> void:
	create_timer(150.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	root.get_node("PlayerProfile").persistence_enabled = false

	var scenario: ScenarioData = load("res://data/scenarios/ruins.tres")
	_check(scenario != null and scenario.id == &"ruins" and scenario.display_name == "Ruinas de la Montaña", "the ruins scenario loads")
	_check(scenario.theme != null and scenario.theme.wall_style == RoomTheme.WallStyle.ROCKS and scenario.theme.tileset != null,
			"it has the ruins theme: rock walls and its own tileset")
	var kinds := {}
	var raised := 0
	for room in scenario.rooms:
		kinds[room.type] = kinds.get(room.type, 0) + 1
		raised += room.height
	_check(scenario.rooms.size() + 2 == 13 and kinds.get(RoomData.RoomType.COMBAT, 0) == 8 and kinds.has(RoomData.RoomType.EVENT)
			and kinds.has(RoomData.RoomType.REWARD) and kinds.has(RoomData.RoomType.SPECIAL),
			"it has 13 room designs: start, boss, 8 combat (3 of them lakes), event, reward and special")
	_check(raised == 1 and scenario.boss_room.height == 1, "the boss arena and one combat room are raised")
	var tags := {}
	for room in scenario.rooms:
		for tag in room.tags:
			tags[tag] = true
	_check(tags.has(&"standard") and tags.has(&"ambush") and tags.has(&"watch"), "it has rooms for every AI reaction")
	var ids: Array = scenario.enemy_pool.map(func(scene: PackedScene) -> String: return scene.resource_path.get_file().get_basename())
	ids.sort()
	_check(ids == ["bestia_de_la_niebla", "murcielago", "sombra_errante"], "its pool has the three enemies of the second map (%s)" % [ids])
	_check(scenario.drops.size() == 7 and not scenario.chest_scenes.is_empty() and scenario.exit_scene != null, "it has drops, chests and an exit")

	var invalid := 0
	var bad_counts := 0
	for map_seed in range(1, 201):
		var layout := MapGenerator.generate(scenario, map_seed)
		if not layout.validate().is_empty():
			invalid += 1
		if layout.count_of_type(RoomData.RoomType.EVENT) != 1 or layout.count_of_type(RoomData.RoomType.REWARD) != 2 \
				or layout.count_of_type(RoomData.RoomType.SPECIAL) != 1:
			bad_counts += 1
	_check(invalid == 0 and bad_counts == 0, "200 ruins maps are valid and have 1 event, 2 reward and 1 special room (%d, %d)" % [invalid, bad_counts])

	var level: Node2D = load("res://scenes/levels/ruins_level.tscn").instantiate()
	level.seed_value = 4242
	level.use_director = false
	root.add_child(level)
	for i in 6:
		await physics_frame
	_check(level.rooms.size() == level.layout.cells.size() and level.layout.validate().is_empty(), "the ruins level builds a valid map")
	var forest_pieces := 0
	for room in level.rooms.values():
		if room.get_node_or_null("WallTrees") != null:
			forest_pieces += 1
		for prop in room.find_children("*", "Node2D", false, false):
			if prop.get_script() == load("res://scripts/world/room_prop.gd"):
				forest_pieces += 1
	_check(forest_pieces == 0, "no tree walls and no forest props in any room (%d)" % forest_pieces)
	var raised_rooms: Array = level.rooms.values().filter(func(room: Node) -> bool: return room.height == 1)
	var stairs: Array = level.get_node("Map/Corridors").find_children("Stairs*", "Node2D", false, false)
	var expected := 0
	for coord: Vector2i in level.layout.cells:
		for dir in [Vector2i.RIGHT, Vector2i.DOWN]:
			if level.layout.are_connected(coord, coord + dir) \
					and level.layout.get_cell(coord).room_data.height != level.layout.get_cell(coord + dir).room_data.height:
				expected += 1
	_check(raised_rooms.size() >= 1 and stairs.size() == expected and expected >= 1,
			"%d raised rooms are reached by %d staircase corridors" % [raised_rooms.size(), stairs.size()])
	var enemies: Array = level.get_tree().get_nodes_in_group("enemies")
	_check(enemies.size() > 0 and enemies.all(func(e: Node) -> bool: return e.data.id in [&"bestia_de_la_niebla", &"sombra_errante", &"murcielago", &"stone_serpent"]),
			"only the second map's enemies and its boss live there (%d)" % enemies.size())
	# Traps: three spike traps in the narrow and the falls rooms, none elsewhere.
	var traps_ok := true
	var trapped := 0
	for room in level.rooms.values():
		var traps: Array = room.find_children("*", "Node2D", true, false).filter(
				func(n: Node) -> bool: return n.get_script() != null and n.get_script().resource_path.ends_with("spike_trap.gd"))
		var expected_traps := 2 if room.data.id in [&"ruins_narrow", &"ruins_falls"] else 0
		traps_ok = traps_ok and traps.size() == expected_traps
		trapped += traps.size()
	_check(traps_ok, "spike traps only in the narrow and the falls rooms (%d on this map)" % trapped)

	# Light and life: dark rooms have their shade, crystals and fires have lights, and the water, the
	# fires and the crystals are animated.
	var dark_ok := true
	var dark_rooms := 0
	for room in level.rooms.values():
		var has_shade := room.get_node_or_null("Darkness") != null
		dark_ok = dark_ok and has_shade == room.data.dark
		dark_rooms += 1 if room.data.dark else 0
	_check(dark_ok, "exactly the dark rooms have a shade (%d dark rooms)" % dark_rooms)
	var lights := 0
	var animated := 0
	for room in level.rooms.values():
		animated += room.find_children("*", "AnimatedSprite2D", true, false).size()
		for glow in room.find_children("*", "Sprite2D", true, false):
			if glow.material is CanvasItemMaterial and glow.z_index == Tuning.RUIN_LIGHT_Z:
				lights += 1
	_check(lights > 20 and animated > 20, "the rooms have lights and animated pieces (%d lights, %d animated)" % [lights, animated])
	# No forest earth on the ruins' paths, and the exit waits for the Serpiente.
	var dirt_layers := 0
	for room in level.rooms.values():
		dirt_layers += 1 if room.get_node_or_null("Paths") != null else 0
	dirt_layers += level.get_node("Map/Corridors").find_children("CorridorPath*", "", false, false).size()
	_check(dirt_layers == 0, "the ruins keep their worn-stone paths (no forest dirt layers)")
	var portals: Array = level.get_tree().get_nodes_in_group("exit_portals")
	_check(portals.size() == 1 and not portals[0].is_open() and portals[0].required_flag == &"ruins_boss_defeated",
			"the ruins' exit is sealed until the Serpiente falls")
	portals[0].seal_with(&"ruins_boss_defeated")
	root.get_node("GameState").set_flag(&"forest_boss_defeated")
	_check(not portals[0].is_open(), "sealed with the chapter's flag, the forest's flag does not open it")
	root.get_node("GameState").reset()
	# The Viajera waits in the event room and her conversation follows the chapter's story.
	var npcs: Array = level.get_tree().get_nodes_in_group("npcs")
	var travelers: Array = npcs.filter(func(n: Node) -> bool: return n.dialogue_id == &"traveler")
	var merchants: Array = npcs.filter(func(n: Node) -> bool: return n.dialogue_id == &"merchant")
	_check(npcs.size() == 2 and travelers.size() == 1 and travelers[0].get_parent().data.type == RoomData.RoomType.EVENT,
			"the Viajera waits in the event room (%d NPCs)" % npcs.size())
	var merchant_rooms: Array = merchants.map(func(n: Node) -> int: return n.get_parent().data.type)
	merchant_rooms.sort()
	_check(merchant_rooms == [RoomData.RoomType.SPECIAL], "the Mercader waits only in the special room")
	var dialogue: Node = root.get_node("Dialogue")
	var state: Node = root.get_node("GameState")
	state.reset()
	var traveler: Dictionary = dialogue.load_dialogue(&"traveler")
	var first: bool = dialogue.pick_state(traveler) == &"first"
	state.set_flag(&"met_traveler")
	var again: bool = dialogue.pick_state(traveler) == &"again"
	state.set_flag(&"ruins_boss_defeated")
	var final: bool = dialogue.pick_state(traveler) == &"final"
	state.reset()
	_check(first and again and final and traveler.speaker == "La Viajera",
			"she greets, then hints at the boss, and after the Serpiente falls she says her last lines")
	_check(level.get_node("WorldTint").color.b > level.get_node("WorldTint").color.r and level.get_node_or_null("AmbientLife") == null
			or level.find_children("AmbientLife*", "", true, false).is_empty(),
			"a cold tint and no forest life over the ruins")
	var player: Node2D = level.player
	var dark_room = level.rooms.values().filter(func(r: Node) -> bool: return r.data.dark)[0]
	dark_room._set_player_light(player, true)
	_check(player.get_node_or_null("DarkRoomLight") != null, "a glow follows the player in a dark room")
	dark_room._set_player_light(player, false)
	await process_frame
	_check(player.get_node_or_null("DarkRoomLight") == null, "and goes away when he leaves")
	level.free()

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
