class_name Arrow
extends Node2D
## Projectile of the player's ranged weapon. Its Hitbox damages the first enemy Hurtbox it touches
## (layer 4, mask 3, like every player attack); a wall or the end of its range makes it vanish.

signal hit_landed(hurtbox: Hurtbox)

## From the arrow's origin to its tip, where the impact puff appears.
const TIP_DISTANCE := 10.0
## The arrow is drawn at the height of the bow while its Hitbox stays at the body's level. The root
## never rotates, so this offset points up for every direction (only the sprite turns).
const ART_HEIGHT := Vector2(0, -8)
## Where the Hitbox and the wall sensor sit along the flight: at the arrow's tip.
const SENSOR_DISTANCE := 9.0

## Puff played where the arrow ends on something (an enemy or a wall).
@export var impact_scene: PackedScene

var _velocity := Vector2.ZERO
var _damage := 1
var _range_left := 200.0
var _angle := 0.0

@onready var _art: Sprite2D = $Art
@onready var _hitbox: Hitbox = $Hitbox
@onready var _wall_sensor: Area2D = $WallSensor


## Sets the flight before the arrow enters the tree.
func setup(direction: Vector2, speed: float, max_range: float, damage: int) -> void:
	_velocity = direction.normalized() * speed
	_range_left = max_range
	_damage = damage
	_angle = direction.angle()


func _ready() -> void:
	_art.rotation = _angle
	_art.position = ART_HEIGHT
	var tip := Vector2.from_angle(_angle) * SENSOR_DISTANCE
	_hitbox.position = tip
	_wall_sensor.position = tip + Vector2.from_angle(_angle)
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
		impact.position = position + Vector2.from_angle(_angle) * TIP_DISTANCE + ART_HEIGHT
		get_parent().add_child.call_deferred(impact)
	queue_free()
