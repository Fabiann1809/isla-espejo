class_name LavaBackdrop
extends RefCounted
## The sea of lava around a generated map of the Templo del Eclipse: animated lava on every tile that
## is not a room (the bridges cross it, so their cells are lava too), with islets of rock standing in
## it, rock shelves along the north edge, lava falls pouring over their cliffs, smoking rocks, ember
## vents and bursting bubbles, so the space between the rooms is a living sea and not a flat orange
## carpet. Where the lava meets a room or an islet a dark crust with pulsing cracks marks the shore
## (`lava_rim`), the feet of the cliffs are lit from below, and the sea darkens into cooled crust the
## farther it is from the way (`Crust`, one pixel per tile like the forest's shade), so the rooms and
## bridges read bright and the far sea dark with glowing channels. Purely decorative (no collision:
## the rooms' walls and the bridges' rails keep everybody out of it), drawn below every floor.
## Same seed = same sea. Values: `Tuning.TEMPLE_BACKDROP_*` and `TEMPLE_LAVA_*`.
##
## Layers of the `Backdrop` node, in draw order: `Lava` (the animated 4x4 macro), `Rim` (the crust
## blob on the lava cells beside a shore), `Islets` (the tops and the upper cliff rows of the islets),
## `IsletEdge` (the ledge blob on their tops and small details), `Glow` (animated: the rim's pulse, the
## lava-lit cliff feet and the bubbles), `Props` (lava falls, smoking rocks, ember vents) and `Crust`.
##
## The animated tiles come from the temple profile's `animations` (frames side by side in one row of
## the sheet) through a TileSet of this class's own (`animated_tile_set()`): the profile's shared
## TileSet keeps one tile per cell, so animating it there would steal those cells from everybody
## else. `Level` paints the lava under its bridges with `lava_layer()` and `paint_lava()`.

## The lava macro: `lava_m_{x mod MACRO}_{y mod MACRO}` tiles together into one seamless surface.
const MACRO := 4
## Animated tiles of the sea: name -> [frames per second, random start times].
const LAVA_TILE := &"lava_m_%d_%d"
const RIM_GLOW := &"lava_rim_glow"
const BUBBLE := &"lava_bubble_over"
const CLIFF_FOOT := &"cliff_foot_lava_%s"
const SIDES: Array[String] = ["l", "m", "r"]
## Details laid on an islet's inner cells (over the dark level-0 stone).
const DETAILS: Array[StringName] = [&"moss_over_a", &"moss_over_b", &"floor0_crack_over_a", &"floor0_crack_over_b",
		&"pebbles", &"rubble_a", &"rubble_b", &"ember_a", &"ember_b", &"ash_a", &"boulder_small"]

## Profile path -> its animated TileSet, and -> {animation name: the tile's coordinates in it}.
static var _tile_sets := {}
static var _tiles := {}


## Builds the sea under `parent`. `walkable` holds the rooms' tiles (islands: never lava), `taken`
## the corridors' tiles (bridges: open lava under them, nothing standing on them) and `area` is in
## tiles; islets keep clear of both. Returns the `Backdrop` node.
static func build(parent: Node, area: Rect2i, walkable: Dictionary, taken: Dictionary, map_seed: int) -> Node2D:
	var root := Node2D.new()
	root.name = "Backdrop"
	root.z_index = RoomTheme.FLOOR_Z - 1
	parent.add_child(root)
	parent.move_child(root, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["lava_backdrop", map_seed])

	var lava := lava_layer("Lava")
	root.add_child(lava)
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			if not walkable.has(cell) and not taken.has(cell):
				paint_lava_cell(lava, cell)

	var islets: Array = _plant_islets(area, walkable, taken, rng) if Tuning.TEMPLE_BACKDROP_ISLETS else []
	# Every cell of rock (tops and faces), so the shore and the glow know where the islets stand.
	var rock := {}
	var feet := {}
	for islet: Dictionary in islets:
		for cell in _cells_of(islet.rect):
			rock[cell] = true
		for cell in _cells_of(_faces_of(islet)):
			rock[cell] = true
		var faces: Rect2i = _faces_of(islet)
		for x in range(faces.position.x, faces.end.x):
			feet[Vector2i(x, faces.end.y - 1)] = _side(x, faces)
	var is_lava := func(cell: Vector2i) -> bool:
		return not area.has_point(cell) or (not walkable.has(cell) and not rock.has(cell))
	var rim := _paint_rim(root, area, walkable, taken, rock, is_lava)
	_paint_islets(root, islets, rock, rng)
	_paint_glow(root, area, taken, rim, feet, is_lava, rng)
	_place_props(root, islets, area, walkable, taken, rock, is_lava, rng)
	_paint_crust(root, area, walkable, taken, map_seed)
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


