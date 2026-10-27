class_name WeaponData
extends Resource
## Definition of the player's weapon. One `.tres` per weapon in `data/weapons/`.
## The player reads its attack numbers from here instead of keeping them in code, so a new
## weapon is a new file and not a change to `Player`.

@export var id: StringName = &"weapon"
## Player-facing text (Spanish).
@export var display_name := "Arma"
@export var damage := 1
## Seconds the attack state lasts (the swing animation is fitted to it).
@export var attack_time := 0.2
@export var attack_cooldown := 0.35
## Share of the walking speed Nico keeps while attacking (0 = rooted, 1 = full speed).
@export_range(0.0, 1.0) var move_factor := 0.3

@export_group("Ranged")
## Scene shot by the attack (see scripts/player/arrow.gd). Without one the attack only plays its pose.
@export var projectile_scene: PackedScene
@export var projectile_speed := 260.0
## Pixels the projectile flies before it vanishes.
@export var projectile_range := 200.0
## Moment of the attack (0 = start, 1 = end) when the projectile leaves.
@export_range(0.0, 1.0) var release_at := 0.5
