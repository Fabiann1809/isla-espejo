class_name BronzeBellRingerData
extends EnemyData
## Data of the Campanero de bronce: the normal enemy stats (its `attack_range` is how close Nico must
## be for it to strike the bell, `attack_windup` the warning before the first stroke) plus the rings
## its bell sends out.

@export_group("Strike")
## Radius of the warning circle drawn at its feet during the windup.
@export var warning_radius := 26.0
@export var warning_color := Color(1.0, 0.75, 0.3)
## Seconds it stays still after the last ring leaves the bell before walking again.
@export var recover_time := 0.9

@export_group("Rings")
## Rings sent per strike, one every `ring_interval` seconds.
@export var ring_count := 3
@export var ring_interval := 0.55
## Each ring grows from the bell to `ring_max_radius` in `ring_time` seconds.
@export var ring_max_radius := 120.0
@export var ring_time := 0.9
## Thickness of a ring (px): it hurts Nico when its band passes over him, once per ring.
@export var ring_band := 10.0
@export var ring_damage := 1
@export var ring_color := Color(1.0, 0.8, 0.35)
## Pixel art of the ring (tools/make_campanero_bronce_art.py): square cells drawn at growing radii,
## the last one at the art's full radius; without it the ring is drawn in `ring_color`.
@export var ring_art: Texture2D
