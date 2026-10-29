extends SceneTree
## Tileset profiles (TilesetProfile + TileArt roles): the game asks for tiles by role, so another
## profile changes the art without touching code; and a pack of 32x32 tiles, with
## Tuning.TILESET_FIT_TO_GRID, fills exactly the same 16 px cells as today (same rooms, same collision).
## Run: godot --headless --path . --script res://tests/test_tileset_profile.gd
## `Level` and `Room` types must not be referenced here (autoload compile order).

const SEED := 4242

var _ok := true


func _initialize() -> void:
	create_timer(150.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var default_profile: TilesetProfile = load(TileArt.DEFAULT_PROFILE)

	_check(default_profile.problems(TileArt.ROLES, TileArt.PATTERNS).is_empty(),
			"the default profile has a tile for every role")
	var broken: TilesetProfile = default_profile.duplicate()
	broken.tiles = default_profile.tiles.duplicate()
	broken.tiles.erase(TileArt.PINE)
	broken.patterns = default_profile.patterns.duplicate()
	broken.patterns[TileArt.POND] = [Vector2i(2, 0)]
	var problems: Array = broken.problems(TileArt.ROLES, TileArt.PATTERNS)
	_check(problems.size() == 2, "a profile with a missing role or a short pattern is reported (%s)" % [problems])

	var level := await _build_level()
	var today := _drawn(level)
	var collision := _collision(level)
	level.free()

	# Another pack, same roles: the floor is painted with whatever the profile says is grass.
	var swapped: TilesetProfile = default_profile.duplicate()
	swapped.tiles = default_profile.tiles.duplicate()
	swapped.tiles[TileArt.GRASS] = default_profile.tiles[TileArt.DIRT]
	level = await _build_level(swapped)
	var ground: TileMapLayer = level.rooms[level.layout.start_cell].get_node("Ground")
	var cell := Vector2i(5, 5)
	_check(ground.get_cell_atlas_coords(cell) == default_profile.tiles[TileArt.DIRT],
			"the rooms ask for the 'grass' role, not for a sheet coordinate")
	level.free()

	# The same sheet, doubled: a pack of 32x32 tiles with 2 px between them.
	var doubled := _doubled(default_profile)
	TileArt.fit_to_grid = true
	level = await _build_level(doubled)
	var fitted := _drawn(level)
	_check(fitted.size() == today.size() and fitted == today,
			"32x32 tiles fitted to the grid fill the same 16 px cells as today (%d tiles)" % fitted.size())
	_check(_collision(level) == collision, "and the collision of the map does not change")
	var any_sprite: Sprite2D = level.find_children("*", "Sprite2D", true, false).filter(
			func(node: Node) -> bool: return node.texture is AtlasTexture)[0]
	_check(is_equal_approx(any_sprite.global_scale.x, 0.5) and any_sprite.texture.region.size == Vector2(32, 32),
			"each 32 px tile is drawn at half size")
	level.free()

	TileArt.fit_to_grid = false
	level = await _build_level(doubled)
	var native := _drawn(level)
	_check(native != today, "without the flag a 32 px pack is drawn at its own size (the flag is needed)")
	level.free()

	TileArt.fit_to_grid = Tuning.TILESET_FIT_TO_GRID
	TileArt.use_profile(null)
	_check(TileArt.profile() == default_profile and TileArt.draw_scale() == 1.0, "the default profile is back")
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


## The forest level with `profile` as its theme's pack (null = the forest theme as it is).
func _build_level(profile: TilesetProfile = null) -> Node2D:
	var level: Node2D = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.use_director = false
	level.seed_value = SEED
	if profile != null:
		level.scenario = level.scenario.duplicate()
		level.scenario.theme = level.scenario.theme.duplicate()
		level.scenario.theme.tileset = profile
	root.add_child(level)
	await physics_frame
	await physics_frame
	return level


## A copy of `profile` whose sheet is twice as big (nearest): 32 px tiles, same coordinates.
func _doubled(profile: TilesetProfile) -> TilesetProfile:
	var image: Image = profile.texture.get_image()
	image.resize(image.get_width() * 2, image.get_height() * 2, Image.INTERPOLATE_NEAREST)
	var doubled: TilesetProfile = profile.duplicate()
	doubled.texture = ImageTexture.create_from_image(image)
	doubled.tile_size = profile.tile_size * 2
	doubled.separation = profile.separation * 2
	doubled.margin = profile.margin * 2
	return doubled


## The world rectangle of every tile the map draws (layers and tile sprites), sorted.
func _drawn(level: Node) -> Array:
	var rects := []
	for node in level.get_node("Map").find_children("*", "", true, false):
		if node is TileMapLayer:
			var layer := node as TileMapLayer
			var size := Vector2(layer.tile_set.tile_size) * layer.global_scale
			for cell in layer.get_used_cells():
				var top_left := layer.to_global(layer.map_to_local(cell) - Vector2(layer.tile_set.tile_size) / 2.0)
				rects.append(Rect2(top_left.round(), size))
		elif node is Sprite2D and node.texture is AtlasTexture and not node.centered:
			rects.append(Rect2(node.global_position.round(), node.texture.region.size * node.global_scale))
	rects.sort_custom(func(a: Rect2, b: Rect2) -> bool:
		return [a.position.x, a.position.y, a.size.x] < [b.position.x, b.position.y, b.size.x])
	return rects


## Every collision shape of the map (world rectangle), sorted.
func _collision(level: Node) -> Array:
	var shapes := []
	for node in level.get_node("Map").find_children("*", "CollisionShape2D", true, false):
		if node.shape is RectangleShape2D and node.get_parent() is StaticBody2D:
			shapes.append(Rect2(node.global_position - node.shape.size / 2.0, node.shape.size))
	shapes.sort_custom(func(a: Rect2, b: Rect2) -> bool:
		return [a.position.x, a.position.y, a.size.x] < [b.position.x, b.position.y, b.size.x])
	return shapes


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false
