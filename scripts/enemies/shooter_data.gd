class_name ShooterData
extends EnemyData
## Data of an enemy that stands its ground and spits projectiles: the normal enemy stats (its
## `attack_range` is how far it shoots) plus the projectile it fires.

@export_group("Projectile")
## A scene with an EnemyOrb root.
@export var projectile_scene: PackedScene
@export var projectile_speed := 90.0
## How far the projectile flies before it vanishes.
@export var projectile_range := 220.0
## Distance from the enemy's center to where the projectile appears.
@export var muzzle_distance := 10.0
