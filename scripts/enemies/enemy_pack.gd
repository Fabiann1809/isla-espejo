class_name EnemyPack
extends RefCounted
## Enemies of one kind that share a room act as a group: their attacks take turns, one after another
## instead of all in the same instant. Mates are the living siblings (same room node) with the same
## enemy id. Each enemy marks the physics tick when it starts an attack.

const STRIKE_META := &"pack_strike_tick"


## The living enemies of the same kind in the same room, without `enemy`.
static func mates(enemy: Enemy) -> Array[Enemy]:
	var result: Array[Enemy] = []
	var parent := enemy.get_parent()
	if parent == null:
		return result
	for node in parent.get_children():
		var other := node as Enemy
		if other != null and other != enemy and not other.is_dead() and other.data != null \
				and other.data.id == enemy.data.id:
			result.append(other)
	return result


## True when no mate started an attack in the last `gap` seconds.
static func my_turn(enemy: Enemy, gap: float) -> bool:
	var now := Engine.get_physics_frames()
	var gap_ticks := int(ceil(gap * Engine.physics_ticks_per_second))
	for mate in mates(enemy):
		if mate.has_meta(STRIKE_META) and now - int(mate.get_meta(STRIKE_META)) < gap_ticks:
			return false
	return true


## Records that `enemy` starts an attack now.
static func mark_strike(enemy: Enemy) -> void:
	enemy.set_meta(STRIKE_META, Engine.get_physics_frames())
