extends SceneTree
## Draw order: nothing decorative may be painted over an actor (Nico, enemies, NPCs) that overlaps it,
## wherever the actor walks: inside its own room, inside a room built later (enemies are children
## of their own room) or in a corridor. Godot's 2D order is emulated (z index, then y-sort, then
## tree order) because headless runs cannot take screenshots.
## Run: godot --headless --path . --script res://tests/test_draw_order.gd

const SEEDS := [4242, 777, 31337, 9001, 12]

var _ok := true


func _initialize() -> void:
	create_timer(170.0).timeout.connect(func() -> void:
		printerr("TIMEOUT")
		quit(1))
	await process_frame
	var level = load("res://scenes/levels/forest_level.tscn").instantiate()
	level.use_director = false
	level.seed_value = SEEDS[0]
	root.add_child(level)
	await _frames(2)

	var covered_total := 0
	var probes_total := 0
	for map_seed in SEEDS:
		level.generate(map_seed)
		await _frames(2)
		var result := _probe_map(level)
		covered_total += result.covered
		probes_total += result.probes
	_check(probes_total > 0 and covered_total == 0,
			"%d maps: no decoration is drawn over an actor that walks over it (%d of %d spots covered)"
			% [SEEDS.size(), covered_total, probes_total])

	# Ground-like props (ponds, bridges, dirt, tufts) are part of the floor.
	var flat_low := true
	for prop in level.get_node("Map").find_children("*", "Node2D", true, false):
		if prop.get_script() != null and prop.has_method("is_flat") and prop.is_flat():
			flat_low = flat_low and prop.z_index < 0
	_check(flat_low, "flat props (ponds, bridges, dirt, tufts) are drawn with the floor")
	print("RESULT: ", "OK" if _ok else "FAILED")
	quit(0 if _ok else 1)


## Moves one enemy of the first room and one of the last, and Nico, over every prop and corridor
## of the map and counts the spots where a decoration would hide them.
func _probe_map(level: Node) -> Dictionary:
	var map: Node = level.get_node("Map")
	var decorations := _decorations(map)
	var actors: Array = []
	var enemies := get_nodes_in_group("enemies").filter(func(e: Node) -> bool: return map.is_ancestor_of(e))
	if not enemies.is_empty():
		actors.append(enemies.front())
		actors.append(enemies.back())
	actors.append(level.player)
	var spots: Array[Vector2] = []
	for item in decorations:
		var rect := _rect_of(item)
		spots.append(rect.get_center())
		# Just in front of (below) an upright prop.
		spots.append(Vector2(rect.get_center().x, _base_y(item) + 4.0))
	for corridor_layer in map.get_node("Corridors").get_children():
		if corridor_layer is TileMapLayer:
			for cell in corridor_layer.get_used_cells():
				spots.append(corridor_layer.to_global(corridor_layer.map_to_local(cell)))
	var covered := 0
	var probes := 0
	for actor in actors:
		var home: Vector2 = actor.global_position
		for spot in spots:
			actor.global_position = spot
			probes += 1
			var visual := _visual_of(actor)
			var actor_rect := _rect_of(visual)
			for item in decorations:
				var item_rect := _rect_of(item)
				# Behind an upright prop (above its base) the actor may be hidden; never in front of it
				# and never under the ground.
				var in_front: bool = _is_flat(item) or actor.global_position.y >= _base_y(item)
				if in_front and item_rect.intersects(actor_rect) and _draws_above(item, visual):
					covered += 1
					if covered <= 5:
						printerr("%s at %s is covered by %s" % [actor.name, spot, item.get_path()])
					break
		actor.global_position = home
	return {"covered": covered, "probes": probes}


## Every drawn scenery piece: sprites and tiles of props, and every tile layer.
func _decorations(map: Node) -> Array:
	var items: Array = []
	for node in map.find_children("*", "CanvasItem", true, false):
		if node is Sprite2D or node is TileMapLayer:
			if not _belongs_to_actor(node):
				items.append(node)
	return items


