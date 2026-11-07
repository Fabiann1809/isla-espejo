class_name TempleBridge
extends RefCounted
## A corridor of the Templo del Eclipse as a stone causeway over the lava, like the bridges of
## `docs/referencias/templo_mapa.jpg`: the sea runs under the whole rectangle (its own animated layer,
## so the bridge has lava under it even with the backdrop off), a deck along the door lane and a low
## parapet on each side, flat with the floor except the near (south) one of a horizontal bridge, which
## stands with the actors and sorts by its foot, so Nico walking along it is drawn behind it. The
## parapets carry no posts but one where they meet a room (`Tuning.TEMPLE_BRIDGE_END_POSTS`).
##
## A corridor longer than `Tuning.TEMPLE_LANDING_MIN_TILES` gets a landing at mid-span: a stone island
## as wide as the lane and both parapet rows, with the floor of its level, a lit ledge round its
## edge, rows of cliff dropping into the lava on its south side and a brazier on a pedestal on each
## side of the way. Its outline is solid where the deck neither enters nor leaves, so Nico can step
## off the deck onto it but never into the lava. `Level` hands its cells to `LavaBackdrop` as stone
## (the sea rims it and keeps its islets clear) and as taken (no lava or bubbles of the sea under it).
##
## Between rooms one level apart the steps take one stretch of the corridor and the rest is a deck at
## each end's height: across the landing when there is one (braziers at the top of the flight), else
## at the high room's door (braziers on the high room's wall flanking its door, as before). One
## `StairZone` covers the stretch, `low_level` the lower room's height. The deck of the high side
## blocks the actors below its level and the deck of the low side those above it, the rooms' own
## rules (`TemplePlan.collision_rects`, `Heights`), so nobody walks a deck at the wrong height.
## Collision never depends on the art: the corridor's wall rectangles are the rails.

const TILE := TileArt.TILE
const LANE := Room.DOOR_WIDTH / TileArt.TILE
const WALL := Room.WALL / TileArt.TILE

var theme: RoomTheme
## The corridor's floor (the lane) and its two wall rectangles, world px (`Level._add_corridor`).
var floor_rect: Rect2
var walls: Array[Rect2]
var from_height: int
var to_height: int
## RIGHT or DOWN: from the first room to the second.
var dir: Vector2i
## Numbers the nodes (siblings with the same name are renamed by the engine).
var number: int

## What was built, in world tiles: the landing's floor (empty without one), the cliff cells under it,
## the stair stretch (empty on a flat bridge) and the way up.
var landing := Rect2i()
var face_cells: Array[Vector2i] = []
var stairs := Rect2i()
var uphill := Vector2i.ZERO
var low_level := 0
var high_level := 0

var _horizontal: bool
## The lane in tiles: its first cell along the corridor, its length, its first row (column) across.
var _a0: int
var _len: int
var _c0: int
var _floor_cells: Rect2i
## Whether the low room lies before the stair stretch (toward smaller coordinates).
var _low_first: bool
var _rails := 0


func _init(bridge_theme: RoomTheme, corridor_floor: Rect2, corridor_walls: Array[Rect2], height_from: int,
		height_to: int, direction: Vector2i, index: int) -> void:
	theme = bridge_theme
	floor_rect = corridor_floor
	walls = corridor_walls
	from_height = height_from
	to_height = height_to
	dir = direction
	number = index
	_horizontal = dir == Vector2i.RIGHT
	_floor_cells = _cells(floor_rect)
	_a0 = _floor_cells.position.x if _horizontal else _floor_cells.position.y
	_len = _floor_cells.size.x if _horizontal else _floor_cells.size.y
	_c0 = _floor_cells.position.y if _horizontal else _floor_cells.position.x
	low_level = mini(from_height, to_height)
	high_level = maxi(from_height, to_height)
	if from_height != to_height:
		uphill = dir if to_height > from_height else -dir
	_low_first = uphill.x > 0 or uphill.y > 0


