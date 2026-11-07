extends SceneTree
## Map generator test (pure data, no nodes): validity over many seeds, determinism, variety,
## special rooms, director weight modifiers and edge-case scenarios.
## Run: godot --headless --path . --script res://tests/test_map_generator.gd

const SEEDS := 400
## room_data.id per cell ("x,y:id" sorted by coord) of the forest and the ruins for seeds 1..20,
## recorded after the special room (the Mercader's shop) took the first free dead end, so a change to the generator that moves one room of
## the first two chapters fails here (regenerate the table only on purpose, with the old code).
const REFERENCE := {
	"forest": {
		1: "2,3:forest_reward 2,4:forest_river 2,5:forest_start 3,0:forest_boss 3,1:forest_clearing_a 3,2:forest_event 3,3:forest_river 3,4:forest_clearing_a 3,5:forest_reward 4,0:forest_clearing_b 4,1:forest_watch 4,2:forest_dense 4,3:forest_special",
		2: "0,2:forest_reward 0,3:forest_river 0,4:forest_watch 0,5:forest_start 1,1:forest_reward 1,2:forest_event 1,3:forest_clearing_b 1,4:forest_dense 2,0:forest_special 2,1:forest_dense 2,2:forest_clearing_a 3,0:forest_boss 3,1:forest_river",
		3: "0,1:forest_reward 1,1:forest_dense 1,2:forest_clearing_b 2,0:forest_reward 2,1:forest_watch 2,2:forest_event 2,3:forest_clearing_a 3,0:forest_boss 3,1:forest_clearing_b 3,2:forest_special 3,3:forest_clearing_a 3,4:forest_river 3,5:forest_dense 4,4:forest_river 4,5:forest_start",
		4: "0,3:forest_reward 1,3:forest_clearing_b 2,2:forest_special 2,3:forest_river 2,4:forest_river 2,5:forest_start 3,2:forest_event 3,3:forest_clearing_a 3,4:forest_reward 4,0:forest_boss 4,1:forest_clearing_a 4,2:forest_watch",
		5: "0,0:forest_special 0,1:forest_watch 0,2:forest_reward 0,3:forest_event 0,4:forest_river 1,0:forest_clearing_a 1,1:forest_river 1,2:forest_clearing_b 1,3:forest_clearing_a 1,4:forest_river 1,5:forest_start 2,0:forest_boss 2,2:forest_reward 2,4:forest_dense 2,5:forest_clearing_b",
		6: "0,4:forest_dense 0,5:forest_clearing_b 1,2:forest_reward 1,3:forest_watch 1,4:forest_river 1,5:forest_start 2,1:forest_special 2,2:forest_event 2,3:forest_dense 2,4:forest_clearing_a 3,0:forest_boss 3,1:forest_clearing_a 3,2:forest_clearing_b 3,3:forest_reward 4,0:forest_clearing_a 4,1:forest_clearing_b",
		7: "0,1:forest_clearing_b 0,2:forest_clearing_a 0,3:forest_event 0,4:forest_river 1,0:forest_boss 1,1:forest_watch 1,2:forest_reward 1,3:forest_reward 1,4:forest_dense 1,5:forest_clearing_a 2,1:forest_special 2,4:forest_clearing_a 2,5:forest_river 3,5:forest_start",
		8: "1,0:forest_reward 1,1:forest_clearing_a 1,2:forest_special 2,0:forest_dense 2,1:forest_dense 2,4:forest_reward 3,0:forest_boss 3,1:forest_dense 3,2:forest_river 3,3:forest_clearing_b 3,4:forest_clearing_b 3,5:forest_watch 4,1:forest_river 4,2:forest_event 4,5:forest_start",
		9: "1,0:forest_boss 1,1:forest_clearing_b 1,2:forest_river 1,3:forest_clearing_a 1,4:forest_reward 2,1:forest_special 2,3:forest_river 2,4:forest_event 2,5:forest_clearing_b 3,2:forest_reward 3,3:forest_clearing_b 3,4:forest_watch 3,5:forest_dense 4,4:forest_clearing_a 4,5:forest_start",
		10: "1,3:forest_reward 2,0:forest_dense 2,1:forest_clearing_b 2,2:forest_dense 2,3:forest_clearing_a 2,4:forest_river 2,5:forest_watch 3,0:forest_boss 3,2:forest_river 3,3:forest_watch 3,4:forest_clearing_b 3,5:forest_start 4,1:forest_special 4,2:forest_event 4,3:forest_clearing_a 4,4:forest_reward",
		11: "0,0:forest_dense 0,1:forest_clearing_a 0,2:forest_event 0,3:forest_reward 0,4:forest_watch 0,5:forest_start 1,0:forest_boss 1,1:forest_river 1,2:forest_watch 1,3:forest_special 1,5:forest_reward",
		12: "0,4:forest_reward 1,2:forest_river 1,3:forest_clearing_b 1,4:forest_clearing_b 1,5:forest_start 2,0:forest_reward 2,1:forest_dense 2,2:forest_event 2,4:forest_clearing_a 3,0:forest_clearing_b 3,4:forest_watch 4,0:forest_boss 4,4:forest_special",
		13: "0,4:forest_dense 0,5:forest_start 1,3:forest_watch 1,4:forest_clearing_b 1,5:forest_clearing_b 2,0:forest_boss 2,1:forest_reward 2,2:forest_dense 2,3:forest_river 3,0:forest_clearing_a 3,1:forest_clearing_b 3,2:forest_event 3,3:forest_reward 4,0:forest_watch 4,1:forest_river 4,2:forest_special",
		14: "1,5:forest_start 2,0:forest_special 2,2:forest_clearing_b 2,3:forest_watch 2,4:forest_clearing_b 2,5:forest_dense 3,0:forest_river 3,1:forest_river 3,2:forest_event 3,3:forest_clearing_a 4,0:forest_boss 4,1:forest_river 4,2:forest_dense 4,3:forest_reward 4,4:forest_reward",
		15: "0,5:forest_dense 1,0:forest_boss 1,1:forest_event 1,2:forest_clearing_a 1,3:forest_dense 1,4:forest_river 1,5:forest_start 2,0:forest_river 2,1:forest_clearing_a 2,2:forest_reward 2,3:forest_clearing_b 2,4:forest_river 3,0:forest_clearing_b 3,1:forest_clearing_b 3,4:forest_reward 4,0:forest_special",
		16: "0,4:forest_clearing_b 0,5:forest_start 1,1:forest_dense 1,2:forest_reward 1,3:forest_event 1,4:forest_clearing_b 2,0:forest_boss 2,1:forest_clearing_a 2,2:forest_reward 2,3:forest_river 2,4:forest_clearing_a 3,0:forest_dense 3,1:forest_watch 4,0:forest_special",
		17: "1,1:forest_special 1,2:forest_event 1,3:forest_clearing_b 2,0:forest_boss 2,1:forest_watch 2,2:forest_river 2,3:forest_dense 2,4:forest_clearing_a 2,5:forest_start 3,1:forest_reward 3,2:forest_reward 3,4:forest_river",
		18: "2,0:forest_boss 2,1:forest_clearing_a 2,2:forest_special 2,5:forest_river 3,1:forest_clearing_b 3,2:forest_clearing_b 3,3:forest_reward 3,5:forest_start 4,1:forest_reward 4,2:forest_event 4,3:forest_river 4,4:forest_dense 4,5:forest_clearing_a",
		19: "0,0:forest_boss 0,1:forest_reward 1,0:forest_river 1,1:forest_dense 1,2:forest_clearing_b 1,3:forest_river 2,2:forest_reward 2,3:forest_watch 2,4:forest_special 3,2:forest_event 3,4:forest_dense 3,5:forest_start 4,2:forest_clearing_a 4,3:forest_dense 4,4:forest_clearing_b",
		20: "0,0:forest_boss 0,1:forest_clearing_b 0,2:forest_event 0,3:forest_clearing_a 0,4:forest_river 0,5:forest_start 1,0:forest_watch 1,1:forest_river 1,2:forest_reward 1,3:forest_clearing_b 1,4:forest_dense 1,5:forest_clearing_a 2,0:forest_special 2,1:forest_reward",
	},
	"ruins": {
		1: "2,3:ruins_reward 2,4:ruins_plateau 2,5:ruins_start 3,0:ruins_boss 3,1:ruins_river 3,2:ruins_event 3,3:ruins_plateau 3,4:ruins_river 3,5:ruins_reward 4,0:ruins_terraces 4,1:ruins_falls 4,2:ruins_narrow 4,3:ruins_special",
		2: "0,2:ruins_reward 0,3:ruins_plateau 0,4:ruins_falls 0,5:ruins_start 1,1:ruins_reward 1,2:ruins_event 1,3:ruins_terraces 1,4:ruins_narrow 2,0:ruins_special 2,1:ruins_narrow 2,2:ruins_river 3,0:ruins_boss 3,1:ruins_plateau",
		3: "0,1:ruins_reward 1,1:ruins_narrow 1,2:ruins_terraces 2,0:ruins_reward 2,1:ruins_falls 2,2:ruins_event 2,3:ruins_river 3,0:ruins_boss 3,1:ruins_terraces 3,2:ruins_special 3,3:ruins_river 3,4:ruins_plateau 3,5:ruins_narrow 4,4:ruins_plateau 4,5:ruins_start",
		4: "0,3:ruins_reward 1,3:ruins_terraces 2,2:ruins_special 2,3:ruins_plateau 2,4:ruins_plateau 2,5:ruins_start 3,2:ruins_event 3,3:ruins_river 3,4:ruins_reward 4,0:ruins_boss 4,1:ruins_river 4,2:ruins_falls",
		5: "0,0:ruins_special 0,1:ruins_falls 0,2:ruins_reward 0,3:ruins_event 0,4:ruins_plateau 1,0:ruins_river 1,1:ruins_plateau 1,2:ruins_terraces 1,3:ruins_river 1,4:ruins_plateau 1,5:ruins_start 2,0:ruins_boss 2,2:ruins_reward 2,4:ruins_narrow 2,5:ruins_terraces",
		6: "0,4:ruins_narrow 0,5:ruins_terraces 1,2:ruins_reward 1,3:ruins_falls 1,4:ruins_plateau 1,5:ruins_start 2,1:ruins_special 2,2:ruins_event 2,3:ruins_narrow 2,4:ruins_river 3,0:ruins_boss 3,1:ruins_river 3,2:ruins_terraces 3,3:ruins_reward 4,0:ruins_river 4,1:ruins_terraces",
		7: "0,1:ruins_terraces 0,2:ruins_river 0,3:ruins_event 0,4:ruins_plateau 1,0:ruins_boss 1,1:ruins_falls 1,2:ruins_reward 1,3:ruins_reward 1,4:ruins_narrow 1,5:ruins_river 2,1:ruins_special 2,4:ruins_river 2,5:ruins_plateau 3,5:ruins_start",
		8: "1,0:ruins_reward 1,1:ruins_river 1,2:ruins_special 2,0:ruins_narrow 2,1:ruins_narrow 2,4:ruins_reward 3,0:ruins_boss 3,1:ruins_narrow 3,2:ruins_plateau 3,3:ruins_terraces 3,4:ruins_terraces 3,5:ruins_falls 4,1:ruins_plateau 4,2:ruins_event 4,5:ruins_start",
		9: "1,0:ruins_boss 1,1:ruins_terraces 1,2:ruins_plateau 1,3:ruins_river 1,4:ruins_reward 2,1:ruins_special 2,3:ruins_plateau 2,4:ruins_event 2,5:ruins_terraces 3,2:ruins_reward 3,3:ruins_terraces 3,4:ruins_falls 3,5:ruins_narrow 4,4:ruins_river 4,5:ruins_start",
		10: "1,3:ruins_reward 2,0:ruins_narrow 2,1:ruins_terraces 2,2:ruins_narrow 2,3:ruins_river 2,4:ruins_plateau 2,5:ruins_falls 3,0:ruins_boss 3,2:ruins_plateau 3,3:ruins_falls 3,4:ruins_terraces 3,5:ruins_start 4,1:ruins_special 4,2:ruins_event 4,3:ruins_river 4,4:ruins_reward",
		11: "0,0:ruins_narrow 0,1:ruins_river 0,2:ruins_event 0,3:ruins_reward 0,4:ruins_falls 0,5:ruins_start 1,0:ruins_boss 1,1:ruins_plateau 1,2:ruins_falls 1,3:ruins_special 1,5:ruins_reward",
		12: "0,4:ruins_reward 1,2:ruins_plateau 1,3:ruins_terraces 1,4:ruins_terraces 1,5:ruins_start 2,0:ruins_reward 2,1:ruins_narrow 2,2:ruins_event 2,4:ruins_river 3,0:ruins_terraces 3,4:ruins_falls 4,0:ruins_boss 4,4:ruins_special",
		13: "0,4:ruins_narrow 0,5:ruins_start 1,3:ruins_falls 1,4:ruins_terraces 1,5:ruins_terraces 2,0:ruins_boss 2,1:ruins_reward 2,2:ruins_narrow 2,3:ruins_plateau 3,0:ruins_river 3,1:ruins_terraces 3,2:ruins_event 3,3:ruins_reward 4,0:ruins_falls 4,1:ruins_plateau 4,2:ruins_special",
		14: "1,5:ruins_start 2,0:ruins_special 2,2:ruins_terraces 2,3:ruins_falls 2,4:ruins_terraces 2,5:ruins_narrow 3,0:ruins_plateau 3,1:ruins_plateau 3,2:ruins_event 3,3:ruins_river 4,0:ruins_boss 4,1:ruins_plateau 4,2:ruins_narrow 4,3:ruins_reward 4,4:ruins_reward",
		15: "0,5:ruins_narrow 1,0:ruins_boss 1,1:ruins_event 1,2:ruins_river 1,3:ruins_narrow 1,4:ruins_plateau 1,5:ruins_start 2,0:ruins_plateau 2,1:ruins_river 2,2:ruins_reward 2,3:ruins_terraces 2,4:ruins_plateau 3,0:ruins_terraces 3,1:ruins_terraces 3,4:ruins_reward 4,0:ruins_special",
		16: "0,4:ruins_terraces 0,5:ruins_start 1,1:ruins_narrow 1,2:ruins_reward 1,3:ruins_event 1,4:ruins_terraces 2,0:ruins_boss 2,1:ruins_river 2,2:ruins_reward 2,3:ruins_plateau 2,4:ruins_river 3,0:ruins_narrow 3,1:ruins_falls 4,0:ruins_special",
		17: "1,1:ruins_special 1,2:ruins_event 1,3:ruins_terraces 2,0:ruins_boss 2,1:ruins_falls 2,2:ruins_plateau 2,3:ruins_narrow 2,4:ruins_river 2,5:ruins_start 3,1:ruins_reward 3,2:ruins_reward 3,4:ruins_plateau",
		18: "2,0:ruins_boss 2,1:ruins_river 2,2:ruins_special 2,5:ruins_plateau 3,1:ruins_terraces 3,2:ruins_terraces 3,3:ruins_reward 3,5:ruins_start 4,1:ruins_reward 4,2:ruins_event 4,3:ruins_plateau 4,4:ruins_narrow 4,5:ruins_river",
		19: "0,0:ruins_boss 0,1:ruins_reward 1,0:ruins_plateau 1,1:ruins_narrow 1,2:ruins_terraces 1,3:ruins_plateau 2,2:ruins_reward 2,3:ruins_falls 2,4:ruins_special 3,2:ruins_event 3,4:ruins_narrow 3,5:ruins_start 4,2:ruins_river 4,3:ruins_narrow 4,4:ruins_terraces",
		20: "0,0:ruins_boss 0,1:ruins_terraces 0,2:ruins_event 0,3:ruins_river 0,4:ruins_plateau 0,5:ruins_start 1,0:ruins_falls 1,1:ruins_plateau 1,2:ruins_reward 1,3:ruins_terraces 1,4:ruins_narrow 1,5:ruins_river 2,0:ruins_special 2,1:ruins_reward",
	},
}

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

	_check_heights(scenario)
	_check_reference_layouts()
	_check_reference_geometry()
	_check_temple_geometry()
	_check_real_scenarios()

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


