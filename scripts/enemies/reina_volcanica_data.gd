class_name VolcanicQueenData
extends EnemyData
## Data of the Reina volcánica (VolcanicQueen): the normal enemy stats plus its sting and its brood.
## `attack_range` is how close Nico must be for it to mark a sting, `attack_windup` how long the
## warning lane shows, `attack_time` how long the lunge lasts (its reach is `lunge_speed` times it)
## and `attack_cooldown` the rest before the next sting. `chase_speed` is its flying speed.

@export_group("Sting")
## While it marks the sting it backs off a little (px/s).
@export var windup_backoff_speed := 14.0
## The lunge with the stinger out: speed over `attack_time`.
@export var lunge_speed := 210.0
## After the lunge it hangs in the air, open to hits, for this long.
@export var lunge_recover := 0.45

@export_group("Brood")
## The creature it summons (a scene of an Enemy).
@export var brood_scene: PackedScene
## How many appear each time (fewer if the cap would be passed).
@export var brood_per_summon := 2
## It does not summon while this many of its creatures are alive.
@export var max_brood := 3
## Seconds between two summons while it hunts Nico, and before the first one.
@export var summon_interval := 6.5
@export var first_summon_delay := 2.0
## The call that warns of a summon (plays `special`), and the pose after it.
@export var summon_windup := 0.8
@export var summon_recover := 0.4
## Distance from its center where the creatures appear.
@export var spawn_radius := 26.0
## Tint of its creatures (white: they have their own art).
@export var brood_tint := Color.WHITE
## Its creatures burn out when it dies.
@export var brood_dies_with_queen := true
