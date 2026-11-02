class_name CursedDuelistData
extends EnemyData
## Data of the Duelista maldito: the normal enemy stats (its plain melee slash) plus the sidestep it
## uses against arrows and the lunge it answers with.

@export_group("Dodge")
## Chance (0..1) of sidestepping an arrow that is coming at it, rolled once per arrow.
@export_range(0.0, 1.0) var dodge_chance := 0.5
## Seconds after a sidestep before it can sidestep again.
@export var dodge_cooldown := 2.5
@export var dodge_speed := 300.0
@export var dodge_time := 0.14
## It notices player attacks within this distance of its center.
@export var arrow_sense_radius := 70.0
## An arrow counts as coming at it if its line passes this close to its center (px).
@export var arrow_lane_width := 14.0

@export_group("Lunge")
## After a sidestep it crouches for `lunge_windup` seconds (the warning), then dashes at the player
## for `lunge_time` seconds with its blade out, then rests `lunge_recover` seconds.
@export var lunge_windup := 0.2
@export var lunge_speed := 250.0
@export var lunge_time := 0.24
@export var lunge_recover := 0.5
