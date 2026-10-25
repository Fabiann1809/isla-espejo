class_name ForestBackdrop
extends RefCounted
## The deep forest around a generated map: dark grass and a thick wall of trees, bushes and rocks on
## every tile that is not a room or a corridor floor, so nothing black shows between rooms, in empty
## grid cells or around the corridors. Thicker next to the paths and darker the farther away.
## Purely decorative: tile layers with no collision, drawn below every floor. Same seed = same forest.

const DEEP_TREES: Array[Vector2i] = [TileArt.TREE_DARK, TileArt.PINE_DARK, TileArt.TREE_DARK, TileArt.PINE_DARK]
const UNDERGROWTH: Array[Vector2i] = [TileArt.BUSH_DARK, TileArt.BUSH_DARK, TileArt.BUSH_BERRIES, TileArt.ROCK, TileArt.ROCK_MOSSY, TileArt.STUMP]


## Builds the forest under `parent`. `walkable` holds the floor tiles (rooms and corridor floors) and
## `taken` the tiles already drawn by something else (corridor walls of trees); `area` is in tiles.
static func build(parent: Node, tile_set: TileSet, area: Rect2i, walkable: Dictionary,
		taken: Dictionary, map_seed: int) -> Node2D:
	var root := Node2D.new()
	root.name = "Backdrop"
	# Below the room floors (FLOOR_Z) and below the corridors.
	root.z_index = RoomTheme.FLOOR_Z - 1
	parent.add_child(root)
	parent.move_child(root, 0)

	var bands := Tuning.BACKDROP_BAND_TINTS.size()
	var grounds: Array[TileMapLayer] = []
	var canopies: Array[TileMapLayer] = []
	for band in bands:
		grounds.append(_layer(root, tile_set, "Ground%d" % band, Tuning.BACKDROP_BAND_TINTS[band]))
	for band in bands:
		canopies.append(_layer(root, tile_set, "Canopy%d" % band, Tuning.BACKDROP_BAND_TINTS[band]))

	var distance := _distances(area, walkable)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["backdrop", map_seed])
	# Every tile with a tree, bush or rock, on any band's layer (a crown reaches into the row above).
	var planted := {}
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			if walkable.has(cell):
				continue
			var band := _band(distance.get(cell, 999))
			grounds[band].set_cell(cell, 0, TileArt.GRASS_TEXTURED)
			if taken.has(cell) or planted.has(cell) or rng.randf() >= Tuning.BACKDROP_BAND_DENSITY[band]:
				continue
			_plant(canopies[band], cell, rng, walkable, taken, planted)
	return root


## One tree, bush or rock on `cell`. A tall tree also takes the tile above it for its crown.
static func _plant(layer: TileMapLayer, cell: Vector2i, rng: RandomNumberGenerator,
		walkable: Dictionary, taken: Dictionary, planted: Dictionary) -> void:
	var roll := rng.randf()
	var above := cell + Vector2i.UP
	var room_above := walkable.has(above) or taken.has(above) or planted.has(above)
	planted[cell] = true
	if roll < 0.22 and not room_above:
		var pine := rng.randf() < 0.5
		layer.set_cell(above, 0, TileArt.PINE_DARK_TALL_TOP if pine else TileArt.TREE_DARK_TALL_TOP)
		layer.set_cell(cell, 0, TileArt.PINE_DARK_TALL_BASE if pine else TileArt.TREE_DARK_TALL_BASE)
		planted[above] = true
	elif roll < 0.82:
		layer.set_cell(cell, 0, DEEP_TREES[rng.randi_range(0, DEEP_TREES.size() - 1)])
	else:
		layer.set_cell(cell, 0, UNDERGROWTH[rng.randi_range(0, UNDERGROWTH.size() - 1)])


static func _band(tiles_away: int) -> int:
	for band in Tuning.BACKDROP_BAND_LIMITS.size():
		if tiles_away <= Tuning.BACKDROP_BAND_LIMITS[band]:
			return band
	return Tuning.BACKDROP_BAND_LIMITS.size()


## Tiles to the nearest walkable tile (4-neighbour steps), for every tile of `area`.
static func _distances(area: Rect2i, walkable: Dictionary) -> Dictionary:
	var distance := {}
	var frontier: Array[Vector2i] = []
	for cell: Vector2i in walkable:
		distance[cell] = 0
		frontier.append(cell)
	var head := 0
	while head < frontier.size():
		var cell := frontier[head]
		head += 1
		var next_distance: int = distance[cell] + 1
		for step in MapLayout.DIRS:
			var next: Vector2i = cell + step
			if area.has_point(next) and not distance.has(next):
				distance[next] = next_distance
				frontier.append(next)
	return distance


static func _layer(parent: Node, tile_set: TileSet, layer_name: String, tint: Color) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# `modulate`, not `self_modulate`: a layer draws its tiles through child canvas items.
	layer.modulate = tint
	parent.add_child(layer)
	return layer
