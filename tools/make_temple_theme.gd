extends SceneTree
## Writes the visual theme of the Templo del Eclipse (data/themes/temple.tres): the temple tileset
## profile, flagstone floors mixed from six slabs, a warm tint and no wall art (the rooms are
## islands whose edges drop into lava: WallStyle.LAVA).
## Run: godot --headless --path . --script res://tools/make_temple_theme.gd


func _initialize() -> void:
	var theme := RoomTheme.new()
	theme.tileset = load("res://data/tilesets/temple.tres")
	theme.floor_tile = &"floor_a"
	# The floor is a mix of the six slab tiles, so no single tile repeats across a room.
	theme.floor_variants.assign([&"floor_b", &"floor_c", &"floor_d", &"floor_e", &"floor_f"])
	theme.floor_variant_chance = 0.8
	theme.decor_tiles.assign([&"floor_moss_a", &"floor_moss_b", &"floor_crack_a", &"floor_crack_b", &"rubble_a", &"pebbles"])
	theme.decor_chance = 0.04
	theme.path_tile = TileArt.DIRT
	theme.wall_style = RoomTheme.WallStyle.LAVA
	# The lava's warm light over everything, and no fireflies or leaves.
	theme.world_tint = Tuning.TEMPLE_WORLD_TINT
	theme.ambient_life = false
	ResourceSaver.save(theme, "res://data/themes/temple.tres")
	print("theme written")
	quit()
