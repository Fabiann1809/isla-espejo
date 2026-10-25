extends SceneTree
## The forest's look: on 30 maps every tile the camera can show has ground drawn on it (no black in
## the corners, between rooms or along the corridors), the decoration never blocks anyone, the
## backdrop is the same for the same seed, actors have shadows, and the debug text starts hidden.
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

	# --- Decoration never blocks: no tile has collision and nothing decorative has a body.
	var tile_set: TileSet = load("res://data/themes/forest.tres").tile_set
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

	# --- Debug text: hidden at start, F3 (debug_toggle_info) shows and hides it.
	var debug: CanvasLayer = level.get_node("Debug")
	_check(not debug.visible, "the debug text starts hidden")
	_press(level, "debug_toggle_info")
	var shown: bool = debug.visible
	_press(level, "debug_toggle_info")
	_check(shown and not debug.visible, "the debug key shows and hides it")

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


func _backdrop_signature(level: Node) -> Array:
	var signature := []
	for layer in level.get_node("Map/Backdrop").get_children():
		var cells: Array = layer.get_used_cells()
		cells.sort()
		signature.append(cells.size())
		signature.append(hash(cells))
	return signature


func _press(level: Node, action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	level._unhandled_input(event)


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
