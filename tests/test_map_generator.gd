extends SceneTree
## Map generator test (pure data, no nodes): validity over many seeds, determinism, variety,
## special rooms, director weight modifiers and edge-case scenarios.
## Run: godot --headless --path . --script res://tests/test_map_generator.gd

const SEEDS := 400

var _ok := true


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	var scenario: ScenarioData = load("res://data/scenarios/test.tres")

	# --- Every seed gives a valid, fully reachable map
	var invalid := 0
	var out_of_range := 0
	var bad_special := 0
	var bad_ends := 0
	var sizes := {}
	var distinct := {}
	for map_seed in range(1, SEEDS + 1):
		var layout := MapGenerator.generate(scenario, map_seed)
		if not layout.validate().is_empty():
			invalid += 1
			printerr("seed %d: %s" % [map_seed, layout.validate()])
		var length := layout.main_path.size()
		if length < scenario.min_main_path or length > scenario.max_main_path:
			out_of_range += 1
		if layout.count_of_type(RoomData.RoomType.EVENT) != 1 \
				or layout.count_of_type(RoomData.RoomType.REWARD) != 1 \
				or layout.count_of_type(RoomData.RoomType.SPECIAL) != 1:
			bad_special += 1
		if layout.start_cell.y != scenario.grid_size.y - 1 or layout.boss_cell.y != 0:
			bad_ends += 1
		if layout.cells.size() != length + scenario.side_rooms:
			sizes[map_seed] = layout.cells.size()
		distinct[layout.to_ascii()] = true
	_check(invalid == 0, "%d seeds produce valid, fully reachable maps (invalid: %d)" % [SEEDS, invalid])
	_check(out_of_range == 0, "main path length is within limits (out of range: %d)" % out_of_range)
	_check(bad_special == 0, "every map has exactly one event, reward and special room (bad: %d)" % bad_special)
	_check(bad_ends == 0, "start is on the bottom row and the boss on the top row (bad: %d)" % bad_ends)
	_check(sizes.is_empty(), "cell count = main path + side rooms (bad: %d)" % sizes.size())
	_check(distinct.size() > SEEDS / 2, "different seeds give different maps (%d distinct of %d)" % [distinct.size(), SEEDS])

	# --- Determinism
	var a := MapGenerator.generate(scenario, 424242)
	var b := MapGenerator.generate(scenario, 424242)
	_check(a.to_ascii() == b.to_ascii() and _room_ids(a) == _room_ids(b), "same seed gives the same map")
	_check(a.to_ascii() != MapGenerator.generate(scenario, 424243).to_ascii(), "a different seed changes the map")
	print("Sample map (seed 424242):\n", a.to_ascii())

	# --- Director weight modifiers steer which rooms appear
	var ambush_boost := _share_of_room(scenario, &"test_combat_c", {&"ambush": 1000.0})
	var ambush_off := _share_of_room(scenario, &"test_combat_c", {&"ambush": 0.0})
	var neutral := _share_of_room(scenario, &"test_combat_c", {})
	_check(ambush_boost > 0.8, "weighting a tag up makes it dominant (%.0f%%)" % (ambush_boost * 100.0))
	_check(ambush_off == 0.0, "weighting a tag to 0 removes those rooms (%.0f%%)" % (ambush_off * 100.0))
	_check(neutral > 0.05 and neutral < 0.6, "without modifiers rooms are mixed (%.0f%%)" % (neutral * 100.0))

	# --- Edge-case scenarios still produce playable maps
	_check_variant(scenario, "small 3x3 grid", func(s: ScenarioData) -> void:
		s.grid_size = Vector2i(3, 3)
		s.min_main_path = 3
		s.max_main_path = 5
		s.side_rooms = 2)
	_check_variant(scenario, "large 8x8 grid", func(s: ScenarioData) -> void:
		s.grid_size = Vector2i(8, 8)
		s.min_main_path = 10
		s.max_main_path = 18
		s.side_rooms = 8
		s.loop_chance = 0.3)
	_check_variant(scenario, "tiny 2x2 grid", func(s: ScenarioData) -> void:
		s.grid_size = Vector2i(2, 2)
		s.min_main_path = 2
		s.max_main_path = 3
		s.side_rooms = 1)
	_check_variant(scenario, "single column", func(s: ScenarioData) -> void:
		s.grid_size = Vector2i(1, 5)
		s.min_main_path = 5
		s.max_main_path = 5
		s.side_rooms = 0)
	_check_variant(scenario, "impossible minimum length (falls back to a straight path)", func(s: ScenarioData) -> void:
		s.min_main_path = 40
		s.max_main_path = 50)
	_check_variant(scenario, "no loops", func(s: ScenarioData) -> void:
		s.loop_chance = 0.0)
	_check_variant(scenario, "no special rooms requested", func(s: ScenarioData) -> void:
		s.event_rooms = 0
		s.reward_rooms = 0
		s.special_rooms = 0)
	_check_variant(scenario, "only combat rooms available (others fall back to combat)", func(s: ScenarioData) -> void:
		var only_combat: Array[RoomData] = []
		for room in s.rooms:
			if room.type == RoomData.RoomType.COMBAT:
				only_combat.append(room)
		s.rooms = only_combat)

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _check_variant(base: ScenarioData, label: String, tweak: Callable) -> void:
	var scenario: ScenarioData = base.duplicate()
	tweak.call(scenario)
	var bad := 0
	for map_seed in range(1, 101):
		var layout := MapGenerator.generate(scenario, map_seed)
		if not layout.validate().is_empty():
			bad += 1
			printerr("%s, seed %d: %s" % [label, map_seed, layout.validate()])
	_check(bad == 0, "variant '%s' stays valid over 100 seeds (invalid: %d)" % [label, bad])


func _share_of_room(scenario: ScenarioData, room_id: StringName, modifiers: Dictionary) -> float:
	var combat := 0
	var matching := 0
	for map_seed in range(1, 101):
		var layout := MapGenerator.generate(scenario, map_seed, modifiers)
		for cell: MapLayout.Cell in layout.cells.values():
			if cell.type == RoomData.RoomType.COMBAT:
				combat += 1
				if cell.room_data.id == room_id:
					matching += 1
	return float(matching) / maxf(combat, 1)


func _room_ids(layout: MapLayout) -> Array:
	var ids := []
	var coords := layout.cells.keys()
	coords.sort()
	for coord in coords:
		ids.append("%s:%s" % [coord, layout.get_cell(coord).room_data.id])
	return ids


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
