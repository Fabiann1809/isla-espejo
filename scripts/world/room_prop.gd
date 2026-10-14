class_name RoomProp
extends Node2D
## Scenery placed by hand in a room scene: trees, bushes, ponds, a campfire... Each prop draws itself
## with tiles of the sheet and adds the collision it needs, so rooms are described by a few nodes
## (kind, position, size) instead of painted tile by tile.
##
## `position` is the top-left corner of the prop's footprint, in pixels and a multiple of 16.
## Trees and bushes occupy one tile wide; tall trees are two tiles high (crown above, trunk below).

enum Kind {
	PINE, TALL_PINE, ROUND_TREE, TALL_ROUND_TREE, BUSH,
	POND, PLANKS, DIRT_PATCH, CAMPFIRE, LOGS, TUFT,
}

@export var kind: Kind = Kind.PINE
## Footprint in tiles. Only used by POND, PLANKS and DIRT_PATCH.
@export var size_tiles := Vector2i(3, 3)

const TRUNK := Vector2(10, 8)
const WATER_INSET := 4.0


func _ready() -> void:
	match kind:
		Kind.PINE:
			_tree(TileArt.PINE)
		Kind.TALL_PINE:
			_tall_tree(TileArt.PINE_TALL_TOP, TileArt.PINE_TALL_BASE)
		Kind.ROUND_TREE:
			_tree(TileArt.ROUND_TREE)
		Kind.TALL_ROUND_TREE:
			_tall_tree(TileArt.ROUND_TREE_TALL_TOP, TileArt.ROUND_TREE_TALL_BASE)
		Kind.BUSH:
			add_child(TileArt.sprite(TileArt.BUSH))
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
			add_child(TileArt.sprite(TileArt.LOGS))
			_collide(Rect2(1, 4, 14, 10))
		Kind.TUFT:
			add_child(TileArt.sprite(TileArt.TUFT_A))


func _tree(coords: Vector2i) -> void:
	add_child(TileArt.sprite(coords))
	_collide(Rect2(Vector2(3, 6), TRUNK))


func _tall_tree(top: Vector2i, base: Vector2i) -> void:
	add_child(TileArt.sprite(top))
	add_child(TileArt.sprite(base, Vector2(0, TileArt.TILE)))
	_collide(Rect2(Vector2(3, TileArt.TILE + 6), TRUNK))


## Draws a nine-slice pattern over `size_tiles` cells.
func _area(pattern: Array[Vector2i]) -> void:
	for y in size_tiles.y:
		for x in size_tiles.x:
			add_child(TileArt.sprite(TileArt.nine_slice_tile(pattern, x, y, size_tiles),
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
