class_name SlagSnailData
extends EnemyData
## Data of the Caracol de escoria: the normal enemy stats (slow, sturdy, a weak bite) plus the
## burning trail it leaves behind.

@export_group("Burning trail")
## Every `trail_spacing` px it moves it drops a burning patch (GroundHazard) under itself.
@export var trail_spacing := 14.0
@export var trail_radius := 9.0
@export var trail_lifetime := 8.0
@export var trail_damage := 1
@export var trail_tick := 0.5
## Nico walks at `trail_slow_factor` of his speed on it, and for `trail_slow_time` after stepping off.
@export_range(0.0, 1.0) var trail_slow_factor := 0.55
@export var trail_slow_time := 0.6
@export var trail_color := Color(0.95, 0.38, 0.08, 0.6)
## The drawn lava patch (GroundHazard.art); without it the patch is a plain `trail_color` circle.
@export var trail_art: Texture2D
