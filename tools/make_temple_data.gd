extends SceneTree
## Generates the Templo del Eclipse scenario (data/scenarios/temple.tres) and its rooms
## (data/rooms/temple_*.tres), and points the ruins' exit at the temple (data/scenarios/ruins.tres,
## which tools/make_ruins_data.gd also writes). The temple's grid cell is 48x32 tiles and its rooms come
## in three sizes (large 42x28, medium 34x24, small 26x20), each centred in its cell; every room's
## `size_tiles` is checked against its plan here.
## Run from the repo root: godot --headless --path . --script res://tools/make_temple_data.gd
## Needs the room scenes (python tools/make_temple_rooms.py), the tileset profile, the theme and the
## props' art. Every room's plan is checked again here with the game's rules
## (tools/validate_temple_plans.gd: TemplePlan.validate with the room's surge stages and spawn_ok for
## its markers), and nothing is written when one fails. Balance lives in the generated .tres files.

## The three room sizes of the temple (tiles) and the grid cell every room is centred in.
const LARGE := Vector2i(42, 28)
const MEDIUM := Vector2i(34, 24)
const SMALL := Vector2i(26, 20)
const CELL_TILES := Vector2i(48, 32)

const ROOMS := [
	# id, type, scene, weight, tags, min_enemies, max_enemies, height, enemy_affinity,
	# [surge_stages, kills_stage_1, kills_to_recede, wave_size, max_alive] (empty = no surge), size_tiles
	[&"temple_start", RoomData.RoomType.START, "start", 1.0, [], 0, 0, 0, {}, [], MEDIUM],
	[&"temple_boss", RoomData.RoomType.BOSS, "boss", 1.0, [], 0, 0, 1, {}, [], LARGE],
	[&"temple_pillar_court", RoomData.RoomType.COMBAT, "pillar_court", 1.0, [&"court"], 2, 4, 0,
			{&"monje_sin_rostro": 2.0, &"centinela_obsidiana": 1.5, &"duelista_maldito": 1.5, &"verdugo_piedra": 1.5}, [], LARGE],
	[&"temple_isles", RoomData.RoomType.COMBAT, "isles", 1.0, [&"bridges"], 2, 4, 0,
			{&"manta_hollin": 3.0, &"carnero_basalto": 0.5, &"rueda_devoradora": 0.5}, [], MEDIUM],
	[&"temple_terraces", RoomData.RoomType.COMBAT, "terraces", 1.0, [&"heights"], 2, 4, 0,
			{&"ojo_sol": 2.0, &"oraculo_ceniza": 2.0, &"acolito_brasero": 1.5, &"carnero_basalto": 0.5, &"rueda_devoradora": 0.5}, [], MEDIUM],
	[&"temple_trap_walk", RoomData.RoomType.COMBAT, "trap_walk", 0.8, [&"traps"], 2, 4, 0,
			{&"relojero_trampas": 3.0, &"baldosa_hambrienta": 2.0, &"carcelero_cadenas": 2.0, &"manos_abismo": 1.5,
			&"carnero_basalto": 0.5, &"rueda_devoradora": 0.5}, [], MEDIUM],
	[&"temple_lava_falls", RoomData.RoomType.COMBAT, "lava_falls", 0.8, [&"falls"], 2, 4, 1,
			{&"manta_hollin": 3.0, &"salamandra_cristal": 2.0, &"ojo_sol": 1.5}, [], MEDIUM],
	[&"temple_surge_basin", RoomData.RoomType.COMBAT, "surge_basin", 2.0, [&"surge"], 2, 3, 0,
			{&"manta_hollin": 1.5, &"nucleo_cria": 0.0, &"arana_talladora": 0.0}, [1, 4, 4, 2, 4], MEDIUM],
	[&"temple_surge_tiers", RoomData.RoomType.COMBAT, "surge_tiers", 2.0, [&"surge"], 2, 3, 0,
			{&"ojo_sol": 1.5, &"acolito_brasero": 1.5, &"nucleo_cria": 0.0, &"arana_talladora": 0.0}, [2, 4, 4, 2, 4], LARGE],
	[&"temple_surge_bridges", RoomData.RoomType.COMBAT, "surge_bridges", 2.0, [&"surge", &"bridges"], 2, 3, 0,
			{&"manta_hollin": 2.0, &"nucleo_cria": 0.0, &"arana_talladora": 0.0}, [2, 4, 4, 2, 4], LARGE],
	[&"temple_sanctum", RoomData.RoomType.REWARD, "sanctum", 1.0, [&"bridges"], 0, 0, 0, {}, [], SMALL],
	[&"temple_event", RoomData.RoomType.EVENT, "event", 1.0, [], 0, 0, 0, {}, [], SMALL],
	[&"temple_special", RoomData.RoomType.SPECIAL, "special", 1.0, [], 0, 0, 0, {}, [], SMALL],
]
## gusano_puentes (the bridge worm) is left out of the temple: too hard for its room in playtests.
const ENEMIES := ["centinela_obsidiana", "carcelero_cadenas", "acolito_brasero", "verdugo_piedra", "duelista_maldito",
		"salamandra_cristal", "caracol_escoria", "carnero_basalto", "manta_hollin", "eco_espejo",
		"monje_sin_rostro", "mascara_parasita", "oraculo_ceniza", "custodio_sello", "ojo_sol", "campanero_bronce",
		"rueda_devoradora", "arana_talladora", "forjador_condenado", "baldosa_hambrienta", "manos_abismo",
		"vasija_poseida", "relojero_trampas", "nucleo_cria"]
const MARKER_CONTAINERS := ["EnemySpawns", "NpcSpawn", "BossSpawn", "ChestSpawn", "SpecialSpawn", "ExitSpawn"]


