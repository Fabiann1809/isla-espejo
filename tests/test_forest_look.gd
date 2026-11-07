extends SceneTree
## The forest's look: on 30 maps every tile the camera can show has ground drawn on it (no black in
## the corners, between rooms or along the corridors), the decoration never blocks anyone, the
## backdrop is the same for the same seed and actors have shadows.
## Run: godot --headless --path . --script res://tests/test_forest_look.gd

const SEEDS := 30

var _ok := true


func _initialize() -> void:
	create_timer(170.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var level = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.use_director = false
	level.seed_value = 1
	root.add_child(level)
	await _frames(2)

	var clear: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	_check(clear.g > clear.r and clear.g > clear.b and clear.v < 0.15, "the background color is a very dark green")

	# --- No black: every tile inside the camera limits has ground on it.
	var bare_total := 0
	var tiles_total := 0
	var bare_maps: Array[int] = []
	for map_seed in range(1, SEEDS + 1):
		level.generate(map_seed)
		await _frames(1)
		var bare := _bare_tiles(level)
		bare_total += bare.bare
		tiles_total += bare.tiles
		if bare.bare > 0:
			bare_maps.append(map_seed)
	_check(bare_total == 0, "%d maps: every visible tile has ground (%d of %d bare, seeds %s)"
			% [SEEDS, bare_total, tiles_total, bare_maps])

	# --- Where paths meet (a T or a cross) their inner corners are rounded, not square.
	var square_corners := 0
	var inner_corners := 0
	for map_seed in [4242, 31337, 7]:
		level.generate(map_seed)
		await _frames(1)
		var corners := _path_corners(level)
		square_corners += corners.square
		inner_corners += corners.rounded
	_check(inner_corners > 0 and square_corners == 0,
			"path crossings have rounded inner corners (%d rounded, %d square)" % [inner_corners, square_corners])

	# --- Decoration never blocks: no tile has collision and nothing decorative has a body.
	var tile_set: TileSet = load("res://data/themes/forest.tres").tileset.tile_set()
	_check(tile_set.get_physics_layers_count() == 0, "the forest tiles have no collision")
	var map: Node = level.get_node("Map")
	var backdrop: Node = map.get_node("Backdrop")
	var bodies := backdrop.find_children("*", "CollisionObject2D", true, false)
	for room in level.rooms.values():
		for layer_name in ["Ground", "Patches", "Decor", "Border", "Details"]:
			bodies.append_array(room.get_node(layer_name).find_children("*", "CollisionObject2D", true, false))
	_check(bodies.is_empty(), "the backdrop and the floor details add no bodies")

	# --- The forest art set: floor details are its pictures, and bushes, rocks and stumps only use
	# the pictures that fit them and block only with their base.
	var tile_art: Script = load("res://scripts/world/tile_art.gd")
	var forest_art: Script = load("res://scripts/world/forest_art.gd")
	var old_details := [tile_art.TUFT_A, tile_art.TUFT_B, tile_art.PEBBLES, tile_art.ROCK_SMALL, tile_art.STUMP].map(
			func(role: StringName) -> Vector2i: return tile_art.coords(role))
	var old_left := 0
	var art_details := 0
	for room in level.rooms.values():
		var decor: TileMapLayer = room.get_node("Decor")
		for cell in decor.get_used_cells():
			if decor.get_cell_atlas_coords(cell) in old_details:
				old_left += 1
		art_details += room.get_node("Details").get_child_count()
		if room.get_node("WallTrees").get_child_count() == 0 or not room.get_node("Border").get_used_cells().is_empty():
			old_left += 1
	_check(old_left == 0 and art_details > 0,
			"floor details and the walls' trees are drawn with the forest art (%d pictures, %d old tiles)" % [art_details, old_left])
	var allowed := {}
	for n in forest_art.SOLID_BUSHES:
		allowed[forest_art.BUSHES % n] = true
	for n in forest_art.BIG_ROCKS:
		allowed[forest_art.ROCKS % n] = true
	allowed[forest_art.STUMP] = true
	allowed[forest_art.CUT_STUMP] = true
	var blockers := 0
	var wrong := []
	for prop in level.get_node("Map").find_children("*", "Node2D", true, false):
		if not prop.has_method("is_flat") or not (prop.kind in [4, 9]):  # RoomProp.Kind.BUSH, LOGS
			continue
		blockers += 1
		var sprite: Sprite2D = prop.find_children("*", "Sprite2D", false, false)[0]
		var shape: RectangleShape2D = prop.find_children("*", "CollisionShape2D", true, false)[0].shape
		if not allowed.has(sprite.texture.resource_path) or shape.size.x > sprite.texture.get_width():
			wrong.append(sprite.texture.resource_path.get_file())
	_check(blockers > 0 and wrong.is_empty(),
			"bushes, boulders and stumps use solid pictures and block no wider than them (%d; wrong: %s)" % [blockers, wrong])
	_check(backdrop.z_index < -1, "the backdrop is drawn below every floor")

	# --- Same seed, same forest.
	level.generate(7)
	await _frames(1)
	var first := _backdrop_signature(level)
	level.generate(8)
	await _frames(1)
	var other := _backdrop_signature(level)
	level.generate(7)
	await _frames(1)
	_check(first == _backdrop_signature(level) and first != other, "the forest is fixed by the map's seed")
	# The backdrop is under the rooms and corridors: a tree reaching over them would be cut off in a
	# straight line, so none does; and the forest's floor is darker, with no hard edge.
	var tree_rects: Array = level.get_node("Map/Backdrop").get_meta("tree_rects", [])
	var keep_clear: Array[Rect2] = []
	for coord in level.layout.cells:
		keep_clear.append(Rect2(level.cell_origin(coord), level.cell_size()))
	keep_clear.append_array(level._corridor_floors)
	keep_clear.append_array(level._corridor_walls)
	var reaching := 0
	for rect: Rect2 in tree_rects:
		var inner := rect.grow(-minf(4.0, minf(rect.size.x, rect.size.y) / 2.0 - 0.5))
		for clear_rect: Rect2 in keep_clear:
			if clear_rect.intersects(inner):
				reaching += 1
				break
	_check(tree_rects.size() > 100 and reaching == 0,
			"%d backdrop trees, none reaching over a room or a corridor (%d do)" % [tree_rects.size(), reaching])
	var shade: Node2D = level.get_node_or_null("Map/ForestShade")
	var shade_sprite: Sprite2D = shade.get_child(0) if shade != null else null
	_check(shade_sprite != null and shade_sprite.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR
			and shade.z_index < 0, "the forest floor is shaded softly, under the actors")

	# --- Shadows and the overall look.
	map = level.get_node("Map")
	var shadows: bool = level.player.has_node("Shadow")
	for enemy in get_nodes_in_group("enemies"):
		if map.is_ancestor_of(enemy) and not enemy.is_queued_for_deletion():
			shadows = shadows and enemy.has_node("Shadow")
	_check(shadows, "Nico and every enemy have a shadow")
	_check(level.has_node("WorldTint") and level.has_node("ScreenGrade")
			and level.get_node("ScreenGrade").get_index() < level.get_node("Hud").get_index(),
			"the world tint and the screen grade are on, below the HUD")

	# --- Forest life: a few particles around the camera, under every actor, and nothing solid.
	var life: Node2D = level.get_node_or_null("AmbientLife")
	# Its emitters are made on its first process frame, where the camera is.
	for i in 3:
		await process_frame
	var particles: Array = life.find_children("*", "CPUParticles2D", false, false) if life != null else []
	var alive := 0
	for emitter in particles:
		alive += emitter.amount
	_check(life != null and particles.size() == 2 and alive <= 20 and life.z_index < 0 and not life.z_as_relative,
			"fireflies and falling leaves (%d particles) drift under every actor" % alive)
	_check(life.find_children("*", "CollisionObject2D", true, false).is_empty(), "the forest life has no collision")

	# --- The look follows the scenario being played, not the first one loaded.
	var plain_first = load("res://scenes/levels/forest_level.tscn").instantiate()
	plain_first.use_director = false
	plain_first.seed_value = 3
	plain_first.scenario = load("res://data/scenarios/test.tres")
	root.add_child(plain_first)
	await _frames(2)
	var off_on_plain := not _look_on(plain_first)
	plain_first.scenario = load("res://data/scenarios/forest.tres")
	plain_first.generate(4)
	await _frames(1)
	var on_in_forest := _look_on(plain_first)
	plain_first.scenario = load("res://data/scenarios/test.tres")
	plain_first.generate(5)
	await _frames(1)
	var life_follows: bool = not plain_first.get_node("AmbientLife").visible
	_check(off_on_plain and on_in_forest and not _look_on(plain_first) and life_follows,
			"the tint and screen grade follow the current scenario's theme")
	plain_first.queue_free()
	await _frames(1)

	# --- Taking the exit: the new map is built behind a black veil (its hitch is not seen), the map
	# is the same one the seed gives, and the veil lifts afterwards.
	var seen := {"veil": -1.0}
	var built := func(_layout) -> void:
		var veil: ColorRect = level.get_node_or_null("MapVeil/Veil")
		seen.veil = veil.color.a if veil != null else -1.0
	level.completion_delay = 0.05
	# The forest is the last chapter: looping it like a sandbox lets the exit build a new map.
	level.end_after_last_chapter = false
	level.generated.connect(built)
	root.get_node("Events").scenario_completed.emit(&"forest")
	var waited := 0
	while seen.veil < 0.0 and waited < 240:
		await process_frame
		waited += 1
	level.generated.disconnect(built)
	var exit_seed: int = level.current_seed
	var exit_cells: Array = level.layout.cells.keys()
	await create_timer(1.0).timeout
	var veil_after: ColorRect = level.get_node_or_null("MapVeil/Veil")
	var veil_at_build: float = seen.veil
	_check(veil_at_build >= 0.99 and veil_after != null and veil_after.color.a <= 0.01,
			"a new map is built behind a black veil that lifts afterwards (%.2f while building)" % veil_at_build)
	level.generate(exit_seed)
	await _frames(1)
	var same: bool = level.layout.cells.keys() == exit_cells
	_check(same, "the veil does not change the map a seed gives")

	# --- Using the exit twice during its pause still moves on only once.
	var builds := {"count": 0}
	var count_build := func(_layout) -> void: builds.count += 1
	level.generated.connect(count_build)
	root.get_node("Events").scenario_completed.emit(&"forest")
	await create_timer(0.02).timeout
	root.get_node("Events").scenario_completed.emit(&"forest")
	await create_timer(1.2).timeout
	level.generated.disconnect(count_build)
	_check(builds.count == 1, "using the exit twice builds one new map (%d)" % builds.count)

	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


## Tiles inside the level bounds with no ground: no room floor, corridor ground or backdrop grass.
func _bare_tiles(level: Node) -> Dictionary:
	var covered := {}
	var map: Node = level.get_node("Map")
	for layer in map.find_children("*", "TileMapLayer", true, false):
		if not (layer.name == "Ground" or String(layer.name).begins_with("CorridorGround") or String(layer.name).begins_with("Ground")):
			continue
		var offset := Vector2i(layer.global_position) / 16
		for cell in layer.get_used_cells():
			covered[cell + offset] = true
	var bounds: Rect2 = level.bounds
	var area := Rect2i(Vector2i(bounds.position) / 16, Vector2i(bounds.size) / 16)
	var bare := 0
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if not covered.has(Vector2i(x, y)):
				bare += 1
	return {"bare": bare, "tiles": area.get_area()}


## Path tiles of the whole map (rooms and corridors): concave corners drawn with an inner-corner tile
## (rounded) or with the plain center tile (square).
func _path_corners(level: Node) -> Dictionary:
	var dirt_art: Script = load("res://scripts/world/dirt_art.gd")
	if dirt_art.available():
		return _earth_corners(level)
	var art: Script = load("res://scripts/world/tile_art.gd")
	var inner: Array = art.pattern(art.DIRT_PATCH_INNER)
	var path_tile: Vector2i = art.coords(art.DIRT)
	_check(path_tile == art.pattern(art.DIRT_PATCH)[4],
			"paths are drawn with the patch's plain dirt (a tile with a grass rim shows as squares)")
	var dirt: Array = art.pattern(art.DIRT_PATCH) + inner + [path_tile]
	var tiles := {}
	for layer in level.get_node("Map").find_children("*", "TileMapLayer", true, false):
		if String(layer.name).begins_with("Ground") and layer.get_parent().name == "Backdrop":
			continue
		var offset := Vector2i(layer.global_position) / 16
		for cell in layer.get_used_cells():
			var coords: Vector2i = layer.get_cell_atlas_coords(cell)
			if coords in dirt:
				# An overlay (patch layer) wins over the ground under it.
				if not tiles.has(cell + offset) or coords != path_tile:
					tiles[cell + offset] = coords
	var result := {"square": 0, "rounded": 0}
	for cell: Vector2i in tiles:
		var sides := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN].all(
				func(d: Vector2i) -> bool: return tiles.has(cell + d))
		var corners := [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)].any(
				func(d: Vector2i) -> bool: return not tiles.has(cell + d))
		if sides and corners:
			if tiles[cell] in inner:
				result.rounded += 1
			else:
				result.square += 1
	return result


