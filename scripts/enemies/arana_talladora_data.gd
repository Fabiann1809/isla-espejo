class_name CarvingSpiderData
extends EnemyData
## Data of the Araña talladora: the normal enemy stats (its `attack_range` is how far from itself it
## can drill, its `attack_*` timings are the drilling's) plus how it scuttles between drills and the
## floor patches it makes sink (SinkingFloor).

@export_group("Scuttling")
## Between drills it scuttles to a new spot up to this far away, choosing among `reposition_samples`
## candidates the one closest to `preferred_distance` from Nico.
@export var reposition_distance := 90.0
@export var reposition_samples := 6
@export var preferred_distance := 80.0
## Gives up a run after this long (blocked), and waits this long at a spot before the next.
@export var reposition_time := 1.0
@export var spot_wait := 0.25
## Spots stay this far inside the edges of its room.
@export var room_margin := 24.0

@export_group("Drilling")
## Patches each drill makes sink: the first under Nico, the others `pit_spread` px around it.
@export var pits_per_drill := 2
@export var pit_spread := 40.0
## Side of a patch, in floor tiles, and whether patches line up with the floor's tiles.
@export var pit_tiles := 2
@export var snap_to_tiles := true

@export_group("Sinking floor")
## The crack is the warning: the patch sinks after `crack_time`, stays a pit for `sunk_time` and
## closes over `close_time`.
@export var crack_time := 0.9
@export var sunk_time := 2.5
@export var close_time := 0.4
## The pit hurts whoever stands in it once every `pit_tick` seconds.
@export var pit_damage := 1
@export var pit_tick := 0.7
## Nico on the patch when it sinks is held in the hole this long (a dodge breaks free).
@export var hold_time := 0.5
@export var crack_color := Color(1.0, 0.55, 0.15, 0.9)
@export var pit_color := Color(0.06, 0.03, 0.03, 0.95)
@export var rim_color := Color(0.85, 0.3, 0.08, 0.9)
## Width of the crack that runs from the spider's drill to each patch while it cracks.
@export var crack_trail_width := 1.0
