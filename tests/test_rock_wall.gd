extends SceneTree
## A theme with `wall_style = ROCKS` (the Ruinas) builds its walls from rock columns and puts solid
## rock around the map instead of the forest; the forest theme keeps its trees.
## Run: godot --headless --path . --script res://tests/test_rock_wall.gd
## `Level`/`Room` must not be referenced as types here (autoload compile order).

var _ok := true


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	root.get_node("PlayerProfile").persistence_enabled = false

	var theme: RoomTheme = load("res://data/themes/ruins.tres")
	_check(theme.wall_style == RoomTheme.WallStyle.ROCKS and theme.tileset != null, "the ruins theme has rock walls and its tileset")

	TileArt.use_profile(theme.tileset)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var picture := RockWall.image(&"column_rock_a")
	var tall := RockWall.image(&"column_tall_a")
	_check(picture.get_size() == Vector2i(16, 32) and tall.get_size() == Vector2i(16, 48), "a column is 2 tiles tall and a tall one is 3")
	_check(not picture.is_invisible() and not tall.is_invisible(), "the column pictures are drawn")
	var feet := RockWall.feet_along(Vector2(0, 15), Vector2(480, 15), rng)
	_check(feet.size() >= 40 and feet[1].x - feet[0].x < 16.0, "the columns along a wall are packed (%d for 480 px)" % feet.size())
	var node := RockWall.column(Vector2(100, 100), rng)
	_check(node.is_in_group(RoomProp.CANOPY_GROUP) and node.get_child_count() == 1, "a column is one sprite that fades like a tree")
	node.free()
	TileArt.use_profile(null)

	var level := await _build(theme)
	var room = level.rooms[level.layout.start_cell]
	_check(room.get_node_or_null("WallRocks") != null and room.get_node_or_null("WallTrees") == null,
			"a ruins room has rock walls and no tree walls")
	_check(room.get_node("WallRocks").get_child_count() > 20, "its side and bottom walls are columns (%d)" % room.get_node("WallRocks").get_child_count())
	var rock_layer := level.get_node_or_null("Map/Backdrop/Rock") as TileMapLayer
	_check(rock_layer != null and rock_layer.get_used_cells().size() > 500, "solid rock fills the space around the map")
	_check(level.get_node_or_null("Map/Backdrop/Ground0") == null and level.get_node_or_null("ForestBoundary") == null,
			"and no forest backdrop or boundary")
	var corridor_columns := 0
	for corridor in level.get_node("Map/Corridors").get_children():
		if corridor.is_in_group(RoomProp.CANOPY_GROUP):
			corridor_columns += 1
	_check(corridor_columns > 0, "the corridors' walls are columns too (%d)" % corridor_columns)
	level.free()

	var forest := await _build(load("res://data/themes/forest.tres"))
	var forest_room = forest.rooms[forest.layout.start_cell]
	_check(forest_room.get_node_or_null("WallTrees") != null and forest_room.get_node_or_null("WallRocks") == null,
			"the forest theme keeps its trees")
	forest.free()

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _build(theme: RoomTheme) -> Node2D:
	var level: Node2D = load("res://scenes/levels/forest_level.tscn").instantiate()
	var scenario: ScenarioData = load("res://data/scenarios/forest.tres").duplicate()
	scenario.theme = theme
	level.scenario = scenario
	level.seed_value = 4242
	level.use_director = false
	root.add_child(level)
	for i in 6:
		await physics_frame
	return level


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
