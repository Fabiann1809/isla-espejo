extends SceneTree
## Builds the forest RoomTheme (data/themes/forest.tres) with tile ROLES and the default tileset
## profile, and saves that profile's TileSet as assets/tilesets/forest_tileset.tres so any tile of
## the sheet can be painted with a TileMapLayer in the editor (the game builds its own at runtime).
## Run from the repo root, after tools/make_tileset_profile.gd:
##   godot --headless --path . --script res://tools/make_forest_tileset.gd


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/themes")
	var profile: TilesetProfile = load(TileArt.DEFAULT_PROFILE)
	ResourceSaver.save(profile.tile_set().duplicate(true), "res://assets/tilesets/forest_tileset.tres")

	var theme := RoomTheme.new()
	theme.tileset = profile
	theme.floor_tile = TileArt.GRASS
	theme.decor_tiles = [TileArt.TUFT_A, TileArt.TUFT_B]
	theme.decor_chance = 0.05
	theme.border_tile = TileArt.PINE
	theme.path_tile = TileArt.DIRT
	ResourceSaver.save(theme, "res://data/themes/forest.tres")
	print("forest tileset and theme written")
	quit()
