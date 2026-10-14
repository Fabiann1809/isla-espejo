extends CharacterBody2D
## Nico: 8-direction movement and dash. Attack and skills come in later tasks.

@export var speed := 110.0
@export var dash_speed := 300.0
@export var dash_time := 0.15
@export var dash_cooldown := 0.6

var facing := Vector2.DOWN
var _dash_left := 0.0
var _cooldown_left := 0.0
var _dash_dir := Vector2.ZERO


func _physics_process(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != Vector2.ZERO:
		facing = input.normalized()

	_cooldown_left = maxf(_cooldown_left - delta, 0.0)

	if _dash_left > 0.0:
		_dash_left -= delta
		velocity = _dash_dir * dash_speed
	else:
		velocity = input * speed
		if Input.is_action_just_pressed("dash") and _cooldown_left == 0.0:
			_dash_dir = facing
			_dash_left = dash_time
			_cooldown_left = dash_cooldown

	move_and_slide()
