class_name CoinIcon
extends Control
## The coin of the gold counter: the same coin the enemies drop (a gold disc with a darker rim and a
## highlight, see Pickup), drawn a little bigger, that pops each time the counter changes.

const SIZE := 10.0
const POP_SCALE := 1.45
const POP_SECONDS := 0.22

var color := Color(1.0, 0.8, 0.25)

var _tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	pivot_offset = Vector2(SIZE, SIZE) / 2.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center := Vector2(SIZE, SIZE) / 2.0
	draw_circle(center, 4.6, color.darkened(0.35))
	draw_circle(center, 3.4, color)
	draw_circle(center + Vector2(-1.0, -1.0), 1.2, color.lightened(0.5))


## A short bump, so a coin picked up is noticed in the corner of the eye.
func pop() -> void:
	if _tween != null:
		_tween.kill()
	scale = Vector2.ONE * POP_SCALE
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, POP_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
