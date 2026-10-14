class_name DirectorPlan
extends RefCounted
## The adjustments the director decided for the next map: enemy stat multipliers, how many and
## which enemies, and which rooms are favoured. A plain snapshot (no nodes); Level applies it.

var style: StringName = &"balanced"
## 0 = no reaction, 1 = full reaction.
var intensity := 0.0
var aggression := 0.5
var stealth := 0.5

var health_multiplier := 1.0
var speed_multiplier := 1.0
var damage_multiplier := 1.0
var vision_multiplier := 1.0
var patrol_multiplier := 1.0
var count_multiplier := 1.0
## Room tag -> weight multiplier (given to the map generator).
var room_weights := {}
## Enemy id -> weight multiplier (used when choosing which enemy fills a spot).
var enemy_weights := {}

## Spanish, for the player.
var island_line := ""
var hints: Array[String] = []
## English, for debugging: why the director decided what it decided.
var reasons: Array[String] = []


## A plan that changes nothing.
static func neutral() -> DirectorPlan:
	return DirectorPlan.new()


## How many enemies a room should get, given the room's own base count.
func adjust_count(base: int) -> int:
	if base <= 0:
		return 0
	return maxi(roundi(base * count_multiplier), 1)


func enemy_weight(enemy_id: StringName) -> float:
	return enemy_weights.get(enemy_id, 1.0)


## Sets the director modifiers of an enemy. Call before adding the enemy to the tree.
func apply_to_enemy(enemy: Node) -> void:
	enemy.set("health_multiplier", health_multiplier)
	enemy.set("speed_multiplier", speed_multiplier)
	enemy.set("damage_multiplier", damage_multiplier)
	enemy.set("vision_multiplier", vision_multiplier)
	enemy.set("patrol_multiplier", patrol_multiplier)


## One line for the debug label and the log.
func summary_line() -> String:
	return "%s %d%% | hp x%.2f speed x%.2f dmg x%.2f vision x%.2f patrol x%.2f count x%.2f | rooms %s" % [
		style, roundi(intensity * 100.0), health_multiplier, speed_multiplier, damage_multiplier,
		vision_multiplier, patrol_multiplier, count_multiplier, room_weights]
