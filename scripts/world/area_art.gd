class_name AreaArt
extends RefCounted
## Areas drawn with the team's own autotile sheets (the water and the dirt, drawn by
## tools/make_water_art.py and tools/make_dirt_art.py): one 16 px tile per row, its animation frames
## along the row, transparent outside the area so the grass below shows through. Which tile a cell
## gets depends on which neighbours belong to the area, like TileArt.blob_tile.
##
## Rows: 0-8 the nine-slice in reading order (top-left, top, top-right, left, middle, right,
## bottom-left, bottom, bottom-right), 9-12 inner corners by the diagonal that is outside (SE, SW,
## NE, NW), 13-16 other looks of the top, left, right and bottom edges, 17-18 more middles.

const INNER_ROWS := [9, 10, 11, 12]
const EDGE_VARIANTS := {1: 13, 3: 14, 5: 15, 7: 16}
const MIDDLE_ROWS := [4, 17, 18]

static var _tile_sets := {}


static func exists(path: String) -> bool:
	return ResourceLoader.exists(path)


## The tiles of the sheet at `path`, each animated along its row (`frame_time` seconds per frame).
static func tile_set(path: String, frame_time := 0.0) -> TileSet:
	if not _tile_sets.has(path):
		var sheet: Texture2D = load(path)
		var source := TileSetAtlasSource.new()
		source.texture = sheet
		source.texture_region_size = Vector2i.ONE * TileArt.TILE
		var frames := sheet.get_width() / TileArt.TILE
		for row in sheet.get_height() / TileArt.TILE:
			var coords := Vector2i(0, row)
			source.create_tile(coords)
			if frames > 1:
				source.set_tile_animation_columns(coords, frames)
				source.set_tile_animation_frames_count(coords, frames)
				for frame in frames:
					source.set_tile_animation_frame_duration(coords, frame, frame_time)
		var tiles := TileSet.new()
		tiles.tile_size = Vector2i.ONE * TileArt.TILE
		tiles.add_source(source, 0)
		_tile_sets[path] = tiles
	return _tile_sets[path]


## An empty layer that paints with the sheet at `path`, with the floors.
static func new_layer(path: String, layer_name: String, frame_time := 0.0) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = tile_set(path, frame_time)
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return layer


## The row for `cell` of an area made of `cells` (a set: cell -> true): its edges and outer corners
## come from the nine-slice, a turn inwards from an inner corner, and straight edges and middles get
## one of their looks by the cell, so a long edge does not repeat one tile.
static func row(cells: Dictionary, cell: Vector2i) -> int:
	var column := 0 if not cells.has(cell + Vector2i.LEFT) else (2 if not cells.has(cell + Vector2i.RIGHT) else 1)
	var line := 0 if not cells.has(cell + Vector2i.UP) else (2 if not cells.has(cell + Vector2i.DOWN) else 1)
	var look := absi(hash(cell))
	if line != 1 or column != 1:
		var index := line * 3 + column
		if EDGE_VARIANTS.has(index) and look % 3 == 0:
			return EDGE_VARIANTS[index]
		return index
	var diagonals := [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	for i in diagonals.size():
		if not cells.has(cell + diagonals[i]):
			return INNER_ROWS[i]
	return MIDDLE_ROWS[look % MIDDLE_ROWS.size()]


## Paints every cell of `cells` that lies in `rect` into `layer`, whose cell (0, 0) is `rect`'s corner.
static func paint(layer: TileMapLayer, cells: Dictionary, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if cells.has(cell):
				layer.set_cell(cell - rect.position, 0, Vector2i(0, row(cells, cell)))
