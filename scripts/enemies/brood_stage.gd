class_name BroodStage
extends Resource
## One damage stage of the Núcleo de cría past the first (see BroodCoreData.stages): once its health
## falls to `health_below` it cracks into this stage's art and breeds fiercer creatures, faster.

## It enters this stage when its health falls to this fraction of its maximum or less.
@export_range(0.0, 1.0) var health_below := 0.66
## Its art in this stage (null keeps the art it has); entering plays its `crack` animation.
@export var sprite_frames: SpriteFrames
## Energy it gets back on entering: the cracked hive spills out more brood.
@export var energy_bonus := 0

@export_group("Breeding")
@export var spawn_interval := 4.5
@export var brood_per_spawn := 2
@export var max_brood := 3

@export_group("Creatures")
## Multiplied into the director's multipliers its creatures inherit from the core.
@export var brood_speed := 1.0
@export var brood_damage := 1.0
## Scale of their `attack_cooldown` (below 1 they bite more often).
@export var brood_cooldown := 1.0
## Their tint, so a fiercer brood reads at a glance.
@export var brood_tint := Color.WHITE
