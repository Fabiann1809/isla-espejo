extends SceneTree
## Lists every tile and tile sprite a generated forest map draws (texture, region in pixels, place,
## scale, tint) and prints one hash per map. Two runs with the same hashes draw exactly the same
## thing: use it to check that a change in how tiles are looked up keeps the game identical.
##   godot --headless --path . --script res://tools/dump_tiles.gd -- [seed ...]

const DEFAULT_SEEDS := [4242, 1, 2, 3, 7]


func _initialize() -> void:
	await process_frame
	var seeds: Array = Array(OS.get_cmdline_user_args()).map(func(arg: String) -> int: return int(arg))
	if seeds.is_empty():
		seeds = DEFAULT_SEEDS
	var level = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.use_director = false
	level.seed_value = seeds[0]
	root.add_child(level)
	await physics_frame
	var all := []
	for map_seed in seeds:
		level.generate(map_seed)
		await physics_frame
		var lines := _describe(level.get_node("Map"))
		lines.sort()
		var text := "\n".join(lines)
		all.append(text)
		print("seed %d: %d drawn tiles, hash %s" % [map_seed, lines.size(), text.md5_text()])
	print("ALL %s" % "\n".join(all).md5_text())
	quit(0)


func _describe(node: Node) -> Array:
	var lines := []
	if node is TileMapLayer:
		var layer := node as TileMapLayer
		for cell in layer.get_used_cells():
			var source := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
			var region := source.get_tile_texture_region(layer.get_cell_atlas_coords(cell))
			var at: Vector2 = layer.to_global(layer.map_to_local(cell))
			lines.append("L %s %s %s %s %s z%d %s" % [source.texture.resource_path.get_file(), region, at.round(),
					layer.global_scale, layer.modulate, layer.z_index, layer.texture_filter])
	elif node is Sprite2D and node.texture is AtlasTexture:
		var sprite := node as Sprite2D
		var texture := sprite.texture as AtlasTexture
		lines.append("S %s %s %s %s %s %s" % [texture.atlas.resource_path.get_file(), texture.region,
				sprite.global_position.round(), sprite.global_scale, sprite.centered, sprite.texture_filter])
	for child in node.get_children():
		lines.append_array(_describe(child))
	return lines
