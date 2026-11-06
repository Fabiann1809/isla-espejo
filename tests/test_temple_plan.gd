extends SceneTree
## TemplePlan (scripts/world/temple_plan.gd): a temple room's 18x30 text plan becomes heights per cell,
## cliff faces, collision rectangles per physics layer, stair zones and a validation of the design
## (doors reachable, stairs with free ends, no plain rectangle, surge rooms fair). Pure logic, no nodes.
## Run: godot --headless --path . --script res://tests/test_temple_plan.gd

var _ok := true

#          x: 0123456789012345678901234567890 (30 columns, cell = 16 px)
# Flat room (base 0) with a lava moat around an island, four bridges on the lanes, a pillar slot and
# two blocks of masonry.
const MOAT := [
	"#############....#############",  # 0
	"#............................#",  # 1
	"#.........................##.#",  # 2
	"#...~~~~~~~~~~||~~~~~~~~~~...#",  # 3
	"#...~~~~~~~~~~||~~~~~~~~~~...#",  # 4
	"#...~~..................~~...#",  # 5
	"#...~~..p...............~~...#",  # 6
	"....~~..................~~....",  # 7
	"....==..................==....",  # 8
	"....==..................==....",  # 9
	"....~~..................~~....",  # 10
	"#...~~..................~~...#",  # 11
	"#...~~..................~~...#",  # 12
	"#...~~~~~~~~~~||~~~~~~~~~~...#",  # 13
	"#...~~~~~~~~~~||~~~~~~~~~~...#",  # 14
	"#............................#",  # 15
	"#............................#",  # 16
	"#############....#############",  # 17
]

# Three levels (base 0): a north-east platform at 1 with a 2-high block on it, a raised deck to a
# small level-1 island, a south-west platform at 1, a lava pool and three stairs.
const TERRACES := [
	"#############....#############",  # 0
	"#.................1112222221.#",  # 1
	"#.~~~.............11>2222221.#",  # 2
	"#.~~~........11bbb11>2222221.#",  # 3
	"#.................1112222221.#",  # 4
	"#.................1112222221.#",  # 5
	"#..................^^........#",  # 6
	"..............................",  # 7
	"..............................",  # 8
	"..............................",  # 9
	"..............................",  # 10
	"#.....vv.....................#",  # 11
	"#.1111111111.................#",  # 12
	"#.1111111111.................#",  # 13
	"#.1111111111.................#",  # 14
	"#.1111111111.................#",  # 15
	"#.1111111111.................#",  # 16
	"#############....#############",  # 17
]

