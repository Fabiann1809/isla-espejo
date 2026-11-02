class_name AbyssHandsData
extends EnemyData
## Data of the Manos del abismo: the normal enemy stats (its `attack_windup` is the warning before
## the hand comes out, `attack_damage` what a grab hurts and `attack_cooldown` the rest under the
## ground between grabs; `attack_range` and `attack_time` are not used) plus where it comes out and
## how its arm reaches, holds and sinks back.

@export_group("Coming out")
## It comes out on the edge of its room nearest Nico: on a line this far inside the edge, slid up
## to `edge_jitter` px along it. Without a room it comes out `fallback_distance` px from him.
@export var edge_margin := 10.0
@export var edge_jitter := 20.0
@export var fallback_distance := 90.0
## The warning circle on the spot it comes out of.
@export var warning_radius := 14.0
@export var warning_color := Color(1.0, 0.35, 0.1)

@export_group("Reach and grab")
## The arm shoots out from the edge toward where Nico stood, up to `reach_length`.
@export var reach_length := 130.0
@export var reach_speed := 300.0
@export var grab_radius := 9.0
## Where the grab and the arm meet the hand, from its feet.
@export var hand_offset := Vector2(0, -10)
## A caught Nico is held this long, pulled toward the hand at `hold_pull_speed` (0 keeps him in
## place); a dodge breaks free.
@export var hold_time := 0.9
@export var hold_pull_speed := 0.0
## Then the arm winds back, the hand stays out at the edge (it can be hit) and sinks.
@export var retract_speed := 180.0
@export var out_time := 1.2
@export var sink_time := 0.4

@export_group("Looks")
@export var arm_width := 7.0
@export var arm_color := Color(0.62, 0.2, 0.08)
@export var arm_edge_color := Color(1.0, 0.5, 0.12)
@export var pool_radius := 11.0
@export var pool_color := Color(1.0, 0.45, 0.1, 0.75)
