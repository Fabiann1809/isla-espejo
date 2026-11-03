class_name BroodCoreData
extends EnemyData
## Data of the Núcleo de cría: a volcanic structure that never moves (keep `move_speed`,
## `chase_speed` and `patrol_radius` at 0 and `knockback_resistance` at 1). It breeds small creatures
## while it has energy, breaks in stages as it is hurt (each breeding a fiercer brood), lets its
## queen out once near the end and explodes when it is destroyed. Its `attack_*` numbers are unused.
## The breeding numbers below are those of its first, whole stage.

@export_group("Breeding")
## The creature it breeds (a scene of an Enemy).
@export var brood_scene: PackedScene
## Creatures it can breed in all; each one spends one.
@export var energy := 6
## How many appear each time (fewer if the cap or the energy would be passed).
@export var brood_per_spawn := 2
## It does not breed while this many of its creatures are alive.
@export var max_brood := 3
## Seconds between two breedings while it hunts Nico, and before the first one.
@export var spawn_interval := 4.5
@export var first_spawn_delay := 1.2
## The pulse that warns of a breeding (plays `special`).
@export var spawn_windup := 0.7
## Distance from its center where the creatures appear.
@export var spawn_radius := 28.0
## Tint of its creatures (white: they have their own art).
@export var brood_tint := Color.WHITE
## Its art dims toward this color as its energy runs out.
@export var spent_tint := Color(0.5, 0.45, 0.45)

@export_group("Damage stages")
## The stages after the first, in order of falling health (each with its own art and brood).
@export var stages: Array[BroodStage] = []
## Entering a stage shakes its art this many px from side to side for this long.
@export var crack_shake := 2.0
@export var crack_shake_time := 0.3

@export_group("Queen")
## Let out once, when its health falls to `queen_health_below` of its maximum: the comb splits open
## (`open` animation of the broken stage) over a ring on the floor for `queen_windup` seconds, and
## she comes out of the ring, `queen_spawn_distance` px in front of it. Destroyed before that, she
## comes out at its blast instead (the ring shows while it burns). Null: no queen.
@export var queen_scene: PackedScene
@export_range(0.0, 1.0) var queen_health_below := 0.2
@export var queen_windup := 1.4
@export var queen_spawn_distance := 34.0
## The ring where she will appear (pixel art strip of square frames, played over its time; without
## it a plain circle of its color).
@export var queen_ring_radius := 24.0
@export var queen_ring_color := Color(1.0, 0.75, 0.25)
@export var queen_ring_art: Texture2D

@export_group("Explosion")
## When destroyed it burns for `fuse_time` (a warning circle of `explosion_radius` shows where) and
## then explodes, hurting Nico if he is inside.
@export var fuse_time := 0.9
@export var explosion_radius := 44.0
@export var explosion_damage := 1
## How long the blast's Hitbox stays on.
@export var blast_time := 0.12
@export var warning_color := Color(1.0, 0.35, 0.1)
@export var blast_color := Color(1.0, 0.8, 0.3)
## Pixel art of the warning ring and of the blast (strips of square frames, played over each one's
## time); without them both are plain circles of their color.
@export var warning_art: Texture2D
@export var blast_art: Texture2D
## While it burns its art flickers this many times a second.
@export var fuse_flicker := 12.0
