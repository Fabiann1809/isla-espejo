class_name DoomedForgerData
extends EnemyData
## Data of the Forjador condenado: the normal enemy stats (its `attack_*` numbers are its hammer
## swing up close) plus the glowing iron blocks it drops from above, which stay as solid obstacles
## (IronBlock) until they cool down.

@export_group("Block drop")
## It calls the blocks down when Nico is this close and it sees him, once every `drop_cooldown`
## seconds; `drop_windup` is the special animation before the warnings appear.
@export var drop_range := 150.0
@export var drop_windup := 0.6
@export var drop_cooldown := 3.5
## Blocks per drop: the first on Nico, the others `drop_spread` px around him.
@export var blocks_per_drop := 3
@export var drop_spread := 36.0
## Blocks of this forger standing (or falling) at once; it does not drop more while at the cap.
@export var max_blocks := 5
## The warning circle lasts the whole fall.
@export var warning_color := Color(1.0, 0.45, 0.1)

@export_group("Where blocks may land")
## Blocks never land in the door lanes of its room: the cross this wide each side of its middle.
@export var door_lane_half_width := 48.0
## Nor closer than this to the edges of its room.
@export var room_margin := 12.0

@export_group("Iron block")
## Footprint (the solid part on the floor) and how tall it is drawn.
@export var block_size := Vector2(22, 14)
@export var block_height := 14.0
## The fall: time from the warning to the impact, and the height it falls from.
@export var fall_time := 0.8
@export var fall_height := 70.0
## The impact hurts for this long around its footprint (a little wider than it).
@export var impact_damage := 1
@export var impact_time := 0.15
@export var impact_margin := 3.0
## Seconds it stands as an obstacle (the last `fade_time` fading), and how long it glows.
@export var block_lifetime := 7.0
@export var fade_time := 0.6
@export var cool_time := 3.0
@export var hot_color := Color(1.0, 0.5, 0.15)
@export var cold_color := Color(0.27, 0.25, 0.27)
@export var edge_color := Color(1.0, 0.85, 0.4)
