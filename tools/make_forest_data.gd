extends SceneTree
## Generates the forest scenario (data/scenarios/forest.tres) and its rooms (data/rooms/forest_*.tres).
## Run from the repo root: godot --headless --path . --script res://tools/make_forest_data.gd
## Needs the room scenes (python tools/make_forest_rooms.py) and the theme
## (tools/make_forest_tileset.gd). Balance and parameters live in the generated .tres files.

const ROOMS := [
	# id, type, scene, weight, tags, min_enemies, max_enemies
	[&"forest_start", RoomData.RoomType.START, "start", 1.0, [], 0, 0],
	[&"forest_boss", RoomData.RoomType.BOSS, "boss", 1.0, [], 0, 0],
	[&"forest_clearing_a", RoomData.RoomType.COMBAT, "clearing_a", 1.0, [&"standard"], 2, 4],
	[&"forest_clearing_b", RoomData.RoomType.COMBAT, "clearing_b", 1.0, [&"standard"], 2, 4],
	[&"forest_river", RoomData.RoomType.COMBAT, "river", 1.0, [&"standard"], 2, 4],
	[&"forest_dense", RoomData.RoomType.COMBAT, "dense", 0.8, [&"ambush"], 4, 6],
	[&"forest_watch", RoomData.RoomType.COMBAT, "watch", 0.8, [&"watch"], 3, 5],
	[&"forest_event", RoomData.RoomType.EVENT, "event", 1.0, [], 0, 0],
	[&"forest_reward", RoomData.RoomType.REWARD, "reward", 1.0, [], 0, 0],
	[&"forest_special", RoomData.RoomType.SPECIAL, "special", 1.0, [], 0, 0],
]


func _initialize() -> void:
	var saved := {}
	for spec in ROOMS:
		var room := RoomData.new()
		room.id = spec[0]
		room.type = spec[1]
		room.scene = load("res://scenes/levels/rooms/forest/%s.tscn" % spec[2])
		room.weight = spec[3]
		var tags: Array[StringName] = []
		for tag in spec[4]:
			tags.append(tag)
		room.tags = tags
		room.min_enemies = spec[5]
		room.max_enemies = spec[6]
		var path := "res://data/rooms/%s.tres" % spec[0]
		ResourceSaver.save(room, path)
		saved[spec[0]] = load(path)

	var scenario := ScenarioData.new()
	scenario.id = &"forest"
	scenario.display_name = "Bosque de la Aurora"
	scenario.chapter_title = "El bosque despierta."
	scenario.theme = load("res://data/themes/forest.tres")
	scenario.grid_size = Vector2i(5, 6)
	scenario.min_main_path = 7
	scenario.max_main_path = 12
	scenario.side_rooms = 4
	scenario.loop_chance = 0.1
	scenario.event_rooms = 1
	scenario.reward_rooms = 2
	scenario.special_rooms = 1
	scenario.start_room = saved[&"forest_start"]
	scenario.boss_room = saved[&"forest_boss"]
	var rooms: Array[RoomData] = []
	for id in [&"forest_clearing_a", &"forest_clearing_b", &"forest_river", &"forest_dense", &"forest_watch",
			&"forest_event", &"forest_reward", &"forest_special"]:
		rooms.append(saved[id])
	scenario.rooms = rooms
	# Sombra errante and Murciélago (a visitor from the ruins, for now) are real; the grunt stays as a stand-in until the Bestia de la niebla exists.
	var pool: Array[PackedScene] = [load("res://scenes/enemies/sombra_errante.tscn"), load("res://scenes/enemies/murcielago.tscn"), load("res://scenes/enemies/grunt.tscn")]
	scenario.enemy_pool = pool
	scenario.npc_scene = load("res://scenes/npcs/elder.tscn")
	var chests: Array[PackedScene] = [load("res://scenes/world/chest_heart.tscn"), load("res://scenes/world/chest_heal.tscn")]
	scenario.chest_scenes = chests
	scenario.boss_scene = load("res://scenes/enemies/forest_guardian.tscn")
	scenario.exit_scene = load("res://scenes/world/exit_portal.tscn")
	scenario.objective = "Encuentra al Guardián del bosque"
	scenario.objective_done = "Cruza el portal"
	scenario.objective_flag = &"forest_boss_defeated"
	scenario.completion_text = "Capítulo 1 completado. Las ruinas de la montaña te esperan."
	ResourceSaver.save(scenario, "res://data/scenarios/forest.tres")
	print("forest data written")
	quit()
