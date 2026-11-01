class_name DiverData
extends EnemyData
## Data of a flying enemy that circles the player and dives through them: the normal enemy stats
## (`chase_speed` is its flying speed, `attack_windup` the warning before a dive, `attack_time` the
## longest a dive lasts) plus how it circles, dives and takes turns with its group.

@export_group("Circling")
## Distance from the player it circles at, and how much it weaves in and out of it (px).
@export var orbit_radius := 46.0
@export var weave_amplitude := 12.0
## Weaves per second.
@export var weave_frequency := 1.4
## How far ahead along the circle it steers (radians): more = rounder, faster circling.
@export var orbit_lead := 0.8
## Seconds between changes of direction (a random time in this range): the zig-zag.
@export var turn_time_min := 0.9
@export var turn_time_max := 2.2

@export_group("Dive")
## It dives when the player is this close and in sight.
@export var dive_trigger_range := 84.0
@export var dive_speed := 250.0
## How far past the player's position the dive goes (px).
@export var dive_overshoot := 30.0
## After a dive it climbs away at this speed for the recovery (`attack_cooldown` / 2).
@export var climb_speed := 95.0
## Bats of the same room dive at least this many seconds apart.
@export var group_gap := 0.55

@export_group("Warning")
@export var warn_color := Color(1.0, 0.35, 0.3)
@export var lane_width := 5.0
## Brightness of the flash that blinks on the bat during the warning.
@export var flash_color := Color(2.0, 0.8, 0.8)
