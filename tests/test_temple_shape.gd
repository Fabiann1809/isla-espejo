extends SceneTree
## TempleShape: a temple room's plan becomes a stone island over animated lava with three heights.
## The layers come in the draw order of the design, the lava is animated tiles, the lava and the
## cliff edges stop walkers of the wrong level, the stairs raise Nico level by level, an enemy born on
## a level-2 cell is level 2, arrows only stop at what is higher than them, and a lava-walled room
## plants no wall art on its border.
## Run: godot --headless --path . --script res://tests/test_temple_shape.gd

const PLAN := """
#############....#############
#~~~~~~~~~~~~....~~~~~~~~~~~~#
#~~~~~~~~~~~~....~~~~.......~#
#~~.......~~~....~~~~.11111.~#
#~~.11111.~~~....~~~~.12221.~#
#~~.12221.~~~.....==..12221.~#
#~~.12221.~~~.....~~..1^^11.~#
....1^^11.............1111....
....11111.............1^^1....
.....^^..p................p...
...p.......................p..
#~~~~~~~~~~~~.........~~~~...#
#~~~.....====........~~~~~...#
#~~~~....~~~~....~~~~~~~~~~..#
#~~~~....~~~~....~~~~~~~~~~~.#
#~~~~~~~~~~~~....~~~~~~~~~~~~#
#~~~~~~~~~~~~....~~~~~~~~~~~~#
#############....#############
"""
## A level-2 block straight north of level-0 floor: a 2 -> 0 drop onto ground Nico walks on.
const DROP_PLAN := """
#############....#############
#............................#
#............................#
#............................#
#.........22222..............#
#.........22222..............#
#............................#
..............................
..............................
..............................
..............................
#............................#
#............................#
#............................#
#............................#
#............................#
#............................#
#############....#############
"""
const LAYERS := ["Lava", "Faces", "Floor0", "Floor1", "Floor2", "Rims", "Ledges", "Shadows", "Stairs", "Bridges"]

var _ok := true


