class_name SkillZone
extends Node2D
## Placeholder visual for skills (a circle or a wave) that fades out and frees itself. A circle can
## also call `on_tick` at a fixed interval, which is how lasting zones (Raíces) keep affecting enemies.

enum Shape { CIRCLE, WAVE }

var shape := Shape.CIRCLE
var color := Color.WHITE
var radius := 40.0
var lifetime := 1.0
var tick_interval := 0.1
var on_tick := Callable()
## WAVE only
var direction := Vector2.RIGHT
var arc := deg_to_rad(90.0)

var _age := 0.0
var _tick_left := 0.0


## A circle centered on `center` (world position) that lasts `seconds`.
static func circle(center: Vector2, circle_radius: float, circle_color: Color, seconds: float,
		tick := Callable()) -> SkillZone:
	var zone := SkillZone.new()
	zone.shape = Shape.CIRCLE
	zone.radius = circle_radius
	zone.color = circle_color
	zone.lifetime = seconds
	zone.on_tick = tick
	zone.position = center
	return zone


## A wave that expands from `origin` up to `reach` in `facing`, spanning `arc_degrees`.
static func wave(origin: Vector2, facing: Vector2, reach: float, arc_degrees: float,
		wave_color: Color, seconds := 0.35) -> SkillZone:
	var zone := SkillZone.new()
	zone.shape = Shape.WAVE
	zone.radius = reach
	zone.direction = facing
	zone.arc = deg_to_rad(arc_degrees)
	zone.color = wave_color
	zone.lifetime = seconds
	zone.position = origin
	return zone


func _physics_process(delta: float) -> void:
	_age += delta
	if on_tick.is_valid():
		_tick_left -= delta
		if _tick_left <= 0.0:
			_tick_left = tick_interval
			on_tick.call()
	queue_redraw()
	if _age >= lifetime:
		queue_free()


func _draw() -> void:
	var progress := clampf(_age / maxf(lifetime, 0.001), 0.0, 1.0)
	match shape:
		Shape.CIRCLE:
			var fill := color
			fill.a = 0.22 * (1.0 - progress * 0.6)
			draw_circle(Vector2.ZERO, radius, fill)
			var edge := color
			edge.a = 0.8 * (1.0 - progress)
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, edge, 2.0)
		Shape.WAVE:
			var reach := radius * (0.3 + 0.7 * progress)
			var edge := color
			edge.a = 0.9 * (1.0 - progress)
			var center_angle := direction.angle()
			draw_arc(Vector2.ZERO, reach, center_angle - arc / 2.0, center_angle + arc / 2.0, 20, edge, 4.0)
