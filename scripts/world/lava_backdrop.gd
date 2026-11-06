class_name LavaBackdrop
extends RefCounted
## The sea of lava around a generated map of the Templo del Eclipse: animated lava on every tile that
## is not a room (the bridges cross it, so their cells are lava too), with islets of rock standing in
## it (irregular blobs with stepped cliff faces on their south side, moss, a ruin now and then), rock
## shelves along the north edge, lava falls pouring over their cliffs, smoking rocks, ember vents and
## bursting bubbles, so the space between the rooms is a living sea and not a flat orange carpet.
##
## The sea and the rooms' lava are one body: every lava tile of the map (here, the rooms' shapes and
## the bridges) is painted at `SEA_Z` with `lava_animation(cell)`, which picks the macro cell by the
## WORLD tile and one of the sheet's three edge-matched macro variants by a world-space noise, so no
## seam marks a room's rectangle and the pattern never repeats on a grid. Over all of it drift big
## plates of cooler crust (`Plates`, a tiling noise picture moved by a tween), and the sea darkens
## into cooled crust the farther it is from the islands' stone (`Crust`, one pixel per tile like the
## forest's shade; the stone is the rooms' floors, never their rectangles). Where the lava meets an
## islet a dark crust with pulsing cracks marks the shore (`lava_rim`; the rooms draw their own) and
## the feet of the cliffs are lit from below. Purely decorative (no collision: the rooms' walls and
## the bridges' rails keep everybody out of it), drawn below every floor. Same seed = same sea.
## Values: `Tuning.TEMPLE_BACKDROP_*` and `TEMPLE_LAVA_*`.
##
## Layers of the `Backdrop` node (z `SEA_Z`), in draw order: `Lava` (the animated macro), then at
## `OVER_SEA_Z` (one above, still under every floor) `Plates`, `Rim`, `Islets` (the tops and the
## upper cliff rows of the islets), `IsletEdge` (the ledge blob on their tops and small details),
## `Glow` (animated: the rim's pulse, the lava-lit cliff feet and the bubbles), `Props` (lava falls,
## smoking rocks, ruins, ember vents) and `Crust`.
##
## The animated tiles come from the temple profile's `animations` (frames side by side in one row of
## the sheet) through a TileSet of this class's own (`animated_tile_set()`): the profile's shared
## TileSet keeps one tile per cell, so animating it there would steal those cells from everybody
## else. `Level` paints the lava under its bridges with `lava_layer()` and `paint_lava()`.

## The lava macro: `<variant>_{x mod MACRO}_{y mod MACRO}` tiles together into one seamless surface.
const MACRO := 8
const VARIANTS: Array[String] = ["lava_m", "lava_m2", "lava_m3"]
const LAVA_TILE := "%s_%d_%d"
## The z of every lava layer of the map (the sea, the rooms' lava, the bridges'), two under the
## floors, and the relative z of what the backdrop lays over the lava (one under the floors).
const SEA_Z := RoomTheme.FLOOR_Z - 2
const OVER_SEA_Z := 1
## Animated tiles of the sea: name -> [frames per second, random start times].
const RIM_GLOW := &"lava_rim_glow"
const BUBBLE := &"lava_bubble_over"
const CLIFF_FOOT := &"cliff_foot_lava_%s"
const SIDES: Array[String] = ["l", "m", "r"]
## Details laid on an islet's inner cells (over the dark level-0 stone).
const DETAILS: Array[StringName] = [&"moss_over_a", &"moss_over_b", &"floor0_crack_over_a", &"floor0_crack_over_b",
		&"pebbles", &"rubble_a", &"rubble_b", &"ember_a", &"ember_b", &"ash_a", &"boulder_small"]
## Where the variant noise is seeded (a constant: a room's own lava and the sea must agree).
const VARIANT_SEED := 1917
const PLATE_SEED := 4242

## Profile path -> its animated TileSet, and -> {animation name: the tile's coordinates in it}.
static var _tile_sets := {}
static var _tiles := {}
static var _variant_noise: FastNoiseLite
static var _plate_texture: ImageTexture


