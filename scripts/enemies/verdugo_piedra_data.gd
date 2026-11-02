class_name StoneExecutionerData
extends EnemyData
## Data of the Verdugo de piedra: the normal enemy stats plus its hammer slam and the shockwave the
## slam releases. `attack_range` is how close Nico must be for it to slam, `attack_windup` the
## warning before the hammer lands, `attack_time` the pause on the ground after it.

@export_group("Slam")
## Radius of the warning circle drawn at its feet during the windup.
@export var warning_radius := 30.0
@export var warning_color := Color(1.0, 0.45, 0.2)
## Seconds it stays still after the slam (after `attack_time`) before walking again.
@export var recover_time := 1.0

@export_group("Shockwave")
## The ring grows from the hammer to `wave_max_radius` in `wave_time` seconds.
@export var wave_max_radius := 110.0
@export var wave_time := 0.75
## Thickness of the ring (px): it hurts whoever its band passes over, once per slam.
@export var wave_band := 12.0
@export var wave_damage := 2
@export var wave_color := Color(1.0, 0.55, 0.2)
