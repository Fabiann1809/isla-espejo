class_name RuinProp
extends Node2D
## Scenery of the Ruinas placed by hand in a room scene, like RoomProp does for the forest: each prop
## draws itself with the tiles of the ruins tileset profile (by name) and adds the collision it
## needs, so a room is a list of nodes (kind, position, size).
##
## `position` is the top-left corner of the prop's footprint, in pixels and a multiple of 16.
## Single props are one tile wide; the tall ones (pillars, crystals, steles, banners) are two tiles
## high, crown above the footprint. Upright props are y-sorted with the actors.
##
## TERRACE and ALCOVE are raised platforms (see Heights): a terrace is an open dais, an alcove is a
## small room closed by rock on three sides; both are reached by a staircase in their south face,
## the only way between the two height levels.

enum Kind {
	ROCKS, STALAGMITE, BOULDER, PILLAR, CRYSTAL, STELE, BRAZIER, TORCH, BANNER, CRATE, BARREL,
	BRIDGE, WATERFALL, TERRACE, ALCOVE,
}

@export var kind: Kind = Kind.STALAGMITE
## Footprint in tiles. Used by ROCKS, BRIDGE, WATERFALL, TERRACE and ALCOVE.
@export var size_tiles := Vector2i(2, 2)
## BRIDGE: true when it runs along x (its planks side by side from left to right).
@export var horizontal := true

## Props that are part of the ground: drawn with the floor, never over an actor.
const FLAT_KINDS: Array[Kind] = [Kind.BRIDGE, Kind.WATERFALL, Kind.TERRACE, Kind.ALCOVE]
const WORLD_BITS := 1
const BLOCK_LOW_BITS := 1 << (Heights.BLOCK_LOW_LAYER - 1)
const BLOCK_HIGH_BITS := 1 << (Heights.BLOCK_HIGH_LAYER - 1)
## How far outside a terrace its edge keeps the high actors in (px).
const EDGE_THICKNESS := 8.0
## Where the blocking part of a single prop stands inside its tile, by kind.
const FOOTS := {
	Kind.STALAGMITE: Rect2(4, 9, 8, 6),
	Kind.BOULDER: Rect2(3, 8, 10, 7),
	Kind.BRAZIER: Rect2(3, 9, 10, 6),
	Kind.TORCH: Rect2(5, 11, 6, 4),
	Kind.CRATE: Rect2(2, 5, 12, 10),
	Kind.BARREL: Rect2(3, 4, 10, 10),
}
const TALL_FOOT := Rect2(3, 22, 10, 8)


func is_flat() -> bool:
	return kind in FLAT_KINDS


func _ready() -> void:
	_build()
	if is_flat():
		z_index = RoomTheme.FLOOR_Z
	else:
		_sort_at(_footprint_height() - RoomProp.SORT_ABOVE_BOTTOM)


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(global_position))
	match kind:
		Kind.ROCKS:
			_rocks(rng)
		Kind.STALAGMITE:
			add_child(TileArt.sprite([&"stalagmite_a", &"stalagmite_b"][rng.randi_range(0, 1)]))
		Kind.BOULDER:
			add_child(TileArt.sprite([&"boulder_a", &"boulder_b"][rng.randi_range(0, 1)]))
		Kind.PILLAR:
			_tall(&"pillar")
		Kind.CRYSTAL:
			_tall(&"crystal")
		Kind.STELE:
			_tall(&"stele")
		Kind.BRAZIER:
			add_child(TileArt.sprite(&"brazier_a"))
		Kind.TORCH:
			add_child(TileArt.sprite(&"torch_a"))
		Kind.BANNER:
			_tall([&"banner_a", &"banner_b"][rng.randi_range(0, 1)], false)
		Kind.CRATE:
			add_child(TileArt.sprite(&"crate"))
		Kind.BARREL:
			add_child(TileArt.sprite(&"barrel"))
		Kind.BRIDGE:
			_bridge()
		Kind.WATERFALL:
			_waterfall()
		Kind.TERRACE, Kind.ALCOVE:
			_terrace(kind == Kind.ALCOVE, rng)
	if FOOTS.has(kind):
		_collide(FOOTS[kind])