## Rooms are picked by height: a corridor never joins rooms two levels apart (a staircase climbs one
## level). Every room of the test scenario is offered at heights 0, 1 and 2.
func _check_heights(base: ScenarioData) -> void:
	var scenario: ScenarioData = base.duplicate()
	var tall: Array[RoomData] = []
	for room in base.rooms:
		for height in 3:
			var copy: RoomData = room.duplicate()
			copy.id = StringName("%s_h%d" % [room.id, height])
			copy.height = height
			tall.append(copy)
	scenario.rooms = tall
	var bad := 0
	var invalid := 0
	var steps := 0
	var raised := 0
	for map_seed in range(1, 201):
		var layout := MapGenerator.generate(scenario, map_seed)
		var problems := layout.validate()
		if not problems.is_empty():
			invalid += 1
			printerr("heights, seed %d: %s" % [map_seed, problems])
		var wide := false
		for coord: Vector2i in layout.cells:
			var cell := layout.get_cell(coord)
			if cell.room_data.height > 0:
				raised += 1
			for dir in cell.doors:
				var step := absi(cell.room_data.height - layout.get_cell(coord + dir).room_data.height)
				if step == 1:
					steps += 1
				wide = wide or step > 1
		if wide:
			bad += 1
	_check(bad == 0, "no corridor joins rooms two levels apart over 200 seeds (bad: %d)" % bad)
	_check(invalid == 0, "height-aware maps stay valid over 200 seeds (invalid: %d)" % invalid)
	_check(raised > 0 and steps > 0, "raised rooms and one-level steps do appear (%d raised rooms, %d steps)" % [raised, steps])

	# Neighbours two levels apart with nothing between them: the room at one neighbour's height is
	# picked, never a room at neither (height 3 is only a probe here, beyond the editor's range).
	var gap: ScenarioData = base.duplicate()
	var gap_rooms: Array[RoomData] = []
	for height in [0, 2, 3]:
		var copy: RoomData = tall[0].duplicate()
		copy.id = StringName("gap_h%d" % height)
		copy.height = height
		gap_rooms.append(copy)
	gap.rooms = gap_rooms
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var picked_heights := {}
	var neighbours: Array[int] = [0, 2]
	for i in 200:
		var room: RoomData = MapGenerator._pick_room(gap, RoomData.RoomType.COMBAT, rng, {}, {}, neighbours)
		picked_heights[room.height] = picked_heights.get(room.height, 0) + 1
	_check(picked_heights.has(0) and picked_heights.has(2) and not picked_heights.has(3),
			"with neighbours at 0 and 2 and no room between, a room at one neighbour's height is picked (%s)" % [picked_heights])

	# The layout check itself names the pair.
	var layout := MapLayout.new()
	layout.grid_size = Vector2i(1, 2)
	layout.start_cell = Vector2i(0, 1)
	layout.boss_cell = Vector2i(0, 0)
	layout.add_cell(Vector2i(0, 0)).type = RoomData.RoomType.BOSS
	layout.add_cell(Vector2i(0, 1)).type = RoomData.RoomType.START
	layout.connect_cells(Vector2i(0, 0), Vector2i(0, 1))
	layout.get_cell(Vector2i(0, 0)).room_data = tall[2]
	layout.get_cell(Vector2i(0, 1)).room_data = tall[0]
	_check(layout.validate().has("height step > 1 between (0, 0) and (0, 1)"),
			"validate() reports a height step > 1: %s" % [layout.validate()])
	layout.get_cell(Vector2i(0, 0)).room_data = tall[1]
	_check(layout.validate().is_empty(), "a one-level step is fine: %s" % [layout.validate()])


