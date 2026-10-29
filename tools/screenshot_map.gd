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
	# Run with a window, saving would be on: never touch the player's save or profile.
	root.get_node("SaveGame").persistence_enabled = false
	root.get_node("PlayerProfile").persistence_enabled = false

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
	# No black veil in the pictures (it hides the map being built in the game).
	level._veil.color.a = 0.0
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
	# A crossing of paths: the middle of a room (not the start or boss) with three or more doors.
	for coord: Vector2i in level.layout.cells:
		var cell = level.layout.get_cell(coord)
		if cell.doors.size() >= 3 and coord != level.layout.start_cell and coord != level.layout.boss_cell:
			spots["junction"] = level.rooms[coord].global_position + Vector2(240, 144)
			break
	# Where a room meets the row above it (the line between two rows of rooms).
	spots["room_seam"] = level.rooms[level.layout.start_cell].global_position + Vector2(100, 0)
	# The special rooms (their decoration) and the way into the boss arena.
	for coord: Vector2i in level.layout.cells:
		var room: Node2D = level.rooms[coord]
		match room.data.type:
			RoomData.RoomType.REWARD:
				spots["reward"] = room.global_position + Vector2(240, 144)
			RoomData.RoomType.EVENT:
				spots["event"] = room.global_position + Vector2(160, 110)
			RoomData.RoomType.BOSS:
				if not room.open_doors.is_empty():
					var door: Vector2i = room.open_doors[0]
					spots["boss_door"] = room.global_position + Vector2(240, 144) + Vector2(door) * Vector2(170, 90)
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
		# The forest's particles live in the world: each jump of the picture camera regrows them here.
		var life: Node = level.get_node_or_null("AmbientLife")
		if life != null and life.visible:
			life.set_enabled(true)
		await _frames(4)
		await _save(viewport, "%s/map_%d_%s.png" % [out, map_seed, spot_name])
	await _open_portal(level, camera, viewport, "%s/map_%d_portal_open.png" % [out, map_seed])
	await _boss_attack(level, camera, viewport, "%s/map_%d_boss_attack.png" % [out, map_seed])
	quit(0)


## The exit portal as it looks once the boss has fallen (shown open without touching the story flags).
func _open_portal(level: Node, camera: Camera2D, viewport: SubViewport, path: String) -> void:
	var portals := get_nodes_in_group("exit_portals").filter(func(node: Node) -> bool: return level.is_ancestor_of(node))
	if portals.is_empty():
		return
	var portal: Node2D = portals[0]
	# The boss stands in front of the portal: out of the picture, as after the fight.
	for node in get_nodes_in_group("enemies"):
		if node.get("phase") != null and level.is_ancestor_of(node):
			node.visible = false
			node.process_mode = Node.PROCESS_MODE_DISABLED
	portal.get_node("Glow").visible = true
	for part in ["Light", "Sparks"]:
		var node := portal.get_node_or_null(part)
		if node != null:
			node.visible = true
			if node is CPUParticles2D:
				node.emitting = true
	level.player.global_position = portal.global_position + Vector2(44, 36)
	camera.global_position = portal.global_position + Vector2(0, 30)
	camera.reset_smoothing()
	for i in 40:
		await physics_frame
	await _save(viewport, path)


## The boss winding up its roots attack next to Nico: are the warnings easy to read?
func _boss_attack(level: Node, camera: Camera2D, viewport: SubViewport, path: String) -> void:
	var boss: Node2D = null
	for node in get_nodes_in_group("enemies"):
		if node.get("phase") != null and level.is_ancestor_of(node):
			boss = node
	if boss == null:
		return
	var player: Node2D = level.player
	player.set("_invulnerable_left", 99.0)
	player.global_position = boss.global_position + Vector2(90, 30)
	camera.global_position = boss.global_position + Vector2(45, 20)
	camera.reset_smoothing()
	boss._last_pattern = boss.Pattern.SLAM
	boss._acquire_target(player)
	for i in 300:
		await physics_frame
		player.set("_invulnerable_left", 99.0)
		if boss.state == boss.State.ATTACK and boss.pattern == boss.Pattern.ROOTS and boss._step_left < 0.6:
			break
		if boss.state != boss.State.ATTACK:
			boss._last_pattern = boss.Pattern.SLAM
			player.global_position = boss.global_position + Vector2(90, 30)
	await _save(viewport, path)


func _save(viewport: SubViewport, path: String) -> void:
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(path)
	print("saved ", path)


func _frames(count: int) -> void:
	for i in count:
		await process_frame
