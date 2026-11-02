class_name BroodCoreData
extends EnemyData
## Data of the Núcleo de cría: a volcanic structure that never moves (keep `move_speed`,
## `chase_speed` and `patrol_radius` at 0 and `knockback_resistance` at 1). It breeds small creatures
## while it has energy and explodes when it is destroyed. Its `attack_*` numbers are unused.

@export_group("Breeding")
## The creature it breeds (a scene of an Enemy).
@export var brood_scene: PackedScene
## Creatures it can breed in all; each one spends one.
@export var energy := 6
## How many appear each time (fewer if the cap or the energy would be passed).
@export var brood_per_spawn := 2
## It does not breed while this many of its creatures are alive.
@export var max_brood := 3
## Seconds between two breedings while it hunts Nico, and before the first one.
@export var spawn_interval := 4.5
@export var first_spawn_delay := 1.2
## The pulse that warns of a breeding (plays `special`).
@export var spawn_windup := 0.7
## Distance from its center where the creatures appear.
@export var spawn_radius := 28.0
## Tint of its creatures (they reuse another enemy's art).
@export var brood_tint := Color(1.0, 0.55, 0.35)
## Its art dims toward this color as its energy runs out.
@export var spent_tint := Color(0.5, 0.45, 0.45)

@export_group("Explosion")
## When destroyed it burns for `fuse_time` (a warning circle of `explosion_radius` shows where) and
## then explodes, hurting Nico if he is inside.
@export var fuse_time := 0.9
@export var explosion_radius := 44.0
@export var explosion_damage := 1
## How long the blast's Hitbox stays on.
@export var blast_time := 0.12
@export var warning_color := Color(1.0, 0.35, 0.1)
@export var blast_color := Color(1.0, 0.8, 0.3)
## While it burns its art flickers this many times a second.
@export var fuse_flicker := 12.0
