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
## Draws the floor's tufts, pebbles and stumps with the forest art set (assets/art_forest/) instead
## of the tileset's tiles (Room swaps them once the floor is painted).
@export var forest_art_details := false


## A light tint over the whole world while this theme is played, and whether the quiet life (fireflies
## and falling leaves of the forest) drifts around the camera.
@export var world_tint := Tuning.WORLD_TINT
@export var ambient_life := true
## How far the camera leads Nico in this scenario (px): -1 keeps Tuning.CAMERA_LOOK_AHEAD, 0 turns it
## off (the temple, where the lead made the picture tremble).
@export var camera_look_ahead := -1.0
enum WallStyle { TREES, ROCKS, LAVA }
## How the walls of rooms and corridors are drawn and what fills the space around the map: rows of
## trees over a forest, clusters of rock columns over solid rock (the Ruinas), or no wall art at all
## because the room is an island whose edge drops into a sea of lava (the Templo).
@export var wall_style := WallStyle.TREES


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
