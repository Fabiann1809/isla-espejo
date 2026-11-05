class_name WaterArt
extends RefCounted
## The forest's own water and wooden bridges (assets/tilesets/water/, drawn pixel by pixel by
## `python tools/make_water_art.py`), used by RoomProp's POND and PLANKS instead of the tileset's
## flat pond and square of planks (Tuning.WATER_ART_ENABLED; without the art, the tileset's are used).
##
## The ponds of a room and the planks that touch them are one body of water: a pond has no shore
## where a bridge starts, so the water runs on under the deck. Water is a TileMapLayer of animated
## tiles (ripples, glints and foam) picked by which neighbours are water (AreaArt). A bridge
## is its deck, rails, piles and the shade it casts on the water. Only drawing changes: collision is
## RoomProp's, the same as before.
##
## Layers: everything lies with the floor (RoomTheme.FLOOR_Z) except the railing on the bridge's
## near (south) side, which stands at the actors' level and is y-sorted with them, so Nico walking
## along that edge is drawn behind it. The rest of the bridge sorts after the pond below it, so its
## shade and piles lie on that water.

const DIR := "res://assets/tilesets/water/"
const WATER := DIR + "water.png"
const LILY := DIR + "water_lily.png"
const DECK := DIR + "bridge_deck.png"
const DECK_END := DIR + "bridge_deck_end.png"
const RAIL := DIR + "bridge_rail.png"
const NEWEL := DIR + "bridge_newel.png"
const SIDE := DIR + "bridge_side.png"
const SHADOW := DIR + "bridge_shadow.png"

## Width of one lily pad in water_lily.png (the pads stand side by side).
const LILY_WIDTH := 8

static var _textures := {}


static func available() -> bool:
	return Tuning.WATER_ART_ENABLED and AreaArt.exists(WATER)


static func texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]


## Draws a pond: its water and a few lily pads on open water.
static func dress_pond(pond: RoomProp) -> void:
	var cells := water_cells(pond)
	var origin := cell_rect(pond).position
	var layer := AreaArt.new_layer(WATER, "Water", Tuning.WATER_FRAME_TIME)
	pond.add_child(layer)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(origin)
	var lilies := texture(LILY)
	for y in pond.size_tiles.y:
		for x in pond.size_tiles.x:
			var row := AreaArt.row(cells, origin + Vector2i(x, y))
			layer.set_cell(Vector2i(x, y), 0, Vector2i(0, row))
			if lilies != null and row in AreaArt.MIDDLE_ROWS and rng.randf() < Tuning.WATER_LILY_CHANCE:
				pond.add_child(_lily(lilies, Vector2(x, y) * TileArt.TILE, rng))


## The cells (room tiles) of water around `prop`: the ponds of its room and the planks that touch
## them (the water runs on under a bridge).
static func water_cells(prop: RoomProp) -> Dictionary:
	var ponds: Array[Rect2i] = []
	var planks: Array[Rect2i] = []
	var parent := prop.get_parent()
	var props: Array = parent.get_children() if parent != null else [prop]
	for node in props:
		if node is RoomProp:
			if node.kind == RoomProp.Kind.POND:
				ponds.append(cell_rect(node))
			elif node.kind == RoomProp.Kind.PLANKS:
				planks.append(cell_rect(node))
	var cells := {}
	for rect in ponds:
		_add_cells(cells, rect)
	for rect in planks:
		if ponds.any(func(pond: Rect2i) -> bool: return rect.grow(1).intersects(pond)):
			_add_cells(cells, rect)
	return cells


## A prop's footprint in room tiles.
static func cell_rect(prop: RoomProp) -> Rect2i:
	return Rect2i(Vector2i((prop.position / TileArt.TILE).floor()), prop.size_tiles)


