class_name ShieldBubble
extends Node2D
## The bubble around Nico while an "Escudo de eco" lasts. Uses the art strip when it exists
## (`Tuning.SHIELD_BUBBLE_ART`) and draws a ring in code otherwise. `pulse()` swells it for a moment
## when it absorbs a hit.

var color := Color(0.6, 0.85, 1.0)

var _art: AnimatedSprite2D
var _time := 0.0
var _hit_left := 0.0


func _ready() -> void:
	position = Vector2(0, -Tuning.SHIELD_BUBBLE_LIFT)
	z_index = 1
	_art = StripArt.build(Tuning.SHIELD_BUBBLE_ART, Tuning.SHIELD_BUBBLE_FPS)
	if _art != null:
		add_child(_art)


func pulse() -> void:
	_hit_left = Tuning.SHIELD_BUBBLE_HIT_SECONDS


func _process(delta: float) -> void:
	_time += delta
	_hit_left = maxf(_hit_left - delta, 0.0)
	var swell := 1.0 + Tuning.SHIELD_BUBBLE_HIT_SCALE * _hit_left / Tuning.SHIELD_BUBBLE_HIT_SECONDS
	if _art != null:
		_art.scale = Vector2(swell, swell)
	queue_redraw()


func _draw() -> void:
	if _art != null:
		return
	var swell := 1.0 + Tuning.SHIELD_BUBBLE_HIT_SCALE * _hit_left / Tuning.SHIELD_BUBBLE_HIT_SECONDS
	var radius := Tuning.SHIELD_BUBBLE_RADIUS * swell
	var alpha := Tuning.SHIELD_BUBBLE_ALPHA * (0.75 + 0.25 * sin(_time * Tuning.SHIELD_BUBBLE_PULSE_SPEED))
	draw_circle(Vector2.ZERO, radius, Color(color, alpha * 0.25))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(color, alpha), 1.5)
	draw_arc(Vector2.ZERO, radius - 3.0, -2.4, -1.2, 8, Color(1, 1, 1, alpha), 1.0)
