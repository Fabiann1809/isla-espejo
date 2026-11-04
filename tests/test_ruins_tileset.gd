extends SceneTree
## The tileset profile of the Ruinas de la Montaña (data/tilesets/ruins.tres, made by
## tools/make_tileset_ruins.gd from the sheet of tools/make_ruins_tileset_art.py): it plays every role
## the game asks for, every named tile of the sheet exists and is drawn, and the animated sets have
## all their frames.
## Run: godot --headless --path . --script res://tests/test_ruins_tileset.gd

var _ok := true


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var profile: TilesetProfile = load("res://data/tilesets/ruins.tres")
	_check(profile != null and profile.tile_size == 16 and profile.separation == 0, "the ruins profile is 16x16 tiles with no spacing")
	_check(profile.problems(TileArt.ROLES, TileArt.PATTERNS).is_empty(), "it has a tile for every role and pattern of the game")

	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tilesets/ruins/ruins_tiles.json"))
	var image: Image = profile.texture.get_image()
	var empty: Array[String] = []
	var outside: Array[String] = []
	for tile_name: String in parsed["tiles"]:
		var cell := Vector2i(int(parsed["tiles"][tile_name][0]), int(parsed["tiles"][tile_name][1]))
		if not profile.tiles.has(StringName(tile_name)) and not _is_role(tile_name):
			outside.append(tile_name)
			continue
		var rect := profile.region(cell)
		var drawn := false
		for y in range(int(rect.position.y), int(rect.end.y)):
			for x in range(int(rect.position.x), int(rect.end.x)):
				if image.get_pixel(x, y).a > 0.0:
					drawn = true
		if not drawn:
			empty.append(tile_name)
	_check(parsed["tiles"].size() >= 140, "the sheet names %d tiles" % parsed["tiles"].size())
	_check(outside.is_empty() and empty.is_empty(), "every named tile is in the profile and has pixels (missing %s, empty %s)" % [outside, empty])

	for animated in [["torch_a", "torch_b", "torch_c"], ["brazier_a", "brazier_b", "brazier_c"],
			["waterfall_mid_a", "waterfall_mid_b", "waterfall_mid_c"], ["waterfall_base_a", "waterfall_base_b", "waterfall_base_c"],
			["pond_4", "pond_center_b", "pond_center_c"], ["crystal_top", "crystal_top_b"],
			["crystal_small_a", "crystal_small_a2", "crystal_small_b", "crystal_small_b2"]]:
		var all_there := true
		for frame_name: String in animated:
			all_there = all_there and profile.tiles.has(StringName(frame_name))
		_check(all_there, "the animation %s has all its frames" % [animated])
	_check(profile.pattern(TileArt.POND).size() == 9 and profile.pattern(TileArt.DIRT_PATCH_INNER).size() == 4,
			"water and paths come as nine-slice patterns with inner corners")

	# The game asks for roles: with this profile active a 'pine' is a rock column and 'grass' the floor.
	TileArt.use_profile(profile)
	_check(TileArt.coords(TileArt.GRASS) == profile.tiles[&"floor_a"] and TileArt.coords(TileArt.PINE_TALL_TOP) == profile.tiles[&"column_rock_a_top"],
			"asking for 'grass' or a tall 'pine' gives the ruins' floor and column")
	TileArt.use_profile(null)
	_check(TileArt.profile().resource_path == TileArt.DEFAULT_PROFILE, "the default profile comes back with null")

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


func _is_role(tile_name: String) -> bool:
	return TileArt.ROLES.has(StringName(tile_name))


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
