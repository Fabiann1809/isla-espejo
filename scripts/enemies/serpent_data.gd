class_name SerpentData
extends BossData
## Data of the Serpiente de piedra (scripts/enemies/stone_serpent.gd): a boss that charges along a
## warned lane, spits a fan of poison orbs and slithers to another spot of its arena between attacks.
## The slam/roots fields of BossData are not used by it. One `.tres` in `data/enemies/`.

@export_group("Charge (dash along a warned lane)")
## Seconds the lane shows before the dash (shorter in phase two).
@export var charge_windup := 0.85
@export var charge_speed := 300.0
## Longest dash; the lane is cut short by walls and the arena's edge.
@export var charge_length := 230.0
## Width of the lane: standing in it when the serpent passes hurts.
@export var charge_width := 30.0
@export var charge_damage := 2
## Phase two: charges in a row, and the warning of the ones after the first.
@export var phase_two_charges := 2
@export var charge_chain_windup := 0.55

@export_group("Spit (fan of poison orbs)")
@export var spit_windup := 0.8
@export var spit_count := 3
@export var phase_two_extra_orbs := 2
## Angle between two orbs of the fan.
@export var spit_gap_degrees := 18.0
@export var orb_speed := 85.0
@export var orb_range := 240.0
@export var orb_damage := 1
## Orbs leave from this far in front of the serpent.
@export var muzzle_distance := 18.0
@export var projectile_scene: PackedScene

@export_group("Moving between zones")
## Spots are picked in this central fraction of its room's floor (or of arena_radius around its home
## outside a room). In a room the whole floor is its arena; arena_radius only applies outside one.
@export_range(0.1, 1.0) var zone_spread := 0.8
## In a room it keeps this far from the room's edge (slithering and charging).
@export var floor_margin := 40.0
## A new spot is at least this far from where it is.
@export var zone_min_move := 64.0
## It slithers to spots at least this far from Nico.
@export var zone_keep_distance := 80.0
## It attacks anyway after slithering this long (a rock in the way).
@export var zone_move_time := 1.6
## Seconds it rears with its hood open when it enters phase two.
@export var phase_two_roar := 0.6
