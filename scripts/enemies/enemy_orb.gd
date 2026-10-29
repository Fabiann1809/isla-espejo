class_name EnemyOrb
extends Node2D
## Projectile of an enemy. Its Hitbox damages the player's Hurtbox it touches (layer 5, mask 2, like
## every enemy attack); a wall or the end of its range makes it vanish.

## Puff played where the orb ends on something (the player or a wall).
@export var impact_scene: PackedScene

var _velocity := Vector2.ZERO
var _damage := 1
var _range_left := 200.0

@onready var _hitbox: Hitbox = $Hitbox
@onready var _wall_sensor: Area2D = $WallSensor


## Sets the flight before the orb enters the tree.
func setup(direction: Vector2, speed: float, max_range: float, damage: int) -> void:
	_velocity = direction.normalized() * speed
	_range_left = max_range
	_damage = damage


func _ready() -> void:
	_hitbox.damage = _damage
	_hitbox.hit_landed.connect(func(_hurtbox: Hurtbox) -> void: _end_with_impact())
	_hitbox.activate()
	_wall_sensor.body_entered.connect(func(_body: Node2D) -> void: _end_with_impact())
	$Art.play()


func _physics_process(delta: float) -> void:
	var step := _velocity * delta
	position += step
	_range_left -= step.length()
	if _range_left <= 0.0:
		queue_free()


func _end_with_impact() -> void:
	if impact_scene != null and get_parent() != null:
		var impact: Node2D = impact_scene.instantiate()
		impact.position = position
		get_parent().add_child.call_deferred(impact)
	queue_free()
