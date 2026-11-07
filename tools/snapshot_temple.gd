extends SceneTree
## Dev aid (needs a window): saves a screenshot of every room design of the Templo del Eclipse and
## one overview of a whole temple map, to compare them with docs/referencias/templo_mapa.jpg.
## Run: godot --path . --script res://tools/snapshot_temple.gd -- [folder] [seed]
## Default folder: user://snapshots/temple/ (printed at the end); default seed: 7.
## Each room is built as in the game (room_base + its scene, the temple theme, every door open) on a
## sea of lava two tiles wide around it, with Nico standing at its player spawn or its middle; the
## overview is the real temple level (its HUD hidden) seen whole from above.

const ROOM_SIZE := Vector2i(480, 288)
const MARGIN := 32
const WAIT_FRAMES := 12
const ALL_DOORS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
## The largest picture a viewport may render (the overview is shrunk to fit).
const MAX_SIDE := 8192

var _dir := "user://snapshots/temple/"
var _seed := 7


func _initialize() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_dir = args[0]
	if args.size() > 1:
		_seed = int(args[1])
	DirAccess.make_dir_recursive_absolute(_dir)
	root.get_node("PlayerProfile").persistence_enabled = false
	var scenario: ScenarioData = load("res://data/scenarios/temple.tres")
	TileArt.use_profile(scenario.theme.tileset)
	var rooms: Array[RoomData] = [scenario.start_room, scenario.boss_room]
	rooms.append_array(scenario.rooms)
	for data in rooms:
		await _shoot_room(data, scenario.theme)
	await _shoot_overview()
	print("snapshots saved in ", ProjectSettings.globalize_path(_dir))
	quit()


## One room on a sea of lava, Nico on his spawn, shot after its animations have started.
func _shoot_room(data: RoomData, theme: RoomTheme) -> void:
	var viewport := _viewport(ROOM_SIZE + Vector2i.ONE * MARGIN * 2)
	var world := Node2D.new()
	world.y_sort_enabled = true
	world.position = Vector2.ONE * MARGIN
	viewport.add_child(world)
	var lava := LavaBackdrop.lava_layer("Sea")
	lava.z_index = LavaBackdrop.SEA_Z
	world.add_child(lava)
	var tiles := Vector2i(ROOM_SIZE) / TileArt.TILE
	var margin_tiles := MARGIN / TileArt.TILE
	LavaBackdrop.paint_lava(lava, Rect2i(Vector2i.ONE * -margin_tiles, tiles + Vector2i.ONE * margin_tiles * 2))
	Ambience.apply(world, true, theme.world_tint)
	var room: Node2D = data.scene.instantiate()
	room.theme = theme
	room.debug_label = false
	room.setup(data, ALL_DOORS.duplicate())
	world.add_child(room)
	var player: Node2D = load("res://scenes/player/player.tscn").instantiate()
	player.position = room.player_spawn() if room.get_node_or_null("PlayerSpawn") != null else Vector2(ROOM_SIZE) / 2.0
	room.add_child(player)
	_disable_camera(player)
	# The ground shadow Level gives him on a temple map, so the room shots show him standing.
	ActorShadow.attach(player, Tuning.TEMPLE_SHADOW_ALPHA, Tuning.TEMPLE_SHADOW_SCALE, Tuning.TEMPLE_SHADOW_DROP)
	Heights.set_level(player, room.height_at(player.position))
	_center_camera(viewport, Vector2(viewport.size) / 2.0)
	await _frames(WAIT_FRAMES)
	await _save(viewport, String(data.id).trim_prefix("temple_"))
	viewport.queue_free()


## A whole temple map from above (its HUD and veil hidden), shrunk when it would not fit a texture.
func _shoot_overview() -> void:
	var level: Node2D = load("res://scenes/levels/temple_level.tscn").instantiate()
	level.seed_value = _seed
	level.use_director = false
	var holder := _viewport(Vector2i(64, 64))
	var started := Time.get_ticks_msec()
	holder.add_child(level)
	var build_ms := Time.get_ticks_msec() - started
	print("temple map built in %d ms (seed %d)" % [build_ms, _seed])
	for layer in level.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	_disable_camera(level.player)
	var area: Rect2 = level.bounds.grow(Tuning.TEMPLE_BACKDROP_MARGIN_TILES * TileArt.TILE)
	var scale := minf(1.0, MAX_SIDE / maxf(area.size.x, area.size.y))
	holder.size = Vector2i((area.size * scale).ceil())
	var camera := _center_camera(holder, area.get_center())
	camera.zoom = Vector2.ONE * scale
	await _frames(WAIT_FRAMES * 2)
	await _save(holder, "overview_seed_%d" % _seed)
	print("Temple map (seed %d):\n%s" % [_seed, level.layout.to_ascii()])
	holder.queue_free()


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


## The player's own camera would take the viewport: it is switched off.
func _disable_camera(player: Node) -> void:
	if player == null:
		return
	for camera in player.find_children("*", "Camera2D", true, false):
		camera.enabled = false


func _save(viewport: SubViewport, name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var path := _dir.path_join(name + ".png")
	image.save_png(path)
	print("saved ", name, " (", image.get_width(), "x", image.get_height(), ")")


func _frames(count: int) -> void:
	for i in count:
		await process_frame