func _footprint_height() -> float:
	if kind in [Kind.PILLAR, Kind.CRYSTAL, Kind.STELE, Kind.BANNER]:
		return TileArt.TILE * 2.0
	if kind == Kind.ROCKS:
		return TileArt.TILE * size_tiles.y
	return TileArt.TILE


## Moves the node's origin (its y-sort key) down by `offset` without moving what it draws or its collision.
func _sort_at(offset: float) -> void:
	position.y += offset
	for child in get_children():
		if child is Node2D:
			child.position.y -= offset


## A tall prop: two tiles, `<name>_top` above and `<name>_base` below; `solid` blocks its base.
func _tall(prop_name: StringName, solid := true) -> void:
	add_child(TileArt.sprite(StringName(prop_name + "_top")))
	add_child(TileArt.sprite(StringName(prop_name + "_base"), Vector2(0, TileArt.TILE)))
	if solid:
		_collide(TALL_FOOT)


## An outcrop of rock columns that fills the footprint (rows staggered every 8 px, like the walls).
func _rocks(rng: RandomNumberGenerator) -> void:
	var size := Vector2(size_tiles * TileArt.TILE)
	var row := size.y - 1.0
	var staggered := false
	while row > TileArt.TILE * 0.5:
		var feet := RockWall.feet_along(Vector2(0, row), Vector2(size.x, row), rng)
		if staggered:
			var shifted: Array[Vector2] = []
			for foot in feet:
				shifted.append(foot + Vector2(Tuning.ROCK_WALL_STEP / 2.0, 0))
			feet = shifted
		for foot: Vector2 in feet:
			if foot.x < size.x - 2.0:
				add_child(RockWall.column(foot, rng))
		row -= Tuning.ROCK_WALL_BACK_ROW
		staggered = not staggered
	_collide(Rect2(2, 8, size.x - 4, size.y - 10))


## Planks with a low stone parapet on each side, across a river (the river itself leaves a gap in its
## water collision, like the forest's). Nothing to collide with: the water on both sides does it.
func _bridge() -> void:
	for y in size_tiles.y:
		for x in size_tiles.x:
			var along_edge := (y == 0 or y == size_tiles.y - 1) if horizontal else (x == 0 or x == size_tiles.x - 1)
			var rail: StringName = &"bridge_rail_h" if horizontal else &"bridge_rail_v"
			var planks: StringName = &"bridge_planks_h" if horizontal else &"bridge_planks_v"
			add_child(TileArt.sprite(rail if along_edge and (size_tiles.y > 2 if horizontal else size_tiles.x > 2) else planks,
					Vector2(x, y) * TileArt.TILE))


## A waterfall falling down a wall: its top, the falling water and its foot (no collision).
func _waterfall() -> void:
	for x in size_tiles.x:
		for y in size_tiles.y:
			var role: StringName = &"waterfall_mid_a"
			if y == 0:
				role = &"waterfall_top"
			elif y == size_tiles.y - 1:
				role = &"waterfall_base_a"
			add_child(TileArt.sprite(role, Vector2(x, y) * TileArt.TILE))


