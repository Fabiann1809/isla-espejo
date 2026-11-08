extends SceneTree
## Writes the tileset profile of the Templo del Eclipse (data/tilesets/temple.tres) from the sheet
## drawn by tools/make_temple_tileset_art.py (assets/tilesets/temple/: 16x16 tiles, no spacing, and
## temple_tiles.json with the coordinates of each named tile, pattern and animation).
## Every tile of the sheet is kept under its own name (floors, lava, rims, cliff faces, stairs,
## bridges... for the temple's own shapes and props), every animation under its name (an animated
## tile's name also points at its first frame), and every ROLE the game asks for is mapped to its
## closest temple tile, so rooms, corridors and the existing props can be dressed with it (a tall
## "pine" is a carved column, "grass" is the flagstone floor, a "pond" is a lava pool...).
##
## The blob patterns `lava_rim` and `ledge` hold 47 tiles, one per distinct 8-neighbour mask
## (N=1 NE=2 E=4 SE=8 S=16 SW=32 W=64 NW=128, a corner only counting when both edges beside it are
## inside; "inside" is lava for the rim and the high plateau for the ledge). Their order is the
## json's `blob_masks`: the nine-slice in reading order, the four inner corners (SE, SW, NE, NW;
## also kept as `lava_rim_inner` / `ledge_inner`, so `TileArt.blob_tile` works with them as it
## does with the pond), then the other 34 masks ascending.
## Run: godot --headless --path . --script res://tools/make_tileset_temple.gd

const SHEET := "res://assets/tilesets/temple/temple_sheet.png"
const TILES_JSON := "res://assets/tilesets/temple/temple_tiles.json"
const OUT := "res://data/tilesets/temple.tres"

## Role -> name of the temple tile that plays it.
const ROLE_TILES := {
	# Ground
	&"grass": &"floor_a",
	&"dirt": &"floor_c",
	&"grass_textured": &"floor_b",
	&"planks": &"bridge_wood_deck_h",
	&"flowers_red": &"floor_crack_a",
	&"flowers_white": &"floor_moss_a",
	&"flowers_blue": &"floor_rune_d",
	&"tuft_a": &"rubble_a",
	&"tuft_b": &"pebbles",
	&"pebbles": &"pebbles",
	&"rock_small": &"boulder_small",
	&"rock_mossy": &"rubble_b",
	&"stump": &"rocks_heap",
	&"mushroom_brown": &"rubble_a",
	&"mushroom_orange": &"ember_a",
	&"mushroom_red": &"ember_b",
	&"mushroom_pale": &"ash_a",
	&"flower_purple": &"floor_crack_b",
	&"flower_yellow": &"floor_rune_c",
	# Props: lava rocks and carved columns stand where the forest has trees
	&"pine": &"boulder_a",
	&"pine_tall_top": &"column_top",
	&"pine_tall_base": &"column_base",
	&"round_tree": &"boulder_b",
	&"round_tree_tall_top": &"column_moss_top",
	&"round_tree_tall_base": &"column_moss_base",
	&"bush": &"rocks_heap",
	&"tree_dark": &"boulder_b",
	&"tree_dark_tall_top": &"column_moss_top",
	&"tree_dark_tall_base": &"column_moss_base",
	&"pine_dark": &"boulder_a",
	&"pine_dark_tall_top": &"column_top",
	&"pine_dark_tall_base": &"column_base",
	&"bush_dark": &"rocks_heap",
	&"bush_berries": &"rocks_heap",
	&"rock": &"boulder_b",
	&"bush_orange": &"rocks_heap",
	&"campfire": &"brazier_f0",
	&"logs": &"crate",
	&"chest_closed": &"chest_closed",
	&"chest_open": &"chest_open",
	&"torch_a": &"torch_f0",
	&"torch_b": &"torch_f1",
	&"sign": &"stele",
}

## Pattern role -> name of the pattern in the sheet.
const ROLE_PATTERNS := {
	&"pond": &"pond",
	&"pond_inner": &"pond_inner",
	&"grass_patch": &"moss_patch",
	&"grass_patch_inner": &"moss_patch_inner",
	&"dirt_patch": &"ash_patch",
	&"dirt_patch_inner": &"ash_patch_inner",
	&"stone_floor": &"slab_floor",
}


func _initialize() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TILES_JSON))
	if not parsed is Dictionary:
		printerr("Cannot read %s (run tools/make_temple_tileset_art.py first)." % TILES_JSON)
		quit(1)
		return
	var sheet_tiles: Dictionary = parsed["tiles"]
	var sheet_patterns: Dictionary = parsed["patterns"]
	var sheet_animations: Dictionary = parsed["animations"]

	var profile := TilesetProfile.new()
	profile.texture = load(SHEET)
	profile.tile_size = int(parsed["tile_size"])
	profile.separation = 0
	profile.margin = 0
	for tile_name: String in sheet_tiles:
		profile.tiles[StringName(tile_name)] = _cell(sheet_tiles[tile_name])
	for pattern_name: String in sheet_patterns:
		profile.patterns[StringName(pattern_name)] = _cells(sheet_patterns[pattern_name])
	for animation_name: String in sheet_animations:
		var frames := _cells(sheet_animations[animation_name])
		profile.animations[StringName(animation_name)] = frames
		if not profile.tiles.has(StringName(animation_name)):
			profile.tiles[StringName(animation_name)] = frames[0]
	var missing: Array[String] = []
	for role: StringName in ROLE_TILES:
		var tile_name := String(ROLE_TILES[role])
		if not profile.tiles.has(StringName(tile_name)):
			missing.append("%s -> %s" % [role, tile_name])
		else:
			profile.tiles[role] = profile.tiles[StringName(tile_name)]
	for role: StringName in ROLE_PATTERNS:
		var pattern_name := String(ROLE_PATTERNS[role])
		if not sheet_patterns.has(pattern_name):
			missing.append("%s -> %s" % [role, pattern_name])
		else:
			profile.patterns[role] = _cells(sheet_patterns[pattern_name])
	if not missing.is_empty():
		printerr("The temple sheet lacks: %s" % [missing])
		quit(1)
		return
	var problems := profile.problems(TileArt.ROLES, TileArt.PATTERNS)
	if not problems.is_empty():
		printerr("The profile is incomplete: %s" % [problems])
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://data/tilesets")
	ResourceSaver.save(profile, OUT)
	print("tileset profile written to %s (%d tiles, %d patterns, %d animations)" % [OUT, profile.tiles.size(), profile.patterns.size(), profile.animations.size()])
	quit()


func _cell(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))


func _cells(values: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for value in values:
		cells.append(_cell(value))
	return cells
