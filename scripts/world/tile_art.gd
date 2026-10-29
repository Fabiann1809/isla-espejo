class_name TileArt
extends RefCounted
## The tiles the game draws, by ROLE. Every constant below is a role name; the active
## `TilesetProfile` says which tile of its sheet plays it (the default profile is the Kenney
## Roguelike/RPG sheet, CC0, see CREDITS.md). Never use sheet coordinates outside a profile: ask for
## a role (`sprite()`, `tile()`, `coords()`, `pattern()`) and add a role here when a new one is needed.
## How to dress the game with another pack: docs/GUIA_TILESET.md.

## The logical grid of the world, in pixels: rooms, props, corridors and collision are laid out in
## cells of this size, whatever the tile size of the pack (see Tuning.TILESET_FIT_TO_GRID).
const TILE := 16
const DEFAULT_PROFILE := "res://data/tilesets/kenney_forest.tres"

# Ground
const GRASS := &"grass"
const DIRT := &"dirt"
const FLOWERS_RED := &"flowers_red"
const FLOWERS_WHITE := &"flowers_white"
const FLOWERS_BLUE := &"flowers_blue"
const TUFT_A := &"tuft_a"
const TUFT_B := &"tuft_b"
## Wooden planks: the bridge over a pond.
const PLANKS := &"planks"
## A slightly darker, textured grass (center of a grass patch, and the deep forest floor).
const GRASS_TEXTURED := &"grass_textured"
## Small ground details, drawn over grass (no collision).
const PEBBLES := &"pebbles"
const ROCK_SMALL := &"rock_small"
const ROCK_MOSSY := &"rock_mossy"
const STUMP := &"stump"
const MUSHROOM_BROWN := &"mushroom_brown"
const MUSHROOM_ORANGE := &"mushroom_orange"
const MUSHROOM_RED := &"mushroom_red"
const MUSHROOM_PALE := &"mushroom_pale"
const FLOWER_PURPLE := &"flower_purple"
const FLOWER_YELLOW := &"flower_yellow"

# Props: a tall tree is two tiles (top, then trunk)
const PINE := &"pine"
const PINE_TALL_TOP := &"pine_tall_top"
const PINE_TALL_BASE := &"pine_tall_base"
const ROUND_TREE := &"round_tree"
const ROUND_TREE_TALL_TOP := &"round_tree_tall_top"
const ROUND_TREE_TALL_BASE := &"round_tree_tall_base"
const BUSH := &"bush"
## The dark green trees and bushes of the deep forest around the map.
const TREE_DARK := &"tree_dark"
const TREE_DARK_TALL_TOP := &"tree_dark_tall_top"
const TREE_DARK_TALL_BASE := &"tree_dark_tall_base"
const PINE_DARK := &"pine_dark"
const PINE_DARK_TALL_TOP := &"pine_dark_tall_top"
const PINE_DARK_TALL_BASE := &"pine_dark_tall_base"
const BUSH_DARK := &"bush_dark"
const BUSH_BERRIES := &"bush_berries"
const ROCK := &"rock"
const BUSH_ORANGE := &"bush_orange"
const CAMPFIRE := &"campfire"
const LOGS := &"logs"
const CHEST_CLOSED := &"chest_closed"
const CHEST_OPEN := &"chest_open"
## A standing torch, in two flame frames (they alternate to flicker).
const TORCH_A := &"torch_a"
const TORCH_B := &"torch_b"
## A wooden signpost.
const SIGN := &"sign"

# Areas (patterns): nine-slice, row by row (top-left, top, top-right, left, center, right,
# bottom-left, bottom, bottom-right), and inner corners (SE, SW, NE, NW)
## Water with a shore, drawn on grass.
const POND := &"pond"
## A patch of darker, textured grass with rounded edges, drawn over grass.
const GRASS_PATCH := &"grass_patch"
## Inner corners of the grass patch, by the diagonal that is NOT patch.
const GRASS_PATCH_INNER := &"grass_patch_inner"
## A round patch of bare earth on grass; also the rounded edges of the dirt paths.
const DIRT_PATCH := &"dirt_patch"
## Inner corners of the dirt patch (where two paths meet), by the diagonal that is grass.
const DIRT_PATCH_INNER := &"dirt_patch_inner"
## A patch of grey flagstones on grass (the base of the exit portal).
const STONE_FLOOR := &"stone_floor"

