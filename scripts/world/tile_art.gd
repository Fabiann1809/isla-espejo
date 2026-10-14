class_name TileArt
extends RefCounted
## Catalog of the tiles used from the Kenney Roguelike/RPG sheet (CC0, see CREDITS.md), by name.
## The sheet is 16x16 tiles with a 1 px margin. Coordinates are (column, row); to find more tiles
## render a labeled preview with `tools/atlas_preview.gd`.

const SHEET_PATH := "res://assets/tilesets/kenney_roguelike_rpg/sheet.png"
const TILE := 16
const MARGIN := 1
const STRIDE := TILE + MARGIN

# Ground
const GRASS := Vector2i(5, 0)
const DIRT := Vector2i(6, 0)
const FLOWERS_RED := Vector2i(0, 6)
const FLOWERS_WHITE := Vector2i(0, 9)
const FLOWERS_BLUE := Vector2i(0, 12)
const TUFT_A := Vector2i(22, 10)
const TUFT_B := Vector2i(22, 11)
const PLANKS := Vector2i(8, 3)

# Nine-slice patterns, row by row: top-left, top, top-right, left, center, right, bottom-left, bottom, bottom-right
## Water with a shore, drawn on grass.
const POND: Array[Vector2i] = [
	Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0),
	Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1),
	Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2),
]
## A round patch of bare earth on grass.
const DIRT_PATCH: Array[Vector2i] = [
	Vector2i(7, 9), Vector2i(8, 9), Vector2i(9, 9),
	Vector2i(7, 10), Vector2i(8, 10), Vector2i(9, 10),
	Vector2i(7, 11), Vector2i(8, 11), Vector2i(9, 11),
]

# Props: a tall tree is two tiles (top, then trunk)
const PINE := Vector2i(16, 9)
const PINE_TALL_TOP := Vector2i(16, 10)
const PINE_TALL_BASE := Vector2i(16, 11)
const ROUND_TREE := Vector2i(13, 9)
const ROUND_TREE_TALL_TOP := Vector2i(13, 10)
const ROUND_TREE_TALL_BASE := Vector2i(13, 11)
const BUSH := Vector2i(19, 9)
const BUSH_ORANGE := Vector2i(20, 9)
const CAMPFIRE := Vector2i(14, 8)
const LOGS := Vector2i(13, 8)
const CHEST_CLOSED := Vector2i(13, 7)
const CHEST_OPEN := Vector2i(14, 7)

static var _sheet: Texture2D


static func sheet() -> Texture2D:
	if _sheet == null:
		_sheet = load(SHEET_PATH)
	return _sheet


## One 16x16 tile of the sheet as a texture.
static func tile(coords: Vector2i) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = sheet()
	texture.region = Rect2(coords.x * STRIDE, coords.y * STRIDE, TILE, TILE)
	return texture


## A Sprite2D showing one tile, with its top-left corner at `position`.
static func sprite(coords: Vector2i, position := Vector2.ZERO) -> Sprite2D:
	var node := Sprite2D.new()
	node.texture = tile(coords)
	node.centered = false
	node.position = position
	node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return node


## The tile of a nine-slice pattern for cell (x, y) of a `size`-cell area.
static func nine_slice_tile(pattern: Array[Vector2i], x: int, y: int, size: Vector2i) -> Vector2i:
	var column := 0 if x == 0 else (2 if x == size.x - 1 else 1)
	var row := 0 if y == 0 else (2 if y == size.y - 1 else 1)
	return pattern[row * 3 + column]
