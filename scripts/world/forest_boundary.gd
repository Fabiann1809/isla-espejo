class_name ForestBoundary
extends Node2D
## Procedural dark fantasy outer forest surrounding the generated dungeon.
## Fills the black void outside and between rooms with dense dark trees,
## canopies and bushes, creating a lush, dark forest backdrop while keeping
## room interiors and corridor floors completely unobstructed.

const CELL_SIZE := Vector2(480, 288)
const CORRIDOR_LENGTH := 48.0
const STRIDE := CELL_SIZE + Vector2(CORRIDOR_LENGTH, CORRIDOR_LENGTH)
const DOOR_WIDTH := 64.0

const CANOPY_DARK_COUNT := 9
const CANOPY_SIL_COUNT := 9
const BUSH_COUNT := 30
const TREE_DARK_NAMES := ["dark_oak", "dark_round", "dark_mossy", "dark_dense", "dark_grand"]

var _dark_canopies: Array[Texture2D] = []
var _sil_canopies: Array[Texture2D] = []
var _dark_trees: Array[Texture2D] = []
var _sil_trees: Array[Texture2D] = []
var _bushes: Array[Texture2D] = []


func _init() -> void:
	z_index = -3
	_load_textures()


func _load_textures() -> void:
	for i in range(1, CANOPY_DARK_COUNT + 1):
		var path_d := "res://assets/art_forest/boundary/canopy_dark_%d.png" % i
		if ResourceLoader.exists(path_d):
			_dark_canopies.append(load(path_d))
		var path_s := "res://assets/art_forest/boundary/canopy_sil_%d.png" % i
		if ResourceLoader.exists(path_s):
			_sil_canopies.append(load(path_s))

	for tname in TREE_DARK_NAMES:
		var path_td := "res://assets/art_forest/boundary/%s.png" % tname
		if ResourceLoader.exists(path_td):
			_dark_trees.append(load(path_td))
		var path_ts := "res://assets/art_forest/boundary/%s_silhouette.png" % tname
		if ResourceLoader.exists(path_ts):
			_sil_trees.append(load(path_ts))

	for i in range(1, BUSH_COUNT + 1):
		var path_b := "res://assets/art_forest/bushes/bush_%d.png" % i
		if ResourceLoader.exists(path_b):
			_bushes.append(load(path_b))


## Generates the dark forest filling the black void and gaps between rooms.
func generate(layout: MapLayout, bounds: Rect2, seed_val: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_val + 77777)

	# 1. Build protected exclusion zones for playable areas:
	# room interiors and walkable corridor floors.
	var protected_rects: Array[Rect2] = []
	for coord: Vector2i in layout.cells:
		var origin := Vector2(coord) * STRIDE
		# Protect playable room interior (keeps 16 px walls open for forest depth)
		protected_rects.append(Rect2(origin + Vector2(16, 16), CELL_SIZE - Vector2(32, 32)))

	for coord: Vector2i in layout.cells:
		for dir in [Vector2i.RIGHT, Vector2i.DOWN]:
			if layout.are_connected(coord, coord + dir):
				var origin := Vector2(coord) * STRIDE
				if dir == Vector2i.RIGHT:
					var x := origin.x + CELL_SIZE.x - 4.0
					var y := origin.y + CELL_SIZE.y / 2.0 - DOOR_WIDTH / 2.0
					protected_rects.append(Rect2(x, y, CORRIDOR_LENGTH + 8.0, DOOR_WIDTH))
				else:
					var x := origin.x + CELL_SIZE.x / 2.0 - DOOR_WIDTH / 2.0
					var y := origin.y + CELL_SIZE.y - 4.0
					protected_rects.append(Rect2(x, y, DOOR_WIDTH, CORRIDOR_LENGTH + 8.0))

	# 2. Outer margin around bounds into the black void
	var outer_margin := 180.0
	var gen_rect := bounds.grow(outer_margin)

	# 3. Dense step to completely populate the black void and gaps
	var step := 24.0
	var y_pos := gen_rect.position.y
	while y_pos <= gen_rect.end.y:
		var x_pos := gen_rect.position.x
		while x_pos <= gen_rect.end.x:
			var jitter := Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-6.0, 6.0))
			var pt := Vector2(x_pos, y_pos) + jitter

			if not _is_protected(pt, protected_rects):
				var dist := _dist_to_rooms(pt, layout)
				if dist <= 180.0:
					_place_boundary_element(pt, dist, rng)
			x_pos += step
		y_pos += step


func _is_protected(pt: Vector2, rects: Array[Rect2]) -> bool:
	for rect in rects:
		if rect.has_point(pt):
			return true
	return false


func _dist_to_rooms(pt: Vector2, layout: MapLayout) -> float:
	var min_d := 999999.0
	for coord: Vector2i in layout.cells:
		var origin := Vector2(coord) * STRIDE
		var room_rect := Rect2(origin, CELL_SIZE)
		var dx := maxf(maxf(room_rect.position.x - pt.x, 0.0), pt.x - room_rect.end.x)
		var dy := maxf(maxf(room_rect.position.y - pt.y, 0.0), pt.y - room_rect.end.y)
		var d := sqrt(dx * dx + dy * dy)
		if d < min_d:
			min_d = d
	return min_d


func _place_boundary_element(pt: Vector2, dist: float, rng: RandomNumberGenerator) -> void:
	var sprite := Sprite2D.new()
	sprite.position = pt
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var roll := rng.randf()

	if dist > 75.0:
		# Deep silhouette layer in the distant black void
		if not _sil_trees.is_empty() and roll < 0.5:
			sprite.texture = _sil_trees[rng.randi_range(0, _sil_trees.size() - 1)]
		elif not _sil_canopies.is_empty():
			sprite.texture = _sil_canopies[rng.randi_range(0, _sil_canopies.size() - 1)]
		sprite.modulate = Color(0.45, 0.5, 0.65, 0.85)
	elif dist > 35.0:
		# Midground dark forest and undergrowth
		if roll < 0.25 and not _bushes.is_empty():
			sprite.texture = _bushes[rng.randi_range(0, _bushes.size() - 1)]
			sprite.modulate = Color(0.22, 0.35, 0.3, 0.95)
		elif roll < 0.65 and not _dark_trees.is_empty():
			sprite.texture = _dark_trees[rng.randi_range(0, _dark_trees.size() - 1)]
			sprite.modulate = Color(0.75, 0.85, 0.82, 1.0)
		elif not _dark_canopies.is_empty():
			sprite.texture = _dark_canopies[rng.randi_range(0, _dark_canopies.size() - 1)]
			sprite.modulate = Color(0.75, 0.85, 0.82, 1.0)
	else:
		# Near gaps between rooms and directly outside room walls:
		# rich dark fantasy trees, canopies and dark bushes
		if roll < 0.3 and not _bushes.is_empty():
			sprite.texture = _bushes[rng.randi_range(0, _bushes.size() - 1)]
			sprite.modulate = Color(0.3, 0.48, 0.38, 0.98)
		elif roll < 0.7 and not _dark_trees.is_empty():
			sprite.texture = _dark_trees[rng.randi_range(0, _dark_trees.size() - 1)]
			sprite.modulate = Color(0.92, 0.98, 0.95, 1.0)
		elif not _dark_canopies.is_empty():
			sprite.texture = _dark_canopies[rng.randi_range(0, _dark_canopies.size() - 1)]
			sprite.modulate = Color(0.92, 0.98, 0.95, 1.0)

	if sprite.texture != null:
		add_child(sprite)