## The lava tile of a world cell: its place in the 4x4 macro decides which one, so the sea is seamless.
static func paint_lava_cell(layer: TileMapLayer, cell: Vector2i) -> void:
	layer.set_cell(cell, 0, animated_tile(StringName(LAVA_TILE % [posmod(cell.x, MACRO), posmod(cell.y, MACRO)])))


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
	for y in MACRO:
		for x in MACRO:
			found.append([StringName(LAVA_TILE % [x, y]), Tuning.TEMPLE_LAVA_FPS, false])
	found.append([RIM_GLOW, Tuning.TEMPLE_LAVA_GLOW_FPS, true])
	found.append([BUBBLE, Tuning.TEMPLE_LAVA_BUBBLE_FPS, true])
	for side in SIDES:
		found.append([StringName(CLIFF_FOOT % side), Tuning.TEMPLE_LAVA_FOOT_FPS, true])
	return found


# --- islets -----------------------------------------------------------------------------------------
## Where the rock stands: {rect: the top cells, faces: rows of cliff under it, fall: pours a lava fall,
## shelf: hangs from the north edge}. Shelves first along the top of the area, then islets scattered
## over it, never within `TEMPLE_BACKDROP_ISLET_CLEAR_TILES` of a room, a corridor or another islet.
static func _plant_islets(area: Rect2i, walkable: Dictionary, taken: Dictionary, rng: RandomNumberGenerator) -> Array:
	var islets := []
	var occupied := {}
	var clear := Tuning.TEMPLE_BACKDROP_ISLET_CLEAR_TILES
	# Shelves: their first row lies above the area, so the view cuts them and they read as the edge
	# of a bigger rock, not as islands with a top edge.
	var x := area.position.x + rng.randi_range(0, Tuning.TEMPLE_BACKDROP_SHELF_GAP.y)
	while x < area.end.x:
		var width := rng.randi_range(Tuning.TEMPLE_BACKDROP_SHELF_WIDTH.x, Tuning.TEMPLE_BACKDROP_SHELF_WIDTH.y)
		if rng.randf() < Tuning.TEMPLE_BACKDROP_SHELF_CHANCE:
			var rows := rng.randi_range(Tuning.TEMPLE_BACKDROP_SHELF_ROWS.x, Tuning.TEMPLE_BACKDROP_SHELF_ROWS.y)
			var fall := rng.randf() < Tuning.TEMPLE_BACKDROP_SHELF_FALL_CHANCE
			var islet := {
				"rect": Rect2i(x, area.position.y - 1, mini(width, area.end.x - x), 1 + rows),
				"faces": Tuning.TEMPLE_BACKDROP_ISLET_FACE_ROWS.y if fall \
						else rng.randi_range(Tuning.TEMPLE_BACKDROP_ISLET_FACE_ROWS.x, Tuning.TEMPLE_BACKDROP_ISLET_FACE_ROWS.y),
				"fall": fall,
				"shelf": true,
			}
			if _fits(islet, area, walkable, taken, occupied, clear, true):
				islets.append(islet)
				_occupy(occupied, islet)
		x += width + rng.randi_range(Tuning.TEMPLE_BACKDROP_SHELF_GAP.x, Tuning.TEMPLE_BACKDROP_SHELF_GAP.y)
	# Islets on a jittered grid of spots.
	var step := Tuning.TEMPLE_BACKDROP_ISLET_STEP
	var jitter := Tuning.TEMPLE_BACKDROP_ISLET_JITTER
	var y := area.position.y
	while y < area.end.y:
		x = area.position.x
		while x < area.end.x:
			var spot := Vector2i(x + rng.randi_range(-jitter, jitter), y + rng.randi_range(-jitter, jitter))
			x += step
			if rng.randf() >= Tuning.TEMPLE_BACKDROP_ISLET_CHANCE:
				continue
			var fall := rng.randf() < Tuning.TEMPLE_BACKDROP_FALL_CHANCE
			var size := Vector2i(rng.randi_range(Tuning.TEMPLE_BACKDROP_ISLET_MIN.x, Tuning.TEMPLE_BACKDROP_ISLET_MAX.x),
					rng.randi_range(Tuning.TEMPLE_BACKDROP_ISLET_MIN.y, Tuning.TEMPLE_BACKDROP_ISLET_MAX.y))
			var faces := Tuning.TEMPLE_BACKDROP_ISLET_FACE_ROWS.y if fall \
					else rng.randi_range(Tuning.TEMPLE_BACKDROP_ISLET_FACE_ROWS.x, Tuning.TEMPLE_BACKDROP_ISLET_FACE_ROWS.y)
			var islet := {"rect": Rect2i(spot, size), "faces": faces, "fall": fall, "shelf": false}
			if _fits(islet, area, walkable, taken, occupied, clear, false):
				islets.append(islet)
				_occupy(occupied, islet)
		y += step
	return islets


