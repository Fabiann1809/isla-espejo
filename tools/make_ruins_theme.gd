extends SceneTree
## Writes the visual theme of the Ruinas de la Montaña (data/themes/ruins.tres): the ruins tileset
## profile, the stone floor, worn-stone paths and walls made of rock columns over solid rock.
## Run: godot --headless --path . --script res://tools/make_ruins_theme.gd


func _initialize() -> void:
	var theme := RoomTheme.new()
	theme.tileset = load("res://data/tilesets/ruins.tres")
	theme.floor_tile = TileArt.GRASS
	theme.floor_variants.assign([&"floor_b", &"floor_crack", &"floor_moss"])
	theme.floor_variant_chance = 0.05
	theme.decor_tiles.assign([&"pebbles", &"moss_clump_a", &"moss_clump_b", &"rubble_a", &"rubble_b"])
	theme.decor_chance = 0.025
	theme.path_tile = TileArt.DIRT
	theme.wall_style = RoomTheme.WallStyle.ROCKS
	# A cold blue light over the cave, and no fireflies or leaves.
	theme.world_tint = Color(0.8, 0.86, 1.0)
	theme.ambient_life = false
	ResourceSaver.save(theme, "res://data/themes/ruins.tres")
	print("theme written")
	quit()
