extends SceneTree
## Generates the test room and scenario resources in data/rooms/ and data/scenarios/.
## Run from the repo root: godot --headless --path . --script res://tools/make_test_data.gd
## The .tres files can be edited by hand afterwards; this only exists to create them in the right format.

const ROOMS := [
	# id, type, scene, weight, tags, min_enemies, max_enemies
	[&"test_start", RoomData.RoomType.START, "start", 1.0, [], 0, 0],
	[&"test_boss", RoomData.RoomType.BOSS, "boss", 1.0, [], 0, 0],
	[&"test_combat_a", RoomData.RoomType.COMBAT, "combat_a", 1.0, [&"standard"], 2, 4],
	[&"test_combat_b", RoomData.RoomType.COMBAT, "combat_b", 1.0, [&"standard"], 2, 4],
	[&"test_combat_c", RoomData.RoomType.COMBAT, "combat_c", 0.8, [&"ambush"], 4, 6],
	[&"test_combat_d", RoomData.RoomType.COMBAT, "combat_d", 0.8, [&"watch"], 3, 5],
	[&"test_event", RoomData.RoomType.EVENT, "event", 1.0, [], 0, 0],
	[&"test_reward", RoomData.RoomType.REWARD, "reward", 1.0, [], 0, 0],
	[&"test_special", RoomData.RoomType.SPECIAL, "special", 1.0, [], 0, 0],
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/rooms")
	DirAccess.make_dir_recursive_absolute("res://data/scenarios")
	var saved := {}
	for spec in ROOMS:
		var room := RoomData.new()
		room.id = spec[0]
		room.type = spec[1]
		room.scene = load("res://scenes/levels/rooms/%s.tscn" % spec[2])
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
	scenario.id = &"test"
	scenario.display_name = "Escenario de prueba"
	scenario.grid_size = Vector2i(5, 5)
	scenario.min_main_path = 6
	scenario.max_main_path = 11
	scenario.side_rooms = 3
	scenario.loop_chance = 0.1
	scenario.event_rooms = 1
	scenario.reward_rooms = 1
	scenario.special_rooms = 1
	scenario.start_room = saved[&"test_start"]
	scenario.boss_room = saved[&"test_boss"]
	var rooms: Array[RoomData] = []
	for id in [&"test_combat_a", &"test_combat_b", &"test_combat_c", &"test_combat_d", &"test_event", &"test_reward", &"test_special"]:
		rooms.append(saved[id])
	scenario.rooms = rooms
	var pool: Array[PackedScene] = [load("res://scenes/enemies/grunt.tscn")]
	scenario.enemy_pool = pool
	ResourceSaver.save(scenario, "res://data/scenarios/test.tres")
	print("test data written")
	quit()
