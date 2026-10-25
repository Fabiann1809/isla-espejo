class_name Tuning
extends RefCounted
## The one place for the values added in the level-1 polish pass (see docs/PULIDO_LOG.md): how
## enemies keep to their rooms and share the chase, and the look and "game feel" of the forest.
## Gameplay data (enemy stats, rooms, the director's rules) stays in `data/`; these are pacing and
## presentation limits. Every effect can be switched off here.

# --- Enemies ---------------------------------------------------------------------------------------
## A patrol point stays this far inside the enemy's room (px), so patrols do not walk into the walls.
const PATROL_MARGIN := 24.0
## A patrol leg gives up after this many times its expected walking time (blocked by a tree or rock).
const PATROL_TIMEOUT_FACTOR := 2.0
## A patrol that barely moves for this long (s) is blocked: the enemy rests and picks another point.
const PATROL_STALL_TIME := 0.4
## Boss eruptions (roots) stay this far inside the arena's outer edge (px): the wall is 16 px thick.
const ARENA_MARGIN := 24.0
