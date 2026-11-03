class_name Heights
extends RefCounted
## Two real height levels for a map (the Ruinas): LOW (ground, rivers, pits) and HIGH (terraces and
## bridges). What blocks an actor depends on its level, set with `set_level()`:
##   - `block_low` (layer 8): the footprint of a terrace or a bridge deck. Blocks low actors only.
##   - `block_high` (layer 9): the edge of a terrace and the rails of a bridge. Blocks high actors only.
##   - `world` (layer 1) blocks everybody; `water` (layer 7) blocks low actors only (a bridge crosses it).
## Actors change level only through a `StairZone`. Everything starts LOW, so flat rooms (the forest,
## the temple) have no object on layers 8 and 9 and behave exactly as before.

const LOW := 0
const HIGH := 1

const WATER_LAYER := 7
const BLOCK_LOW_LAYER := 8
const BLOCK_HIGH_LAYER := 9

const LEVEL_META := &"height_level"
## Whether the body's mask had the water bit before it was given a level.
const WATER_META := &"height_water"


static func level_of(node: Node) -> int:
	return int(node.get_meta(LEVEL_META, LOW))


## Puts a body or an area (an actor, a projectile or a wall sensor) on `level`: its mask learns which
## of the level-bound obstacles it collides with. A mask that had no water bit (a flyer) never gets one.
static func set_level(node: CollisionObject2D, level: int) -> void:
	if not node.has_meta(WATER_META):
		node.set_meta(WATER_META, node.get_collision_mask_value(WATER_LAYER))
	var high := level == HIGH
	node.set_meta(LEVEL_META, level)
	node.set_collision_mask_value(WATER_LAYER, not high and node.get_meta(WATER_META))
	node.set_collision_mask_value(BLOCK_LOW_LAYER, not high)
	node.set_collision_mask_value(BLOCK_HIGH_LAYER, high)


## Like `set_level` for a projectile's wall sensor: a shot only stops at a terrace seen from below
## (`block_low`); it flies over edges, rails and water, and a high shot is stopped by none of them.
static func set_projectile_level(sensor: CollisionObject2D, level: int) -> void:
	sensor.set_meta(LEVEL_META, level)
	sensor.set_collision_mask_value(BLOCK_LOW_LAYER, level == LOW)
	sensor.set_collision_mask_value(BLOCK_HIGH_LAYER, false)