## A raised platform with a staircase in the middle of its south face. Rows: the top surface, then the
## lip and the face of the cliff (the stairs replace them in the middle, between two parapets).
## Collision (see Heights): the footprint blocks low actors and the edge keeps high actors up, with a
## gap only at the stairs, where a StairZone changes the level; an ALCOVE also walls its other sides
## with rock and blocks everyone from the face.
func _terrace(walled: bool, rng: RandomNumberGenerator) -> void:
	var w := size_tiles.x
	var h := size_tiles.y
	var tile := float(TileArt.TILE)
	var stairs_x := w / 2 - 1
	for y in h - 2:
		for x in w:
			var surface: StringName = &"floor_worn"
			if not walled and y == 0:
				surface = &"terrace_top"
			elif not walled and x == 0:
				surface = &"terrace_side_l"
			elif not walled and x == w - 1:
				surface = &"terrace_side_r"
			add_child(TileArt.sprite(surface, Vector2(x, y) * tile))
	for x in w:
		var near_stairs := x >= stairs_x - 1 and x <= stairs_x + 2
		var lip: StringName = &"wall_lip_moss" if rng.randf() < 0.2 else &"wall_lip"
		var face: StringName = &"wall_face_moss" if rng.randf() < 0.2 else &"wall_face"
		if x == stairs_x - 1:
			lip = &"stairs_rail_l"
			face = &"stairs_rail_l"
		elif x == stairs_x + 2:
			lip = &"stairs_rail_r"
			face = &"stairs_rail_r"
		elif near_stairs:
			lip = &"stairs_steps"
			face = &"stairs_steps"
		add_child(TileArt.sprite(lip, Vector2(x, h - 2) * tile))
		add_child(TileArt.sprite(face, Vector2(x, h - 1) * tile))
	var size := Vector2(w, h) * tile
	var gap_left := (stairs_x - 1) * tile
	var gap_right := (stairs_x + 3) * tile
	var face_top := (h - 2) * tile
	# The footprint: low actors cannot enter, except by the stairs.
	_collide(Rect2(0, 0, size.x, face_top), BLOCK_LOW_BITS)
	_collide(Rect2(0, face_top, gap_left, size.y - face_top), BLOCK_LOW_BITS)
	_collide(Rect2(gap_right, face_top, size.x - gap_right, size.y - face_top), BLOCK_LOW_BITS)
	# The parapets of the stairs stop everybody.
	_collide(Rect2(gap_left, face_top, tile, size.y - face_top), WORLD_BITS)
	_collide(Rect2(gap_right - tile, face_top, tile, size.y - face_top), WORLD_BITS)
	# The edge: high actors stay on the surface and the stairs.
	_collide(Rect2(0, face_top, gap_left, size.y - face_top), BLOCK_HIGH_BITS)
	_collide(Rect2(gap_right, face_top, size.x - gap_right, size.y - face_top), BLOCK_HIGH_BITS)
	_collide(Rect2(-EDGE_THICKNESS, -EDGE_THICKNESS, size.x + EDGE_THICKNESS * 2.0, EDGE_THICKNESS), BLOCK_HIGH_BITS)
	_collide(Rect2(-EDGE_THICKNESS, 0, EDGE_THICKNESS, face_top), BLOCK_HIGH_BITS)
	_collide(Rect2(size.x, 0, EDGE_THICKNESS, face_top), BLOCK_HIGH_BITS)
	if walled:
		_rock_walls(rng, w, h)
	var zone := StairZone.new()
	zone.direction = Vector2.UP
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(tile * 2.0, tile * 2.0)
	shape.shape = rectangle
	zone.add_child(shape)
	zone.position = Vector2(stairs_x * tile + tile, face_top + tile)
	add_child(zone)


## Rock columns on the back and the sides of an alcove, standing on its border (solid for everybody).
func _rock_walls(rng: RandomNumberGenerator, w: int, h: int) -> void:
	var tile := float(TileArt.TILE)
	var walls := Node2D.new()
	walls.name = "Rocks"
	walls.y_sort_enabled = true
	add_child(walls)
	var feet: Array[Vector2] = RockWall.feet_along(Vector2(0, tile - 1.0), Vector2(w * tile, tile - 1.0), rng)
	for x in [tile / 2.0, w * tile - tile / 2.0]:
		feet.append_array(RockWall.feet_along(Vector2(x, tile * 1.5), Vector2(x, (h - 2) * tile), rng))
	for foot in feet:
		walls.add_child(RockWall.column(foot, rng))
	_collide(Rect2(0, 0, w * tile, tile), WORLD_BITS)
	_collide(Rect2(0, 0, tile, (h - 2) * tile), WORLD_BITS)
	_collide(Rect2((w - 1) * tile, 0, tile, (h - 2) * tile), WORLD_BITS)


## Collision on `layer_bits` (world by default, see Heights for the level layers).
func _collide(rect: Rect2, layer_bits := WORLD_BITS) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = layer_bits
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = rect.size
	shape.shape = rectangle
	shape.position = rect.get_center()
	body.add_child(shape)
	add_child(body)
