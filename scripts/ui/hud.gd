extends CanvasLayer
## In-game HUD. Reads state from the Events bus only. Placeholder art (colored squares).

const HEART_SIZE := Vector2(10, 10)
const HEART_FULL := Color(0.85, 0.2, 0.25)
const HEART_EMPTY := Color(0.25, 0.1, 0.12)

@onready var _hearts: HBoxContainer = $Margin/Hearts
@onready var _message: Label = $Message


func _ready() -> void:
	Events.player_health_changed.connect(_on_player_health_changed)
	_message.hide()


func show_message(text: String) -> void:
	_message.text = text
	_message.show()


func _on_player_health_changed(current: int, maximum: int) -> void:
	for child in _hearts.get_children():
		child.queue_free()
	for i in maximum:
		var heart := ColorRect.new()
		heart.custom_minimum_size = HEART_SIZE
		heart.color = HEART_FULL if i < current else HEART_EMPTY
		_hearts.add_child(heart)