# A surge room (base 0): a level-1 terrace with a level-2 top, stairs up from every side so no
# level-0 cell is far from one, and the level-2 top is big enough to fight on.
const SURGE := [
	"#############....#############",  # 0
	"#............................#",  # 1
	"#....vv.......vv........vv...#",  # 2
	"#...1111111111111111111111...#",  # 3
	"#...1111111111vv1111111111...#",  # 4
	"#...1111222222222222221111...#",  # 5
	"#...1111222222222222221111...#",  # 6
	"....1111222222222222221111....",  # 7
	"...>1111222222222222221111<...",  # 8
	"...>1111222222222222221111<...",  # 9
	"....1111222222222222221111....",  # 10
	"#...1111222222222222221111...#",  # 11
	"#...1111111111^^1111111111...#",  # 12
	"#...1111111111111111111111...#",  # 13
	"#...1111111111111111111111...#",  # 14
	"#....^^.......^^........^^...#",  # 15
	"#............................#",  # 16
	"#############....#############",  # 17
]


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))

	# --- malformed input -------------------------------------------------------------------------
	var short := TemplePlan.parse("#\n#\n#")
	_check(not short.errors.is_empty() and short.errors[0].contains("3 rows"), "a malformed plan reports its row count")
	var narrow_rows := MOAT.duplicate()
	narrow_rows[5] = "#...~~..~~...#"
	var narrow := TemplePlan.parse("\n".join(narrow_rows))
	_check(not narrow.errors.is_empty() and narrow.errors[0].contains("row 5"), "a short row is reported with its index")
	var odd_rows := MOAT.duplicate()
	odd_rows[8] = "....==.....?............==...."
	_check(TemplePlan.parse("\n".join(odd_rows)).errors.any(func(e: String) -> bool: return e.contains("?")),
			"an unknown character is reported")
	var door_rows := MOAT.duplicate()
	door_rows[0] = "#############.1..#############"
	_check(not TemplePlan.parse("\n".join(door_rows)).errors.is_empty(), "a door at another height is an error")

	# --- the moat: lava, bridges, pillar, masonry -----------------------------------------------
	var moat := TemplePlan.parse("\n".join(MOAT))
	_check(moat.errors.is_empty() and moat.base_height == 0, "the moat plan parses with base height 0")
	var lava := Vector2i(8, 3)
	_check(moat.height_at(lava) == -1 and not moat.is_walkable(lava, 0) and not moat.is_walkable(lava, 1)
			and _covers(moat.collision_rects(7), lava) and not _covers(moat.collision_rects(8), lava)
			and not _covers(moat.collision_rects(11), lava) and _covers(moat.collision_rects(9), lava),
			"lava is height -1 and blocks only on the water layer")
	_check(moat.face_rows(lava) == 1 and moat.face_rows(Vector2i(8, 4)) == 0,
			"the lava just south of the floor shows one row of the island's edge")
	var deck := Vector2i(14, 3)
	_check(moat.height_at(deck) == 0 and moat.is_walkable(deck, 0) and not moat.is_walkable(deck, 1)
			and not _covers(moat.collision_rects(7), deck) and not _covers(moat.collision_rects(8), deck)
			and _covers(moat.collision_rects(9), deck), "a level-0 deck crosses the lava and is walkable only at level 0")
	_check(moat.height_at(Vector2i(8, 6)) == 0 and not moat.is_walkable(Vector2i(8, 6), 0)
			and not _covers(moat.collision_rects(8), Vector2i(8, 6)), "a pillar slot takes its west neighbour's height and is not walkable")
	var masonry := moat.collision_rects(1)
	_check(masonry.size() == 1 and masonry[0] == Rect2(26 * 16, 2 * 16, 32, 16) and moat.height_at(Vector2i(26, 2)) == 99
			and not _covers(moat.collision_rects(8), Vector2i(26, 2)) and not _covers(moat.collision_rects(9), Vector2i(26, 2)),
			"masonry is one rectangle on layer 1 and nothing else")
	_check(moat.collision_rects(7).size() == 8 and _area(moat.collision_rects(7)) == 104 * 256,
			"the lava merges into few rectangles that cover every lava cell (%d rects)" % moat.collision_rects(7).size())
	_check(moat.stairs().is_empty() and moat.level_regions()[0].size() > 200 and moat.level_regions()[1].is_empty(),
			"a flat room has no stairs and all its walkable cells at level 0")

	# --- the terraces: heights, faces, stairs, layers ------------------------------------------
	var terraces := TemplePlan.parse("\n".join(TERRACES))
	_check(terraces.errors.is_empty() and terraces.height_at(Vector2i(22, 2)) == 2 and terraces.height_at(Vector2i(19, 3)) == 1
			and terraces.height_at(Vector2i(20, 2)) == 1 and terraces.height_at(Vector2i(19, 6)) == 0,
			"floors read their height and a stair's height is its low end")
	var face := Vector2i(22, 6)
	_check(terraces.face_rows(face) == 2 and not terraces.is_walkable(face, 0) and not terraces.is_walkable(face, 2)
			and _covers(terraces.collision_rects(8), face) and _covers(terraces.collision_rects(9), face)
			and _covers(terraces.collision_rects(10), face) and not _covers(terraces.collision_rects(11), face),
			"a face cell south of a 2-high platform has 2 rows and is not walkable")
	_check(terraces.face_rows(Vector2i(18, 6)) == 1 and terraces.face_rows(Vector2i(28, 6)) == 0
			and terraces.face_rows(Vector2i(19, 6)) == 0 and terraces.face_rows(Vector2i(2, 4)) == 0,
			"faces are one row per level of drop, none under a stair or south of lava")
	var zones := terraces.stairs()
	var up := _zone_at(zones, Vector2i(19, 6))
	var right := _zone_at(zones, Vector2i(20, 2))
	var down := _zone_at(zones, Vector2i(6, 11))
	_check(zones.size() == 3 and up.get("cells") == Rect2i(19, 6, 2, 1) and up.get("direction") == Vector2i.UP
			and up.get("low_level") == 0 and right.get("cells") == Rect2i(20, 2, 1, 2) and right.get("direction") == Vector2i.RIGHT
			and right.get("low_level") == 1 and down.get("cells") == Rect2i(6, 11, 2, 1) and down.get("direction") == Vector2i.DOWN,
			"stairs merge into one zone with low_level and direction")
	_check(terraces.is_walkable(Vector2i(19, 6), 0) and terraces.is_walkable(Vector2i(19, 6), 1) and not terraces.is_walkable(Vector2i(19, 6), 2)
			and terraces.is_walkable(Vector2i(20, 2), 1) and terraces.is_walkable(Vector2i(20, 2), 2) and not terraces.is_walkable(Vector2i(20, 2), 0),
			"a stair is walkable at its low and its high level")
	var layer9 := terraces.collision_rects(9)
	_check(not _covers(layer9, Vector2i(19, 3)) and not _covers(layer9, Vector2i(19, 6)) and not _covers(layer9, Vector2i(20, 2))
			and _covers(layer9, Vector2i(10, 8)) and _covers(layer9, Vector2i(22, 2)) and _covers(layer9, Vector2i(3, 2)),
			"collision on layer 9 excludes level-1 floor and stairs touching level 1")
	var layer8 := terraces.collision_rects(8)
	_check(_covers(layer8, Vector2i(19, 3)) and _covers(layer8, Vector2i(22, 2)) and _covers(layer8, Vector2i(20, 2))
			and not _covers(layer8, Vector2i(19, 6)) and not _covers(layer8, Vector2i(10, 8)) and not _covers(layer8, Vector2i(3, 2)),
			"layer 8 holds every raised cell and stair above level 0, not the floor nor the lava")
	var layer10 := terraces.collision_rects(10)
	_check(_covers(layer10, Vector2i(19, 3)) and not _covers(layer10, Vector2i(22, 2)) and not _covers(layer10, Vector2i(20, 2))
			and _covers(layer10, Vector2i(10, 8)), "layer 10 holds what level 2 may not enter")
	var layer11 := terraces.collision_rects(11)
	var mismatches := 0
	for y in range(1, 17):
		for x in range(1, 29):
			if _covers(layer11, Vector2i(x, y)) != (terraces.height_at(Vector2i(x, y)) == 2):
				mismatches += 1
	_check(mismatches == 0 and _area(layer11) == 30 * 256, "layer 11 holds exactly the height-2 cells")
	_check(_covers(layer8, Vector2i(15, 3)) and _covers(layer8, Vector2i(17, 3)) and not _covers(layer8, Vector2i(16, 3))
			and not _covers(layer9, Vector2i(16, 3)) and terraces.is_walkable(Vector2i(16, 3), 1) and not terraces.is_walkable(Vector2i(16, 3), 0),
			"a raised deck blocks level 0 only at its ends and is walkable at its own height")
	var regions := terraces.level_regions()
	# Level 2: the 30 cells of the block plus the two cells of the stair that climbs onto it.
	_check(regions[2].size() == 32 and regions[1].has(Vector2i(19, 6)) and regions[0].has(Vector2i(19, 6))
			and regions[1].has(Vector2i(13, 3)) and not regions[0].has(face) and not regions[0].has(Vector2i(0, 8)),
			"level_regions lists the walkable inner cells of each level, stairs on both")

	# --- validation ---------------------------------------------------------------------------------
	var surge := TemplePlan.parse("\n".join(SURGE))
	_check(moat.validate().is_empty() and terraces.validate().is_empty() and surge.validate().is_empty(),
			"the valid plans validate clean (%s %s %s)" % [moat.validate(), terraces.validate(), surge.validate()])
	var broken_rows := TERRACES.duplicate()
	for y in range(7, 11):
		broken_rows[y] = "..........................~~~."
	var broken := TemplePlan.parse("\n".join(broken_rows))
	var broken_problems := broken.validate()
	_check(broken_problems.any(func(p: String) -> bool: return p.contains("east door")),
			"the broken plan reports the unreachable door (%s)" % [broken_problems])
	var box_rows := MOAT.duplicate()
	for y in range(1, 17):
		box_rows[y] = ".".repeat(30) if y >= 7 and y <= 10 else MOAT[1]
	var box_problems := TemplePlan.parse("\n".join(box_rows)).validate()
	_check(box_problems.size() == 1 and box_problems[0].contains("rectangle"), "a rectangle-only plan is rejected (%s)" % [box_problems])
	var stair_rows := TERRACES.duplicate()
	stair_rows[7] = "...................##........."
	var stair_problems := TemplePlan.parse("\n".join(stair_rows)).validate()
	_check(stair_problems.any(func(p: String) -> bool: return p.contains("stair") and p.contains("low end")),
			"a stair with no free cell at its low end is reported (%s)" % [stair_problems])
	_check(surge.validate(1).is_empty() and surge.validate(2).is_empty(), "the surge plan is fair for one and two stages")
	var far_rows := SURGE.duplicate()
	far_rows[8] = "....1111222222222222221111<..."
	far_rows[9] = far_rows[8]
	var far_problems := TemplePlan.parse("\n".join(far_rows)).validate(2)
	# Without the west stair, (1, 9) walks 7 cells north and 4 east to the nearest one.
	_check(far_problems.size() == 1 and far_problems[0].contains("stair up") and far_problems[0].contains("(1, 9) is 11 steps"),
			"the surge plan fails when a level-0 cell is too far from stairs (%s)" % [far_problems])
	_check(TemplePlan.parse("\n".join(far_rows)).validate(0).is_empty(), "without a surge the same plan is fine")
	var small := terraces.validate(2)
	_check(small.any(func(p: String) -> bool: return p.contains("safe level 2")),
			"a surge needs 60 connected cells on the safe level (%s)" % [small])
	_check(Tuning.TEMPLE_SURGE_MAX_STAIR_DISTANCE == 9, "the stair distance of a surge room is a Tuning value")

	# --- spawns ---------------------------------------------------------------------------------------
	_check(moat.spawn_ok(Vector2i(14, 8)) and terraces.spawn_ok(Vector2i(10, 8)) and terraces.spawn_ok(Vector2i(23, 2))
			and not moat.spawn_ok(lava) and not terraces.spawn_ok(face) and not terraces.spawn_ok(Vector2i(19, 6))
			and not moat.spawn_ok(Vector2i(6, 6)) and not moat.spawn_ok(Vector2i(6, 5)) and not moat.spawn_ok(Vector2i(8, 6))
			and not moat.spawn_ok(Vector2i(26, 2)),
			"spawn_ok rejects lava, faces, stairs and lava neighbours")

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _covers(rects: Array[Rect2], cell: Vector2i) -> bool:
	var center := Vector2(cell) * 16.0 + Vector2(8.0, 8.0)
	return rects.any(func(r: Rect2) -> bool: return r.has_point(center))


func _area(rects: Array[Rect2]) -> float:
	var total := 0.0
	for r in rects:
		total += r.get_area()
	return total


func _zone_at(zones: Array[Dictionary], cell: Vector2i) -> Dictionary:
	for zone in zones:
		if zone.get("cells", Rect2i()).has_point(cell):
			return zone
	return {}


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
