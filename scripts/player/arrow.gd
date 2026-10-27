class_name Arrow
extends Node2D
## Projectile of the player's ranged weapon. Its Hitbox damages the first enemy Hurtbox it touches
## (layer 4, mask 3, like every player attack); a wall or the end of its range makes it vanish.

signal hit_landed(hurtbox: Hurtbox)

var _velocity := Vector2.ZERO
var _damage := 1
var _range_left := 200.0

@onready var _hitbox: Hitbox = $Hitbox
@onready var _wall_sensor: Area2D = $WallSensor


## Sets the flight before the arrow enters the tree.
func setup(direction: Vector2, speed: float, max_range: float, damage: int) -> void:
	_velocity = direction.normalized() * speed
	_range_left = max_range
	_damage = damage
	rotation = direction.angle()


func _ready() -> void:
	_hitbox.damage = _damage
	_hitbox.hit_landed.connect(_on_hit_landed)
	_hitbox.activate()
	_wall_sensor.body_entered.connect(func(_body: Node2D) -> void: queue_free())


func _physics_process(delta: float) -> void:
	var step := _velocity * delta
	position += step
	_range_left -= step.length()
	if _range_left <= 0.0:
		queue_free()


func _on_hit_landed(hurtbox: Hurtbox) -> void:
	hit_landed.emit(hurtbox)
	queue_free()
