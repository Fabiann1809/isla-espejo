class_name AttackLane
extends Node2D
## A warning stripe on the ground: where a moving attack (a bat's dive, a beast's charge) is going
## to pass. It lies at the ground-effects level (over the floor, under every actor), gets brighter
## while the warning runs and frees itself after `lifetime` (its enemy also frees it when the
## attack starts or is cut short).

var width := 8.0
var color := Color(1.0, 0.3, 0.25)
var lifetime := 1.0
## The lane, relative to the node's position.
var _span := Vector2.RIGHT
var _age := 0.0


## A lane from `from` to `to` (world positions) under `parent`, lasting `seconds`.
static func create(parent: Node2D, from: Vector2, to: Vector2, lane_width: float, lane_color: Color,
		seconds: float) -> AttackLane:
	var lane := AttackLane.new()
	lane.width = lane_width
	lane.color = lane_color
	lane.lifetime = seconds
	parent.add_child(lane)
	lane.aim(from, to)
	return lane


## Moves the lane (world positions), for a warning that follows its target until it locks.
func aim(from: Vector2, to: Vector2) -> void:
	var parent := get_parent() as Node2D
	position = parent.to_local(from) if parent != null else from
	_span = (parent.to_local(to) if parent != null else to) - position
	queue_redraw()


func _ready() -> void:
	z_index = RoomTheme.GROUND_FX_Z


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= lifetime:
		queue_free()


func _draw() -> void:
	var progress := clampf(_age / maxf(lifetime, 0.001), 0.0, 1.0)
	var along := _span.normalized()
	var side := Vector2(-along.y, along.x)
	# A dark edge under the colored stripe so it reads on any floor.
	if Tuning.ZONE_OUTLINE_ALPHA > 0.0:
		draw_line(Vector2.ZERO, _span, Color(0, 0, 0, Tuning.ZONE_OUTLINE_ALPHA * 0.6), width + 2.0)
	var fill := color
	fill.a = 0.18 + 0.32 * progress
	draw_line(Vector2.ZERO, _span, fill, width)
	# The arrow head at the far end says which way it goes.
	var edge := color
	edge.a = 0.55 + 0.4 * progress
	var head := width * 0.9
	draw_colored_polygon(PackedVector2Array([
		_span + along * head * 0.6, _span - along * head * 0.6 + side * head,
		_span - along * head * 0.6 - side * head]), edge)
	draw_line(side * width * 0.5, _span + side * width * 0.5, edge, 1.0)
	draw_line(-side * width * 0.5, _span - side * width * 0.5, edge, 1.0)