## Builds the sea under `parent`. `walkable` holds the stone of the rooms (their islands' cells in
## world tiles: never lava, the crust and the rims measure from it), `taken` the corridors' tiles
## (bridges: open lava under them, nothing standing on them), `rooms` the rooms' whole rectangles
## (the rooms paint their own lava and rims there, so the sea stays out of them) and `area` is in
## tiles; islets keep clear of all of them. With no `rooms`, `walkable` is taken as the rectangles.
## Returns the `Backdrop` node.
static func build(parent: Node, area: Rect2i, walkable: Dictionary, taken: Dictionary, map_seed: int,
		rooms: Dictionary = {}) -> Node2D:
	if rooms.is_empty():
		rooms = walkable
	var root := Node2D.new()
	root.name = "Backdrop"
	root.z_index = SEA_Z
	parent.add_child(root)
	parent.move_child(root, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["lava_backdrop", map_seed])

	var lava := lava_layer("Lava")
	root.add_child(lava)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			if not rooms.has(cell) and not taken.has(cell):
				paint_lava_cell(lava, cell)
	_paint_plates(root, area)

	var islets: Array = _plant_islets(area, walkable, taken, rooms, rng) if Tuning.TEMPLE_BACKDROP_ISLETS else []
	# Every cell of rock (tops and faces), so the shore and the glow know where the islets stand.
	var rock := {}
	var feet := {}
	for islet: Dictionary in islets:
		for cell: Vector2i in islet.tops:
			rock[cell] = true
		for cell: Vector2i in islet.faces:
			rock[cell] = true
		for cell: Vector2i in islet.feet:
			feet[cell] = islet.feet[cell]
	var is_lava := func(cell: Vector2i) -> bool:
		return not area.has_point(cell) or (not walkable.has(cell) and not rock.has(cell))
	var rim := _paint_rim(root, area, walkable, taken, rooms, rock, is_lava)
	_paint_islets(root, islets, rng)
	_paint_glow(root, area, taken, rooms, rim, feet, is_lava, rng)
	_place_props(root, islets, area, walkable, taken, rooms, rock, rng)
	_paint_crust(root, area, walkable, taken, rock, map_seed)
	return root


# --- animated tiles ---------------------------------------------------------------------------------
## A TileMapLayer that paints with the animated tiles of the active profile (lava, bubbles, the rim's
## glow, the cliff feet). Not added to any parent.
static func lava_layer(layer_name: String) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.tile_set = animated_tile_set()
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.scale = Vector2.ONE * TileArt.draw_scale()
	return layer


## Fills `cells` (world tiles) of an animated layer with the flowing lava macro.
static func paint_lava(layer: TileMapLayer, cells: Rect2i) -> void:
	for y in range(cells.position.y, cells.end.y):
		for x in range(cells.position.x, cells.end.x):
			paint_lava_cell(layer, Vector2i(x, y))


## The lava tile of a world cell (see `lava_animation`).
static func paint_lava_cell(layer: TileMapLayer, cell: Vector2i) -> void:
	layer.set_cell(cell, 0, animated_tile(lava_animation(cell)))


## The animation name of the lava on a WORLD cell: its place in the macro decides the tile and a
## world-space noise picks the variant of its 8x8 block, so every lava of the map is one seamless,
## never-repeating surface (a room must pass its cells in world tiles, not its own).
static func lava_animation(cell: Vector2i) -> StringName:
	var variant := 0
	if Tuning.TEMPLE_LAVA_VARIANT_FREQUENCY > 0.0 and VARIANTS.size() > 1:
		var block := Vector2i(floori(cell.x / float(MACRO)), floori(cell.y / float(MACRO)))
		var n := variant_noise().get_noise_2d(block.x, block.y)
		variant = 0 if n < -0.12 else (1 if n < 0.12 else 2)
	var animations := TileArt.profile().animations
	var name := StringName(LAVA_TILE % [VARIANTS[variant], posmod(cell.x, MACRO), posmod(cell.y, MACRO)])
	if not animations.has(name):
		name = StringName(LAVA_TILE % [VARIANTS[0], posmod(cell.x, MACRO), posmod(cell.y, MACRO)])
	return name


static func variant_noise() -> FastNoiseLite:
	if _variant_noise == null:
		_variant_noise = FastNoiseLite.new()
		_variant_noise.seed = VARIANT_SEED
		_variant_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		_variant_noise.frequency = Tuning.TEMPLE_LAVA_VARIANT_FREQUENCY
	return _variant_noise


## The coordinates of an animated tile (its first frame) in `animated_tile_set()`; (-1, -1) if the
## active profile has no such animation.
static func animated_tile(animation: StringName) -> Vector2i:
	animated_tile_set()
	return _tiles[TileArt.profile().resource_path].get(animation, Vector2i(-1, -1))


