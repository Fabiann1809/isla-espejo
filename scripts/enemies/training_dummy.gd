extends StaticBody2D
## Test target for the player's attack. Replaced by real enemies with health in the next task.

var hits := 0

@onready var _body: ColorRect = $Body
@onready var _label: Label = $Label


func take_hit(_damage: int, _from_position: Vector2) -> void:
	hits += 1
	_label.text = str(hits)
	_body.color = Color.WHITE
	await get_tree().create_timer(0.08).timeout
	_body.color = Color(0.8, 0.25, 0.25)
