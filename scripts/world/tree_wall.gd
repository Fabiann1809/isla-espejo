class_name TreeWall
extends RefCounted
## Walls drawn as rows of the forest art's trees (the rooms' borders, the corridors' sides), packed
## so their crowns touch. Purely visual: the walls keep their own collision.


## One tree standing on `foot`, fading while Nico is behind it (CanopyFade). It is y-sorted with
## the actors a little above its foot, like the rooms' own trees, so whoever stands at its foot is
## drawn in front of it.
static func tree(foot: Vector2, rng: RandomNumberGenerator) -> Node2D:
	var node := Node2D.new()
	node.position = foot - Vector2(0, RoomProp.SORT_ABOVE_BOTTOM)
	var picture := ForestArt.pick_path(ForestArt.WALL_TREES, rng)
	node.add_child(ForestArt.standing(picture, Vector2(0, RoomProp.SORT_ABOVE_BOTTOM)))
	if picture != null:
		GroundShadow.under(node, Vector2(0, RoomProp.SORT_ABOVE_BOTTOM - 3), picture.get_width())
	node.add_to_group(RoomProp.CANOPY_GROUP)
	return node


## A row of trees painted into one picture: for a row nobody ever walks behind (a room's top wall),
## so hundreds of trees cost one sprite. It sorts a little above its lowest foot, like that tree.
static func baked_row(feet: Array[Vector2], rng: RandomNumberGenerator) -> Node2D:
	var sorted := feet.duplicate()
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	var pictures: Array[Image] = []
	var bounds := Rect2()
	for i in sorted.size():
		var picture := ForestArt.image(ForestArt.WALL_TREES[rng.randi_range(0, ForestArt.WALL_TREES.size() - 1)])
		pictures.append(picture)
		var rect := Rect2(sorted[i] - Vector2(picture.get_width() / 2, picture.get_height()), picture.get_size())
		bounds = rect if i == 0 else bounds.merge(rect)
	var node := Node2D.new()
	if sorted.is_empty():
		return node
	var canvas := Image.create_empty(int(ceilf(bounds.size.x)), int(ceilf(bounds.size.y)), false, Image.FORMAT_RGBA8)
	for i in sorted.size():
		ForestArt.paint(canvas, pictures[i], sorted[i] - bounds.position)
	node.position = Vector2(0, bounds.end.y - RoomProp.SORT_ABOVE_BOTTOM)
	var sprite := ForestArt.baked(canvas)
	sprite.position = bounds.position - node.position
	node.add_child(sprite)
	return node


## Feet every `Tuning.WALL_TREE_STEP` px from `from` to `to`, each nudged a little.
static func feet_along(from: Vector2, to: Vector2, rng: RandomNumberGenerator) -> Array[Vector2]:
	var feet: Array[Vector2] = []
	var length := from.distance_to(to)
	var direction := (to - from).normalized()
	var travelled := Tuning.WALL_TREE_STEP / 2.0
	while travelled < length:
		var nudge := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * Tuning.WALL_TREE_JITTER
		feet.append((from + direction * travelled + nudge).round())
		travelled += Tuning.WALL_TREE_STEP
	return feet