## The TileSet with the sea's animated tiles of the active profile (built once per profile): each
## animation is one tile whose frames run along its row, all in step for the lava's flow and starting
## at random times for the glows and bubbles.
static func animated_tile_set() -> TileSet:
	var profile := TileArt.profile()
	var key := profile.resource_path
	if _tile_sets.has(key):
		return _tile_sets[key]
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(profile.tile_size, profile.tile_size)
	var source := TileSetAtlasSource.new()
	source.texture = profile.texture
	source.margins = Vector2i(profile.margin, profile.margin)
	source.separation = Vector2i(profile.separation, profile.separation)
	source.texture_region_size = Vector2i(profile.tile_size, profile.tile_size)
	var tiles := {}
	for entry in _animations():
		var animation: StringName = entry[0]
		var frames := profile.animation(animation)
		if frames.is_empty() or source.has_tile(frames[0]):
			continue
		var first := frames[0]
		# The frames must be the cells to the right of the first one (the art tool lays them out so).
		var count := 1
		while count < frames.size() and frames[count] == first + Vector2i(count, 0):
			count += 1
		source.create_tile(first)
		source.set_tile_animation_columns(first, 0)
		source.set_tile_animation_frames_count(first, count)
		for i in count:
			source.set_tile_animation_frame_duration(first, i, 1.0 / entry[1])
		source.set_tile_animation_mode(first, TileSetAtlasSource.TILE_ANIMATION_MODE_RANDOM_START_TIMES if entry[2]
				else TileSetAtlasSource.TILE_ANIMATION_MODE_DEFAULT)
		tiles[animation] = first
	tile_set.add_source(source, 0)
	_tile_sets[key] = tile_set
	_tiles[key] = tiles
	return tile_set


## [animation name, frames per second, random start] of every animated tile of the sea.
static func _animations() -> Array:
	var found := []
	for variant in VARIANTS:
		for y in MACRO:
			for x in MACRO:
				found.append([StringName(LAVA_TILE % [variant, x, y]), Tuning.TEMPLE_LAVA_FPS, false])
	found.append([RIM_GLOW, Tuning.TEMPLE_LAVA_GLOW_FPS, true])
	found.append([BUBBLE, Tuning.TEMPLE_LAVA_BUBBLE_FPS, true])
	for side in SIDES:
		found.append([StringName(CLIFF_FOOT % side), Tuning.TEMPLE_LAVA_FOOT_FPS, true])
	return found


# --- plates -----------------------------------------------------------------------------------------
## Big plates of cooler crust over every lava of the map: a tiling picture of soft dark blobs (one
## texel per TEMPLE_BACKDROP_PLATE_TEXEL px, linear filtering) that drifts slowly, each axis looping
## over the picture's period, so the drift never jumps.
static func _paint_plates(root: Node2D, area: Rect2i) -> void:
	if Tuning.TEMPLE_BACKDROP_PLATE_ALPHA <= 0.0:
		return
	var sprite := Sprite2D.new()
	sprite.name = "Plates"
	sprite.z_index = OVER_SEA_Z
	sprite.centered = false
	sprite.texture = plate_texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.region_enabled = true
	var texel := float(Tuning.TEMPLE_BACKDROP_PLATE_TEXEL)
	sprite.region_rect = Rect2(Vector2.ZERO, Vector2(area.size * TileArt.TILE) / texel)
	sprite.scale = Vector2.ONE * texel
	sprite.position = Vector2(area.position * TileArt.TILE)
	root.add_child(sprite)
	var period := float(Tuning.TEMPLE_BACKDROP_PLATE_SIZE)
	var drift := Tuning.TEMPLE_BACKDROP_PLATE_DRIFT / texel
	for axis in ["x", "y"]:
		var speed: float = absf(drift.x if axis == "x" else drift.y)
		if speed <= 0.0:
			continue
		var sign := -1.0 if (drift.x if axis == "x" else drift.y) > 0.0 else 1.0
		var tween := sprite.create_tween().set_loops()
		tween.tween_property(sprite, "region_rect:position:%s" % axis, sign * period, period / speed).from(0.0)


