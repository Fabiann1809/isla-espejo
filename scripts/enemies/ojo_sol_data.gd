class_name SunEyeData
extends EnemyData
## Data of the Ojo del sol: the normal enemy stats (its `attack_range` is how far it starts aiming,
## `attack_windup` how long the light ray follows Nico, `attack_time` how long the laser burns and
## `attack_damage` what it deals, once per shot) plus the ray and the laser.

@export_group("Aim")
## The ray turns toward Nico at most this fast (degrees per second), so a quick sidestep outruns it.
@export var aim_turn_speed := 100.0
## Then it holds still this long before the laser fires: the moment to step out of the line.
@export var lock_time := 0.35
## While chasing it floats toward Nico until this close, then hovers.
@export var approach_distance := 140.0
## Pause after the laser before it moves again.
@export var recover_time := 0.6

@export_group("Laser")
## The beam reaches up to the first wall, never farther than `laser_range`.
@export var laser_range := 260.0
## Thickness of the beam (px): Nico is hurt if it touches him while it burns.
@export var laser_width := 8.0
## The beam starts this far from the eye's center.
@export var muzzle_distance := 6.0

@export_group("Look")
@export var ray_width := 1.0
@export var ray_color := Color(1.0, 0.85, 0.35, 0.55)
## Blinks per second of the held ray before it fires.
@export var lock_blink_rate := 10.0
@export var laser_color := Color(1.0, 0.6, 0.15)
@export var laser_core_color := Color(1.0, 0.97, 0.75)
