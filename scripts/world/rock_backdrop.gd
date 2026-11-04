class_name RockBackdrop
extends RefCounted
## The rock around a generated map of the Ruinas: a dark mass on every tile that is not a room or a
## corridor, with formations standing on it so the space between rooms and around the corridors is a
## cave and not a flat wall of cobbles. Which formation goes where depends on how far the spot is from
## the nearest floor: low rubble, stalagmites and broken pillars close to the way, pillars, wall panels
## and small crags farther in, big crags and tall columns deep inside, each ring a little darker than
## the one before; a low-frequency noise leaves open pockets and dense stands, so there is no grid and
## no even carpet. Purely decorative (no collision), painted into a few big pictures (chunks), drawn
## below every floor. Same seed = same rock.

## Crags: name -> columns x rows of tiles (the tiles are `<name>_<row><column>` in the ruins profile).
const CRAGS := {
	&"crag_a": Vector2i(2, 2), &"crag_b": Vector2i(3, 3), &"crag_c": Vector2i(3, 2),
	&"crag_d": Vector2i(4, 3), &"crag_e": Vector2i(2, 2),
}
const NEAR_CRAGS: Array[StringName] = [&"crag_a", &"crag_e"]
const MID_CRAGS: Array[StringName] = [&"crag_c", &"crag_b", &"crag_a"]
const FAR_CRAGS: Array[StringName] = [&"crag_d", &"crag_b", &"crag_c", &"crag_d"]
## One-tile pieces for the edge of the way.
const LOW_PIECES: Array[StringName] = [
	&"stalagmite_a", &"stalagmite_b", &"boulder_a", &"boulder_b", &"boulder_small", &"boulder_small_moss",
	&"rubble_a", &"rubble_b",
]
## Pieces made of two tiles (top and base) like the wall's columns.
const LOW_STACKS: Array[StringName] = [
	&"column_broken_a", &"column_broken_b", &"column_ruin_a", &"column_ruin_b", &"column_stack_a", &"column_stack_b",
]

## Name -> its painted picture (per profile), and darkened copies of them.
static var _images := {}
static var _shaded := {}


## Builds the rock under `parent`. `walkable` holds the floor tiles, `taken` the corridor walls and `area` is
## in tiles; no formation reaches over a floor or a wall (the backdrop is drawn below them).
static func build(parent: Node, area: Rect2i, walkable: Dictionary, taken: Dictionary, map_seed: int) -> Node2D:
	var root := Node2D.new()
	root.name = "Backdrop"
	root.z_index = RoomTheme.FLOOR_Z - 1
	parent.add_child(root)
	parent.move_child(root, 0)
	var layer := TileMapLayer.new()
	layer.name = "Rock"
	TileArt.prepare_layer(layer)
	root.add_child(layer)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["rock_backdrop", map_seed])
	# The ground underneath: almost black cave rock with faint cracks (the formations give it its texture).
	var tiles: Array[Vector2i] = [TileArt.coords(&"void_a"), TileArt.coords(&"void_b"), TileArt.coords(&"void_a"),
			TileArt.coords(&"void_b"), TileArt.coords(&"void_a"), TileArt.coords(&"rock_mass_dark")]
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if not walkable.has(Vector2i(x, y)):
				layer.set_cell(Vector2i(x, y), 0, tiles[rng.randi_range(0, tiles.size() - 1)])
	if Tuning.RUIN_BACKDROP_FORMATIONS:
		_bake(root, _plant(area, walkable, taken, map_seed, rng))
	return root


## Tiles from the nearest floor or corridor wall (breadth first, up to `Tuning.RUIN_BACKDROP_DEPTH`).
static func _depths(area: Rect2i, walkable: Dictionary, taken: Dictionary) -> Dictionary:
	var depth := {}
	var frontier: Array[Vector2i] = []
	for source: Dictionary in [walkable, taken]:
		for cell: Vector2i in source:
			if area.has_point(cell) and not depth.has(cell):
				depth[cell] = 0
				frontier.append(cell)
	var index := 0
	while index < frontier.size():
		var cell := frontier[index]
		index += 1
		if depth[cell] >= Tuning.RUIN_BACKDROP_DEPTH:
			continue
		for step in MapLayout.DIRS:
			var next: Vector2i = cell + step
			if area.has_point(next) and not depth.has(next):
				depth[next] = depth[cell] + 1
				frontier.append(next)
	return depth


