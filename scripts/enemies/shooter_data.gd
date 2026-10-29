class_name ShooterData
extends EnemyData
## Data of an enemy that spits projectiles and repositions between shots: the normal enemy stats (its
## `attack_range` is how far it shoots) plus the projectile it fires.

@export_group("Repositioning")
## Between shots it scurries for `shuffle_time` seconds (at `chase_speed`), then stays put for about
## `shuffle_wait`. Sideways mostly; toward the player when too far, away when too close.
@export var shuffle_time := 0.5
@export var shuffle_wait := 1.0

@export_group("Projectile")
## A scene with an EnemyOrb root.
@export var projectile_scene: PackedScene
@export var projectile_speed := 90.0
## How far the projectile flies before it vanishes.
@export var projectile_range := 220.0
## Distance from the enemy's center to where the projectile appears.
@export var muzzle_distance := 10.0
