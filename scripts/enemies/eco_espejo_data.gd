class_name MirrorEchoData
extends EnemyData
## Data of the Eco del Espejo: the normal enemy stats (it never uses the melee `attack_*` numbers
## except `attack_damage`, the damage of each echoed shot) plus how it replays Nico's moves.
## `chase_speed` is the speed its run animation is drawn for (Nico's walking speed).

@export_group("Echo")
## It replays where Nico was and what he shot this many seconds ago.
@export var echo_delay := 1.0
## Fastest it may move along Nico's past path (it lags after his dashes and then catches up).
@export var follow_speed := 150.0
## Seconds the attack pose shows after an echoed shot.
@export var shot_pose_time := 0.25

@export_group("Echoed shots")
## A scene with an EnemyOrb root, fired in the direction Nico shot.
@export var projectile_scene: PackedScene
@export var projectile_speed := 150.0
@export var projectile_range := 200.0
## Distance from its center where the shot appears.
@export var muzzle_distance := 10.0
@export var shot_tint := Color(0.75, 0.88, 1.0)

@export_group("Touch")
## Touching it hurts lightly: a Hitbox of this radius around its body, live again every
## `touch_interval` seconds.
@export var touch_damage := 1
@export var touch_radius := 7.0
@export var touch_interval := 0.6

@export_group("Look")
## Its art is a reflection of Nico: tinted silver-blue and a little see-through.
@export var echo_tint := Color(0.72, 0.85, 1.0, 0.7)