## The cliff rows under an islet's top.
static func _faces_of(islet: Dictionary) -> Rect2i:
	var rect: Rect2i = islet.rect
	return Rect2i(rect.position + Vector2i(0, rect.size.y), Vector2i(rect.size.x, islet.faces))


## Top and faces together.
static func _footprint(islet: Dictionary) -> Rect2i:
	return (islet.rect as Rect2i).merge(_faces_of(islet))


## True if the islet lies inside the area (a shelf may stick out above it) with `clear` tiles of open
## lava between it and every room, corridor and other islet.
static func _fits(islet: Dictionary, area: Rect2i, walkable: Dictionary, taken: Dictionary, occupied: Dictionary,
		clear: int, shelf: bool) -> bool:
	var footprint := _footprint(islet)
	var inside := area if not shelf else Rect2i(area.position - Vector2i(0, 1), area.size + Vector2i(0, 1))
	if not inside.encloses(footprint):
		return false
	var grown := footprint.grow(clear)
	for y in range(grown.position.y, grown.end.y):
		for x in range(grown.position.x, grown.end.x):
			var cell := Vector2i(x, y)
			if walkable.has(cell) or taken.has(cell) or occupied.has(cell):
				return false
	return true


static func _occupy(occupied: Dictionary, islet: Dictionary) -> void:
	for cell in _cells_of(_footprint(islet)):
		occupied[cell] = true


