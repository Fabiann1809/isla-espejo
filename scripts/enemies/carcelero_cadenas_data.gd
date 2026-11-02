class_name ChainJailerData
extends EnemyData
## Data of the Carcelero de cadenas: the normal enemy stats (its `attack_*` numbers are the melee
## swing that follows a catch) plus the chain it throws to drag Nico close.

@export_group("Chain throw")
## It throws the chain when Nico is farther than `chain_min_range` and within `chain_range`.
@export var chain_range := 120.0
@export var chain_min_range := 40.0
## Aiming before the throw; the aim follows Nico except for the last `aim_lock_time` seconds, so a
## sidestep at the right moment dodges it.
@export var chain_windup := 0.65
@export var aim_lock_time := 0.2
## Speed of the chain's tip going out and coming back (px/s).
@export var chain_speed := 280.0
@export var retract_speed := 360.0
## Radius of the tip's Hitbox.
@export var tip_radius := 6.0
@export var chain_damage := 1
## Seconds between two throws (the melee swing keeps its own `attack_cooldown`).
@export var chain_cooldown := 3.0
## Rest after the chain is back before it acts again.
@export var chain_recover := 0.25

@export_group("Pull")
## A caught Nico is dragged to the jailer at `pull_speed` for up to `pull_time` seconds (it must
## outlast his hurt state, during which the drag waits). A dodge breaks free.
@export var pull_speed := 240.0
@export var pull_time := 1.1

@export_group("Chain look")
@export var chain_width := 2.0
@export var chain_color := Color(0.62, 0.6, 0.58)
@export var aim_width := 1.0
@export var aim_color := Color(1.0, 0.45, 0.2, 0.55)
## Where the chain leaves the body, relative to the jailer's center (facing right; flipped left).
@export var hand_offset := Vector2(6, -6)
