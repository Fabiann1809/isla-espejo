class_name AshOracleData
extends EnemyData
## Data of the Oráculo de ceniza: the normal enemy stats (its `attack_range` is how far it casts,
## `attack_windup` the staff raise before it reads Nico's course, `attack_cooldown` the rest between
## two fireballs) plus the prediction, the fireball and how it keeps its distance.

@export_group("Prediction")
## It marks where Nico will be after `lead_time` seconds if he keeps his course, never farther than
## `max_lead` px from where he stands (a dash does not send the mark across the room).
@export var lead_time := 0.8
@export var max_lead := 110.0

@export_group("Fireball")
## The mark stays this long on the ground while the fireball falls; it lands when it runs out.
@export var fall_time := 0.9
## Height (px) the fireball falls from, and its drawn radius.
@export var fall_height := 120.0
@export var ball_radius := 5.0
## Radius of the mark: the impact hurts whoever is inside it.
@export var strike_radius := 22.0
@export var strike_damage := 1
## Seconds the impact's Hitbox stays on, and how long its burst shows.
@export var impact_time := 0.12
@export var burst_time := 0.3
@export var mark_color := Color(1.0, 0.4, 0.15)
@export var ball_color := Color(1.0, 0.55, 0.2)
@export var ball_core_color := Color(1.0, 0.9, 0.5)
## Pause after the cast before it moves again.
@export var recover_time := 0.6

@export_group("Keeping its distance")
## Closer than this it backs away; farther than `approach_distance` it walks toward Nico.
@export var preferred_distance := 100.0
@export var approach_distance := 150.0
@export var retreat_speed := 42.0
## How far ahead it checks that a step back keeps it inside its room and off walls.
@export var retreat_lookahead := 24.0