func _initialize() -> void:
	create_timer(150.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var theme: Resource = load("res://data/themes/temple.tres")
	TileArt.use_profile(theme.tileset)

	# A temple room built in code: room_base plus a Shape with a 3-level plan, as the room scenes do.
	var room: Node2D = load("res://scenes/levels/rooms/room_base.tscn").instantiate()
	room.theme = theme
	room.debug_label = false
	var data: Resource = load("res://scripts/world/room_data.gd").new()
	data.id = "temple_test"
	var doors: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	room.setup(data, doors)
	var shape_script: GDScript = load("res://scripts/world/temple_shape.gd")
	_check(shape_script != null, "scripts/world/temple_shape.gd exists")
	if shape_script == null:
		print("RESULT: FAILED")
		quit(1)
		return
	var shape: Node2D = shape_script.new()
	shape.name = "Shape"
	shape.rows = PLAN
	room.add_child(shape)
	root.add_child(room)
	var player: Node2D = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(240, 160)
	room.add_child(player)
	await _frames(3)

	_check(shape.plan != null and shape.plan.errors.is_empty(), "the plan reads (%s)" % [shape.plan.errors if shape.plan != null else "no plan"])
	var problems: Array = shape.plan.validate()
	_check(problems.is_empty(), "the test plan is a valid design (%s)" % [problems])

	# Layers exist, in draw order, all with the floor's z.
	var last_index := -1
	var in_order := true
	for layer_name in LAYERS:
		var layer := shape.get_node_or_null(layer_name) as TileMapLayer
		if layer == null or layer.z_index != RoomTheme.FLOOR_Z or layer.get_index() <= last_index:
			in_order = false
			print("  layer %s: %s" % [layer_name, "missing" if layer == null else "index %d z %d" % [layer.get_index(), layer.z_index]])
		else:
			last_index = layer.get_index()
	_check(in_order, "layers exist in draw order")

	# Lava cells are animated tiles (8 frames of flow), with bubbles over a few of them.
	var lava: TileMapLayer = shape.get_node("Lava")
	var animated := 0
	var lava_cells := 0
	for y in 18:
		for x in 30:
			var cell := Vector2i(x, y)
			if not shape.plan.is_lava(cell):
				continue
			lava_cells += 1
			if _frames_of(lava, cell) == 8:
				animated += 1
	_check(lava_cells > 100 and animated == lava_cells, "lava cells are animated tiles (%d of %d)" % [animated, lava_cells])
	var bubbles := shape.get_node("Bubbles") as TileMapLayer
	var bubble_count := bubbles.get_used_cells().size() if bubbles != null else 0
	var bubble_animated := bubbles != null and bubble_count > 0 and _frames_of(bubbles, bubbles.get_used_cells()[0]) == 6
	_check(bubble_count > 0 and bubble_count < lava_cells * 0.15 and bubble_animated,
			"bubbles are scattered over a few lava cells and animated (%d)" % bubble_count)
	var faces: TileMapLayer = shape.get_node("Faces")
	var rims: TileMapLayer = shape.get_node("Rims")
	var ledges: TileMapLayer = shape.get_node("Ledges")
	var shadows: TileMapLayer = shape.get_node("Shadows")
	_check(faces.get_used_cells().has(Vector2i(4, 9)) and faces.get_used_cells().has(Vector2i(4, 11))
			and faces.get_used_cells().has(Vector2i(28, 15)) and not faces.get_used_cells().has(Vector2i(5, 9)),
			"faces stand south of a drop, into lava too (a stair casts none) (%d cells)" % faces.get_used_cells().size())
	_check(_frames_of(faces, Vector2i(4, 11)) == 4, "a face's foot in lava is lit by animated lava")
	_check(rims.get_used_cells().has(Vector2i(2, 3)) and not rims.get_used_cells().has(Vector2i(1, 1))
			and shape.get_node("RimGlow").get_used_cells().has(Vector2i(2, 3)),
			"rims lie on the lava around the island and glow (%d cells)" % rims.get_used_cells().size())
	_check(ledges.get_used_cells().has(Vector2i(4, 4)) and ledges.get_used_cells().has(Vector2i(3, 3))
			and not ledges.get_used_cells().has(Vector2i(14, 8)),
			"ledges lip the high side of every change (%d cells)" % ledges.get_used_cells().size())
	_check(shadows.get_used_cells().has(Vector2i(4, 10)) and not shadows.get_used_cells().has(Vector2i(4, 9)),
			"shadows fall on the lower floor south of a face (%d cells)" % shadows.get_used_cells().size())
	_check(shape.get_node("Stairs").get_used_cells().size() == 8 and shape.get_node("Bridges").get_used_cells().size() == 6,
			"stairs and bridges are deck tiles")
	var rails := shape.get_node("Rails")
	_check(rails != null and rails.y_sort_enabled and rails.z_index == 0 and rails.get_child_count() >= 8,
			"rails and posts stand upright, y-sorted at z 0 (%d)" % (rails.get_child_count() if rails != null else -1))

	# Props: pillars on the `p` cells, lights along the rims, ember vents on the lava.
	var pillars := 0
	var vents := 0
	var pillar_levels_ok := true
	for child in shape.get_children():
		if child.get_script() == load("res://scripts/world/temple_prop.gd"):
			if child.kind == child.Kind.EMBER_VENT:
				vents += 1
			elif child.kind == child.Kind.PILLAR_CARVED or child.kind == child.Kind.PILLAR_BLOCK:
				pillars += 1
				pillar_levels_ok = pillar_levels_ok and child.level == 0 and child.has_node("Body")
	_check(pillars == 4 and pillar_levels_ok, "the p cells hold pillars of their level with a body (%d)" % pillars)
	_check(vents >= 2 and vents < lava_cells / 10, "ember vents sit on a few lava cells (%d)" % vents)
	var embers := shape.get_node_or_null("Embers")
	_check(embers != null and embers.z_index == 0 and embers.y_sort_enabled and embers.get_child_count() == vents,
			"every vent has embers rising, y-sorted at z 0")
	var lights := shape.get_node_or_null("Lights")
	_check(lights != null and lights.get_child_count() >= 5 and lights.get_child_count() < 40,
			"lava lights glow along the rims (%d)" % (lights.get_child_count() if lights != null else -1))

	# Collision: lava stops a low Nico; a level-1 Nico cannot walk off his platform's edge.
	await _walk(player, Vector2(264, 56), 0, "move_right", 40)
	_check(player.global_position.x < 272.0, "a low Nico cannot walk into lava (x = %.0f)" % player.global_position.x)
	await _walk(player, Vector2(104, 72), 1, "move_up", 40)
	_check(player.global_position.y > 56.0, "a level-1 Nico on the platform cannot walk off its edge (y = %.0f)" % player.global_position.y)
	await _walk(player, Vector2(104, 72), 1, "move_down", 40)
	_check(player.global_position.y < 84.0, "nor up onto the level-2 block (y = %.0f)" % player.global_position.y)
	await _walk(player, Vector2(72, 168), 0, "move_up", 40)
	_check(player.global_position.y > 150.0, "a low Nico is stopped by the platform's face (y = %.0f)" % player.global_position.y)
	await _walk(player, Vector2(120, 200), 0, "move_right", 60)
	_check(player.global_position.x > 220.0, "and crosses the lava by the bridge (x = %.0f)" % player.global_position.x)

	# Stairs: up the first flight Nico is level 1, up the second he is level 2.
	await _walk(player, Vector2(96, 168), 0, "move_up", 18)
	_check(Heights.level_of(player) == 1, "walking up the stairs makes Nico level 1 (y = %.0f)" % player.global_position.y)
	await _walk(player, player.global_position, Heights.level_of(player), "move_up", 24)
	_check(Heights.level_of(player) == 2 and player.global_position.y < 112.0,
			"then level 2 (y = %.0f)" % player.global_position.y)
	await _walk(player, player.global_position, Heights.level_of(player), "move_down", 50)
	_check(Heights.level_of(player) == 0 and player.global_position.y > 160.0,
			"and down again to level 0 (y = %.0f)" % player.global_position.y)
	Heights.set_level(player, 0)
	player.global_position = Vector2(240, 160)

	# An enemy placed on a level-2 cell is level 2; one on the ground stays level 0.
	_check(room.height_at(Vector2(104, 88)) == 2 and room.height_at(Vector2(104, 72)) == 1
			and room.height_at(Vector2(240, 160)) == 0 and room.height_at(Vector2(40, 40)) == 0,
			"Room.height_at answers the plan's height, never below 0")
	var high: Node2D = load("res://scenes/enemies/grunt.tscn").instantiate()
	high.position = Vector2(104, 88)
	room.add_child(high)
	var low: Node2D = load("res://scenes/enemies/grunt.tscn").instantiate()
	low.position = Vector2(240, 160)
	room.add_child(low)
	await _frames(2)
	_check(Heights.level_of(high) == 2 and high.get_collision_mask_value(10) and not high.get_collision_mask_value(8),
			"an enemy placed on a level-2 cell is level 2")
	_check(Heights.level_of(low) == 0, "one placed on the ground is level 0")
	high.queue_free()
	low.queue_free()

	# Arrows: a low one stops at the platform's cliff; a level-1 one flies over lava.
	var low_arrow := _arrow(room, Vector2(40, 88), 0)
	var high_arrow := _arrow(room, Vector2(216, 72), 1)
	await _frames(20)
	_check(not is_instance_valid(low_arrow) or low_arrow.is_queued_for_deletion(), "a low arrow stops at the platform face")
	_check(is_instance_valid(high_arrow) and not high_arrow.is_queued_for_deletion() and high_arrow.global_position.x > 290.0,
			"a level-1 arrow flies over lava (x = %.0f)" % (high_arrow.global_position.x if is_instance_valid(high_arrow) else -1.0))

	# The island floats in lava: every wall cell is hidden and no wall art is planted on the border.
	_check(shape.hides_wall_at(Vector2i(5, 0)) and shape.hides_wall_at(Vector2i(29, 3))
			and not shape.hides_wall_at(Vector2i(14, 0)) and not shape.hides_wall_at(Vector2i(5, 5)),
			"hides_wall_at is true for the wall cells of the border and false for the doors")
	var border: TileMapLayer = room.get_node("Border")
	_check(border.get_used_cells().is_empty() and room.get_node_or_null("WallRocks") == null
			and room.get_node_or_null("WallTrees") == null, "no wall art is planted on hidden borders")
	_check(room.get_node("Walls").get_child_count() == 8, "the room keeps its wall collision with four door gaps")

	# A 2 -> 0 drop onto floor paints faces only where the plan reserves them (or over lava).
	var drop_room: Node2D = load("res://scenes/levels/rooms/room_base.tscn").instantiate()
	drop_room.theme = theme
	drop_room.debug_label = false
	drop_room.setup(data, doors)
	var drop_shape: Node2D = shape_script.new()
	drop_shape.name = "Shape"
	drop_shape.rows = DROP_PLAN
	drop_room.add_child(drop_shape)
	root.add_child(drop_room)
	await _frames(3)
	_check(drop_shape.plan.errors.is_empty(), "the drop plan reads (%s)" % [drop_shape.plan.errors])
	var drop_faces: TileMapLayer = drop_shape.get_node("Faces")
	var painted := drop_faces.get_used_cells()
	var stray := 0
	for face_cell in painted:
		# The border walls hide as lava: the floor's foot there is lava too.
		var kind: String = drop_shape.plan.cell_at(face_cell)
		if drop_shape.plan.face_rows(face_cell) <= 0 and kind != TemplePlan.LAVA and kind != "#":
			stray += 1
	_check(not painted.is_empty() and stray == 0,
			"a 2->0 drop onto floor paints faces only on the plan's face cells (%d painted, %d stray)" % [painted.size(), stray])

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _frames_of(layer: TileMapLayer, cell: Vector2i) -> int:
	var source_id := layer.get_cell_source_id(cell)
	if source_id < 0:
		return 0
	var source := layer.tile_set.get_source(source_id) as TileSetAtlasSource
	return source.get_tile_animation_frames_count(layer.get_cell_atlas_coords(cell))


func _arrow(room: Node, at: Vector2, level: int) -> Node2D:
	var arrow = load("res://scenes/player/arrow.tscn").instantiate()
	arrow.setup(Vector2.RIGHT, 300.0, 400.0, 1)
	arrow.height_level = level
	room.add_child(arrow)
	arrow.global_position = at
	return arrow


func _walk(player: Node2D, from: Vector2, level: int, action: String, frames: int) -> void:
	player.global_position = from
	Heights.set_level(player, level)
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)
	await _frames(1)


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
