class_name RoomProp
extends Node2D
## Scenery placed by hand in a room scene: trees, bushes, ponds, a campfire... Each prop draws itself
## with tile roles of the active tileset profile (TileArt) and adds the collision it needs, so rooms are described by a few nodes
## (kind, position, size) instead of painted tile by tile.
##
## `position` is the top-left corner of the prop's footprint, in pixels and a multiple of 16.
## Trees and bushes occupy one tile wide; tall trees are two tiles high (crown above, trunk below).
## Y-Sort enabled: player can walk naturally behind canopies and in front of trunks.

enum Kind {
	PINE, TALL_PINE, ROUND_TREE, TALL_ROUND_TREE, BUSH,
	POND, PLANKS, DIRT_PATCH, CAMPFIRE, LOGS, TUFT,
}

@export var kind: Kind = Kind.PINE
## Footprint in tiles. Only used by POND, PLANKS and DIRT_PATCH.
@export var size_tiles := Vector2i(3, 3)

const TRUNK := Vector2(10, 8)
const WATER_INSET := 4.0
## Props that are part of the ground: drawn with the floor, never over an actor.
const FLAT_KINDS: Array[Kind] = [Kind.POND, Kind.PLANKS, Kind.DIRT_PATCH, Kind.TUFT]
## Upright props are y-sorted with the actors by the bottom of their footprint (a little above it,
## where the trunk stands), so whoever walks in front of a tree is drawn in front of it.
const SORT_ABOVE_BOTTOM := 4.0


func is_flat() -> bool:
	return kind in FLAT_KINDS

const MED_TREES := [
	{"path": "res://assets/art_forest/trees_med/tree_med_oak.png", "pivot": Vector2(18, 36)},
	{"path": "res://assets/art_forest/trees_med/tree_med_round.png", "pivot": Vector2(17, 35)},
	{"path": "res://assets/art_forest/trees_med/tree_med_mossy.png", "pivot": Vector2(18, 36)},
	{"path": "res://assets/art_forest/trees_med/tree_med_dense.png", "pivot": Vector2(18, 34)},
	{"path": "res://assets/art_forest/trees_med/tree_med_emerald.png", "pivot": Vector2(18, 40)},
	{"path": "res://assets/art_forest/trees_med/tree_med_small.png", "pivot": Vector2(15, 33)},
]

const LARGE_TREES := [
	{"path": "res://assets/art_forest/trees_large/tree_large_oak.png", "pivot": Vector2(23, 48)},
	{"path": "res://assets/art_forest/trees_large/tree_large_round.png", "pivot": Vector2(21, 47)},
	{"path": "res://assets/art_forest/trees_large/tree_large_mossy.png", "pivot": Vector2(24, 50)},
	{"path": "res://assets/art_forest/trees_large/tree_large_dense.png", "pivot": Vector2(22, 48)},
	{"path": "res://assets/art_forest/trees_large/tree_large_emerald.png", "pivot": Vector2(23, 55)},
	{"path": "res://assets/art_forest/trees_large/tree_large_grand.png", "pivot": Vector2(25, 61)},
]

static var _cached_textures := {}


func _ready() -> void:
	_build()
	if is_flat():
		z_index = RoomTheme.FLOOR_Z
	else:
		_sort_at(_footprint_height() - SORT_ABOVE_BOTTOM)


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(global_position))
	match kind:
		Kind.PINE, Kind.ROUND_TREE:
			_lush_tree(MED_TREES, Vector2(8, 14), rng)
			_collide(Rect2(Vector2(3, 6), TRUNK))
		Kind.TALL_PINE, Kind.TALL_ROUND_TREE:
			_lush_tree(LARGE_TREES, Vector2(8, 30), rng)
			_collide(Rect2(Vector2(3, TileArt.TILE + 6), TRUNK))
		Kind.BUSH:
			_bush(rng)
			_collide(Rect2(2, 5, 12, 9))
		Kind.POND:
			_area(TileArt.POND)
			_collide(Rect2(Vector2.ONE * WATER_INSET, Vector2(size_tiles * TileArt.TILE) - Vector2.ONE * WATER_INSET * 2.0))
		Kind.PLANKS:
			_planks()
		Kind.DIRT_PATCH:
			_area(TileArt.DIRT_PATCH)
		Kind.CAMPFIRE:
			add_child(TileArt.sprite(TileArt.CAMPFIRE))
			_collide(Rect2(3, 6, 10, 8))
		Kind.LOGS:
			_mossy_log(rng)
			_collide(Rect2(1, 4, 14, 10))
		Kind.TUFT:
			_tuft(rng)