## Every real scenario (the temple with its three heights too) builds valid maps: no room two
## levels from a connected neighbour, every cell reached, the counts of special rooms right.
func _check_real_scenarios() -> void:
	for name in ["forest", "ruins", "temple"]:
		var scenario: ScenarioData = load("res://data/scenarios/%s.tres" % name)
		if scenario == null:
			_check(false, "data/scenarios/%s.tres exists" % name)
			continue
		var bad := 0
		for map_seed in range(1, 101):
			var problems := MapGenerator.generate(scenario, map_seed).validate()
			if not problems.is_empty():
				bad += 1
				printerr("%s, seed %d: %s" % [name, map_seed, problems])
		_check(bad == 0, "%s maps stay valid over 100 seeds (invalid: %d)" % [name, bad])


## The forest and the ruins (heights 0 and 1 only) keep every layout they had before.
func _check_reference_layouts() -> void:
	for name in REFERENCE:
		var scenario: ScenarioData = load("res://data/scenarios/%s.tres" % name)
		var changed: Array[int] = []
		for map_seed in REFERENCE[name]:
			var layout := MapGenerator.generate(scenario, map_seed)
			if " ".join(_room_ids(layout)) != REFERENCE[name][map_seed]:
				changed.append(map_seed)
		_check(changed.is_empty(), "%s layouts are unchanged for seeds 1..20 (changed: %s)" % [name, changed])


