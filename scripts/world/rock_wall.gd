class_name RockWall
extends RefCounted
## Walls drawn as clusters of rock columns (the rooms' borders and the corridors' sides in the
## Ruinas), packed and staggered so they read as one mass of cliff. Purely visual: the walls keep
## their own collision. It mirrors TreeWall, with the columns of the active tileset profile.

## Names of the column tiles in the ruins profile: `<name>_top` and `<name>_base` (32 px tall), and
## the taller ones with a `<name>_mid` (48 px).
const COLUMNS: Array[StringName] = [&"column_rock_a", &"column_rock_b", &"column_rock_c", &"column_rock_d"]
const TALL_COLUMNS: Array[StringName] = [&"column_tall_a", &"column_tall_b"]
## Now and then a column of another width or state, so the walls have no rhythm.
const THIN_COLUMNS: Array[StringName] = [&"column_thin_a", &"column_thin_b"]
const FAT_COLUMNS: Array[StringName] = [&"column_fat_a"]
const BROKEN_COLUMNS: Array[StringName] = [&"column_broken_a", &"column_broken_b"]
## The temple's own pieces: square-capitalled pillars, snapped pillars, brick panels, heaps of blocks.
const TEMPLE_COLUMNS: Array[StringName] = [&"column_temple_a", &"column_temple_b"]
const RUIN_COLUMNS: Array[StringName] = [&"column_ruin_a", &"column_ruin_b"]
const PANEL_COLUMNS: Array[StringName] = [&"column_wall_a", &"column_wall_b"]
const STACK_COLUMNS: Array[StringName] = [&"column_stack_a", &"column_stack_b"]

## Column name -> its painted picture, per profile (a column is two or three tiles put together).
static var _images := {}


## The picture of a column: its tiles stacked, top to base.
static func image(column: StringName) -> Image:
	var profile := TileArt.profile()
	var key := "%s/%s" % [profile.resource_path, column]
	if not _images.has(key):
		var parts: Array[StringName] = [&"top", &"base"]
		if TALL_COLUMNS.has(column):
			parts = [&"top", &"mid", &"base"]
		var size := profile.tile_size
		var source := profile.texture.get_image()
		if source.is_compressed():
			source.decompress()
		source.convert(Image.FORMAT_RGBA8)
		var picture := Image.create_empty(size, size * parts.size(), false, Image.FORMAT_RGBA8)
		for i in parts.size():
			var tile := profile.coords(StringName("%s_%s" % [column, parts[i]]))
			picture.blit_rect(source, Rect2i(Vector2i(profile.region(tile).position), Vector2i(size, size)), Vector2i(0, i * size))
		_images[key] = picture
	return _images[key]


static func pick(rng: RandomNumberGenerator) -> StringName:
	var roll := rng.randf()
	if TileArt.profile().tiles.has(&"column_temple_a_top"):
		var table: Array = [
			[Tuning.ROCK_WALL_BROKEN_CHANCE, BROKEN_COLUMNS + RUIN_COLUMNS],
			[Tuning.ROCK_WALL_THIN_CHANCE, THIN_COLUMNS],
			[Tuning.ROCK_WALL_FAT_CHANCE, FAT_COLUMNS],
			[Tuning.ROCK_WALL_TEMPLE_CHANCE, TEMPLE_COLUMNS],
			[Tuning.ROCK_WALL_PANEL_CHANCE, PANEL_COLUMNS],
			[Tuning.ROCK_WALL_STACK_CHANCE, STACK_COLUMNS],
		]
		for entry in table:
			var names: Array = entry[1]
			if roll < entry[0]:
				return names[rng.randi_range(0, names.size() - 1)]
			roll -= entry[0]
	if rng.randf() < Tuning.ROCK_WALL_TALL_CHANCE:
		return TALL_COLUMNS[rng.randi_range(0, TALL_COLUMNS.size() - 1)]
	return COLUMNS[rng.randi_range(0, COLUMNS.size() - 1)]


## One column standing on `foot`, fading while Nico is behind it (CanopyFade). It is y-sorted with the
## actors a little above its foot, like the rooms' own props.
static func column(foot: Vector2, rng: RandomNumberGenerator) -> Node2D:
	var picture := image(pick(rng))
	var node := Node2D.new()
	node.position = foot - Vector2(0, RoomProp.SORT_ABOVE_BOTTOM)
	var sprite := ForestArt.baked(picture)
	sprite.position = Vector2(-picture.get_width() / 2.0, -picture.get_height() + RoomProp.SORT_ABOVE_BOTTOM)
	node.add_child(sprite)
	node.add_to_group(RoomProp.CANOPY_GROUP)
	return node


## A row of columns painted into one picture, for a row nobody walks behind (a room's top wall).
static func baked_row(feet: Array[Vector2], rng: RandomNumberGenerator) -> Node2D:
	var sorted := feet.duplicate()
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y < b.y)
	var pictures: Array[Image] = []
	var bounds := Rect2()
	for i in sorted.size():
		var picture := image(pick(rng))
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


## Feet along a line, never at an even distance: each step is a different length, now and then a gap is left,
## and the line sways across itself (a wave of the world position, so neighbouring cells agree), so the wall
## has bays and small salients and no rhythm.
static func feet_along(from: Vector2, to: Vector2, rng: RandomNumberGenerator) -> Array[Vector2]:
	var feet: Array[Vector2] = []
	var length := from.distance_to(to)
	var direction := (to - from).normalized()
	var across := Vector2(-direction.y, direction.x)
	var travelled := Tuning.ROCK_WALL_STEP * rng.randf_range(0.2, 0.7)
	while travelled < length:
		var at := from + direction * travelled
		var wave := sin(at.x * 0.09 + at.y * 0.05) * Tuning.ROCK_WALL_WAVE + sin(at.y * 0.13 - at.x * 0.04) * Tuning.ROCK_WALL_WAVE * 0.6
		var nudge := Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * Tuning.ROCK_WALL_JITTER
		feet.append((at + across * wave + nudge).round())
		travelled += Tuning.ROCK_WALL_STEP * rng.randf_range(Tuning.ROCK_WALL_STEP_MIN, Tuning.ROCK_WALL_STEP_MAX)
		if rng.randf() < Tuning.ROCK_WALL_GAP_CHANCE:
			travelled += Tuning.ROCK_WALL_STEP
	return feet


## A chunk of fallen rock at the foot of a wall (no collision), so the cliff juts out here and there.
static func chunk(foot: Vector2, rng: RandomNumberGenerator) -> Node2D:
	var node := Node2D.new()
	node.position = foot - Vector2(0, RoomProp.SORT_ABOVE_BOTTOM)
	var sprite := TileArt.sprite([&"rubble_a", &"rubble_b", &"boulder_small", &"boulder_small_moss", &"boulder_b"][rng.randi_range(0, 4)])
	sprite.position = Vector2(-8, -15 + RoomProp.SORT_ABOVE_BOTTOM)
	node.add_child(sprite)
	return node
