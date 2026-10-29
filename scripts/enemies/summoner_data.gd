class_name SummonerData
extends EnemyData
## Data of an enemy that grows minions from its body: the normal enemy stats (its `attack_range` is
## the reach of its melee slam) plus how it summons.

@export_group("Summoning")
## The minion that is grown (a scene of an Enemy).
@export var minion_scene: PackedScene
## How many appear each time (fewer if the limit would be passed).
@export var minions_per_summon := 2
## It does not summon while this many of its minions are alive.
@export var max_minions := 4
## Seconds before it can summon again after doing so.
@export var summon_cooldown := 4.5
## It summons when the player is closer than this and in sight.
@export var summon_range := 170.0
## Distance from its body where the minions appear.
@export var spawn_radius := 26.0