## Builds the bridge under `parent` (the level's `Corridors` node).
func build(parent: Node) -> void:
	_place_landing()
	_place_stairs()
	_paint_lava(parent)
	_paint_faces(parent)
	var layer := theme.new_layer(parent, "Corridor%d" % number)
	layer.modulate = Tuning.TEMPLE_FLOOR_MODULATE
	_paint_deck(layer)
	_paint_landing_floor(layer)
	_paint_parapets(parent, layer)
	_paint_ledge(parent)
	_paint_stairs(parent)
	_build_collision(parent)
	_build_stair_zone(parent)
	_place_braziers(parent)


## Every cell the bridge covers (the lane, the parapets, the landing and its cliff): the sea paints
## nothing there.
func taken_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	_append_cells(cells, _floor_cells)
	for wall in walls:
		_append_cells(cells, _cells(wall))
	_append_cells(cells, landing)
	cells.append_array(face_cells)
	return cells


## The landing's stone (its floor and its cliff): the sea rims it and measures its crust from it.
func stone_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	_append_cells(cells, landing)
	cells.append_array(face_cells)
	return cells


# --- geometry --------------------------------------------------------------------------------------
## A rectangle of cells from its span along the corridor and across it.
func _rect(along_start: int, along_size: int, across_start: int, across_size: int) -> Rect2i:
	if _horizontal:
		return Rect2i(along_start, across_start, along_size, across_size)
	return Rect2i(across_start, along_start, across_size, along_size)


func _along(cell: Vector2i) -> int:
	return cell.x if _horizontal else cell.y


func _across(cell: Vector2i) -> int:
	return cell.y if _horizontal else cell.x


func _cell(along: int, across: int) -> Vector2i:
	return Vector2i(along, across) if _horizontal else Vector2i(across, along)


static func _cells(rect: Rect2) -> Rect2i:
	return Rect2i(Vector2i(rect.position / TileArt.TILE), Vector2i(rect.size / TileArt.TILE))