## The forest and the ruins keep the geometry they had before rooms had a size of their own: cells of
## 480 x 288 px 48 px apart, every room filling its cell, every corridor 48 px long and one door wide.
## The numbers are written out here on purpose; they are not read from the scenario. The temple has
## its own, wider geometry (see _check_temple_geometry).
func _check_reference_geometry() -> void:
	var cell := Vector2(480, 288)
	var stride := Vector2(528, 336)
	for name in ["forest", "ruins"]:
		var scenario: ScenarioData = load("res://data/scenarios/%s.tres" % name)
		var level = load("res://scenes/levels/forest_level.tscn").instantiate()
		level.scenario = scenario
		_check(level.cell_size() == cell and level.stride() == stride,
				"%s: the cell is 480 x 288 px and the stride 528 x 336 px" % name)
		var bad_rooms := 0
		var bad_corridors := 0
		var corridors := 0
		for map_seed in [1, 2, 3, 7, 12, 20]:
			level.layout = MapGenerator.generate(scenario, map_seed)
			for coord: Vector2i in level.layout.cells:
				var origin := Vector2(coord) * stride
				if level.cell_origin(coord) != origin or level.room_origin(coord) != origin \
						or level.room_size(coord) != cell or level.room_rect(coord) != Rect2(origin, cell):
					bad_rooms += 1
				if level.layout.are_connected(coord, coord + Vector2i.RIGHT):
					corridors += 1
					if level.corridor_floor(coord, Vector2i.RIGHT) != Rect2(origin.x + 480.0, origin.y + 144.0 - 32.0, 48.0, 64.0):
						bad_corridors += 1
				if level.layout.are_connected(coord, coord + Vector2i.DOWN):
					corridors += 1
					if level.corridor_floor(coord, Vector2i.DOWN) != Rect2(origin.x + 240.0 - 32.0, origin.y + 288.0, 64.0, 48.0):
						bad_corridors += 1
		level.free()
		_check(bad_rooms == 0, "%s: every room sits at its cell's origin and fills the cell (bad: %d)" % [name, bad_rooms])
		_check(corridors > 20 and bad_corridors == 0,
				"%s: every corridor floor is the 48 x 64 px gap between its doors (%d checked, bad: %d)" % [name, corridors, bad_corridors])


