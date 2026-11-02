class_name CrystalSalamanderData
extends EnemyData
## Data of the Salamandra de cristal: the normal enemy stats (its `attack_range` is how far it spits,
## its `attack_*` timings are the spit's) plus how it runs along the edges of its room and the hot
## crystals it lobs, which stay on the ground.

@export_group("Running the edges")
## Patrol and repositioning spots lie on a line this far inside the edges of its room.
@export var edge_margin := 28.0
## While hunting it runs to a new spot up to this far away, choosing among `reposition_samples`
## candidates the one closest to `preferred_distance` from Nico.
@export var reposition_distance := 110.0
@export var reposition_samples := 6
@export var preferred_distance := 100.0
## Gives up a run after this long (blocked), and rests this long at a spot before the next.
@export var reposition_time := 1.4
@export var spot_wait := 0.35

@export_group("Crystal lob")
## Flight of the lobbed crystal: time to land, height of its arc and half the size of its diamond.
@export var flight_time := 0.75
@export var lob_height := 28.0
@export var crystal_size := 3.0
## Distance from its center to where the crystal leaves its mouth.
@export var muzzle_distance := 8.0
@export var crystal_color := Color(1.0, 0.8, 0.35)
## The warning circle on the landing spot during the flight.
@export var warning_color := Color(1.0, 0.55, 0.2)

@export_group("Crystal patch")
## The patch the crystal leaves: it hurts every `hazard_tick` seconds and slows a little.
@export var hazard_radius := 12.0
@export var hazard_lifetime := 4.5
@export var hazard_damage := 1
@export var hazard_tick := 0.5
@export_range(0.0, 1.0) var hazard_slow_factor := 0.8
@export var hazard_slow_time := 0.6
@export var hazard_color := Color(1.0, 0.72, 0.3, 0.6)
