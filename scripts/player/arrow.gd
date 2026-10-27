class_name Arrow
extends Node2D
## Projectile of the player's ranged weapon. Its Hitbox damages the first enemy Hurtbox it touches
## (layer 4, mask 3, like every player attack); a wall or the end of its range makes it vanish.

signal hit_landed(hurtbox: Hurtbox)

## From the arrow's origin to its tip, where the impact puff appears.
const TIP_DISTANCE := 10.0
## The arrow is drawn at the height of the bow while its Hitbox stays at the body's level.
const ART_HEIGHT := Vector2(0, -8)

## Puff played where the arrow ends on something (an enemy or a wall).
@export var impact_scene: PackedScene

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
	_wall_sensor.body_entered.connect(func(_body: Node2D) -> void: _end_with_impact())


func _physics_process(delta: float) -> void:
	var step := _velocity * delta
	position += step
	_range_left -= step.length()
	if _range_left <= 0.0:
		queue_free()


func _on_hit_landed(hurtbox: Hurtbox) -> void:
	hit_landed.emit(hurtbox)
	_end_with_impact()


func _end_with_impact() -> void:
	if impact_scene != null and get_parent() != null:
		var impact: Node2D = impact_scene.instantiate()
		impact.position = position + Vector2.from_angle(rotation) * TIP_DISTANCE + ART_HEIGHT
		get_parent().add_child.call_deferred(impact)
	queue_free()