## Draws a bridge over the planks' footprint. It crosses the water from west to east when there is
## water on its north or south side (rails along both, piles and shade on the south); with no water
## next to it, it is a plain boardwalk.
static func dress_bridge(planks: RoomProp) -> void:
	var cells := water_cells(planks)
	var rect := cell_rect(planks)
	var size := Vector2(planks.size_tiles * TileArt.TILE)
	var over := float(Tuning.BRIDGE_OVERHANG)
	var reach := RoomProp.WATER_INSET
	var spans_water := false
	for x in range(rect.position.x, rect.end.x):
		spans_water = spans_water or cells.has(Vector2i(x, rect.position.y - 1)) or cells.has(Vector2i(x, rect.end.y))
	# The deck covers exactly where Nico can walk: the footprint and the band up to the water's
	# collision on each side; it rests on both banks.
	var deck := Rect2(-over, -reach if spans_water else 0.0, size.x + over * 2.0, size.y + (reach * 2.0 if spans_water else 0.0))
	var ground := Node2D.new()
	ground.name = "Deck"
	if spans_water:
		var shade_corner := Vector2(deck.position.x, deck.end.y) + Tuning.BRIDGE_SHADOW_OFFSET
		ground.add_child(_strip(SHADOW, Rect2(shade_corner, Vector2(deck.size.x, texture(SHADOW).get_height()))))
	ground.add_child(_strip(DECK, deck))
	var end_width := texture(DECK_END).get_width()
	ground.add_child(_strip(DECK_END, Rect2(deck.position, Vector2(end_width, deck.size.y)), false))
	ground.add_child(_strip(DECK_END, Rect2(deck.end.x - end_width, deck.position.y, end_width, deck.size.y), false, true))
	planks.add_child(ground)
	if not spans_water:
		return
	ground.add_child(_strip(SIDE, Rect2(deck.position.x, deck.end.y, deck.size.x, texture(SIDE).get_height())))
	# The far rail lies with the floor: nobody can stand north of it.
	_add_railing(ground, deck, deck.position.y + Tuning.BRIDGE_RAIL_INSET)
	# Sorted after the pond below, so the shade and the piles lie on that water.
	_sort_at(ground, deck.end.y + 1.0)
	# The near rail stands with the actors and sorts by its foot.
	var railing := Node2D.new()
	railing.name = "Railing"
	railing.z_as_relative = false
	railing.z_index = 0
	var foot := deck.end.y - Tuning.BRIDGE_RAIL_INSET
	_add_railing(railing, deck, foot)
	planks.add_child(railing)
	_sort_at(railing, foot)
	planks.y_sort_enabled = true


## A rail along the deck whose posts stand on `foot`, with a thick post at each end.
static func _add_railing(parent: Node2D, deck: Rect2, foot: float) -> void:
	var rail_height := texture(RAIL).get_height()
	parent.add_child(_strip(RAIL, Rect2(deck.position.x, foot - rail_height, deck.size.x, rail_height)))
	var newel := texture(NEWEL)
	for x in [deck.position.x, deck.end.x - newel.get_width()]:
		parent.add_child(_strip(NEWEL, Rect2(Vector2(x, foot - newel.get_height()), newel.get_size()), false))


## Moves `node`'s origin (its y-sort key) to `y` without moving what it draws.
static func _sort_at(node: Node2D, y: float) -> void:
	node.position.y += y
	for child in node.get_children():
		if child is Node2D:
			child.position.y -= y


## A sprite repeating `path`'s picture over `rect`. Lined up (`align`) with the prop's own origin, the
## piles and posts fall at the same places whatever the bridge's length; otherwise the picture starts
## at the rect's corner.
static func _strip(path: String, rect: Rect2, align := true, flip := false) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture(path)
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2(rect.position.x if align else 0.0, 0.0), rect.size)
	sprite.position = rect.position
	sprite.flip_h = flip
	return sprite


static func _lily(sheet: Texture2D, cell_corner: Vector2, rng: RandomNumberGenerator) -> Sprite2D:
	var pad := AtlasTexture.new()
	pad.atlas = sheet
	var looks := sheet.get_width() / LILY_WIDTH
	pad.region = Rect2(rng.randi_range(0, looks - 1) * LILY_WIDTH, 0, LILY_WIDTH, sheet.get_height())
	var sprite := Sprite2D.new()
	sprite.texture = pad
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.position = cell_corner + Vector2(rng.randi_range(2, TileArt.TILE - LILY_WIDTH - 2),
			rng.randi_range(2, TileArt.TILE - sheet.get_height() - 2))
	sprite.flip_h = rng.randf() < 0.5
	return sprite


static func _add_cells(cells: Dictionary, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			cells[Vector2i(x, y)] = true