func _initialize() -> void:
	var validator: GDScript = load("res://tools/validate_temple_plans.gd")
	var problems := 0
	var rooms := {}
	for spec in ROOMS:
		var scene: PackedScene = load("res://scenes/levels/rooms/temple/%s.tscn" % spec[2])
		var surge: Array = spec[9]
		for problem in _check_scene(validator, scene, surge[0] if not surge.is_empty() else 0, spec[7], spec[10]):
			printerr("%s: %s" % [spec[0], problem])
			problems += 1
		rooms[spec[0]] = [spec, scene]
	if problems > 0:
		printerr("%d problems: no temple data written" % problems)
		quit(1)
		return

	var saved := {}
	for id in rooms:
		var spec: Array = rooms[id][0]
		var room := RoomData.new()
		room.id = spec[0]
		room.type = spec[1]
		room.scene = rooms[id][1]
		room.weight = spec[3]
		var tags: Array[StringName] = []
		for tag in spec[4]:
			tags.append(tag)
		room.tags = tags
		room.min_enemies = spec[5]
		room.max_enemies = spec[6]
		room.height = spec[7]
		room.size_tiles = spec[10]
		room.enemy_affinity = spec[8]
		var surge: Array = spec[9]
		if not surge.is_empty():
			room.surge_stages = surge[0]
			room.kills_stage_1 = surge[1]
			room.kills_to_recede = surge[2]
			room.wave_size = surge[3]
			room.max_alive = surge[4]
		var path := "res://data/rooms/%s.tres" % spec[0]
		ResourceSaver.save(room, path)
		saved[spec[0]] = load(path)

	var scenario := ScenarioData.new()
	scenario.id = &"temple"
	scenario.display_name = "Templo del Eclipse"
	scenario.chapter_title = "El templo conoce tu destino."
	scenario.theme = load("res://data/themes/temple.tres")
	scenario.grid_size = Vector2i(5, 5)
	scenario.min_main_path = 6
	scenario.max_main_path = 9
	scenario.cell_tiles = CELL_TILES
	scenario.side_rooms = 4
	scenario.loop_chance = 0.1
	scenario.event_rooms = 1
	scenario.reward_rooms = 2
	scenario.special_rooms = 1
	scenario.start_room = saved[&"temple_start"]
	scenario.boss_room = saved[&"temple_boss"]
	var room_list: Array[RoomData] = []
	for spec in ROOMS:
		if spec[1] != RoomData.RoomType.START and spec[1] != RoomData.RoomType.BOSS:
			room_list.append(saved[spec[0]])
	scenario.rooms = room_list
	var pool: Array[PackedScene] = []
	for id in ENEMIES:
		pool.append(load("res://scenes/enemies/%s.tscn" % id))
	scenario.enemy_pool = pool
	scenario.enemy_weights = {}
	scenario.roster_size = 10
	scenario.boss_scene = load("res://scenes/enemies/ancient_guardian.tscn")
	var chests: Array[PackedScene] = [load("res://scenes/world/chest.tscn")]
	scenario.chest_scenes = chests
	scenario.exit_scene = load("res://scenes/world/exit_portal.tscn")
	# The Mercader waits near the landing and again in the special room; the event room stays empty.
	scenario.start_npc_scene = load("res://scenes/npcs/merchant.tscn")
	scenario.special_npc_scene = load("res://scenes/npcs/merchant.tscn")
	var drops: Array[ResourceData] = [load("res://data/resources/heart.tres"), load("res://data/resources/arrows.tres"),
			load("res://data/resources/gold.tres")]
	scenario.drops = drops
	scenario.objective = "Encuentra al Guardián antiguo"
	scenario.objective_done = "Cruza el portal"
	scenario.objective_flag = &"temple_boss_defeated"
	scenario.completion_text = "Capítulo 3 completado. La brújula está completa: Nico vuelve a casa."
	ResourceSaver.save(scenario, "res://data/scenarios/temple.tres")

	# The ruins' exit leads here: the temple is the last chapter.
	var ruins: ScenarioData = load("res://data/scenarios/ruins.tres")
	ruins.next_scenario = load("res://data/scenarios/temple.tres")
	ResourceSaver.save(ruins, "res://data/scenarios/ruins.tres")
	print("temple data written")
	quit()


## The problems of a room scene: its Shape's plan judged by TemplePlan (with the room's surge stages,
## base height and size) and every marker on a spawn_ok cell. Read from the packed scene's state, so no
## node is built.
func _check_scene(validator: GDScript, scene: PackedScene, surge_stages: int, height: int, size: Vector2i) -> Array:
	var state := scene.get_state()
	var rows := ""
	var markers: Array[Vector2] = []
	for i in state.get_node_count():
		var node_name := String(state.get_node_name(i))
		var parent := String(state.get_node_path(i, true)).get_file()
		for j in state.get_node_property_count(i):
			var property := String(state.get_node_property_name(i, j))
			if node_name == "Shape" and property == "rows":
				rows = state.get_node_property_value(i, j)
			elif property == "position" and (node_name == "PlayerSpawn" or MARKER_CONTAINERS.has(parent)):
				markers.append(state.get_node_property_value(i, j))
	if rows == "":
		return ["no Shape with a plan"]
	var result: Dictionary = validator.check(rows, surge_stages, height, size)
	var problems: Array = result["problems"].duplicate()
	var ok := {}
	for cell in result["spawn_ok"]:
		ok[Vector2i(cell[0], cell[1])] = true
	for point in markers:
		var cell := Vector2i((point / TemplePlan.TILE).floor())
		if not ok.has(cell):
			problems.append("the marker at %s is not on a spawn_ok cell" % point)
	return problems
