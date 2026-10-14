class_name Hurtbox
extends Area2D
## Area that can receive damage. Put it on the "player" or "enemy" collision layer
## (never both) and connect to `hit` from the owner.

signal hit(damage: int, from_position: Vector2)

## Optional callable returning true while the owner cannot be damaged (i-frames).
var invulnerability_check := Callable()


func _ready() -> void:
	monitoring = false


## Returns true if the hit was accepted.
func receive_hit(damage: int, from_position: Vector2) -> bool:
	if invulnerability_check.is_valid() and invulnerability_check.call():
		return false
	hit.emit(damage, from_position)
	return true
