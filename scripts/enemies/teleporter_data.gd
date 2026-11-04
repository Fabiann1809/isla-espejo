class_name TeleporterData
extends EnemyData
## Data of an enemy that fades out and reappears next to the player: the normal enemy stats (its
## `attack_range`, `attack_windup` and `attack_time` are the strike it makes, up close or after
## reappearing) plus how it teleports.

@export_group("Teleport")
## It teleports when the player is in sight, closer than this and farther than `teleport_min_range`
## (closer than that it just strikes).
@export var teleport_range := 150.0
@export var teleport_min_range := 40.0
## Seconds before it can teleport again.
@export var teleport_cooldown := 2.6
## Fading out (can still be hit in the first half), hidden while the arrival spot is warned, and
## fading back in at the arrival spot (seconds). It cannot be hit from halfway through the fade out
## until it has fully reappeared.
@export var fade_time := 0.35
@export var hidden_time := 0.45
@export var appear_time := 0.2
## Distance from the player at which it reappears (behind or beside them).
@export var appear_distance := 30.0

@export_group("Warning")
@export var warn_color := Color(0.6, 0.35, 1.0)
@export var warn_radius := 9.0