## The plates' picture (built once): a seamless noise, its upper TEMPLE_BACKDROP_PLATE_COVER share
## turned into the plates with a soft edge, the rest clear.
static func plate_texture() -> ImageTexture:
	if _plate_texture != null:
		return _plate_texture
	var size := Tuning.TEMPLE_BACKDROP_PLATE_SIZE
	var noise := FastNoiseLite.new()
	noise.seed = PLATE_SEED
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = Tuning.TEMPLE_BACKDROP_PLATE_FREQUENCY
	noise.fractal_octaves = 3
	var field := noise.get_seamless_image(size, size)
	var values: Array[float] = []
	values.resize(size * size)
	for y in size:
		for x in size:
			values[y * size + x] = field.get_pixel(x, y).r
	var sorted := values.duplicate()
	sorted.sort()
	var threshold: float = sorted[clampi(int((1.0 - Tuning.TEMPLE_BACKDROP_PLATE_COVER) * sorted.size()), 0, sorted.size() - 1)]
	var edge := Tuning.TEMPLE_BACKDROP_PLATE_EDGE
	var picture := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var alpha := Tuning.TEMPLE_BACKDROP_PLATE_ALPHA * smoothstep(threshold - edge, threshold + edge, values[y * size + x])
			picture.set_pixel(x, y, Color(Tuning.TEMPLE_BACKDROP_PLATE_COLOR, alpha))
	_plate_texture = ImageTexture.create_from_image(picture)
	return _plate_texture


# --- islets -----------------------------------------------------------------------------------------
## Where the rock stands: {tops: {cell: true}, faces: {cell: side}, feet: {cell: side} (the last face
## row of every column, lit by the lava), fall: pours a lava fall, shelf: hangs from the north edge}.
## Shelves first along the top of the area, then islets at random spots over it, never within
## `TEMPLE_BACKDROP_ISLET_CLEAR_TILES` of a room, a corridor or another islet.
static func _plant_islets(area: Rect2i, walkable: Dictionary, taken: Dictionary, rooms: Dictionary,
		rng: RandomNumberGenerator) -> Array:
	var islets := []
	var occupied := {}
	var clear := Tuning.TEMPLE_BACKDROP_ISLET_CLEAR_TILES
	# Shelves: their first row lies above the area, so the view cuts them and they read as the edge
	# of a bigger rock, not as islands with a top edge; their bottom wanders column by column.
	var x := area.position.x + rng.randi_range(0, Tuning.TEMPLE_BACKDROP_SHELF_GAP.y)
	while x < area.end.x:
		var width := rng.randi_range(Tuning.TEMPLE_BACKDROP_SHELF_WIDTH.x, Tuning.TEMPLE_BACKDROP_SHELF_WIDTH.y)
		if rng.randf() < Tuning.TEMPLE_BACKDROP_SHELF_CHANCE:
			var fall := rng.randf() < Tuning.TEMPLE_BACKDROP_SHELF_FALL_CHANCE
			var faces := Tuning.TEMPLE_BACKDROP_ISLET_FACE_ROWS.y if fall \
					else rng.randi_range(Tuning.TEMPLE_BACKDROP_ISLET_FACE_ROWS.x, Tuning.TEMPLE_BACKDROP_ISLET_FACE_ROWS.y)
			var tops := {}
			var depth := rng.randi_range(Tuning.TEMPLE_BACKDROP_SHELF_ROWS.x, Tuning.TEMPLE_BACKDROP_SHELF_ROWS.y)
			for column in range(x, mini(x + width, area.end.x)):
				for row in depth + 1:
					tops[Vector2i(column, area.position.y - 1 + row)] = true
				depth = clampi(depth + rng.randi_range(-1, 1), Tuning.TEMPLE_BACKDROP_SHELF_ROWS.x, Tuning.TEMPLE_BACKDROP_SHELF_ROWS.y)
			var islet := _islet(tops, faces, fall, true)
			if _fits(islet, area, walkable, taken, rooms, occupied, clear, true):
				islets.append(islet)
				_occupy(occupied, islet)
		x += width + rng.randi_range(Tuning.TEMPLE_BACKDROP_SHELF_GAP.x, Tuning.TEMPLE_BACKDROP_SHELF_GAP.y)
	# Islets: random spots, as many tries as the sea's size allows, each a blob cut from a box.
	var tries := maxi(1, area.get_area() / maxi(1, Tuning.TEMPLE_BACKDROP_ISLET_PER_TILES))
	var lo := Tuning.TEMPLE_BACKDROP_ISLET_MIN
	var hi := Tuning.TEMPLE_BACKDROP_ISLET_MAX
	var mid := (lo + hi) / 2
	for i in tries:
		var big := rng.randf() < Tuning.TEMPLE_BACKDROP_ISLET_BIG_CHANCE
		var size := Vector2i(rng.randi_range(mid.x if big else lo.x, hi.x if big else mid.x),
				rng.randi_range(mid.y if big else lo.y, hi.y if big else mid.y))
		var spot := Vector2i(rng.randi_range(area.position.x, area.end.x - size.x), rng.randi_range(area.position.y, area.end.y - size.y))
		var tops := _blob(Rect2i(spot, size), rng)
		if tops.size() < 2:
			continue
		var fall := rng.randf() < Tuning.TEMPLE_BACKDROP_FALL_CHANCE
		var faces := Tuning.TEMPLE_BACKDROP_ISLET_FACE_ROWS.y if fall \
				else rng.randi_range(Tuning.TEMPLE_BACKDROP_ISLET_FACE_ROWS.x, Tuning.TEMPLE_BACKDROP_ISLET_FACE_ROWS.y)
		var islet := _islet(tops, faces, fall, false)
		if _fits(islet, area, walkable, taken, rooms, occupied, clear, false):
			islets.append(islet)
			_occupy(occupied, islet)
	return islets


