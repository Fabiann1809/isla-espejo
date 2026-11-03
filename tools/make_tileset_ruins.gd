extends SceneTree
## Writes the tileset profile of the Ruinas de la Montaña (data/tilesets/ruins.tres) from the sheet
## drawn by tools/make_ruins_tileset_art.py (assets/tilesets/ruins/: 16x16 tiles, no spacing, and
## ruins_tiles.json with the coordinates of each named tile).
## Every tile of the sheet is kept under its own name (columns, stairs, crystals... for the ruins'
## props) and every ROLE the game asks for is mapped to its closest ruins tile, so the rooms, the
## corridors and the existing props can be dressed with it (a "tree" is a rock column, "grass" is the
## stone floor, a "pond" is the river...).
## Run: godot --headless --path . --script res://tools/make_tileset_ruins.gd

const SHEET := "res://assets/tilesets/ruins/ruins_sheet.png"
const TILES_JSON := "res://assets/tilesets/ruins/ruins_tiles.json"
const OUT := "res://data/tilesets/ruins.tres"

## Role -> name of the ruins tile that plays it.
const ROLE_TILES := {
	# Ground
	&"grass": &"floor_a",
	&"dirt": &"floor_worn",
	&"grass_textured": &"floor_b",
	&"planks": &"bridge_planks_h",
	&"flowers_red": &"glow_flower_1",
	&"flowers_white": &"glow_flower_2",
	&"flowers_blue": &"glow_flower_0",
	&"tuft_a": &"moss_clump_a",
	&"tuft_b": &"moss_clump_b",
	&"pebbles": &"pebbles",
	&"rock_small": &"boulder_small",
	&"rock_mossy": &"boulder_small_moss",
	&"stump": &"pillar_broken",
	&"mushroom_brown": &"mushroom_2",
	&"mushroom_orange": &"mushroom_3",
	&"mushroom_red": &"mushroom_1",
	&"mushroom_pale": &"mushroom_0",
	&"flower_purple": &"glow_flower_1",
	&"flower_yellow": &"glow_flower_0",
	# Props: rock columns and stalagmites stand where the forest has trees
	&"pine": &"stalagmite_a",
	&"pine_tall_top": &"column_rock_a_top",
	&"pine_tall_base": &"column_rock_a_base",
	&"round_tree": &"boulder_a",
	&"round_tree_tall_top": &"column_rock_b_top",
	&"round_tree_tall_base": &"column_rock_b_base",
	&"bush": &"fern_a",
	&"tree_dark": &"stalagmite_b",
	&"tree_dark_tall_top": &"column_dark_a_top",
	&"tree_dark_tall_base": &"column_dark_a_base",
	&"pine_dark": &"stalagmite_b",
	&"pine_dark_tall_top": &"column_dark_b_top",
	&"pine_dark_tall_base": &"column_dark_b_base",
	&"bush_dark": &"fern_blue",
	&"bush_berries": &"fern_b",
	&"rock": &"boulder_b",
	&"bush_orange": &"fern_b",
	&"campfire": &"brazier_a",
	&"logs": &"crate",
	&"chest_closed": &"chest_closed",
	&"chest_open": &"chest_open",
	&"torch_a": &"torch_a",
	&"torch_b": &"torch_b",
	&"sign": &"stele_small",
}

## Pattern role -> name of the pattern in the sheet.
const ROLE_PATTERNS := {
	&"pond": &"pond",
	&"grass_patch": &"moss_patch",
	&"grass_patch_inner": &"moss_patch_inner",
	&"dirt_patch": &"path_patch",
	&"dirt_patch_inner": &"path_patch_inner",
	&"stone_floor": &"stone_floor",
}


func _initialize() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TILES_JSON))
	if not parsed is Dictionary:
		printerr("Cannot read %s (run tools/make_ruins_tileset_art.py first)." % TILES_JSON)
		quit(1)
		return
	var sheet_tiles: Dictionary = parsed["tiles"]
	var sheet_patterns: Dictionary = parsed["patterns"]

	var profile := TilesetProfile.new()
	profile.texture = load(SHEET)
	profile.tile_size = int(parsed["tile_size"])
	profile.separation = 0
	profile.margin = 0
	for tile_name: String in sheet_tiles:
		profile.tiles[StringName(tile_name)] = _cell(sheet_tiles[tile_name])
	var missing: Array[String] = []
	for role: StringName in ROLE_TILES:
		var tile_name := String(ROLE_TILES[role])
		if not sheet_tiles.has(tile_name):
			missing.append("%s -> %s" % [role, tile_name])
		else:
			profile.tiles[role] = _cell(sheet_tiles[tile_name])
	for role: StringName in ROLE_PATTERNS:
		var pattern_name := String(ROLE_PATTERNS[role])
		if not sheet_patterns.has(pattern_name):
			missing.append("%s -> %s" % [role, pattern_name])
			continue
		var cells: Array[Vector2i] = []
		for cell in sheet_patterns[pattern_name]:
			cells.append(_cell(cell))
		profile.patterns[role] = cells
		profile.patterns[StringName(pattern_name)] = cells
	if not missing.is_empty():
		printerr("The ruins sheet lacks: %s" % [missing])
		quit(1)
		return
	var problems := profile.problems(TileArt.ROLES, TileArt.PATTERNS)
	if not problems.is_empty():
		printerr("The profile is incomplete: %s" % [problems])
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://data/tilesets")
	ResourceSaver.save(profile, OUT)
	print("tileset profile written to %s (%d tiles)" % [OUT, profile.tiles.size()])
	quit()


func _cell(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))