## The temple only: cells of 48 x 32 tiles (768 x 512 px), rooms of their own size centred in their cell,
## and every corridor exactly the gap between two facing doors (so its length varies with the rooms).
func _check_temple_geometry() -> void:
	var scenario: ScenarioData = load("res://data/scenarios/temple.tres")
	var level = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.scenario = scenario
	var cell := Vector2(768, 512)
	_check(level.cell_size() == cell, "temple: the cell is 768 x 512 px (48 x 32 tiles)")
	var bad_rooms := 0
	var bad_corridors := 0
	var corridors := 0
	var lengths := {}
	for map_seed in [1, 2, 3, 7, 12, 20]:
		level.layout = MapGenerator.generate(scenario, map_seed)
		for coord: Vector2i in level.layout.cells:
			var size: Vector2 = level.room_size(coord)
			var centred: Vector2 = level.cell_origin(coord) + (cell - size) / 2.0
			if level.room_origin(coord) != centred or size.x > cell.x or size.y > cell.y:
				bad_rooms += 1
			for dir in [Vector2i.RIGHT, Vector2i.DOWN]:
				if not level.layout.are_connected(coord, coord + dir):
					continue
				corridors += 1
				var a: Rect2 = level.room_rect(coord)
				var b: Rect2 = level.room_rect(coord + dir)
				var floor_rect: Rect2 = level.corridor_floor(coord, dir)
				var expected: Rect2
				if dir == Vector2i.RIGHT:
					var y: float = level.cell_origin(coord).y + cell.y / 2.0 - 32.0
					expected = Rect2(a.end.x, y, b.position.x - a.end.x, 64.0)
				else:
					var x: float = level.cell_origin(coord).x + cell.x / 2.0 - 32.0
					expected = Rect2(x, a.end.y, 64.0, b.position.y - a.end.y)
				if floor_rect != expected:
					bad_corridors += 1
				lengths[int(max(floor_rect.size.x, floor_rect.size.y) / 16.0)] = true
	level.free()
	_check(bad_rooms == 0, "temple: every room is centred in its cell and fits it (bad: %d)" % bad_rooms)
	_check(corridors > 20 and bad_corridors == 0,
			"temple: every corridor fills the gap between its doors (%d checked, bad: %d)" % [corridors, bad_corridors])
	_check(lengths.size() >= 3, "temple: corridors come in several lengths (%s tiles)" % [lengths.keys()])


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
		ids.append("%d,%d:%s" % [coord.x, coord.y, layout.get_cell(coord).room_data.id])
	return ids


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
