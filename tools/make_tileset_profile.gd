extends SceneTree
## Writes the default tileset profile (data/tilesets/kenney_forest.tres): the Kenney Roguelike/RPG
## sheet (16x16 tiles, 1 px apart) and which of its tiles plays each role of `TileArt`.
## Run from the repo root: godot --headless --path . --script res://tools/make_tileset_profile.gd
## For a new pack copy this script, change the sheet, the sizes and the coordinates (find them with
## tools/atlas_preview.gd) and save under another name. See docs/GUIA_TILESET.md.

const SHEET := "res://assets/tilesets/kenney_roguelike_rpg/sheet.png"
const OUT := "res://data/tilesets/kenney_forest.tres"

const TILES := {
	# Ground
	&"grass": Vector2i(5, 0),
	&"dirt": Vector2i(6, 0),
	&"flowers_red": Vector2i(0, 6),
	&"flowers_white": Vector2i(0, 9),
	&"flowers_blue": Vector2i(0, 12),
	&"tuft_a": Vector2i(22, 10),
	&"tuft_b": Vector2i(22, 11),
	&"planks": Vector2i(8, 3),
	&"grass_textured": Vector2i(3, 16),
	&"pebbles": Vector2i(44, 10),
	&"rock_small": Vector2i(56, 21),
	&"rock_mossy": Vector2i(55, 22),
	&"stump": Vector2i(53, 19),
	&"mushroom_brown": Vector2i(48, 2),
	&"mushroom_orange": Vector2i(48, 4),
	&"mushroom_red": Vector2i(48, 5),
	&"mushroom_pale": Vector2i(48, 6),
	&"flower_purple": Vector2i(41, 23),
	&"flower_yellow": Vector2i(42, 23),
	# Props
	&"pine": Vector2i(16, 9),
	&"pine_tall_top": Vector2i(16, 10),
	&"pine_tall_base": Vector2i(16, 11),
	&"round_tree": Vector2i(13, 9),
	&"round_tree_tall_top": Vector2i(13, 10),
	&"round_tree_tall_base": Vector2i(13, 11),
	&"bush": Vector2i(19, 9),
	&"tree_dark": Vector2i(15, 9),
	&"tree_dark_tall_top": Vector2i(15, 10),
	&"tree_dark_tall_base": Vector2i(15, 11),
	&"pine_dark": Vector2i(18, 9),
	&"pine_dark_tall_top": Vector2i(18, 10),
	&"pine_dark_tall_base": Vector2i(18, 11),
	&"bush_dark": Vector2i(21, 9),
	&"bush_berries": Vector2i(24, 11),
	&"rock": Vector2i(55, 21),
	&"bush_orange": Vector2i(20, 9),
	&"campfire": Vector2i(14, 8),
	&"logs": Vector2i(13, 8),
	&"chest_closed": Vector2i(13, 7),
	&"chest_open": Vector2i(14, 7),
	&"torch_a": Vector2i(17, 7),
	&"torch_b": Vector2i(18, 7),
	&"sign": Vector2i(19, 0),
}

const PATTERNS := {
	&"pond": [
		Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
		Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1),
		Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
	],
	&"grass_patch": [
		Vector2i(2, 15), Vector2i(3, 15), Vector2i(4, 15),
		Vector2i(2, 16), Vector2i(3, 16), Vector2i(4, 16),
		Vector2i(2, 17), Vector2i(3, 17), Vector2i(4, 17),
	],
	&"grass_patch_inner": [Vector2i(0, 15), Vector2i(1, 15), Vector2i(0, 16), Vector2i(1, 16)],
	&"dirt_patch": [
		Vector2i(7, 9), Vector2i(8, 9), Vector2i(9, 9),
		Vector2i(7, 10), Vector2i(8, 10), Vector2i(9, 10),
		Vector2i(7, 11), Vector2i(8, 11), Vector2i(9, 11),
	],
	&"dirt_patch_inner": [Vector2i(5, 9), Vector2i(6, 9), Vector2i(5, 10), Vector2i(6, 10)],
	&"stone_floor": [
		Vector2i(7, 13), Vector2i(8, 13), Vector2i(9, 13),
		Vector2i(7, 14), Vector2i(8, 14), Vector2i(9, 14),
		Vector2i(7, 15), Vector2i(8, 15), Vector2i(9, 15),
	],
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/tilesets")
	var profile := TilesetProfile.new()
	profile.texture = load(SHEET)
	profile.tile_size = 16
	profile.separation = 1
	profile.margin = 0
	profile.tiles.assign(TILES)
	profile.patterns.assign(PATTERNS)
	var problems := profile.problems(TileArt.ROLES, TileArt.PATTERNS)
	if not problems.is_empty():
		printerr("The profile is incomplete: %s" % [problems])
		quit(1)
		return
	ResourceSaver.save(profile, OUT)
	print("tileset profile written to %s" % OUT)
	quit()
