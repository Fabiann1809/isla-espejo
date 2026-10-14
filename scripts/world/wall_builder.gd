class_name WallBuilder
extends RefCounted
## Builds placeholder walls (world collision layer plus a flat-color visual) from rectangles.
## Replaced by tilemap walls once the tileset exists; callers keep passing rectangles.

const WALL_COLOR := Color(0.12, 0.12, 0.16)


## `visible` = false builds only the collision (the theme draws the walls with tiles instead).
static func add_walls(parent: Node, rects: Array[Rect2], color := WALL_COLOR, visible := true) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = "Walls"
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	for rect in rects:
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = rect.size
		shape.shape = rectangle
		shape.position = rect.get_center()
		body.add_child(shape)
		if not visible:
			continue
		var visual := ColorRect.new()
		visual.color = color
		visual.position = rect.position
		visual.size = rect.size
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(visual)
	return body
