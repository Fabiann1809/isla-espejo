class_name SlimeData
extends EnemyData
## Data of a slime: the normal enemy stats plus how it hops and how far its attack lunges.

@export_group("Hop")
## First and last frame of its `walk` cycle in which it is in the air (and so moves).
@export var air_first_frame := 1
@export var air_last_frame := 3

@export_group("Lunge")
## Speed of the short lunge of its attack (it lasts `attack_time`).
@export var leap_speed := 60.0
