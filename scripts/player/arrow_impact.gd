extends AnimatedSprite2D
## The puff where an arrow hits something. Plays once and removes itself.


func _ready() -> void:
	animation_finished.connect(queue_free)
	play()
