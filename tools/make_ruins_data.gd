extends SceneTree
## Generates the Ruinas de la Montaña scenario (data/scenarios/ruins.tres) and its rooms
## (data/rooms/ruins_*.tres).
## Run from the repo root: godot --headless --path . --script res://tools/make_ruins_data.gd
## Needs the room scenes (python tools/make_ruins_rooms.py), the tileset profile
## (tools/make_tileset_ruins.gd) and the theme (tools/make_ruins_theme.gd). Balance and parameters
## live in the generated .tres files.

const ROOMS := [
	# id, type, scene, weight, tags, min_enemies, max_enemies, height, dark
	[&"ruins_start", RoomData.RoomType.START, "start", 1.0, [], 0, 0, 0, false],
	[&"ruins_boss", RoomData.RoomType.BOSS, "boss", 1.0, [], 0, 0, 1, false],
	[&"ruins_river", RoomData.RoomType.COMBAT, "river", 1.0, [&"standard"], 2, 4, 0, false],
	[&"ruins_terraces", RoomData.RoomType.COMBAT, "terraces", 1.0, [&"standard"], 2, 4, 0, false],
	[&"ruins_plateau", RoomData.RoomType.COMBAT, "plateau", 1.0, [&"standard"], 2, 4, 1, false],
	[&"ruins_narrow", RoomData.RoomType.COMBAT, "narrow", 0.8, [&"ambush"], 4, 6, 0, true],
	[&"ruins_falls", RoomData.RoomType.COMBAT, "falls", 0.8, [&"watch"], 3, 5, 0, true],
	[&"ruins_event", RoomData.RoomType.EVENT, "event", 1.0, [], 0, 0, 0, false],
	[&"ruins_reward", RoomData.RoomType.REWARD, "reward", 1.0, [], 0, 0, 0, false],
	[&"ruins_special", RoomData.RoomType.SPECIAL, "special", 1.0, [], 0, 0, 0, false],
]


func _initialize() -> void:
	var saved := {}
	for spec in ROOMS:
		var room := RoomData.new()
		room.id = spec[0]
		room.type = spec[1]
		room.scene = load("res://scenes/levels/rooms/ruins/%s.tscn" % spec[2])
		room.weight = spec[3]
		var tags: Array[StringName] = []
		for tag in spec[4]:
			tags.append(tag)
		room.tags = tags
		room.min_enemies = spec[5]
		room.max_enemies = spec[6]
		room.height = spec[7]
		room.dark = spec[8]
		var path := "res://data/rooms/%s.tres" % spec[0]
		ResourceSaver.save(room, path)
		saved[spec[0]] = load(path)

	var scenario := ScenarioData.new()
	scenario.id = &"ruins"
	scenario.display_name = "Ruinas de la Montaña"
	scenario.chapter_title = "Las ruinas guardan respuestas."
	scenario.theme = load("res://data/themes/ruins.tres")
	scenario.grid_size = Vector2i(5, 6)
	scenario.min_main_path = 7
	scenario.max_main_path = 12
	scenario.side_rooms = 4
	scenario.loop_chance = 0.1
	scenario.event_rooms = 1
	scenario.reward_rooms = 2
	scenario.special_rooms = 1
	scenario.start_room = saved[&"ruins_start"]
	scenario.boss_room = saved[&"ruins_boss"]
	var rooms: Array[RoomData] = []
	for id in [&"ruins_river", &"ruins_terraces", &"ruins_plateau", &"ruins_narrow", &"ruins_falls",
			&"ruins_event", &"ruins_reward", &"ruins_special"]:
		rooms.append(saved[id])
	scenario.rooms = rooms
	var pool: Array[PackedScene] = [load("res://scenes/enemies/bestia_de_la_niebla.tscn"),
			load("res://scenes/enemies/sombra_errante.tscn"), load("res://scenes/enemies/murcielago.tscn")]
	scenario.enemy_pool = pool
	scenario.enemy_weights = {&"bestia_de_la_niebla": 3.0, &"sombra_errante": 3.0, &"murcielago": 4.0}
	var chests: Array[PackedScene] = [load("res://scenes/world/chest_heart.tscn"), load("res://scenes/world/chest_heal.tscn")]
	scenario.npc_scene = load("res://scenes/npcs/traveler.tscn")
	scenario.chest_scenes = chests
	scenario.exit_scene = load("res://scenes/world/exit_portal.tscn")
	var drops: Array[ResourceData] = [load("res://data/resources/heart.tres"), load("res://data/resources/arrows.tres"),
			load("res://data/resources/gold.tres")]
	scenario.drops = drops
	scenario.objective = "Encuentra a la Serpiente de piedra"
	scenario.objective_done = "Cruza el portal"
	scenario.objective_flag = &"ruins_boss_defeated"
	scenario.completion_text = "Capítulo 2 completado. El templo del eclipse te espera."
	ResourceSaver.save(scenario, "res://data/scenarios/ruins.tres")
	print("ruins data written")
	quit()
