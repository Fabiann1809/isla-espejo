class_name PossessedVaseData
extends EnemyData
## Data of the Vasija poseída: the normal enemy stats (it never walks or strikes itself; its health
## does not matter, a hit breaks it) plus its disguise, its decoys and the creature it releases.
## `detection_range` must reach at least `trigger_radius`.

@export_group("Disguise")
## Nico closer than this (px) makes it shake and break.
@export var trigger_radius := 34.0
## Seconds it shakes (the warning) before breaking.
@export var shake_time := 0.55
## How far its picture jumps from side to side while it shakes (px).
@export var shake_amplitude := 1.0

@export_group("Decoys")
## Harmless vases it scatters around itself when it appears (same picture, breakable, they block).
@export var decoy_scene: PackedScene
@export var decoy_count_min := 2
@export var decoy_count_max := 3
## Distance from the real vase to each decoy (px).
@export var decoy_min_distance := 36.0
@export var decoy_max_distance := 64.0
## Least distance between two vases, and from Nico (px).
@export var decoy_spacing := 24.0
## Radius around a decoy that must be free of walls, ponds and bodies (px).
@export var decoy_clearance := 10.0
## Decoys keep this far (px) from the room's middle lines, the lanes between its doors.
@export var door_lane_half_width := 40.0

@export_group("Creature")
@export var creature_scene: PackedScene
## Seconds into the break when the creature comes out.
@export var release_delay := 0.35
## The creature appears this far from the vase, toward Nico (px).
@export var creature_offset := 8.0
