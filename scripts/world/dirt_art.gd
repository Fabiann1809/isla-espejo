class_name DirtArt
extends RefCounted
## The forest's own bare earth (assets/tilesets/dirt/dirt.png, drawn by `python tools/make_dirt_art.py`)
## for the dirt paths of doors and corridors and for RoomProp's DIRT_PATCH, instead of the tileset's
## boxes with a dotted rim (Tuning.DIRT_ART_ENABLED; without the art, the tileset's are used).
## Its edge wanders and frays into the grass; it is transparent outside, so it is drawn over grass:
## Level's path cells keep the floor's grass and get the dirt on a layer above it.
## Paths and patches of a map are one area of earth, so a path runs into a patch with no edge between.

const DIRT := "res://assets/tilesets/dirt/dirt.png"
## Name of the layer a dirt patch draws into (Level repaints it once the paths are known).
const PATCH_LAYER := &"Dirt"


static func available() -> bool:
	return Tuning.DIRT_ART_ENABLED and AreaArt.exists(DIRT)


static func new_layer(layer_name: String) -> TileMapLayer:
	return AreaArt.new_layer(DIRT, layer_name)


## Draws a patch of bare earth over its footprint, on its own (Level joins it to the paths).
static func dress_patch(patch: RoomProp) -> void:
	var layer := new_layer(PATCH_LAYER)
	patch.add_child(layer)
	var rect := Rect2i(Vector2i.ZERO, patch.size_tiles)
	AreaArt.paint(layer, shape(rect, _look(patch)), rect)


## The cells of a patch over `rect` that are earth: its footprint without its corner cells and, on a
## long side, a bite of grass somewhere along it (where, by `look`), so no patch reads as a box.
## Never a strip one cell wide: a bite stays three cells from the corners.
static func shape(rect: Rect2i, look: int) -> Dictionary:
	var cells := {}
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			cells[Vector2i(x, y)] = true
	if rect.size.x < 3 or rect.size.y < 3:
		return cells
	var last := rect.end - Vector2i.ONE
	for corner in [rect.position, Vector2i(last.x, rect.position.y), Vector2i(rect.position.x, last.y), last]:
		cells.erase(corner)
	if rect.size.x >= Tuning.DIRT_PATCH_BITE_SIDE:
		var x := rect.position.x + 3 + look % (rect.size.x - 6)
		cells.erase(Vector2i(x, rect.position.y if look % 2 == 0 else last.y))
	if rect.size.y >= Tuning.DIRT_PATCH_BITE_SIDE:
		var y := rect.position.y + 3 + (look / 7) % (rect.size.y - 6)
		cells.erase(Vector2i(rect.position.x if (look / 7) % 2 == 0 else last.x, y))
	return cells


## The earth cells of a patch, in world tiles.
static func patch_cells(patch: RoomProp) -> Dictionary:
	return shape(Rect2i(Vector2i((patch.global_position / TileArt.TILE).round()), patch.size_tiles), _look(patch))


## Repaints a patch as part of the map's earth (`cells`, in world tiles).
static func repaint_patch(patch: RoomProp, cells: Dictionary) -> void:
	var layer := patch.get_node_or_null(NodePath(PATCH_LAYER)) as TileMapLayer
	if layer == null:
		return
	layer.clear()
	var own := patch_cells(patch)
	var corner := Vector2i((patch.global_position / TileArt.TILE).round())
	for cell in own:
		layer.set_cell(cell - corner, 0, Vector2i(0, AreaArt.row(cells, cell)))


## Where a patch's bites go: by its place in its room, the same before and after Level repaints it.
static func _look(patch: RoomProp) -> int:
	return absi(hash(Vector2i(patch.position)))