func _look_on(level: Node) -> bool:
	var tint: Node = level.get_node_or_null("WorldTint")
	var grade: Node = level.get_node_or_null("ScreenGrade")
	return tint != null and tint.visible and grade != null and grade.visible


func _backdrop_signature(level: Node) -> Array:
	var signature := []
	var backdrop: Node = level.get_node("Map/Backdrop")
	for layer in backdrop.get_children():
		if layer is TileMapLayer:
			var cells: Array = layer.get_used_cells()
			cells.sort()
			signature.append(cells.size())
			signature.append(hash(cells))
	signature.append(hash(backdrop.get_meta("tree_rects", [])))
	return signature


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


## The same with the forest's own earth (DirtArt): every layer painted with its sheet, paths and
## patches alike; a rounded inner corner is one of its inner-corner rows.
func _earth_corners(level: Node) -> Dictionary:
	var area: Script = load("res://scripts/world/area_art.gd")
	var dirt_tiles: TileSet = area.tile_set(load("res://scripts/world/dirt_art.gd").DIRT)
	var tiles := {}
	for layer in level.get_node("Map").find_children("*", "TileMapLayer", true, false):
		if layer.tile_set != dirt_tiles:
			continue
		var offset := Vector2i((layer.global_position / 16.0).round())
		for cell in layer.get_used_cells():
			tiles[cell + offset] = layer.get_cell_atlas_coords(cell).y
	var result := {"square": 0, "rounded": 0}
	for cell: Vector2i in tiles:
		var sides := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN].all(
				func(d: Vector2i) -> bool: return tiles.has(cell + d))
		var corners := [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)].any(
				func(d: Vector2i) -> bool: return not tiles.has(cell + d))
		if sides and corners:
			if tiles[cell] in area.INNER_ROWS:
				result.rounded += 1
			else:
				result.square += 1
	return result
