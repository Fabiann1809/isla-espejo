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
	BRIDGE, WATERFALL, TERRACE, ALCOVE, RIVER, SPIKES, STATUE, VASE, ARMOR, SYMBOL, ALTAR, GRAVE,
}

@export var kind: Kind = Kind.STALAGMITE
## Footprint in tiles. Used by ROCKS, BRIDGE, WATERFALL, TERRACE, ALCOVE and RIVER.
@export var size_tiles := Vector2i(2, 2)
## BRIDGE: true when it runs along x (its planks side by side from left to right).
@export var horizontal := true

## Props that are part of the ground: drawn with the floor, never over an actor.
const FLAT_KINDS: Array[Kind] = [Kind.BRIDGE, Kind.WATERFALL, Kind.TERRACE, Kind.ALCOVE, Kind.RIVER, Kind.SPIKES,
		Kind.ARMOR, Kind.SYMBOL]
const WORLD_BITS := 1
const WATER_BITS := 1 << (Heights.WATER_LAYER - 1)
## Water stops bodies a little inside its picture, so the shore is walkable.
const WATER_INSET := 4.0
## Frames per second of the animated pieces, and of the water.
const FIRE_FPS := 6.0
const WATER_FPS := 3.0
const GLOW_FPS := 1.5
const BLOCK_LOW_BITS := 1 << (Heights.BLOCK_LOW_LAYER - 1)
const BLOCK_HIGH_BITS := 1 << (Heights.BLOCK_HIGH_LAYER - 1)
## How far outside a terrace its edge keeps the high actors in (px).
const EDGE_THICKNESS := 8.0
## How much of a platform's underside row stays open (nothing blocks it), so its shadow shows.
const UNDERSIDE_GAP := 6.0
## Where the blocking part of a single prop stands inside its tile, by kind.
const FOOTS := {
	Kind.STALAGMITE: Rect2(4, 9, 8, 6),
	Kind.BOULDER: Rect2(3, 8, 10, 7),
	Kind.BRAZIER: Rect2(3, 9, 10, 6),
	Kind.TORCH: Rect2(5, 11, 6, 4),
	Kind.CRATE: Rect2(2, 5, 12, 10),
	Kind.BARREL: Rect2(3, 4, 10, 10),
	Kind.VASE: Rect2(4, 5, 8, 9),
	Kind.GRAVE: Rect2(3, 6, 10, 9),
	Kind.STATUE: Rect2(3, 4, 26, 11),
	Kind.ALTAR: Rect2(3, 16, 26, 15),
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
			_tall(&"crystal", true, [&"crystal_top", &"crystal_top_b"], GLOW_FPS)
		Kind.STELE:
			_tall(&"stele")
		Kind.BRAZIER:
			add_child(_animated([&"brazier_a", &"brazier_b", &"brazier_c"], FIRE_FPS, Vector2.ZERO))
		Kind.TORCH:
			add_child(_animated([&"torch_a", &"torch_b", &"torch_c"], FIRE_FPS, Vector2.ZERO))
		Kind.BANNER:
			_tall([&"banner_a", &"banner_b", &"banner_blue"][rng.randi_range(0, 2)], false)
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
		Kind.RIVER:
			_river()
		Kind.SPIKES:
			_spikes()
		Kind.STATUE:
			_statue(rng)
		Kind.VASE:
			add_child(TileArt.sprite([&"vase_a", &"vase_b", &"vase_c", &"urn_a", &"urn_b"][rng.randi_range(0, 4)]))
		Kind.ARMOR:
			add_child(TileArt.sprite([&"armor_fallen_a", &"armor_fallen_b", &"skull", &"sword_fallen"][rng.randi_range(0, 3)]))
		Kind.SYMBOL:
			_symbol()
		Kind.ALTAR:
			_altar()
		Kind.GRAVE:
			add_child(TileArt.sprite([&"gravestone_a", &"gravestone_b"][rng.randi_range(0, 1)]))
	if FOOTS.has(kind):
		_collide(FOOTS[kind])
	match kind:
		Kind.TORCH:
			_light(Tuning.RUIN_TORCH_LIGHT, Tuning.RUIN_TORCH_LIGHT_RADIUS, Vector2(8, 6))
		Kind.BRAZIER:
			_light(Tuning.RUIN_BRAZIER_LIGHT, Tuning.RUIN_BRAZIER_LIGHT_RADIUS, Vector2(8, 5))
		Kind.CRYSTAL:
			_light(Tuning.RUIN_CRYSTAL_LIGHT, Tuning.RUIN_CRYSTAL_LIGHT_RADIUS, Vector2(8, 14))


func _footprint_height() -> float:
	if kind in [Kind.PILLAR, Kind.CRYSTAL, Kind.STELE, Kind.BANNER, Kind.ALTAR]:
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


## A tall prop: two tiles, `<name>_top` above and `<name>_base` below; `solid` blocks its base. With
## `top_frames` the upper tile is animated.
func _tall(prop_name: StringName, solid := true, top_frames: Array[StringName] = [], fps := 0.0) -> void:
	if top_frames.is_empty():
		add_child(TileArt.sprite(StringName(prop_name + "_top")))
	else:
		add_child(_animated(top_frames, fps, Vector2.ZERO))
	add_child(TileArt.sprite(StringName(prop_name + "_base"), Vector2(0, TileArt.TILE)))
	if solid:
		_collide(TALL_FOOT)


## A soft additive light at `at` (see Tuning.RUIN_*): it flickers a little and is drawn over the shade
## of a dark room.
func _light(color: Color, radius: float, at: Vector2) -> void:
	if not Tuning.RUIN_LIGHTS_ENABLED or color.a <= 0.0:
		return
	var glow := RuinLight.glow(color, Vector2.ONE * radius * 2.0)
	glow.position = at
	glow.z_as_relative = false
	glow.z_index = Tuning.RUIN_LIGHT_Z
	add_child(glow)
	var dim := Color(color.r, color.g, color.b, color.a * (1.0 - Tuning.RUIN_LIGHT_FLICKER))
	var tween := glow.create_tween().set_loops()
	var seconds := Tuning.RUIN_LIGHT_FLICKER_SECONDS * randf_range(0.8, 1.4)
	tween.tween_property(glow, "modulate", dim, seconds)
	tween.tween_property(glow, "modulate", color, seconds)


## A tile that cycles through `frames` (see RuinAnim).
func _animated(frames: Array[StringName], fps: float, at: Vector2) -> AnimatedSprite2D:
	return RuinAnim.sprite(frames, fps, at)


## A statue two tiles wide and three high standing on its plinth: `position` is the plinth's left tile, the
## figure rises two tiles above it. Its base blocks.
func _statue(rng: RandomNumberGenerator) -> void:
	var variant: String = ["a", "b", "c"][rng.randi_range(0, 2)]
	for row in 3:
		for col in 2:
			add_child(TileArt.sprite(StringName("statue_big_%s_%d%d" % [variant, row, col]),
					Vector2(col, row - 2) * TileArt.TILE))


## A stone altar with a blue crystal (2x2 tiles, blocking its lower part) and a cold glow.
func _altar() -> void:
	for i in 4:
		add_child(TileArt.sprite(StringName("altar_" + ["tl", "tr", "bl", "br"][i]), Vector2(i % 2, i / 2) * TileArt.TILE))
	_light(Tuning.RUIN_CRYSTAL_LIGHT, Tuning.RUIN_CRYSTAL_LIGHT_RADIUS, Vector2(16, 8))


## An engraved symbol on the floor: a ring of four tiles (2x2), or a small lozenge (1x1). No collision.
func _symbol() -> void:
	if size_tiles == Vector2i.ONE:
		add_child(TileArt.sprite(&"floor_symbol_small"))
		return
	for i in 4:
		var part := StringName("floor_symbol_" + ["tl", "tr", "bl", "br"][i])
		add_child(TileArt.sprite(part, Vector2(i % 2, i / 2) * TileArt.TILE))


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
			var at := Vector2(x, y) * TileArt.TILE
			if y == 0:
				add_child(TileArt.sprite(&"waterfall_top", at))
			elif y == size_tiles.y - 1:
				add_child(_animated([&"waterfall_base_a", &"waterfall_base_b", &"waterfall_base_c"], FIRE_FPS, at))
			else:
				add_child(_animated([&"waterfall_mid_a", &"waterfall_mid_b", &"waterfall_mid_c"], FIRE_FPS, at))


## A floor trap of the ruins (the shared SpikeTrap, drawn with the slab and the iron spikes).
func _spikes() -> void:
	var trap: Node2D = load("res://scenes/world/spike_trap.tscn").instantiate()
	trap.art_off = TileArt.tile(&"spike_trap_off")
	trap.art_on = TileArt.tile(&"spike_trap_on")
	trap.position = Vector2.ONE * TileArt.TILE / 2.0
	add_child(trap)


## A river or pool: water with a luminous shore, its center shimmering. Bodies cannot cross it but
## arrows fly over (layer `water`); leave a gap for a bridge.
func _river() -> void:
	for y in size_tiles.y:
		for x in size_tiles.x:
			var at := Vector2(x, y) * TileArt.TILE
			var tile := TileArt.nine_slice_tile(&"pond", x, y, size_tiles)
			if tile == TileArt.coords(&"pond_4"):
				add_child(_animated([&"pond_4", &"pond_center_b", &"pond_center_c"], WATER_FPS, at))
			else:
				add_child(TileArt.sprite_of(tile, at))
	_collide(Rect2(Vector2.ONE * WATER_INSET, Vector2(size_tiles * TileArt.TILE) - Vector2.ONE * WATER_INSET * 2.0), WATER_BITS)


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
	_terrace_shadows(walled, w, h, stairs_x)
	# Rows: the surface (h - 3), the lip with the top of the wall (h - 3 is its first row), the wall (h - 2) and
	# the underside (h - 1): legs between hanging, ragged bricks, so the slab seems to float over its shadow.
	for y in h - 3:
		for x in w:
			var surface: StringName = [&"platform_a", &"platform_b"][rng.randi_range(0, 1)] if not walled else &"floor_worn"
			if not walled and x == w / 2 and y == (h - 3) / 2:
				surface = &"platform_rune"
			if not walled and y == 0 and x == 0:
				surface = &"terrace_corner_l"
			elif not walled and y == 0 and x == w - 1:
				surface = &"terrace_corner_r"
			elif not walled and y == 0:
				surface = &"terrace_top"
			elif not walled and x == 0:
				surface = &"terrace_side_l"
			elif not walled and x == w - 1:
				surface = &"terrace_side_r"
			add_child(TileArt.sprite(surface, Vector2(x, y) * tile))
	for x in w:
		var near_stairs := x >= stairs_x - 1 and x <= stairs_x + 2
		var lip: StringName = &"wall_lip_moss" if rng.randf() < 0.2 else &"wall_lip"
		var wall: StringName = &"wall_face_moss" if rng.randf() < 0.2 else &"wall_face"
		var face: StringName = [&"wall_under_a", &"wall_under_b"][rng.randi_range(0, 1)]
		if x == stairs_x - 1:
			lip = &"stairs_rail_l"
			wall = &"stairs_rail_l"
			face = &"stairs_rail_l"
		elif x == stairs_x + 2:
			lip = &"stairs_rail_r"
			wall = &"stairs_rail_r"
			face = &"stairs_rail_r"
		elif near_stairs:
			lip = &"stairs_steps"
			wall = &"stairs_steps"
			face = &"stairs_steps"
		elif x == 0 or x == w - 1:
			var side := "l" if x == 0 else "r"
			lip = StringName("terrace_post_%s_lip" % side)
			wall = StringName("terrace_post_%s_face" % side)
			face = wall
		elif x % 4 == 2:
			lip = &"wall_support_lip"
			wall = &"wall_support_face"
			face = &"wall_support_face"
		add_child(TileArt.sprite(lip, Vector2(x, h - 3) * tile))
		add_child(TileArt.sprite(wall, Vector2(x, h - 2) * tile))
		add_child(TileArt.sprite(face, Vector2(x, h - 1) * tile))
		if not near_stairs and x % 4 != 2 and 0 < x and x < w - 1 and rng.randf() < Tuning.RUIN_PLATFORM_VINE_CHANCE:
			add_child(TileArt.sprite([&"vine_hang_a", &"vine_hang_b"][rng.randi_range(0, 1)], Vector2(x, h - 3) * tile + Vector2(0, 5)))
	if not walled:
		_corner_posts(w)
	var size := Vector2(w, h) * tile
	var gap_left := (stairs_x - 1) * tile
	var gap_right := (stairs_x + 3) * tile
	var face_top := (h - 3) * tile
	# The underside hangs 6 px short of its row: nothing blocks where the floor shows beneath it.
	var face_height := size.y - face_top - UNDERSIDE_GAP
	# The footprint: low actors cannot enter, except by the stairs.
	_collide(Rect2(0, 0, size.x, face_top), BLOCK_LOW_BITS)
	_collide(Rect2(0, face_top, gap_left, face_height), BLOCK_LOW_BITS)
	_collide(Rect2(gap_right, face_top, size.x - gap_right, face_height), BLOCK_LOW_BITS)
	# The parapets of the stairs stop everybody.
	_collide(Rect2(gap_left, face_top, tile, size.y - face_top), WORLD_BITS)
	_collide(Rect2(gap_right - tile, face_top, tile, size.y - face_top), WORLD_BITS)
	# The edge: high actors stay on the surface and the stairs.
	_collide(Rect2(0, face_top, gap_left, face_height), BLOCK_HIGH_BITS)
	_collide(Rect2(gap_right, face_top, size.x - gap_right, face_height), BLOCK_HIGH_BITS)
	_collide(Rect2(-EDGE_THICKNESS, -EDGE_THICKNESS, size.x + EDGE_THICKNESS * 2.0, EDGE_THICKNESS), BLOCK_HIGH_BITS)
	_collide(Rect2(-EDGE_THICKNESS, 0, EDGE_THICKNESS, face_top), BLOCK_HIGH_BITS)
	_collide(Rect2(size.x, 0, EDGE_THICKNESS, face_top), BLOCK_HIGH_BITS)
	if walled:
		_rock_walls(rng, w, h)
	var zone := StairZone.new()
	zone.direction = Vector2.UP
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(tile * 2.0, tile * 3.0)
	shape.shape = rectangle
	zone.add_child(shape)
	zone.position = Vector2(stairs_x * tile + tile, face_top + tile * 1.5)
	add_child(zone)


## Tall corner posts at the two back corners of an open platform, rising above its edge like the columns
## of the concept sheet; they stop high actors too.
func _corner_posts(w: int) -> void:
	var tile := float(TileArt.TILE)
	for x in [0, w - 1]:
		add_child(TileArt.sprite(&"pillar_top", Vector2(x, -1) * tile))
		add_child(TileArt.sprite(&"pillar_base", Vector2(x, 0) * tile))
		_collide(Rect2(x * tile, 0, tile, tile), BLOCK_HIGH_BITS)


## The soft shadow a platform throws on the floor: under its face (not under the stairs, where Nico walks),
## along its open sides and at its two lower corners. Drawn first, so it lies under the platform's pieces.
func _terrace_shadows(walled: bool, w: int, h: int, stairs_x: int) -> void:
	var tile := float(TileArt.TILE)
	for x in w:
		if x < stairs_x - 1 or x > stairs_x + 2:
			add_child(TileArt.sprite(&"shadow_under", Vector2(x, h - 1) * tile))
			add_child(TileArt.sprite(&"shadow_s", Vector2(x, h) * tile))
	add_child(TileArt.sprite(&"shadow_sw", Vector2(-1, h) * tile))
	add_child(TileArt.sprite(&"shadow_se", Vector2(w, h) * tile))
	if walled:
		return
	for y in range(1, h):
		add_child(TileArt.sprite(&"shadow_w", Vector2(-1, y) * tile))
		add_child(TileArt.sprite(&"shadow_e", Vector2(w, y) * tile))


## Rock columns on the back and the sides of an alcove, standing on its border (solid for everybody).
func _rock_walls(rng: RandomNumberGenerator, w: int, h: int) -> void:
	var tile := float(TileArt.TILE)
	var walls := Node2D.new()
	walls.name = "Rocks"
	walls.y_sort_enabled = true
	add_child(walls)
	var feet: Array[Vector2] = RockWall.feet_along(Vector2(0, tile - 1.0), Vector2(w * tile, tile - 1.0), rng)
	for x in [tile / 2.0, w * tile - tile / 2.0]:
		feet.append_array(RockWall.feet_along(Vector2(x, tile * 1.5), Vector2(x, (h - 3) * tile), rng))
	for foot in feet:
		walls.add_child(RockWall.column(foot, rng))
	_collide(Rect2(0, 0, w * tile, tile), WORLD_BITS)
	_collide(Rect2(0, 0, tile, (h - 3) * tile), WORLD_BITS)
	_collide(Rect2((w - 1) * tile, 0, tile, (h - 3) * tile), WORLD_BITS)


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
