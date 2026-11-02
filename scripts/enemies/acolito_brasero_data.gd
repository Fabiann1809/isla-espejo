class_name BrazierAcolyteData
extends ShooterData
## Data of the Acólito del brasero: a shooter (its projectile settings are each flame of the fan)
## that fires a fan of fire and backs away from Nico to keep its distance.

@export_group("Fan of fire")
## Flames per shot, spread evenly over `fan_angle` degrees centred on Nico.
@export var fan_count := 5
@export var fan_angle := 70.0
## Tint of the flames (the orb's art is multiplied by it).
@export var fire_tint := Color(1.0, 0.62, 0.35)

@export_group("Keeping its distance")
## Closer than this, it backs away instead of shuffling.
@export var preferred_distance := 90.0
@export var retreat_speed := 50.0
## After backing away this long without a break it stands and shoots anyway, so it cannot be kept
## running forever.
@export var retreat_max_time := 1.4
## How far ahead it checks that a step back keeps it inside its room.
@export var retreat_lookahead := 24.0