## Every formation: {image, foot, rect}, sorted top to bottom so lower ones overlap.
static func _plant(area: Rect2i, walkable: Dictionary, taken: Dictionary, map_seed: int, rng: RandomNumberGenerator) -> Array:
	var depth := _depths(area, walkable, taken)
	var density := FastNoiseLite.new()
	density.seed = map_seed
	density.frequency = Tuning.RUIN_BACKDROP_NOISE_FREQUENCY
	var tile := float(TileArt.TILE)
	var step := Tuning.RUIN_BACKDROP_STEP
	var found := []
	var y := area.position.y * tile
	while y < area.end.y * tile:
		var x := area.position.x * tile
		while x < area.end.x * tile:
			var foot := (Vector2(x, y) + Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * Tuning.RUIN_BACKDROP_JITTER).round()
			x += step
			var cell := Vector2i((foot / tile).floor())
			if walkable.has(cell) or taken.has(cell):
				continue
			var d: int = depth.get(cell, Tuning.RUIN_BACKDROP_DEPTH + 1)
			if d < Tuning.RUIN_BACKDROP_CLEAR_TILES:
				continue
			var chance := clampf(Tuning.RUIN_BACKDROP_DENSITY + density.get_noise_2d(foot.x / tile, foot.y / tile) * Tuning.RUIN_BACKDROP_CONTRAST, 0.0, 1.0)
			if d < Tuning.RUIN_BACKDROP_NEAR_TILES:
				chance = maxf(chance, Tuning.RUIN_BACKDROP_NEAR_DENSITY)
			if rng.randf() >= chance:
				continue
			var picture := _image(_choose(d, rng), _ring(d))
			var rect := _rect_of(picture, foot)
			if picture == null or _blocks_the_way(rect, walkable, taken):
				continue
			found.append({"image": picture, "foot": foot, "rect": rect})
		y += step
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.foot.y < b.foot.y)
	return found


## 0 near the way, 1 in the middle, 2 deep inside: how much the formation is darkened.
static func _ring(d: int) -> int:
	if d < Tuning.RUIN_BACKDROP_NEAR_TILES:
		return 0
	return 1 if d < Tuning.RUIN_BACKDROP_FAR_TILES else 2


## The name of the formation for a spot `d` tiles from the way.
static func _choose(d: int, rng: RandomNumberGenerator) -> StringName:
	var roll := rng.randf()
	if d < Tuning.RUIN_BACKDROP_NEAR_TILES:
		# The narrow gaps between neighbouring rooms are all "near": mostly pillars and fallen pieces, so they
		# read as cliff between two caves and not as a dark trench.
		if roll < 0.22:
			return LOW_PIECES[rng.randi_range(0, LOW_PIECES.size() - 1)]
		if roll < 0.42:
			return LOW_STACKS[rng.randi_range(0, LOW_STACKS.size() - 1)]
		if roll < 0.78:
			return RockWall.pick(rng)
		return NEAR_CRAGS[rng.randi_range(0, NEAR_CRAGS.size() - 1)]
	if d < Tuning.RUIN_BACKDROP_FAR_TILES:
		if roll < 0.55:
			return RockWall.pick(rng)
		return MID_CRAGS[rng.randi_range(0, MID_CRAGS.size() - 1)]
	if roll < 0.2:
		return RockWall.TALL_COLUMNS[rng.randi_range(0, RockWall.TALL_COLUMNS.size() - 1)]
	return FAR_CRAGS[rng.randi_range(0, FAR_CRAGS.size() - 1)]


