class_name ForestBackdrop
extends RefCounted
## The deep forest around a generated map: the rooms' grass and a thick wood of the team's forest art
## (assets/art_forest/) on every tile that is not a room or a corridor, so nothing black shows
## between rooms, in empty grid cells or around the corridors. The trees are scattered (no grid)
## and packed close, and the ForestShade darkens this whole floor (see Level), so the forest reads
## as one dark wood around bright clearings.
## Purely decorative: no collision, drawn below every floor. Same seed = same forest.
## The trees are painted into a few big pictures (chunks): thousands of sprites would cost frames.


## Builds the forest under `parent`. `walkable` holds the floor tiles (rooms and corridor floors) and
## `taken` the corridor walls; no tree reaches over either (the backdrop is drawn below them, so the
## part over them would be cut off in a straight line). `area` is in tiles.
static func build(parent: Node, area: Rect2i, walkable: Dictionary,
		taken: Dictionary, map_seed: int) -> Node2D:
	var root := Node2D.new()
	root.name = "Backdrop"
	# Below the room floors (FLOOR_Z) and below the corridors.
	root.z_index = RoomTheme.FLOOR_Z - 1
	parent.add_child(root)
	parent.move_child(root, 0)

	var ground := TileMapLayer.new()
	ground.name = "Ground0"
	TileArt.prepare_layer(ground)
	root.add_child(ground)
	var grass := TileArt.coords(TileArt.GRASS)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if not walkable.has(Vector2i(x, y)):
				ground.set_cell(Vector2i(x, y), 0, grass)

	var trees := _plant(area, walkable, taken, map_seed)
	var rects: Array[Rect2] = []
	for tree in trees:
		rects.append(tree.rect)
	root.set_meta("tree_rects", rects)
	_bake(root, trees)
	return root


## Where every tree goes: {image, foot, rect}, sorted top to bottom so lower trees overlap. Where a
## tree does not fit (the narrow strips between rooms) a bush may.
static func _plant(area: Rect2i, walkable: Dictionary, taken: Dictionary, map_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["backdrop", map_seed])
	var trees := []
	var tile := float(TileArt.TILE)
	var step := Tuning.BACKDROP_TREE_STEP
	var y := area.position.y * tile
	while y < area.end.y * tile:
		var x := area.position.x * tile
		while x < area.end.x * tile:
			var foot := (Vector2(x, y) + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0))
					* Tuning.BACKDROP_TREE_JITTER).round()
			x += step
			if rng.randf() >= Tuning.BACKDROP_TREE_DENSITY:
				continue
			# Most spots fall inside a room: skip them before looking at any picture.
			var cell := Vector2i((foot / tile).floor())
			if walkable.has(cell) or taken.has(cell):
				continue
			var picture := ForestArt.image(ForestArt.FOREST_TREES[rng.randi_range(0, ForestArt.FOREST_TREES.size() - 1)])
			var rect := _rect_of(picture, foot)
			if _blocks_the_way(rect, walkable, taken):
				picture = ForestArt.image(ForestArt.BUSHES % ForestArt.SOLID_BUSHES[rng.randi_range(0, ForestArt.SOLID_BUSHES.size() - 1)])
				rect = _rect_of(picture, foot)
				if _blocks_the_way(rect, walkable, taken):
					continue
			trees.append({"image": picture, "foot": foot, "rect": rect})
		y += step
	trees.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.foot.y < b.foot.y)
	return trees


static func _rect_of(picture: Image, foot: Vector2) -> Rect2:
	if picture == null:
		return Rect2()
	return Rect2(foot - Vector2(picture.get_width() / 2, picture.get_height()), picture.get_size())


## True if a tree drawn on `rect` would reach a room, a corridor floor or a corridor wall.
static func _blocks_the_way(rect: Rect2, walkable: Dictionary, taken: Dictionary) -> bool:
	if rect.size == Vector2.ZERO:
		return true
	# Its transparent edge may overlap a little; small pictures keep at least their middle pixel.
	var shrink := minf(Tuning.BACKDROP_TREE_OVERLAP, minf(rect.size.x, rect.size.y) / 2.0 - 0.5)
	var inner := rect.grow(-maxf(shrink, 0.0))
	var first := Vector2i((inner.position / TileArt.TILE).floor())
	var last := Vector2i((inner.end / TileArt.TILE).floor())
	for cy in range(first.y, last.y + 1):
		for cx in range(first.x, last.x + 1):
			if walkable.has(Vector2i(cx, cy)) or taken.has(Vector2i(cx, cy)):
				return true
	return false


## Paints the trees into square chunks and adds one sprite per chunk that has any.
static func _bake(root: Node2D, trees: Array) -> void:
	var size := Tuning.BACKDROP_CHUNK
	var chunks := {}
	for tree in trees:
		var rect: Rect2 = tree.rect
		var first := Vector2i((rect.position / size).floor())
		var last := Vector2i((rect.end / size).floor())
		for cy in range(first.y, last.y + 1):
			for cx in range(first.x, last.x + 1):
				var key := Vector2i(cx, cy)
				if not chunks.has(key):
					chunks[key] = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
				ForestArt.paint(chunks[key], tree.image, tree.foot - Vector2(key * size))
	var keys := chunks.keys()
	keys.sort()
	for key: Vector2i in keys:
		var sprite := ForestArt.baked(chunks[key])
		sprite.name = "Trees_%d_%d" % [key.x + 1000, key.y + 1000]
		sprite.position = Vector2(key * size)
		root.add_child(sprite)
