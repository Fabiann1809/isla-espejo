class_name DevouringWheelData
extends EnemyData
## Data of the Rueda devoradora: the normal enemy stats plus its rolling bursts. `attack_range` is
## how far away it starts a burst (it needs to see Nico) and `attack_cooldown` an extra rest after
## the stop.

@export_group("Burst")
## Seconds its carved face glows, aimed at Nico, before it rolls.
@export var windup_time := 0.5
@export var roll_speed := 170.0
## Longest a burst rolls (seconds) before it brakes.
@export var roll_time := 2.4
## It brakes after this many bounces.
@export var max_bounces := 4
## Seconds it takes to slow down to a stop.
@export var brake_time := 0.5
## Seconds it stands still after a burst (the moment to hit it).
@export var rest_time := 0.9

@export_group("Bounce")
## After a bounce its new course leans this much toward Nico (0 = a pure reflection).
@export_range(0.0, 1.0) var aim_bias := 0.35
## A leaned course must still leave the wall at least this much (cosine with the wall's normal).
@export_range(0.0, 1.0) var min_leave := 0.3

@export_group("Look")
## Radius of the stone (px): how much it turns per pixel rolled.
@export var wheel_radius := 13.0
## How far below the frame's center the hub of the wheel is (px); the sprite spins around it.
@export var hub_offset := 6.0
## Seconds the launch frames (special) show at the start of a burst, before it spins.
@export var launch_time := 0.25
