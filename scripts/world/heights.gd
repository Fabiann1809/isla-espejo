class_name Heights
extends RefCounted
## Three real height levels for a map: LOW (0: ground, rivers, pits, lava), MID (1: terraces, bridges,
## the Ruinas' raised rooms; `HIGH` is its old name) and TOP (2: the temple's highest platforms). What
## blocks an actor depends on its level, set with `set_level()`; each level has its own blocking layer
## (`block_layer()`), and one more layer lets projectiles see a cliff of height 2:
##   - `block_low` (layer 8): every cell of height >= 1 (a terrace footprint, a bridge deck, a cliff).
##     Blocks level-0 actors only.
##   - `block_high` (layer 9): what a level-1 actor may not enter: the edge of a level-1 platform, the
##     rails of a bridge and the footprint of a level-2 platform. Blocks level-1 actors only.
##   - `block_top` (layer 10): what a level-2 actor may not enter: the edge of a level-2 platform.
##     Blocks level-2 actors only.
##   - `cliff_top` (layer 11): every cell of height 2, seen only by level-1 projectiles, so a shot from a
##     terrace stops at a higher cliff. No body ever has this bit in its mask.
##   - `world` (layer 1) blocks everybody; `water` (layer 7) blocks low actors only (a bridge crosses it).
## Actors change level only through a `StairZone`. Everything starts LOW, so flat rooms (the forest)
## have no object on layers 8 to 11 and behave exactly as before, and the Ruinas only use 8 and 9.

const LOW := 0
const MID := 1
## The Ruinas' name for MID: their raised rooms, terraces and bridges are level 1.
const HIGH := MID
const TOP := 2
const LEVELS := 3

const WATER_LAYER := 7
const BLOCK_LOW_LAYER := 8
const BLOCK_HIGH_LAYER := 9
const BLOCK_TOP_LAYER := 10
const CLIFF_TOP_LAYER := 11

const LEVEL_META := &"height_level"
## Whether the body's mask had the water bit before it was given a level.
const WATER_META := &"height_water"


static func level_of(node: Node) -> int:
	return int(node.get_meta(LEVEL_META, LOW))


## The layer that holds what blocks an actor standing on `level`: 8, 9 or 10.
static func block_layer(level: int) -> int:
	return BLOCK_LOW_LAYER + clampi(level, LOW, TOP)


## Whether the body flies: its mask never had the water bit, so it crosses water, lava and pits.
## A body that was never given a level gets its current one first, so the answer is always known.
static func is_flyer(node: CollisionObject2D) -> bool:
	if not node.has_meta(WATER_META):
		set_level(node, level_of(node))
	return not node.get_meta(WATER_META)


## Puts a body or an area (an actor, a projectile or a wall sensor) on `level`: its mask learns which
## of the level-bound obstacles it collides with. A mask that had no water bit (a flyer) never gets one.
static func set_level(node: CollisionObject2D, level: int) -> void:
	if not node.has_meta(WATER_META):
		node.set_meta(WATER_META, node.get_collision_mask_value(WATER_LAYER))
	node.set_meta(LEVEL_META, level)
	node.set_collision_mask_value(WATER_LAYER, level == LOW and node.get_meta(WATER_META))
	for other in LEVELS:
		node.set_collision_mask_value(block_layer(other), other == level)
	node.set_collision_mask_value(CLIFF_TOP_LAYER, false)


## Like `set_level` for a projectile's wall sensor: a shot only stops at what is higher than it, seen
## from below (a level-0 shot at `block_low`, a level-1 shot at `cliff_top`); it flies over edges, rails
## and water, and a level-2 shot is stopped by none of them.
static func set_projectile_level(sensor: CollisionObject2D, level: int) -> void:
	sensor.set_meta(LEVEL_META, level)
	sensor.set_collision_mask_value(BLOCK_LOW_LAYER, level == LOW)
	sensor.set_collision_mask_value(BLOCK_HIGH_LAYER, false)
	sensor.set_collision_mask_value(BLOCK_TOP_LAYER, false)
	sensor.set_collision_mask_value(CLIFF_TOP_LAYER, level == MID)