## Bottom of what `item` belongs to: a whole prop (a tall tree is two sprites) or the item itself.
func _base_y(item: CanvasItem) -> float:
	var bottom := _rect_of(item).end.y
	var prop := item.get_parent()
	if prop != null and prop.has_method("is_flat"):
		for sibling in prop.get_children():
			if sibling is Sprite2D:
				bottom = maxf(bottom, _rect_of(sibling).end.y)
	return bottom


func _is_flat(item: Node) -> bool:
	if item is TileMapLayer:
		return true
	var prop := item.get_parent()
	return prop != null and prop.has_method("is_flat") and prop.is_flat()


func _belongs_to_actor(node: Node) -> bool:
	var current := node
	while current != null:
		if current.is_in_group("enemies") or current.is_in_group("npcs") or current.is_in_group("player"):
			return true
		current = current.get_parent()
	return false


func _visual_of(actor: Node) -> CanvasItem:
	for child in actor.get_children():
		if child is AnimatedSprite2D and child.visible:
			return child
	return actor


func _rect_of(item: CanvasItem) -> Rect2:
	if item is TileMapLayer:
		var used: Rect2i = item.get_used_rect()
		var size: Vector2 = Vector2(item.tile_set.tile_size)
		return Rect2(item.to_global(Vector2(used.position) * size), Vector2(used.size) * size)
	if item is Sprite2D and item.texture != null:
		var size: Vector2 = item.texture.get_size() * item.global_scale.abs()
		var top_left: Vector2 = item.global_position - (size / 2.0 if item.centered else Vector2.ZERO) + item.offset
		return Rect2(top_left, size)
	if item is AnimatedSprite2D:
		var frame: Texture2D = item.sprite_frames.get_frame_texture(item.animation, item.frame)
		var size: Vector2 = frame.get_size() * item.global_scale.abs() if frame != null else Vector2(16, 16)
		return Rect2(item.global_position - size / 2.0 + item.offset, size)
	return Rect2((item as Node2D).global_position - Vector2(7, 7), Vector2(14, 14))


## True if `a` is drawn after (over) `b`.
func _draws_above(a: CanvasItem, b: CanvasItem) -> bool:
	var za := _effective_z(a)
	var zb := _effective_z(b)
	if za != zb:
		return za > zb
	var ka := _order_key(a)
	var kb := _order_key(b)
	for i in mini(ka.size(), kb.size()):
		if ka[i] != kb[i]:
			return ka[i] > kb[i]
	return ka.size() > kb.size()


func _effective_z(item: CanvasItem) -> int:
	var z := 0
	var current: Node = item
	while current is CanvasItem:
		z += current.z_index
		if not current.z_as_relative:
			break
		current = current.get_parent()
	return z


## Position of `item` in the draw list: sibling indices from the root, except under a y-sorted parent,
## where a child is placed by its y (y-sorted children of a y-sorted node are merged into its list).
func _order_key(item: Node) -> Array:
	var path: Array[Node] = []
	var current := item
	while current != null:
		path.push_front(current)
		current = current.get_parent()
	var key: Array = []
	var i := 1
	while i < path.size():
		var parent := path[i - 1]
		if parent is CanvasItem and parent.y_sort_enabled:
			var unit := i
			while unit < path.size() - 1 and path[unit] is CanvasItem and path[unit].y_sort_enabled:
				unit += 1
			key.append(snappedf((path[unit] as Node2D).global_position.y, 0.001))
			key.append(_preorder(path[unit]))
			i = unit + 1
		else:
			key.append(-1e12)
			key.append(path[i].get_index())
			i += 1
	return key


func _preorder(node: Node) -> float:
	var index := 0.0
	var current := node
	while current.get_parent() != null:
		index = index / 1000.0 + current.get_index()
		current = current.get_parent()
	return index


func _check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		_ok = false


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
