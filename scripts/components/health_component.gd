class_name HealthComponent
extends Node
## Reusable health for the player and enemies. Does not decide what happens on damage or death;
## the owner connects to `damaged` and `died`.

signal changed(current: int, maximum: int)
signal damaged(amount: int, from_position: Vector2)
signal died

@export var max_health := 3

var current: int


func _ready() -> void:
	current = max_health
	changed.emit(current, max_health)


## Changes the maximum and refills health (used when stats come from data or director modifiers).
func set_max_health(value: int) -> void:
	max_health = maxi(value, 1)
	current = max_health
	changed.emit(current, max_health)


func take_damage(amount: int, from_position := Vector2.ZERO) -> void:
	if is_dead() or amount <= 0:
		return
	current = maxi(current - amount, 0)
	damaged.emit(amount, from_position)
	changed.emit(current, max_health)
	if current == 0:
		died.emit()


func heal(amount: int) -> void:
	if is_dead() or amount <= 0:
		return
	current = mini(current + amount, max_health)
	changed.emit(current, max_health)


## Adds to the maximum and to the current health (a heart container).
func increase_max(amount: int) -> void:
	max_health += amount
	current += amount
	changed.emit(current, max_health)


func is_dead() -> bool:
	return current <= 0