## Every single-tile role a profile must provide.
const ROLES: Array[StringName] = [
	GRASS, DIRT, FLOWERS_RED, FLOWERS_WHITE, FLOWERS_BLUE, TUFT_A, TUFT_B, PLANKS, GRASS_TEXTURED,
	PEBBLES, ROCK_SMALL, ROCK_MOSSY, STUMP, MUSHROOM_BROWN, MUSHROOM_ORANGE, MUSHROOM_RED,
	MUSHROOM_PALE, FLOWER_PURPLE, FLOWER_YELLOW,
	PINE, PINE_TALL_TOP, PINE_TALL_BASE, ROUND_TREE, ROUND_TREE_TALL_TOP, ROUND_TREE_TALL_BASE, BUSH,
	TREE_DARK, TREE_DARK_TALL_TOP, TREE_DARK_TALL_BASE, PINE_DARK, PINE_DARK_TALL_TOP,
	PINE_DARK_TALL_BASE, BUSH_DARK, BUSH_BERRIES, ROCK, BUSH_ORANGE, CAMPFIRE, LOGS,
	CHEST_CLOSED, CHEST_OPEN, TORCH_A, TORCH_B, SIGN,
]
## Every pattern role a profile must provide, with its number of tiles.
const PATTERNS := {POND: 9, GRASS_PATCH: 9, GRASS_PATCH_INNER: 4, DIRT_PATCH: 9, DIRT_PATCH_INNER: 4, STONE_FLOOR: 9}

static var _profile: TilesetProfile
## Tuning.TILESET_FIT_TO_GRID, kept here so tests can try both ways.
static var fit_to_grid := Tuning.TILESET_FIT_TO_GRID


## The profile in use (the default one until a scenario's theme picks another).
static func profile() -> TilesetProfile:
	if _profile == null:
		_profile = load(DEFAULT_PROFILE)
	return _profile


## Dresses what is built next with `new_profile` (null = the default profile).
static func use_profile(new_profile: TilesetProfile) -> void:
	_profile = new_profile if new_profile != null else load(DEFAULT_PROFILE)


## Sheet coordinates of a role's tile in the active profile (for TileMapLayer.set_cell).
static func coords(role: StringName) -> Vector2i:
	return profile().coords(role)


## Sheet coordinates of a pattern role's tiles.
static func pattern(role: StringName) -> Array[Vector2i]:
	return profile().pattern(role)


static func tile_set() -> TileSet:
	return profile().tile_set()


## How much a tile is scaled to fill one grid cell: 1 unless the pack's tiles are another size and
## Tuning.TILESET_FIT_TO_GRID is on.
static func draw_scale() -> float:
	var size := profile().tile_size
	if size == TILE or not fit_to_grid:
		return 1.0
	return float(TILE) / size


## Gets a TileMapLayer ready to paint with the active profile.
static func prepare_layer(layer: TileMapLayer) -> void:
	layer.tile_set = tile_set()
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.scale = Vector2.ONE * draw_scale()


## One tile of a role as a texture.
static func tile(role: StringName) -> AtlasTexture:
	return profile().texture_of(coords(role))


## A Sprite2D showing a role's tile, with its top-left corner at `position`.
static func sprite(role: StringName, position := Vector2.ZERO) -> Sprite2D:
	return sprite_of(coords(role), position)


## A Sprite2D showing the tile at sheet coordinates `tile_coords` (a piece of a pattern).
static func sprite_of(tile_coords: Vector2i, position := Vector2.ZERO) -> Sprite2D:
	var node := Sprite2D.new()
	node.texture = profile().texture_of(tile_coords)
	node.centered = false
	node.position = position
	node.scale = Vector2.ONE * draw_scale()
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return node


## The tile for `cell` of an irregular area (a path, a grass patch) drawn with a nine-slice pattern
## and its inner corners (pattern roles): `inside` says whether a cell belongs to the area. Edges and
## outer corners come from the nine-slice; where the area turns inwards (a T or a cross of paths)
## the inner corner rounds it off instead of leaving a square notch. Returns sheet coordinates.
static func blob_tile(pattern_role: StringName, inner_role: StringName, inside: Callable, cell: Vector2i) -> Vector2i:
	var tiles := pattern(pattern_role)
	var column := 0 if not inside.call(cell + Vector2i.LEFT) else (2 if not inside.call(cell + Vector2i.RIGHT) else 1)
	var row := 0 if not inside.call(cell + Vector2i.UP) else (2 if not inside.call(cell + Vector2i.DOWN) else 1)
	if row != 1 or column != 1:
		return tiles[row * 3 + column]
	var inner := pattern(inner_role)
	var diagonals := [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	for i in diagonals.size():
		if not inside.call(cell + diagonals[i]):
			return inner[i]
	return tiles[4]


## The sheet coordinates of a nine-slice pattern role for cell (x, y) of a `size`-cell area.
static func nine_slice_tile(pattern_role: StringName, x: int, y: int, size: Vector2i) -> Vector2i:
	var column := 0 if x == 0 else (2 if x == size.x - 1 else 1)
	var row := 0 if y == 0 else (2 if y == size.y - 1 else 1)
	return pattern(pattern_role)[row * 3 + column]
