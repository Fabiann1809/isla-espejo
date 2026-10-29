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
		for layer_name in ["Ground", "Patches", "Decor", "Border"]:
			bodies.append_array(room.get_node(layer_name).find_children("*", "CollisionObject2D", true, false))
	_check(bodies.is_empty(), "the backdrop and the floor details add no bodies")
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
	# A tall tree's crown never lands on a tree of the next band (they are on separate layers).
	var used := {}
	var stacked := 0
	for layer in level.get_node("Map/Backdrop").get_children():
		if String(layer.name).begins_with("Canopy"):
			for cell in layer.get_used_cells():
				if used.has(cell):
					stacked += 1
				used[cell] = true
	_check(stacked == 0, "no two backdrop trees on the same tile (%d stacked)" % stacked)

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
	var art: Script = load("res://scripts/world/tile_art.gd")
	var inner: Array = art.pattern(art.DIRT_PATCH_INNER)
	var path_tile: Vector2i = art.coords(art.DIRT)
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
	for layer in level.get_node("Map/Backdrop").get_children():
		var cells: Array = layer.get_used_cells()
		cells.sort()
		signature.append(cells.size())
		signature.append(hash(cells))
	return signature


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
