extends SceneTree
## Dev aid (needs a window): saves a screenshot of a whole map from above, and of each of its room
## designs, to compare the scenarios' look and order (the Templo is the reference for the Ruinas).
## Run: godot --path . --script res://tools/snapshot_level.gd -- <ruins|forest|temple> [folder] [seed]
## Default folder: user://snapshots/<scenario>/ (printed at the end); default seed: 7.
## The overview is the real level (HUD hidden) seen whole; each room shot is the real room built
## as in the game, with every door open and Nico on his spawn.

const WAIT_FRAMES := 12
const MAX_SIDE := 8192
const ALL_DOORS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const MARGIN := 32

var _dir := ""
var _seed := 7


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var name := args[0] if args.size() > 0 else "ruins"
	_dir = args[1] if args.size() > 1 else "user://snapshots/%s/" % name
	_seed = int(args[2]) if args.size() > 2 else 7
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_node("PlayerProfile").persistence_enabled = false
	var scenario: ScenarioData = load("res://data/scenarios/%s.tres" % name)
	await _shoot_overview("res://scenes/levels/%s_level.tscn" % name)
	TileArt.use_profile(scenario.theme.tileset)
	var rooms: Array[RoomData] = [scenario.start_room, scenario.boss_room]
	rooms.append_array(scenario.rooms)
	for data in rooms:
		await _shoot_room(data, scenario.theme)
	print("snapshots saved in ", ProjectSettings.globalize_path(_dir))
	quit()


func _shoot_overview(scene_path: String) -> void:
	var level: Node2D = load(scene_path).instantiate()
	level.seed_value = _seed
	level.use_director = false
	var holder := _viewport(Vector2i(64, 64))
	holder.add_child(level)
	for layer in level.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	_disable_camera(level.player)
	var area: Rect2 = level.bounds.grow(8 * TileArt.TILE)
	var scale := minf(1.0, MAX_SIDE / maxf(area.size.x, area.size.y))
	holder.size = Vector2i((area.size * scale).ceil())
	var camera := _center_camera(holder, area.get_center())
	camera.zoom = Vector2.ONE * scale
	await _frames(WAIT_FRAMES * 2)
	await _save(holder, "overview_seed_%d" % _seed)
	print("Map (seed %d):\n%s" % [_seed, level.layout.to_ascii()])
	holder.queue_free()


func _shoot_room(data: RoomData, theme: RoomTheme) -> void:
	var room_size: Vector2i = data.size_tiles * TileArt.TILE
	var viewport := _viewport(room_size + Vector2i.ONE * MARGIN * 2)
	var world := Node2D.new()
	world.y_sort_enabled = true
	world.position = Vector2.ONE * MARGIN
	viewport.add_child(world)
	var room: Node2D = data.scene.instantiate()
	room.theme = theme
	room.debug_label = false
	room.setup(data, ALL_DOORS.duplicate())
	world.add_child(room)
	var player: Node2D = load("res://scenes/player/player.tscn").instantiate()
	player.position = room.player_spawn() if room.get_node_or_null("PlayerSpawn") != null else Vector2(room_size) / 2.0
	room.add_child(player)
	_disable_camera(player)
	_center_camera(viewport, Vector2(viewport.size) / 2.0)
	await _frames(WAIT_FRAMES)
	await _save(viewport, String(data.id))
	viewport.queue_free()


func _viewport(size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	return viewport


func _center_camera(viewport: SubViewport, at: Vector2) -> Camera2D:
	var camera := Camera2D.new()
	camera.position = at
	camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	viewport.add_child(camera)
	camera.make_current()
	return camera


func _disable_camera(player: Node) -> void:
	if player == null:
		return
	for camera in player.find_children("*", "Camera2D", true, false):
		camera.enabled = false


func _save(viewport: SubViewport, name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.save_png(_dir.path_join(name + ".png"))
	print("saved ", name, " (", image.get_width(), "x", image.get_height(), ")")


func _frames(count: int) -> void:
	for i in count:
		await process_frame