# --- pictures ------------------------------------------------------------------------------------------------------
## The picture of a formation darkened for `ring` (0 = as is).
static func _image(formation: StringName, ring: int) -> Image:
	var key := "%s/%s/%d" % [TileArt.profile().resource_path, formation, ring]
	if _shaded.has(key):
		return _shaded[key]
	var picture := _picture(formation)
	if picture != null and ring > 0:
		picture = picture.duplicate()
		var factor := 1.0 - Tuning.RUIN_BACKDROP_DARKEN * ring
		for py in picture.get_height():
			for px in picture.get_width():
				var c := picture.get_pixel(px, py)
				if c.a > 0.0:
					picture.set_pixel(px, py, Color(c.r * factor, c.g * factor, c.b * factor * 1.02, c.a))
	_shaded[key] = picture
	return picture


static func _picture(formation: StringName) -> Image:
	var key := "%s/%s" % [TileArt.profile().resource_path, formation]
	if _images.has(key):
		return _images[key]
	var picture: Image = null
	if CRAGS.has(formation):
		var cells: Vector2i = CRAGS[formation]
		picture = _blank(cells.x, cells.y)
		for row in cells.y:
			for column in cells.x:
				_blit(picture, StringName("%s_%d%d" % [formation, row, column]), Vector2i(column, row))
	elif TileArt.profile().tiles.has(StringName("%s_top" % formation)):
		picture = RockWall.image(formation)
	elif TileArt.profile().tiles.has(formation):
		picture = _blank(1, 1)
		_blit(picture, formation, Vector2i.ZERO)
	_images[key] = picture
	return picture


static func _blank(columns: int, rows: int) -> Image:
	var size := TileArt.profile().tile_size
	return Image.create_empty(size * columns, size * rows, false, Image.FORMAT_RGBA8)


static func _blit(picture: Image, tile_name: StringName, at: Vector2i) -> void:
	var profile := TileArt.profile()
	var source := profile.texture.get_image()
	if source.is_compressed():
		source.decompress()
	source.convert(Image.FORMAT_RGBA8)
	var size := profile.tile_size
	var region := Rect2i(Vector2i(profile.region(profile.coords(tile_name)).position), Vector2i(size, size))
	picture.blit_rect(source, region, at * size)


static func _rect_of(picture: Image, foot: Vector2) -> Rect2:
	if picture == null:
		return Rect2()
	return Rect2(foot - Vector2(picture.get_width() / 2, picture.get_height()), picture.get_size())


## True if a formation drawn on `rect` would reach a floor or a corridor wall (its transparent edge may overlap a little).
static func _blocks_the_way(rect: Rect2, walkable: Dictionary, taken: Dictionary) -> bool:
	if rect.size == Vector2.ZERO:
		return true
	var shrink := minf(Tuning.RUIN_BACKDROP_OVERLAP, minf(rect.size.x, rect.size.y) / 2.0 - 0.5)
	var inner := rect.grow(-maxf(shrink, 0.0))
	var first := Vector2i((inner.position / TileArt.TILE).floor())
	var last := Vector2i((inner.end / TileArt.TILE).floor())
	for cy in range(first.y, last.y + 1):
		for cx in range(first.x, last.x + 1):
			if walkable.has(Vector2i(cx, cy)) or taken.has(Vector2i(cx, cy)):
				return true
	return false


## Paints the formations into square chunks and adds one sprite per chunk that has any.
static func _bake(root: Node2D, found: Array) -> void:
	var size := Tuning.BACKDROP_CHUNK
	var chunks := {}
	for item in found:
		var rect: Rect2 = item.rect
		var first := Vector2i((rect.position / size).floor())
		var last := Vector2i((rect.end / size).floor())
		for cy in range(first.y, last.y + 1):
			for cx in range(first.x, last.x + 1):
				var key := Vector2i(cx, cy)
				if not chunks.has(key):
					chunks[key] = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
				ForestArt.paint(chunks[key], item.image, item.foot - Vector2(key * size))
	var keys := chunks.keys()
	keys.sort()
	for key: Vector2i in keys:
		var sprite := ForestArt.baked(chunks[key])
		sprite.name = "Rocks_%d_%d" % [key.x + 1000, key.y + 1000]
		sprite.position = Vector2(key * size)
		root.add_child(sprite)
