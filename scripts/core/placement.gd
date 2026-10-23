class_name Placement
extends RefCounted
## Moving a physics body "at once" (spawn, map change, teleport). With physics interpolation on,
## the engine draws a body between its last two physics positions; after a jump that would show it
## sliding across the map for one tick, so the interpolation is reset right after the move.

## Tick of the last reset, kept on the node so tests can check that a jump really reset it.
const RESET_META := &"interpolation_reset_tick"


## Puts `node` at the global position `at` with no in-between frame.
static func teleport(node: Node2D, at: Vector2) -> void:
	node.global_position = at
	reset(node)


## For a node already placed (e.g. positioned and then added to the tree).
static func reset(node: Node) -> void:
	node.reset_physics_interpolation()
	node.set_meta(RESET_META, Engine.get_physics_frames())
