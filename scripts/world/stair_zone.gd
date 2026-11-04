class_name StairZone
extends Area2D
## A staircase between the two height levels. Anything of the player or enemy layers standing on it
## is LOW on the first half (the low end) and HIGH on the second, so it changes level halfway up and
## back halfway down. `direction` points from the low end to the high end of the zone's rectangle,
## whose center is where the level changes. Solid rails (layer `world`) keep actors on the stairs.

## From the low end to the high end of the stairs (a cardinal direction).
@export var direction := Vector2.UP


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0b110
	monitorable = false


func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		var collider := body as CollisionObject2D
		if collider == null:
			continue
		var along := (body.global_position - global_position).dot(direction.normalized())
		var level := Heights.HIGH if along > 0.0 else Heights.LOW
		if Heights.level_of(body) != level:
			Heights.set_level(collider, level)
