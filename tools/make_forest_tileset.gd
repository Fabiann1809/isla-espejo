extends SceneTree
## Builds the TileSet of the forest (assets/tilesets/forest_tileset.tres) and the forest RoomTheme
## (data/themes/forest.tres) from the Kenney Roguelike/RPG sheet.
## Run from the repo root: godot --headless --path . --script res://tools/make_forest_tileset.gd
## The TileSet registers EVERY tile of the sheet (16x16, 1 px separation) as atlas source 0, so any
## tile can be painted with a TileMapLayer in the editor using its (column,row) coordinates.

const COLUMNS := 57
const ROWS := 31


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/themes")

	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TileArt.TILE, TileArt.TILE)
	var source := TileSetAtlasSource.new()
	source.texture = load(TileArt.SHEET_PATH)
	source.texture_region_size = Vector2i(TileArt.TILE, TileArt.TILE)
	source.separation = Vector2i(TileArt.MARGIN, TileArt.MARGIN)
	for row in ROWS:
		for column in COLUMNS:
			source.create_tile(Vector2i(column, row))
	tile_set.add_source(source, 0)
	ResourceSaver.save(tile_set, "res://assets/tilesets/forest_tileset.tres")

	var theme := RoomTheme.new()
	theme.tile_set = load("res://assets/tilesets/forest_tileset.tres")
	theme.floor_tile = TileArt.GRASS
	theme.floor_variants = [TileArt.FLOWERS_RED, TileArt.FLOWERS_WHITE, TileArt.FLOWERS_BLUE]
	theme.floor_variant_chance = 0.03
	theme.decor_tiles = [TileArt.TUFT_A, TileArt.TUFT_B]
	theme.decor_chance = 0.05
	theme.border_tile = TileArt.PINE
	theme.path_tile = TileArt.DIRT
	ResourceSaver.save(theme, "res://data/themes/forest.tres")
	print("forest tileset and theme written")
	quit()
