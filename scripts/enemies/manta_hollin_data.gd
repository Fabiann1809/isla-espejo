class_name SootMantaData
extends EnemyData
## Data of the soot manta (SootManta): the normal enemy stats plus its flight and its dive.
## `attack_windup` is how long the dive is marked before it swoops, `attack_damage` what the swoop
## deals and `attack_cooldown` how long it hovers before it may dive again. `chase_speed` is its
## gliding speed while it circles Nico.

@export_group("Flight")
## How high its art flies over its shadow (px, on top of `sprite_offset`), and how low it swoops.
@export var fly_height := 14.0
@export var dive_height := 2.0
## How fast it climbs back or settles to its flying height (px/s).
@export var height_speed := 30.0
## Its shadow on the ground: where (from its position) and how big.
@export var shadow_offset := Vector2(0, 6)
@export var shadow_size := Vector2(16, 5)

@export_group("Hover")
## It circles Nico at this distance, aiming this many degrees ahead of where it is on the circle.
@export var hover_distance := 72.0
@export var orbit_lead_degrees := 35.0
## It may dive while its distance to Nico is within `hover_tolerance` of `hover_distance`.
@export var hover_tolerance := 22.0

@export_group("Dive")
## Warning circle on the ground where Nico stood when the dive is marked.
@export var dive_warning_radius := 14.0
@export var dive_warning_color := Color(1.0, 0.45, 0.2)
## While marking, it rears back a little.
@export var windup_backoff_speed := 18.0
## The swoop: speed, and how far past the marked spot it keeps going.
@export var dive_speed := 230.0
@export var dive_overshoot := 40.0
## A swoop that advances less than this fraction of its speed in a frame has hit a wall: it climbs.
@export_range(0.0, 1.0) var dive_blocked_fraction := 0.25
## After the swoop it glides on, slowing down, while it climbs back for this long.
@export var climb_time := 0.55
@export var climb_drag := 400.0
