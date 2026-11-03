class_name RockBackdrop
extends RefCounted
## The solid rock around a generated map of the Ruinas: a mass of rock on every tile that is not a
## room or a corridor, so nothing black shows between rooms or around the corridors. Purely
## decorative (no collision), drawn below every floor. Same seed = same rock.


## Builds the rock under `parent`. `walkable` holds the floor tiles and `area` is in tiles.
static func build(parent: Node, area: Rect2i, walkable: Dictionary, map_seed: int) -> Node2D:
	var root := Node2D.new()
	root.name = "Backdrop"
	root.z_index = RoomTheme.FLOOR_Z - 1
	parent.add_child(root)
	parent.move_child(root, 0)
	var layer := TileMapLayer.new()
	layer.name = "Rock"
	TileArt.prepare_layer(layer)
	root.add_child(layer)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["rock_backdrop", map_seed])
	# Mostly the dark mass: the rock around the map should sink away from the lit rooms.
	var dark := TileArt.coords(&"rock_mass_dark")
	var tiles: Array[Vector2i] = [dark, dark, dark, dark, dark, TileArt.coords(&"rock_mass_a")]
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if not walkable.has(Vector2i(x, y)):
				layer.set_cell(Vector2i(x, y), 0, tiles[rng.randi_range(0, tiles.size() - 1)])
	return root
