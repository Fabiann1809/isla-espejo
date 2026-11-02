class_name ForestArt
extends RefCounted
## The forest art set (assets/art_forest/) sorted by what each picture is, so props only use the
## pictures that fit them: the bushes folder mixes solid bushes with tufts of grass, and the rocks
## folder mixes rocks with bits of grass that came out of the same sheet.
## Each list was picked by looking at the pictures; numbers are the file names (bush_12.png...).

const BUSHES := "res://assets/art_forest/bushes/bush_%d.png"
const ROCKS := "res://assets/art_forest/rocks/rock_%d.png"
const STUMP := "res://assets/art_forest/logs/stump.png"

## Round, leafy bushes (some with flowers or berries): they stand up and block the way.
const SOLID_BUSHES := [8, 11, 12, 14, 17, 18, 19, 20, 21, 25, 29]
## The medium trees: they line the walls of the rooms and corridors.
const WALL_TREES := [
	"res://assets/art_forest/trees_med/tree_med_oak.png",
	"res://assets/art_forest/trees_med/tree_med_round.png",
	"res://assets/art_forest/trees_med/tree_med_mossy.png",
	"res://assets/art_forest/trees_med/tree_med_dense.png",
	"res://assets/art_forest/trees_med/tree_med_emerald.png",
	"res://assets/art_forest/trees_med/tree_med_small.png",
]
## Medium and large trees: the deep forest around the map.
const FOREST_TREES := [
	"res://assets/art_forest/trees_med/tree_med_oak.png",
	"res://assets/art_forest/trees_med/tree_med_round.png",
	"res://assets/art_forest/trees_med/tree_med_mossy.png",
	"res://assets/art_forest/trees_med/tree_med_dense.png",
	"res://assets/art_forest/trees_med/tree_med_emerald.png",
	"res://assets/art_forest/trees_large/tree_large_oak.png",
	"res://assets/art_forest/trees_large/tree_large_round.png",
	"res://assets/art_forest/trees_large/tree_large_mossy.png",
	"res://assets/art_forest/trees_large/tree_large_dense.png",
]
## Tufts, sprouts and low plants: ground decoration that never blocks.
const GROUND_PLANTS := [1, 2, 3, 4, 5, 6, 7, 9, 10, 13, 15, 16, 22, 23, 24, 26, 27, 28, 30]
## Boulders big enough to block the way (and no wider than a tile, like the bush they replace).
## rock_8, a boulder two tiles wide, is left for a hand-placed prop.
const BIG_ROCKS := [13, 15, 16, 17]
## Pebbles and small flat stones: ground decoration.
const SMALL_ROCKS := [2, 12, 14, 18, 19, 21]

static var _textures := {}
static var _images := {}


static func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]


## The picture's pixels (RGBA8), to paint many copies into one image.
static func image(path: String) -> Image:
	if not _images.has(path):
		var tex := texture(path)
		var img: Image = null
		if tex != null:
			img = tex.get_image()
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
		_images[path] = img
	return _images[path]


static func pick_path(paths: Array, rng: RandomNumberGenerator) -> Texture2D:
	return texture(paths[rng.randi_range(0, paths.size() - 1)])


## Paints `picture` standing on `foot` into `canvas` (alpha blended).
static func paint(canvas: Image, picture: Image, foot: Vector2) -> void:
	var corner := Vector2i(foot) - Vector2i(picture.get_width() / 2, picture.get_height())
	canvas.blend_rect(picture, Rect2i(Vector2i.ZERO, picture.get_size()), corner)


## A pixel-sharp sprite of a painted image, with its top-left corner at its position.
static func baked(picture: Image) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture = ImageTexture.create_from_image(picture)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite


static func pick(pattern: String, numbers: Array, rng: RandomNumberGenerator) -> Texture2D:
	return texture(pattern % numbers[rng.randi_range(0, numbers.size() - 1)])


## A sprite of `tex` standing on `foot` (the middle of its bottom edge), drawn pixel-sharp.
static func standing(tex: Texture2D, foot: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.position = foot - Vector2(floorf(tex.get_width() / 2.0), tex.get_height())
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return sprite


## The blocking part of something standing on `foot`: the lower band of the picture, a little
## narrower than it, so Nico can brush past the leaves but not walk through the bush or rock.
static func footprint(tex: Texture2D, foot: Vector2) -> Rect2:
	var width := clampf(tex.get_width() - Tuning.PROP_FOOT_INSET * 2.0, Tuning.PROP_FOOT_MIN.x, Tuning.PROP_FOOT_MAX.x)
	var height := clampf(tex.get_height() * 0.5, Tuning.PROP_FOOT_MIN.y, Tuning.PROP_FOOT_MAX.y)
	return Rect2(foot.x - width / 2.0, foot.y - height, width, height)
