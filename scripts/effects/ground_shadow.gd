class_name GroundShadow
extends Node2D
## A soft shadow on the ground at the foot of something standing (a tree, a bush, a rock, a standing
## stone), so its picture sits on the grass instead of floating over it. It is drawn with the floor
## (RoomTheme.FLOOR_Z, whatever its parent's level), so it never darkens Nico or an enemy walking
## past; light comes from the upper left, so it leans a little to the right. Values in Tuning.

const NODE_NAME := "GroundShadow"

var size := Vector2(16, 5)


## Adds a shadow to `parent` at `foot` (local to it), as wide as a picture `width` px across.
static func under(parent: Node2D, foot: Vector2, width: float) -> void:
	if not Tuning.PROP_SHADOWS_ENABLED or width <= 0.0:
		return
	var shadow := GroundShadow.new()
	shadow.name = NODE_NAME
	shadow.z_as_relative = false
	shadow.z_index = RoomTheme.FLOOR_Z
	shadow.position = (foot + Tuning.PROP_SHADOW_OFFSET).round()
	var across := maxf(width * Tuning.PROP_SHADOW_WIDTH_FACTOR, Tuning.PROP_SHADOW_MIN_WIDTH)
	shadow.size = Vector2(across, across * Tuning.PROP_SHADOW_HEIGHT_FACTOR).round()
	parent.add_child(shadow)
	parent.move_child(shadow, 0)


func _draw() -> void:
	# Two nested ellipses: a fainter rim and a darker core, so the edge is soft.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, size.y / maxf(size.x, 0.01)))
	var color := Color(Tuning.PROP_SHADOW_COLOR, Tuning.PROP_SHADOW_ALPHA * 0.5)
	draw_circle(Vector2.ZERO, size.x / 2.0, color)
	draw_circle(Vector2.ZERO, size.x / 2.0 * 0.68, color)
