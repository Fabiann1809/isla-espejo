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