static func _cells_of(rect: Rect2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			cells.append(Vector2i(x, y))
	return cells


## Which cliff tile a column of a face uses: the left end, the middle or the right end.
static func _side(x: int, faces: Rect2i) -> String:
	if faces.size.x == 1:
		return "m"
	return "l" if x == faces.position.x else ("r" if x == faces.end.x - 1 else "m")


## The islets' tops (dark level-0 stone with a ledge along the edge) and their cliff faces: for one
## row of face only its lava-lit foot (animated, in the Glow layer); for more, a carved top row, plain
## courses between and the foot. A few faces carry moss, and inner cells a detail.
static func _paint_islets(root: Node2D, islets: Array, rock: Dictionary, rng: RandomNumberGenerator) -> void:
	var layer := TileMapLayer.new()
	layer.name = "Islets"
	TileArt.prepare_layer(layer)
	layer.modulate = Tuning.TEMPLE_BACKDROP_ISLET_TINT
	root.add_child(layer)
	var edge := TileMapLayer.new()
	edge.name = "IsletEdge"
	TileArt.prepare_layer(edge)
	edge.modulate = Tuning.TEMPLE_BACKDROP_ISLET_TINT
	root.add_child(edge)
	var tops := {}
	for islet: Dictionary in islets:
		for cell in _cells_of(islet.rect):
			tops[cell] = true
	var on_top := func(cell: Vector2i) -> bool: return tops.has(cell)
	for islet: Dictionary in islets:
		var rect: Rect2i = islet.rect
		var mossy := rng.randf() < Tuning.TEMPLE_BACKDROP_MOSS_CHANCE
		for cell in _cells_of(rect):
			layer.set_cell(cell, 0, TileArt.coords(StringName("floor0_m_%d_%d" % [posmod(cell.x, MACRO), posmod(cell.y, MACRO)])))
			var mask := TileArt.blob_mask(on_top, cell)
			if mask != 255:
				edge.set_cell(cell, 0, TileArt.blob47_tile(&"ledge", mask))
			elif rng.randf() < Tuning.TEMPLE_BACKDROP_DETAIL_CHANCE:
				edge.set_cell(cell, 0, TileArt.coords(DETAILS[rng.randi_range(0, DETAILS.size() - 1)]))
		var faces := _faces_of(islet)
		for row in faces.size.y - 1:
			for x in range(faces.position.x, faces.end.x):
				var side := _side(x, faces)
				var tile: String
				if row == 0:
					tile = ("cliff_moss2_top_" if mossy else "cliff_face2_top_") + side
				else:
					tile = "cliff_face_mid_" + side
				layer.set_cell(Vector2i(x, faces.position.y + row), 0, TileArt.coords(StringName(tile)))


# --- shore and glow ---------------------------------------------------------------------------------
## The crust where the lava touches a room or an islet: the `lava_rim` blob on the lava cells beside
## them (a bridge counts as lava, so the sea runs open under it). Returns the rim cells.
static func _paint_rim(root: Node2D, area: Rect2i, walkable: Dictionary, taken: Dictionary, rock: Dictionary,
		is_lava: Callable) -> Dictionary:
	var layer := TileMapLayer.new()
	layer.name = "Rim"
	TileArt.prepare_layer(layer)
	root.add_child(layer)
	var rim := {}
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			if walkable.has(cell) or taken.has(cell) or rock.has(cell):
				continue
			var mask := TileArt.blob_mask(is_lava, cell)
			if mask == 255:
				continue
			layer.set_cell(cell, 0, TileArt.blob47_tile(&"lava_rim", mask))
			rim[cell] = mask
	return rim


## The animated pieces of the sea: the rim's pulsing cracks, the lava-lit feet of the cliffs and a
## few bubbles bursting out in the open lava.
static func _paint_glow(root: Node2D, area: Rect2i, taken: Dictionary, rim: Dictionary, feet: Dictionary,
		is_lava: Callable, rng: RandomNumberGenerator) -> void:
	var layer := lava_layer("Glow")
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
			if taken.has(cell) or rim.has(cell) or not is_lava.call(cell) or TileArt.blob_mask(is_lava, cell) != 255:
				continue
			layer.set_cell(cell, 0, bubble)


# --- props ------------------------------------------------------------------------------------------
## Lava falls pouring over the cliffs of the islets and shelves that have one, smoking rocks and ember
## vents on the islets, and lone smoking rocks half sunk in the open lava.
static func _place_props(root: Node2D, islets: Array, area: Rect2i, walkable: Dictionary, taken: Dictionary,
		rock: Dictionary, is_lava: Callable, rng: RandomNumberGenerator) -> void:
	var props := Node2D.new()
	props.name = "Props"
	root.add_child(props)
	var tile := float(TileArt.TILE)
	var prop_script: GDScript = load("res://scripts/world/temple_prop.gd")
	var kinds: Dictionary = prop_script.get_script_constant_map()["Kind"]
	for islet: Dictionary in islets:
		var rect: Rect2i = islet.rect
		var faces := _faces_of(islet)
		if islet.fall:
			var column: int = rng.randi_range(faces.position.x, faces.end.x - 1)
			var foot := Vector2((column + 0.5) * tile, faces.end.y * tile + Tuning.TEMPLE_BACKDROP_FALL_FOOT)
			_add_prop(props, prop_script, kinds["LAVA_FALL"], foot, rng)
		if rng.randf() < Tuning.TEMPLE_BACKDROP_ROCK_CHANCE:
			# Standing on the top, its base on the row above the cliff (never over the fall's lip).
			var column: int = rng.randi_range(rect.position.x, rect.end.x - 1)
			var foot := Vector2((column + 0.5) * tile, (rect.end.y - 0.5) * tile + 4.0)
			_add_prop(props, prop_script, kinds["ROCK_SMOKING"], foot, rng)
		# Vents crack the inner cells; a thin islet with none uses its top cells.
		var inner := _cells_of(rect.grow(-1))
		for cell in (inner if not inner.is_empty() else _cells_of(rect)):
			if rng.randf() < Tuning.TEMPLE_BACKDROP_VENT_CHANCE:
				_add_prop(props, prop_script, kinds["EMBER_VENT"], Vector2(cell) * tile + Vector2(tile / 2.0, tile - 4.0), rng)
	# Lone rocks out in the sea, two tiles of open lava around each.
	var step := Tuning.TEMPLE_BACKDROP_ISLET_STEP
	var y := area.position.y + step / 2
	while y < area.end.y:
		var x := area.position.x + step / 2
		while x < area.end.x:
			var cell := Vector2i(x + rng.randi_range(-2, 2), y + rng.randi_range(-2, 2))
			x += step
			if rng.randf() >= Tuning.TEMPLE_BACKDROP_LONE_ROCK_CHANCE:
				continue
			if not _open_lava(Rect2i(cell, Vector2i(2, 1)).grow(2), area, walkable, taken, rock):
				continue
			_add_prop(props, prop_script, kinds["ROCK_SMOKING"], Vector2(cell) * tile + Vector2(tile, tile - 2.0), rng)
		y += step


## True if every cell of `rect` is open lava inside the area.
static func _open_lava(rect: Rect2i, area: Rect2i, walkable: Dictionary, taken: Dictionary, rock: Dictionary) -> bool:
	if not area.encloses(rect):
		return false
	for cell in _cells_of(rect):
		if walkable.has(cell) or taken.has(cell) or rock.has(cell):
			return false
	return true


## A TempleProp of `kind` with its foot at `foot`. A flat kind (ember vents) puts itself one z level
## down to lie under the actors; here everything is already below the floors, so a holder lifts it
## back to the sea's own level and it is drawn after the lava, by tree order.
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
## The sea darkens away from the way: a picture with one pixel per tile (linear filtering stretches it
## smoothly), clear over the rooms, the bridges and the lava beside them, and darkening to
## `TEMPLE_BACKDROP_CRUST_ALPHA` with a wobbly edge, over everything else in the backdrop.
static func _paint_crust(root: Node2D, area: Rect2i, walkable: Dictionary, taken: Dictionary, map_seed: int) -> void:
	if Tuning.TEMPLE_BACKDROP_CRUST_ALPHA <= 0.0:
		return
	var depth := _depths(area, walkable, taken)
	var noise := FastNoiseLite.new()
	noise.seed = map_seed
	noise.frequency = Tuning.TEMPLE_BACKDROP_CRUST_FREQUENCY
	var picture := Image.create_empty(area.size.x, area.size.y, false, Image.FORMAT_RGBA8)
	for y in area.size.y:
		for x in area.size.x:
			var cell := area.position + Vector2i(x, y)
			var alpha := 0.0
			if not walkable.has(cell) and not taken.has(cell):
				var d: float = depth.get(cell, Tuning.TEMPLE_BACKDROP_DEPTH + 1) + noise.get_noise_2d(cell.x, cell.y) * Tuning.TEMPLE_BACKDROP_CRUST_WOBBLE
				alpha = Tuning.TEMPLE_BACKDROP_CRUST_ALPHA * smoothstep(Tuning.TEMPLE_BACKDROP_CRUST_NEAR_TILES, Tuning.TEMPLE_BACKDROP_CRUST_FAR_TILES, d)
			picture.set_pixel(x, y, Color(Tuning.TEMPLE_BACKDROP_CRUST_COLOR, alpha))
	var sprite := Sprite2D.new()
	sprite.name = "Crust"
	sprite.centered = false
	sprite.texture = ImageTexture.create_from_image(picture)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = Vector2.ONE * TileArt.TILE
	sprite.position = Vector2(area.position * TileArt.TILE)
	root.add_child(sprite)


## Tiles from the nearest room or corridor (breadth first, up to `TEMPLE_BACKDROP_DEPTH`).
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
