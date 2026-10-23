class_name RoomTheme
extends Resource
## Visual theme of a scenario: which tiles dress the floor, the border and the paths.
## One `.tres` per scenario in `data/themes/`. Collision does not depend on the theme.

## Floors are drawn below every actor. Enemies are children of their own room, so without this a
## room built later would paint its floor over an enemy that wandered in from an earlier room.
const FLOOR_Z := -1

@export var tile_set: TileSet
@export var floor_tile := TileArt.GRASS
## Occasional floor variants (flowers) mixed into the floor.
@export var floor_variants: Array[Vector2i] = []
@export_range(0.0, 1.0) var floor_variant_chance := 0.04
## Small decorations drawn over the floor (tufts of grass).
@export var decor_tiles: Array[Vector2i] = []
@export_range(0.0, 1.0) var decor_chance := 0.05
## What the walls look like (a row of trees for a forest).
@export var border_tile := TileArt.PINE
## Doors and corridors.
@export var path_tile := TileArt.DIRT


## Adds an empty TileMapLayer that uses this theme's TileSet.
func new_layer(parent: Node, layer_name: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.z_index = FLOOR_Z
	layer.name = layer_name
	layer.tile_set = tile_set
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(layer)
	return layer


## Fills the cells of `cells` (in tiles) with one tile.
func fill(layer: TileMapLayer, cells: Rect2i, tile: Vector2i) -> void:
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			layer.set_cell(Vector2i(x, y), 0, tile)
