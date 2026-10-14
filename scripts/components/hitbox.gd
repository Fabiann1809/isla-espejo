class_name Hitbox
extends Area2D
## Area that deals damage to every Hurtbox it overlaps while active, once per activation.
## Its collision mask decides who it can hurt (player attacks mask the enemy layer and vice versa).

signal hit_landed(hurtbox: Hurtbox)

@export var damage := 1

var _already_hit: Array[Hurtbox] = []


func _ready() -> void:
	monitoring = false


func activate() -> void:
	_already_hit.clear()
	monitoring = true


func deactivate() -> void:
	monitoring = false


func _physics_process(_delta: float) -> void:
	if not monitoring:
		return
	for area in get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox == null or hurtbox in _already_hit:
			continue
		if hurtbox.receive_hit(damage, _source_position()):
			_already_hit.append(hurtbox)
			hit_landed.emit(hurtbox)


## Knockback is computed from the root of the scene that owns this hitbox.
func _source_position() -> Vector2:
	var source := owner as Node2D
	return source.global_position if source != null else global_position
