class_name BossData
extends EnemyData
## Data of a boss: the normal enemy stats plus its attack patterns, its second phase and what it
## gives when it falls. One `.tres` per boss in `data/enemies/`.

@export_group("Slam (area hit around the boss)")
@export var slam_radius := 44.0
@export var slam_damage := 2
## Seconds the warning circle shows before the hit lands.
@export var slam_windup := 0.9
## The boss slams when the player is closer than this.
@export var slam_trigger_range := 56.0

@export_group("Roots (eruptions at the player's feet)")
@export var roots_count := 3
@export var roots_radius := 22.0
@export var roots_damage := 1
@export var roots_windup := 1.1
## Spots after the first are placed within this distance of the player.
@export var roots_spread := 60.0
## Optional art drawn over each roots circle (e.g. scenes/effects/boss_roots.tscn, a BossRoots).
## Only visual: the circle still shows the real zone and decides the damage.
@export var roots_effect: PackedScene

@export_group("Rhythm")
@export var strike_time := 0.25
@export var recover_time := 0.8
## The boss never leaves this distance from where it started (it is territorial).
@export var arena_radius := 150.0

@export_group("Phase two")
## Below this fraction of its health the boss becomes faster and more dangerous.
@export_range(0.0, 1.0) var phase_two_threshold := 0.5
@export var phase_two_speed := 1.3
## Multiplier of the warning times in phase two (0.75 = 25% less time to react).
@export var phase_two_windup := 0.75
@export var phase_two_extra_roots := 2

@export_group("Rewards")
## Story flag set when it is defeated (dialogues look for it).
@export var defeated_flag: StringName = &"boss_defeated"
## What appears where the boss falls (the compass fragment).
@export var pickup_scene: PackedScene

@export_group("Texts")
## Lines shown when the fight begins, as "Speaker: text" (Spanish).
@export var intro_lines: Array[String] = []