static func _append_cells(cells: Array[Vector2i], rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			cells.append(Vector2i(x, y))


## The landing at mid-span of a long corridor: the lane and both parapet rows across, its cliff rows
## below it (the whole width of a horizontal bridge; under the two cells beside the lane of a vertical
## one, where the deck goes on).
func _place_landing() -> void:
	if not Tuning.TEMPLE_LANDINGS or _len <= Tuning.TEMPLE_LANDING_MIN_TILES:
		return
	var size := mini(Tuning.TEMPLE_LANDING_TILES, _len)
	var start := _a0 + (_len - size) / 2
	landing = _rect(start, size, _c0 - WALL, LANE + 2 * WALL)
	for row in Tuning.TEMPLE_LANDING_FACE_ROWS:
		if _horizontal:
			for x in range(landing.position.x, landing.end.x):
				face_cells.append(Vector2i(x, landing.end.y + row))
		else:
			face_cells.append(Vector2i(landing.position.x, landing.end.y + row))
			face_cells.append(Vector2i(landing.end.x - 1, landing.end.y + row))


## The stair stretch of a corridor between rooms one level apart: across the landing, else at the
## high room's door (the whole corridor with the stretch switched off).
func _place_stairs() -> void:
	if from_height == to_height:
		return
	if not Tuning.TEMPLE_BRIDGE_STAIR_STRETCH:
		stairs = _floor_cells
		return
	var size: int
	var start: int
	if landing != Rect2i():
		var along_start := landing.position.x if _horizontal else landing.position.y
		var along_size := landing.size.x if _horizontal else landing.size.y
		size = clampi(Tuning.TEMPLE_LANDING_STAIR_TILES, 1, along_size)
		start = along_start + (along_size - size) / 2
	else:
		size = clampi(Tuning.TEMPLE_BRIDGE_STAIR_TILES, 1, _len)
		start = _a0 if not _low_first else _a0 + _len - size
	stairs = _rect(start, size, _c0, LANE)


func _stairs_start() -> int:
	return stairs.position.x if _horizontal else stairs.position.y


func _stairs_end() -> int:
	return stairs.end.x if _horizontal else stairs.end.y


## The level of the floor at `along`: the low room's before or after the stairs by where it lies;
## the corridor's on a flat bridge; on the stairs, the half's.
func _level_at(along: int) -> int:
	if stairs == Rect2i():
		return low_level
	var middle := (_stairs_start() + _stairs_end()) / 2.0
	var before := along + 0.5 < middle
	return low_level if before == _low_first else high_level


## The spans along the corridor on the low side and on the high side of the stairs (empty on a flat
## bridge), as [start, end) pairs.
func _side_spans() -> Dictionary:
	if stairs == Rect2i():
		return {}
	var before := [_a0, _stairs_start()]
	var after := [_stairs_end(), _a0 + _len]
	return {"low": before if _low_first else after, "high": after if _low_first else before}


# --- pictures --------------------------------------------------------------------------------------
## The sea under everything the bridge covers, the sea's own macro by world tile.
func _paint_lava(parent: Node) -> void:
	var lava := LavaBackdrop.lava_layer("CorridorLava%d" % number)
	lava.z_index = LavaBackdrop.SEA_Z
	lava.modulate = Tuning.TEMPLE_LAVA_MODULATE
	parent.add_child(lava)
	for cell in taken_cells():
		LavaBackdrop.paint_lava_cell(lava, cell)


## The landing's cliff: a carved top row, plain courses and a lava-lit foot (one row: the foot alone).
func _paint_faces(parent: Node) -> void:
	if face_cells.is_empty():
		return
	var layer := TileMapLayer.new()
	layer.name = "LandingFaces%d" % number
	layer.z_index = RoomTheme.FLOOR_Z
	layer.tile_set = TempleShape.animated_tile_set()
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.scale = Vector2.ONE * TileArt.draw_scale()
	parent.add_child(layer)
	var rows := Tuning.TEMPLE_LANDING_FACE_ROWS
	for cell in face_cells:
		var row := cell.y - landing.end.y
		var side := "m"
		if _horizontal:
			side = "l" if cell.x == landing.position.x else ("r" if cell.x == landing.end.x - 1 else "m")
		var role: StringName
		if row == rows - 1:
			role = StringName("cliff_foot_lava_" + side)
		elif row == 0:
			role = StringName("cliff_face2_top_" + side)
		else:
			role = StringName("cliff_face_mid_" + side)
		var frames := TileArt.profile().animation(role)
		layer.set_cell(cell, 0, frames[0] if not frames.is_empty() else TileArt.coords(role))


## Flagstones along the lane, off the landing and off the steps.
func _paint_deck(layer: TileMapLayer) -> void:
	var deck := TileArt.coords(&"bridge_stone_deck_h" if _horizontal else &"bridge_stone_deck_v")
	for y in range(_floor_cells.position.y, _floor_cells.end.y):
		for x in range(_floor_cells.position.x, _floor_cells.end.x):
			var cell := Vector2i(x, y)
			if not landing.has_point(cell) and not stairs.has_point(cell):
				layer.set_cell(cell, 0, deck)


## The landing's floor in the stone of its level (each half's on a stair landing).
func _paint_landing_floor(layer: TileMapLayer) -> void:
	if landing == Rect2i():
		return
	for y in range(landing.position.y, landing.end.y):
		for x in range(landing.position.x, landing.end.x):
			var cell := Vector2i(x, y)
			if stairs.has_point(cell):
				continue
			var level := _level_at(_along(cell))
			layer.set_cell(cell, 0, TileArt.coords(StringName("floor%d_m_%d_%d" % [level, posmod(x, 4), posmod(y, 4)])))


## The parapets on the wall rows, off the landing (and off its cliff): flat tiles, except the south
## one of a horizontal bridge, which stands upright; a post only where a parapet meets a room.
func _paint_parapets(parent: Node, layer: TileMapLayer) -> void:
	for wall in walls:
		var cells := _cells(wall)
		var near := _horizontal and wall.position.y > floor_rect.position.y
		var role: StringName
		if _horizontal:
			role = &"bridge_stone_rail_s" if near else &"bridge_stone_rail_n"
		else:
			role = &"bridge_stone_rail_w" if wall.position.x < floor_rect.position.x else &"bridge_stone_rail_e"
		for segment in _wall_segments(cells):
			if near:
				_plant_rail(parent, segment, role)
				continue
			for y in range(segment.position.y, segment.end.y):
				for x in range(segment.position.x, segment.end.x):
					layer.set_cell(Vector2i(x, y), 0, TileArt.coords(role))
			for end_cell in _room_ends(segment):
				layer.set_cell(end_cell, 0, TileArt.coords(&"bridge_stone_post"))


## The pieces of a wall row the landing leaves (and its cliff, on a vertical bridge).
func _wall_segments(cells: Rect2i) -> Array[Rect2i]:
	var segments: Array[Rect2i] = []
	if landing == Rect2i():
		segments.append(cells)
		return segments
	var start := _along(cells.position)
	var end := start + (cells.size.x if _horizontal else cells.size.y)
	var landing_start := _along(landing.position)
	var landing_end := landing_start + (landing.size.x if _horizontal else landing.size.y)
	var across := _across(cells.position)
	if landing_start > start:
		segments.append(_rect(start, landing_start - start, across, 1))
	# South of a vertical landing its cliff takes the first cells of the parapet row.
	var resume := landing_end + (0 if _horizontal else Tuning.TEMPLE_LANDING_FACE_ROWS)
	if end > resume:
		segments.append(_rect(resume, end - resume, across, 1))
	return segments


## The cells of a parapet segment that touch a room, where a post stands.
func _room_ends(segment: Rect2i) -> Array[Vector2i]:
	var ends: Array[Vector2i] = []
	if not Tuning.TEMPLE_BRIDGE_END_POSTS:
		return ends
	var across := _across(segment.position)
	var start := _along(segment.position)
	var end := start + (segment.size.x if _horizontal else segment.size.y)
	if start == _a0:
		ends.append(_cell(start, across))
	if end == _a0 + _len and not ends.has(_cell(end - 1, across)):
		ends.append(_cell(end - 1, across))
	return ends


## The near parapet of a horizontal bridge: upright sprites on a node sorted by the parapet's foot.
func _plant_rail(parent: Node, segment: Rect2i, role: StringName) -> void:
	var rail := Node2D.new()
	rail.name = "BridgeRail%d" % number if _rails == 0 else "BridgeRail%d_%d" % [number, _rails]
	_rails += 1
	rail.z_index = 0
	var origin := Vector2(segment.position * TILE)
	rail.position = Vector2(origin.x, origin.y + Tuning.TEMPLE_BRIDGE_RAIL_BASE)
	parent.add_child(rail)
	var posts := _room_ends(segment)
	for ix in segment.size.x:
		var cell := segment.position + Vector2i(ix, 0)
		var piece: StringName = &"bridge_stone_post" if posts.has(cell) else role
		rail.add_child(TileArt.sprite(piece, Vector2(ix * TILE, -Tuning.TEMPLE_BRIDGE_RAIL_BASE)))


## The lit lip round the landing's edge (open where the deck enters and leaves, never on the steps).
func _paint_ledge(parent: Node) -> void:
	if landing == Rect2i():
		return
	var layer := theme.new_layer(parent, "LandingEdge%d" % number)
	layer.modulate = Tuning.TEMPLE_FLOOR_MODULATE
	var inside := func(cell: Vector2i) -> bool:
		return landing.has_point(cell) or _floor_cells.has_point(cell)
	for y in range(landing.position.y, landing.end.y):
		for x in range(landing.position.x, landing.end.x):
			var cell := Vector2i(x, y)
			if stairs.has_point(cell):
				continue
			var mask := TileArt.blob_mask(inside, cell)
			if mask != 255:
				layer.set_cell(cell, 0, TileArt.blob47_tile(&"ledge", mask))


## The steps of the stair stretch, climbing uphill, with a balustrade on the open sides of a flight
## across the landing (a flight at a door runs between the parapets).
func _paint_stairs(parent: Node) -> void:
	if stairs == Rect2i():
		return
	var layer := theme.new_layer(parent, "Stairs%d" % number)
	layer.modulate = Tuning.TEMPLE_FLOOR_MODULATE
	var on_landing := landing != Rect2i()
	var flip := 0
	if uphill == Vector2i.LEFT:
		flip = TileSetAtlasSource.TRANSFORM_FLIP_H
	elif uphill == Vector2i.DOWN:
		flip = TileSetAtlasSource.TRANSFORM_FLIP_V
	for y in range(stairs.position.y, stairs.end.y):
		for x in range(stairs.position.x, stairs.end.x):
			var cell := Vector2i(x, y)
			var sides := ""
			if on_landing:
				var across := _across(cell)
				if across == _c0:
					sides += "t" if _horizontal else "l"
				if across == _c0 + LANE - 1:
					sides += "b" if _horizontal else "r"
			var role := StringName(("stairs_side_steps" if _horizontal else "stairs_up_steps") + ("_" + sides if sides != "" else ""))
			layer.set_cell(cell, 0, TileArt.coords(role), flip)


# --- collision, the way up and the fires -----------------------------------------------------------------
## The rails (the corridor's wall rectangles, cut round the landing), the landing's outline, the
## cells beside a flight across the landing (solid, the braziers stand on them) and, on a staircase,
## the decks of each side on the layers of the levels they keep out.
func _build_collision(parent: Node) -> void:
	var solid: Array[Rect2] = []
	for wall in walls:
		for segment in _wall_segments_full(_cells(wall)):
			solid.append(_px(segment))
	if landing != Rect2i():
		var start := _along(landing.position) - 1
		var size := (landing.size.x if _horizontal else landing.size.y) + 2
		solid.append(_px(_rect(start, size, _c0 - WALL - 1, 1)))
		solid.append(_px(_rect(start, size, _c0 + LANE + WALL, 1)))
		if stairs != Rect2i():
			var flight := _stairs_end() - _stairs_start()
			solid.append(_px(_rect(_stairs_start(), flight, _c0 - WALL, 1)))
			solid.append(_px(_rect(_stairs_start(), flight, _c0 + LANE, 1)))
	WallBuilder.add_walls(parent, solid, WallBuilder.WALL_COLOR, false)
	var spans := _side_spans()
	if spans.is_empty():
		return
	# The low side keeps out whoever stands above its level, the high side whoever stands below.
	var low_layers: Array[int] = []
	for level in range(low_level + 1, Heights.LEVELS):
		low_layers.append(Heights.block_layer(level))
	var high_layers: Array[int] = []
	for level in range(0, high_level):
		high_layers.append(Heights.block_layer(level))
	_add_level_body(parent, "BlockLow%d" % number, _side_rects(spans["low"]), low_layers)
	_add_level_body(parent, "BlockHigh%d" % number, _side_rects(spans["high"]), high_layers)


## A wall row without the landing's span (its cliff cells stay solid: nobody walks on a face).
func _wall_segments_full(cells: Rect2i) -> Array[Rect2i]:
	var segments: Array[Rect2i] = []
	if landing == Rect2i():
		segments.append(cells)
		return segments
	var start := _along(cells.position)
	var end := start + (cells.size.x if _horizontal else cells.size.y)
	var landing_start := _along(landing.position)
	var landing_end := landing_start + (landing.size.x if _horizontal else landing.size.y)
	var across := _across(cells.position)
	if landing_start > start:
		segments.append(_rect(start, landing_start - start, across, 1))
	if end > landing_end:
		segments.append(_rect(landing_end, end - landing_end, across, 1))
	return segments


## The floor of one side of the stairs: its deck and, on the landing, its half.
func _side_rects(span: Array) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var start: int = span[0]
	var size: int = span[1] - span[0]
	if size <= 0:
		return rects
	rects.append(_px(_rect(start, size, _c0, LANE)))
	if landing != Rect2i():
		var landing_start := _along(landing.position)
		var landing_end := landing_start + (landing.size.x if _horizontal else landing.size.y)
		var from := maxi(start, landing_start)
		var to := mini(span[1], landing_end)
		if to > from:
			rects.append(_px(_rect(from, to - from, _c0 - WALL, LANE + 2 * WALL)))
	return rects


func _add_level_body(parent: Node, body_name: String, rects: Array[Rect2], layers: Array[int]) -> void:
	if rects.is_empty() or layers.is_empty():
		return
	var body := StaticBody2D.new()
	body.name = body_name
	body.collision_layer = 0
	for layer in layers:
		body.set_collision_layer_value(layer, true)
	body.collision_mask = 0
	for rect in rects:
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = rect.size
		shape.shape = rectangle
		shape.position = rect.get_center()
		body.add_child(shape)
	parent.add_child(body)


static func _px(cells: Rect2i) -> Rect2:
	return Rect2(Vector2(cells.position * TILE), Vector2(cells.size * TILE))


func _build_stair_zone(parent: Node) -> void:
	if stairs == Rect2i():
		return
	var zone := StairZone.new()
	zone.name = "StairZone%d" % number
	zone.direction = Vector2(uphill)
	zone.low_level = low_level
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(stairs.size * TILE)
	shape.shape = rectangle
	zone.add_child(shape)
	zone.position = _px(stairs).get_center()
	parent.add_child(zone)


## A brazier on a pedestal on each side of the way: at the middle of a flat landing; at the top of a
## flight across the landing; on the high room's wall flanking its door for a flight at the door.
func _place_braziers(parent: Node) -> void:
	var feet: Array[Vector2] = []
	var level := low_level
	var tile := float(TILE)
	if stairs != Rect2i() and landing == Rect2i():
		level = high_level
		var offset := Tuning.TEMPLE_STAIR_BRAZIER_LANDING
		for side in [-1.0, 1.0]:
			var foot: Vector2
			if _horizontal:
				foot.y = floor_rect.position.y - tile / 2.0 if side < 0.0 else floor_rect.end.y + tile / 2.0
				foot.x = floor_rect.position.x - offset if uphill.x < 0 else floor_rect.end.x + offset
			else:
				foot.x = floor_rect.position.x - tile / 2.0 if side < 0.0 else floor_rect.end.x + tile / 2.0
				foot.y = floor_rect.position.y - offset if uphill.y < 0 else floor_rect.end.y + offset
			feet.append(foot)
	elif landing != Rect2i() and Tuning.TEMPLE_LANDING_BRAZIERS:
		# Px along the corridor: the top cell of the flight, or the landing's middle line.
		var along: float
		var on_stairs := stairs != Rect2i()
		if on_stairs:
			level = high_level
			var top := _stairs_end() - 1 if _low_first else _stairs_start()
			along = (top + 0.5) * tile
		else:
			along = (_along(landing.position) + (landing.size.x if _horizontal else landing.size.y) / 2.0) * tile
		for across in [_c0 - WALL, _c0 + LANE]:
			if _horizontal:
				feet.append(Vector2(along, (across + 1) * tile - 4.0))
			else:
				feet.append(Vector2((across + 0.5) * tile, along + (tile / 2.0 if on_stairs else 0.0) - 4.0))
	for foot in feet:
		var brazier := TempleProp.new()
		brazier.kind = TempleProp.Kind.BRAZIER_PEDESTAL
		brazier.level = level
		brazier.position = foot.round()
		parent.add_child(brazier)
