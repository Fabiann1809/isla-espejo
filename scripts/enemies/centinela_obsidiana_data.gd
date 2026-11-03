class_name ObsidianSentinelData
extends EnemyData
## Data of the Centinela de obsidiana: the normal enemy stats plus its shield and its slow turning.

@export_group("Shield")
## Width of the front arc the shield covers, in degrees, centered on where it faces.
@export_range(1.0, 360.0) var shield_arc := 140.0
## Seconds the shield stays lowered after its swing (the recover phase): the window to hit it.
@export var shield_down_time := 0.9
## Seconds the block pose (`special`) shows after stopping a hit.
@export var block_pose_time := 0.3

@export_group("Turning")
## How fast it turns toward the player while hunting, in degrees per second.
@export var turn_rate := 110.0
## It only starts a swing when the player is within this angle (degrees) of where it faces.
@export var swing_aim_angle := 35.0

@export_group("Masked")
## While a Máscara parásita rides it (on top of the frenzy): the shield covers the front and both
## sides, and it turns faster, so only its back stays open.
@export_range(1.0, 360.0) var masked_shield_arc := 240.0
@export var masked_turn_rate := 170.0