## The cells of an irregular blob inside `box`: an ellipse whose radius swells and shrinks around it
## (two waves of random phase), trimmed to the piece joined to its middle.
static func _blob(box: Rect2i, rng: RandomNumberGenerator) -> Dictionary:
	var center := Vector2(box.position) + Vector2(box.size) / 2.0
	var radius := Vector2(box.size) / 2.0
	var waves := [[rng.randf_range(0.15, 0.3), rng.randf_range(0.0, TAU)], [rng.randf_range(0.1, 0.22), rng.randf_range(0.0, TAU)]]
	var cells := {}
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var p := (Vector2(x, y) + Vector2(0.5, 0.5) - center) / radius
			var angle := p.angle()
			var swell: float = 1.0 + waves[0][0] * sin(2.0 * angle + waves[0][1]) + waves[1][0] * sin(3.0 * angle + waves[1][1])
			if p.length() <= swell - 0.14:
				cells[Vector2i(x, y)] = true
	# Keep what is joined to the cell nearest the middle (a wave can pinch a corner off).
	var start := Vector2i(center.floor())
	if not cells.has(start):
		var best := 99.0
		for cell: Vector2i in cells:
			var d := (Vector2(cell) + Vector2(0.5, 0.5)).distance_to(center)
			if d < best:
				best = d
				start = cell
	var joined := {}
	var frontier: Array[Vector2i] = [start]
	joined[start] = true
	var head := 0
	while head < frontier.size():
		var cell := frontier[head]
		head += 1
		for step in MapLayout.DIRS:
			var next: Vector2i = cell + step
			if cells.has(next) and not joined.has(next):
				joined[next] = true
				frontier.append(next)
	return joined


## An islet from its top cells: `face_rows` rows of cliff under the lowest top of every column, the
## last row of each the lava-lit foot, sides by which neighbours are cliff too.
static func _islet(tops: Dictionary, face_rows: int, fall: bool, shelf: bool) -> Dictionary:
	var bottom := {}
	for cell: Vector2i in tops:
		bottom[cell.x] = maxi(bottom.get(cell.x, cell.y), cell.y)
	var faces := {}
	var feet := {}
	for x: int in bottom:
		for row in face_rows:
			var cell := Vector2i(x, bottom[x] + 1 + row)
			if row == face_rows - 1:
				feet[cell] = "m"
			else:
				faces[cell] = "m"
	for dict: Dictionary in [faces, feet]:
		for cell: Vector2i in dict:
			var left := faces.has(cell + Vector2i.LEFT) or feet.has(cell + Vector2i.LEFT)
			var right := faces.has(cell + Vector2i.RIGHT) or feet.has(cell + Vector2i.RIGHT)
			dict[cell] = "m" if left == right else ("l" if right else "r")
	return {"tops": tops, "faces": faces, "feet": feet, "fall": fall, "shelf": shelf, "bottom": bottom}


