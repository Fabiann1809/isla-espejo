class_name ChargerData
extends EnemyData
## Data of an enemy that hunts in packs and charges: the normal enemy stats (`attack_windup` is the
## warning before a charge, `attack_time` the longest a charge lasts at full speed) plus how it charges
## and how its pack spreads around the player.

@export_group("Charge")
## It charges when the player is this close and in sight.
@export var charge_trigger_range := 96.0
@export var charge_speed := 220.0
## How far past the player's position the charge goes (px); `attack_time` caps its length.
@export var charge_overshoot := 40.0
## The charge follows the player during the warning and locks this many seconds before it starts.
@export var aim_lock_time := 0.25
## Extra rest (seconds) after crashing into a wall, a tree or a pond: the moment to punish it.
@export var wall_stun := 0.7

@export_group("Pack")
## Mates of its room this close join the hunt when one of them notices the player.
@export var pack_alert_range := 180.0
## Mates do not start charges closer together than this (seconds).
@export var pack_gap := 0.4
## Mates spread around the player at this distance, this many degrees apart, before charging.
@export var flank_distance := 70.0
@export var flank_spread_degrees := 70.0
## A flanker charges once it is this close to its spot, or after this many seconds in range.
@export var flank_tolerance := 24.0
@export var flank_patience := 1.5

@export_group("Warning")
@export var warn_color := Color(1.0, 0.45, 0.2)
@export var lane_width := 12.0
