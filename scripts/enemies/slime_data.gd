class_name SlimeData
extends EnemyData
## Data of a slime: the normal enemy stats plus how it leaps at the player.
## The leap lasts `attack_time` (the hitbox is active the whole way), so it covers
## leap_speed * attack_time pixels.

@export_group("Leap")
## Speed of the jump toward where the player stood when the windup began.
@export var leap_speed := 170.0