## Top and faces together.
static func _footprint(islet: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for dict: Dictionary in [islet.tops, islet.faces, islet.feet]:
		for cell: Vector2i in dict:
			cells.append(cell)
	return cells


## True if the islet lies inside the area (a shelf may stick out above it) with `clear` tiles of open
## lava between it and every room, corridor and other islet.
static func _fits(islet: Dictionary, area: Rect2i, walkable: Dictionary, taken: Dictionary, rooms: Dictionary,
		occupied: Dictionary, clear: int, shelf: bool) -> bool:
	var inside := area if not shelf else Rect2i(area.position - Vector2i(0, 1), area.size + Vector2i(0, 1))
	for cell in _footprint(islet):
		if not inside.has_point(cell):
			return false
		for dy in range(-clear, clear + 1):
			for dx in range(-clear, clear + 1):
				var near := cell + Vector2i(dx, dy)
				if walkable.has(near) or taken.has(near) or rooms.has(near) or occupied.has(near):
					return false
	return true


static func _occupy(occupied: Dictionary, islet: Dictionary) -> void:
	for cell in _footprint(islet):
		occupied[cell] = true


## The islets' tops (dark level-0 stone with a ledge along the edge) and their cliff faces: for one
## row of face only its lava-lit foot (animated, in the Glow layer); for more, a carved top row, plain
## courses between and the foot. A few faces carry moss, and inner cells a detail.
static func _paint_islets(root: Node2D, islets: Array, rng: RandomNumberGenerator) -> void:
	var layer := TileMapLayer.new()
	layer.name = "Islets"
	layer.z_index = OVER_SEA_Z
	TileArt.prepare_layer(layer)
	layer.modulate = Tuning.TEMPLE_BACKDROP_ISLET_TINT
	root.add_child(layer)
	var edge := TileMapLayer.new()
	edge.name = "IsletEdge"
	edge.z_index = OVER_SEA_Z
	TileArt.prepare_layer(edge)
	edge.modulate = Tuning.TEMPLE_BACKDROP_ISLET_TINT
	root.add_child(edge)
	var tops := {}
	for islet: Dictionary in islets:
		for cell: Vector2i in islet.tops:
			tops[cell] = true
	var on_top := func(cell: Vector2i) -> bool: return tops.has(cell)
	for islet: Dictionary in islets:
		var mossy := rng.randf() < Tuning.TEMPLE_BACKDROP_MOSS_CHANCE
		for cell: Vector2i in islet.tops:
			layer.set_cell(cell, 0, TileArt.coords(StringName("floor0_m_%d_%d" % [posmod(cell.x, 4), posmod(cell.y, 4)])))
			var mask := TileArt.blob_mask(on_top, cell)
			if mask != 255:
				edge.set_cell(cell, 0, TileArt.blob47_tile(&"ledge", mask))
			elif rng.randf() < Tuning.TEMPLE_BACKDROP_DETAIL_CHANCE:
				edge.set_cell(cell, 0, TileArt.coords(DETAILS[rng.randi_range(0, DETAILS.size() - 1)]))
		for cell: Vector2i in islet.faces:
			var first: bool = islet.tops.has(cell + Vector2i.UP)
			var tile := ("cliff_moss2_top_" if mossy else "cliff_face2_top_") if first else "cliff_face_mid_"
			layer.set_cell(cell, 0, TileArt.coords(StringName(tile + islet.faces[cell])))


# --- shore and glow ---------------------------------------------------------------------------------
## The crust where the lava touches an islet: the `lava_rim` blob on the lava cells beside it (a
## bridge counts as lava, so the sea runs open under it; a room draws its own rims). Returns the rim
## cells.
static func _paint_rim(root: Node2D, area: Rect2i, walkable: Dictionary, taken: Dictionary, rooms: Dictionary,
		rock: Dictionary, is_lava: Callable) -> Dictionary:
	var layer := TileMapLayer.new()
	layer.name = "Rim"
	layer.z_index = OVER_SEA_Z
	TileArt.prepare_layer(layer)
	root.add_child(layer)
	var rim := {}
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			if walkable.has(cell) or taken.has(cell) or rooms.has(cell) or rock.has(cell):
				continue
			var mask := TileArt.blob_mask(is_lava, cell)
			if mask == 255:
				continue
			layer.set_cell(cell, 0, TileArt.blob47_tile(&"lava_rim", mask))
			rim[cell] = mask
	return rim


## The animated pieces of the sea: the rim's pulsing cracks, the lava-lit feet of the cliffs and a
## few bubbles bursting out in the open lava.
static func _paint_glow(root: Node2D, area: Rect2i, taken: Dictionary, rooms: Dictionary, rim: Dictionary,
		feet: Dictionary, is_lava: Callable, rng: RandomNumberGenerator) -> void:
	var layer := lava_layer("Glow")
	layer.z_index = OVER_SEA_Z
	root.add_child(layer)
	for cell: Vector2i in rim:
		layer.set_cell(cell, 0, animated_tile(RIM_GLOW))
	for cell: Vector2i in feet:
		layer.set_cell(cell, 0, animated_tile(StringName(CLIFF_FOOT % feet[cell])))
	var bubble := animated_tile(BUBBLE)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			if rng.randf() >= Tuning.TEMPLE_BACKDROP_BUBBLE_CHANCE:
				continue
			if taken.has(cell) or rooms.has(cell) or rim.has(cell) or not is_lava.call(cell) or TileArt.blob_mask(is_lava, cell) != 255:
				continue
			layer.set_cell(cell, 0, bubble)


# --- props ------------------------------------------------------------------------------------------
## Lava falls pouring over the cliffs of the islets and shelves that have one, smoking rocks, ruins
## (a broken column, a brazier) and ember vents on the islets, and lone smoking rocks half sunk in
## the open lava.
static func _place_props(root: Node2D, islets: Array, area: Rect2i, walkable: Dictionary, taken: Dictionary,
		rooms: Dictionary, rock: Dictionary, rng: RandomNumberGenerator) -> void:
	var props := Node2D.new()
	props.name = "Props"
	props.z_index = OVER_SEA_Z
	root.add_child(props)
	var tile := float(TileArt.TILE)
	var prop_script: GDScript = load("res://scripts/world/temple_prop.gd")
	var kinds: Dictionary = prop_script.get_script_constant_map()["Kind"]
	for islet: Dictionary in islets:
		var tops: Dictionary = islet.tops
		if islet.fall and not islet.feet.is_empty():
			# Over the deepest column of cliff, its splash on the lava under the foot.
			var columns: Array = islet.feet.keys()
			var foot_cell: Vector2i = columns[rng.randi_range(0, columns.size() - 1)]
			var foot := Vector2((foot_cell.x + 0.5) * tile, (foot_cell.y + 1) * tile + Tuning.TEMPLE_BACKDROP_FALL_FOOT)
			_add_prop(props, prop_script, kinds["LAVA_FALL"], foot, rng)
		# Pieces stand on a top cell with top below it too, so nothing hangs over the ledge.
		var standing: Array[Vector2i] = []
		var inner: Array[Vector2i] = []
		for cell: Vector2i in tops:
			if tops.has(cell + Vector2i.DOWN):
				standing.append(cell)
			if TileArt.blob_mask(func(c: Vector2i) -> bool: return tops.has(c), cell) == 255:
				inner.append(cell)
		if rng.randf() < Tuning.TEMPLE_BACKDROP_ROCK_CHANCE and not standing.is_empty():
			var cell: Vector2i = standing.pop_at(rng.randi_range(0, standing.size() - 1))
			_add_prop(props, prop_script, kinds["ROCK_SMOKING"], Vector2(cell) * tile + Vector2(tile / 2.0, tile - 4.0), rng)
		if rng.randf() < Tuning.TEMPLE_BACKDROP_RUIN_CHANCE and not standing.is_empty():
			var cell: Vector2i = standing.pop_at(rng.randi_range(0, standing.size() - 1))
			var kind: int = kinds["COLUMN_BROKEN"] if rng.randf() < 0.7 else kinds["BRAZIER"]
			_add_prop(props, prop_script, kind, Vector2(cell) * tile + Vector2(tile / 2.0, tile - 4.0), rng)
		# Vents crack the inner cells; a thin islet with none uses its standing cells.
		for cell in (inner if not inner.is_empty() else standing):
			if rng.randf() < Tuning.TEMPLE_BACKDROP_VENT_CHANCE:
				_add_prop(props, prop_script, kinds["EMBER_VENT"], Vector2(cell) * tile + Vector2(tile / 2.0, tile - 4.0), rng)
	# Lone rocks out in the sea, two tiles of open lava around each.
	var tries := maxi(1, area.get_area() / maxi(1, Tuning.TEMPLE_BACKDROP_ISLET_PER_TILES))
	for i in tries:
		if rng.randf() >= Tuning.TEMPLE_BACKDROP_LONE_ROCK_CHANCE:
			continue
		var cell := Vector2i(rng.randi_range(area.position.x, area.end.x - 2), rng.randi_range(area.position.y, area.end.y - 1))
		if not _open_lava(Rect2i(cell, Vector2i(2, 1)).grow(2), area, walkable, taken, rooms, rock):
			continue
		_add_prop(props, prop_script, kinds["ROCK_SMOKING"], Vector2(cell) * tile + Vector2(tile, tile - 2.0), rng)


## True if every cell of `rect` is open lava inside the area.
static func _open_lava(rect: Rect2i, area: Rect2i, walkable: Dictionary, taken: Dictionary, rooms: Dictionary,
		rock: Dictionary) -> bool:
	if not area.encloses(rect):
		return false
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell := Vector2i(x, y)
			if walkable.has(cell) or taken.has(cell) or rooms.has(cell) or rock.has(cell):
				return false
	return true


## A TempleProp of `kind` with its foot at `foot`. A flat kind (ember vents) puts itself one z level
## down to lie under the actors; here everything is already below the floors, so a holder lifts it
## back to the props' own level and it is drawn after the islets, by tree order.
static func _add_prop(parent: Node2D, prop_script: GDScript, kind: int, foot: Vector2, rng: RandomNumberGenerator) -> Node2D:
	var prop: Node2D = prop_script.new()
	prop.kind = kind
	prop.flip = rng.randf() < 0.5
	prop.position = foot.round()
	if kind in prop_script.get_script_constant_map()["FLOOR_KINDS"]:
		var holder := Node2D.new()
		holder.z_index = -RoomTheme.GROUND_FX_Z
		holder.add_child(prop)
		parent.add_child(holder)
	else:
		parent.add_child(prop)
	return prop


# --- crust ------------------------------------------------------------------------------------------
## The sea darkens away from the stone: a picture with one pixel per tile (linear filtering stretches
## it smoothly), clear over the islands' stone, the bridges and the lava beside them, darkening to
## `TEMPLE_BACKDROP_CRUST_ALPHA` with a wobbly edge and mottled by a slower noise (cooled regions
## darker, channels lighter), over everything else, the rooms' own lava included; the islets' rock
## takes only a share of it, so they stand out of the dark sea.
static func _paint_crust(root: Node2D, area: Rect2i, walkable: Dictionary, taken: Dictionary, rock: Dictionary,
		map_seed: int) -> void:
	if Tuning.TEMPLE_BACKDROP_CRUST_ALPHA <= 0.0:
		return
	var depth := _depths(area, walkable, taken)
	var noise := FastNoiseLite.new()
	noise.seed = map_seed
	noise.frequency = Tuning.TEMPLE_BACKDROP_CRUST_FREQUENCY
	noise.fractal_octaves = 2
	var mottle := FastNoiseLite.new()
	mottle.seed = map_seed + 1
	mottle.frequency = Tuning.TEMPLE_BACKDROP_CRUST_FREQUENCY * 0.5
	var picture := Image.create_empty(area.size.x, area.size.y, false, Image.FORMAT_RGBA8)
	for y in area.size.y:
		for x in area.size.x:
			var cell := area.position + Vector2i(x, y)
			var alpha := 0.0
			if not walkable.has(cell) and not taken.has(cell):
				var d: float = depth.get(cell, Tuning.TEMPLE_BACKDROP_DEPTH + 1) + noise.get_noise_2d(cell.x, cell.y) * Tuning.TEMPLE_BACKDROP_CRUST_WOBBLE
				var far := smoothstep(Tuning.TEMPLE_BACKDROP_CRUST_NEAR_TILES, Tuning.TEMPLE_BACKDROP_CRUST_FAR_TILES, d)
				var mottled := 1.0 + Tuning.TEMPLE_BACKDROP_CRUST_MOTTLE * mottle.get_noise_2d(cell.x, cell.y)
				alpha = clampf(Tuning.TEMPLE_BACKDROP_CRUST_ALPHA * far * mottled, 0.0, 1.0)
				if rock.has(cell):
					alpha *= Tuning.TEMPLE_BACKDROP_CRUST_ON_ROCK
			picture.set_pixel(x, y, Color(Tuning.TEMPLE_BACKDROP_CRUST_COLOR, alpha))
	var sprite := Sprite2D.new()
	sprite.name = "Crust"
	sprite.z_index = OVER_SEA_Z
	sprite.centered = false
	sprite.texture = ImageTexture.create_from_image(picture)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = Vector2.ONE * TileArt.TILE
	sprite.position = Vector2(area.position * TileArt.TILE)
	root.add_child(sprite)


## Tiles from the nearest stone or bridge (breadth first, up to `TEMPLE_BACKDROP_DEPTH`).
static func _depths(area: Rect2i, walkable: Dictionary, taken: Dictionary) -> Dictionary:
	var depth := {}
	var frontier: Array[Vector2i] = []
	for source: Dictionary in [walkable, taken]:
		for cell: Vector2i in source:
			if area.has_point(cell) and not depth.has(cell):
				depth[cell] = 0
				frontier.append(cell)
	var index := 0
	while index < frontier.size():
		var cell := frontier[index]
		index += 1
		if depth[cell] >= Tuning.TEMPLE_BACKDROP_DEPTH:
			continue
		for step in MapLayout.DIRS:
			var next: Vector2i = cell + step
			if area.has_point(next) and not depth.has(next):
				depth[next] = depth[cell] + 1
				frontier.append(next)
	return depth
