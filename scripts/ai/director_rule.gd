class_name DirectorRule
extends Resource
## How the island reacts to one play style. The numbers are the reaction at full intensity;
## the director blends them with "no change" (1.0) according to how clear the player's style is.
## One rule per style in `data/ai/director_rules.tres`.

@export_group("Enemy stats (multipliers)")
@export var health_multiplier := 1.0
@export var speed_multiplier := 1.0
@export var damage_multiplier := 1.0
## Sight range. Above 1 the enemies notice a stealthy player from farther away.
@export var vision_multiplier := 1.0
## Patrol distance. Above 1 enemies wander farther, so hiding spots are less reliable.
@export var patrol_multiplier := 1.0

@export_group("Population")
## Multiplies the number of enemies in combat rooms.
@export var count_multiplier := 1.0
## Enemy id (scene file name) -> weight multiplier when picking which enemies appear.
@export var enemy_weights: Dictionary = {}

@export_group("Rooms")
## Room tag -> weight multiplier (e.g. "ambush": 3.0 makes ambush rooms three times as likely).
@export var room_weights: Dictionary = {}

@export_group("Texts")
## What the island says when the map starts (Spanish). Empty = says nothing.
@export var island_line := ""
## Short Spanish lines describing the reaction, shown on the death screen.
@export var hints: Array[String] = []
