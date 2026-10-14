extends CanvasLayer
## In-game HUD. Reads state from the Events bus only. Placeholder art (colored squares).

const HEART_SIZE := Vector2(10, 10)
const HEART_FULL := Color(0.85, 0.2, 0.25)
const HEART_EMPTY := Color(0.25, 0.1, 0.12)

const TOAST_SECONDS := 4.5

@onready var _hearts: HBoxContainer = $Margin/Hearts
@onready var _message: Label = $Message
@onready var _toast: Label = $Toast


func _ready() -> void:
	Events.player_health_changed.connect(_on_player_health_changed)
	Director.plan_made.connect(_on_plan_made)
	_message.hide()
	_toast.hide()


func show_message(text: String) -> void:
	_message.text = text
	_message.show()


## A line from the island that fades away by itself.
func show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	_toast.show()
	var tween := create_tween()
	tween.tween_interval(TOAST_SECONDS)
	tween.tween_property(_toast, "modulate:a", 0.0, 1.0)
	tween.tween_callback(_toast.hide)


func _on_plan_made(plan: DirectorPlan) -> void:
	if plan.island_line != "":
		show_toast(plan.island_line)


func _on_player_health_changed(current: int, maximum: int) -> void:
	for child in _hearts.get_children():
		child.queue_free()
	for i in maximum:
		var heart := ColorRect.new()
		heart.custom_minimum_size = HEART_SIZE
		heart.color = HEART_FULL if i < current else HEART_EMPTY
		_hearts.add_child(heart)
