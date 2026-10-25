extends SceneTree
## Saves pictures of a generated forest map (needs a window, not --headless): the whole map from
## above and a few views at the game's own zoom, to check the look without playing.
##   godot --path . --script res://tools/screenshot_map.gd -- <seed> <output folder>

const OVERVIEW_SIZE := Vector2i(1800, 1400)
const VIEW_SIZE := Vector2i(640, 360)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var map_seed := int(args[0]) if args.size() > 0 else 4242
	var out := args[1] if args.size() > 1 else "user://"
	await process_frame

	var viewport := SubViewport.new()
	viewport.size = OVERVIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.snap_2d_transforms_to_pixel = true
	root.add_child(viewport)
	var level = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.seed_value = map_seed
	level.use_director = false
	viewport.add_child(level)
	await _frames(3)
	level.player.get_node("Camera2D").enabled = false
	var camera := Camera2D.new()
	viewport.add_child(camera)
	camera.make_current()

	# Whole map (with a little of the margin around it).
	var bounds: Rect2 = level.bounds.grow(64)
	var fit := minf(OVERVIEW_SIZE.x / bounds.size.x, OVERVIEW_SIZE.y / bounds.size.y)
	camera.zoom = Vector2.ONE * fit
	camera.global_position = bounds.get_center()
	await _frames(4)
	await _save(viewport, "%s/map_%d_overview.png" % [out, map_seed])

	# Views at the game's zoom: the start, a corridor, the boss room, and the map's corners.
	viewport.size = VIEW_SIZE
	camera.zoom = Vector2(2, 2)
	camera.limit_left = int(level.bounds.position.x)
	camera.limit_top = int(level.bounds.position.y)
	camera.limit_right = int(level.bounds.end.x)
	camera.limit_bottom = int(level.bounds.end.y)
	var spots := {
		"start": level.rooms[level.layout.start_cell].global_position + Vector2(240, 144),
		"boss": level.rooms[level.layout.boss_cell].global_position + Vector2(240, 144),
		"corner_tl": level.bounds.position,
		"corner_br": level.bounds.end,
		"room_edge": level.rooms[level.layout.start_cell].global_position + Vector2(120, 288),
		"row_gap": level.cell_origin(level.layout.boss_cell) + Vector2(100, 300),
	}
	var corridors: Node = level.get_node("Map/Corridors")
	for child in corridors.get_children():
		if child is TileMapLayer:
			var used: Rect2i = child.get_used_rect()
			spots["corridor"] = Vector2(used.get_center() * 16)
			break
	for spot_name in spots:
		camera.global_position = spots[spot_name]
		level.player.global_position = spots[spot_name] + Vector2(0, 20)
		camera.reset_smoothing()
		await _frames(4)
		await _save(viewport, "%s/map_%d_%s.png" % [out, map_seed, spot_name])
	quit(0)


func _save(viewport: SubViewport, path: String) -> void:
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(path)
	print("saved ", path)


func _frames(count: int) -> void:
	for i in count:
		await process_frame
