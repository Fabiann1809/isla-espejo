class_name RoomTheme
extends Resource
## Visual theme of a scenario: which tile roles dress the floor, the border and the paths, and the
## tileset profile (the pack) that draws them. One `.tres` per scenario in `data/themes/`.
## Collision does not depend on the theme.

## Floors are drawn below every actor. Enemies are children of their own room, so without this a
## room built later would paint its floor over an enemy that wandered in from an earlier room.
const FLOOR_Z := -2
## Things lying on the ground (warning circles, skill areas, roots): over every floor, flat prop
## and neighbouring room, and under every actor.
const GROUND_FX_Z := -1

## The pack that draws the theme (null = TileArt.DEFAULT_PROFILE).
@export var tileset: TilesetProfile
@export var floor_tile := TileArt.GRASS
## Occasional floor variants (flowers) mixed into the floor.
@export var floor_variants: Array[StringName] = []
@export_range(0.0, 1.0) var floor_variant_chance := 0.04
## Small decorations drawn over the floor (tufts of grass).
@export var decor_tiles: Array[StringName] = []
@export_range(0.0, 1.0) var decor_chance := 0.05
## What the walls look like (a row of trees for a forest).
@export var border_tile := TileArt.PINE
## Doors and corridors.
@export var path_tile := TileArt.DIRT


## Makes this theme's pack the one TileArt draws with (Level does it before building a map).
func activate() -> void:
	TileArt.use_profile(tileset)


## Adds an empty TileMapLayer that paints with the active tileset profile.
func new_layer(parent: Node, layer_name: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.z_index = FLOOR_Z
	layer.name = layer_name
	TileArt.prepare_layer(layer)
	parent.add_child(layer)
	return layer


## Fills the cells of `cells` (in tiles) with the tile of one role.
func fill(layer: TileMapLayer, cells: Rect2i, role: StringName) -> void:
	var tile := TileArt.coords(role)
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			layer.set_cell(Vector2i(x, y), 0, tile)