func _footprint_height() -> float:
	var tall := kind in [Kind.TALL_PINE, Kind.TALL_ROUND_TREE]
	return TileArt.TILE * (2.0 if tall else 1.0)


## Moves the node's origin (its y-sort key) down by `offset` without moving what it draws or its collision.
func _sort_at(offset: float) -> void:
	position.y += offset
	for child in get_children():
		if child is Node2D:
			child.position.y -= offset


func _tree(role: StringName) -> void:
	add_child(TileArt.sprite(role))
	_collide(Rect2(Vector2(3, 6), TRUNK))


func _tall_tree(top: StringName, base: StringName) -> void:
	add_child(TileArt.sprite(top))
	add_child(TileArt.sprite(base, Vector2(0, TileArt.TILE)))
	_collide(Rect2(Vector2(3, TileArt.TILE + 6), TRUNK))
func _lush_tree(catalog: Array, base_pos: Vector2, rng: RandomNumberGenerator) -> void:
	var entry: Dictionary = catalog[rng.randi_range(0, catalog.size() - 1)]
	var path: String = entry["path"]
	var pivot: Vector2 = entry["pivot"]

	var tex := _get_texture(path)
	if tex != null:
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		sprite.position = base_pos - pivot
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
	else:
		# Fallback to legacy sprite if texture missing
		add_child(TileArt.sprite(TileArt.PINE))


func _bush(rng: RandomNumberGenerator) -> void:
	var idx := rng.randi_range(1, 30)
	var path := "res://assets/art_forest/bushes/bush_%d.png" % idx
	var tex := _get_texture(path)
	if tex != null:
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = true
		sprite.position = Vector2(8, 9)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
	else:
		add_child(TileArt.sprite(TileArt.BUSH))


func _mossy_log(rng: RandomNumberGenerator) -> void:
	var path := "res://assets/art_forest/logs/log_mossy.png" if rng.randf() < 0.6 else "res://assets/art_forest/logs/stump_mossy.png"
	var tex := _get_texture(path)
	if tex != null:
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = true
		sprite.position = Vector2(8, 9)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
	else:
		add_child(TileArt.sprite(TileArt.LOGS))


func _tuft(rng: RandomNumberGenerator) -> void:
	var idx := rng.randi_range(1, 7)
	var path := "res://assets/art_forest/bushes/bush_%d.png" % idx
	var tex := _get_texture(path)
	if tex != null:
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = true
		sprite.position = Vector2(8, 10)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(sprite)
	else:
		add_child(TileArt.sprite(TileArt.TUFT_A))


func _get_texture(path: String) -> Texture2D:
	if not _cached_textures.has(path):
		if ResourceLoader.exists(path):
			_cached_textures[path] = load(path)
		else:
			_cached_textures[path] = null
	return _cached_textures[path]


## Draws a nine-slice pattern role over `size_tiles` cells.
func _area(pattern_role: StringName) -> void:
	for y in size_tiles.y:
		for x in size_tiles.x:
			add_child(TileArt.sprite_of(TileArt.nine_slice_tile(pattern_role, x, y, size_tiles),
					Vector2(x, y) * TileArt.TILE))


func _planks() -> void:
	for y in size_tiles.y:
		for x in size_tiles.x:
			add_child(TileArt.sprite(TileArt.PLANKS, Vector2(x, y) * TileArt.TILE))


## Collision on the world layer (the same one the walls use).
func _collide(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.position = rect.get_center()
	body.add_child(shape)
	add_child(body)
