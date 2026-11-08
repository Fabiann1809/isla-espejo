class_name AbyssBackdrop
extends Node2D
## The deep water around and between the rooms of the Ruinas (Tuning.RUIN_ABYSS): every tile that is not a room
## is water, so the rooms are islands and the corridors causeways over it. Three frames of every variant take turns
## so the surface drifts; purely visual (the walls and the rooms' collision keep everybody on the floor), drawn below
## every floor. The rooms paint their own water over their rock cells (RuinShape) with the same tiles, so the two
## look like one sea. Same seed = same sea.

const VARIANTS: Array[String] = ["a", "b", "c", "d"]
## Seconds each frame of the water lasts.
const FRAME_SECONDS := 0.55

var _layers: Array[TileMapLayer] = []
var _time := 0.0


## Builds the sea under `parent`. `area` is in tiles; `walkable` holds the floor tiles of the rooms and corridors.
static func build(parent: Node, area: Rect2i, walkable: Dictionary, _taken: Dictionary, map_seed: int) -> AbyssBackdrop:
	var root := AbyssBackdrop.new()
	root.name = "Backdrop"
	root.z_index = RoomTheme.FLOOR_Z - 1
	parent.add_child(root)
	parent.move_child(root, 0)
	for frame in 3:
		var layer := TileMapLayer.new()
		layer.name = "Sea%d" % frame
		TileArt.prepare_layer(layer)
		layer.visible = frame == 0
		root.add_child(layer)
		root._layers.append(layer)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["abyss_backdrop", map_seed])
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			if walkable.has(cell):
				continue
			var v: String = VARIANTS[rng.randi_range(0, VARIANTS.size() - 1)]
			for frame in 3:
				root._layers[frame].set_cell(cell, 0, TileArt.coords(StringName("abyss_%s_%d" % [v, frame])))
	return root


func _process(delta: float) -> void:
	_time += delta
	var frame := int(_time / FRAME_SECONDS) % 3
	for i in _layers.size():
		_layers[i].visible = i == frame
